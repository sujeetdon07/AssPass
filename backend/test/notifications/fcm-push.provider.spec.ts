import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ConfigService } from '@nestjs/config';

// ── firebase-admin mock ────────────────────────────────────────────────────────
// We mock the entire firebase-admin module so no real network calls or
// credential parsing happens during tests. Credentials must NEVER appear in
// test output — the mock satisfies this requirement by design.
const mockSend = vi.fn<[unknown], Promise<string>>();
const mockMessaging = { send: mockSend };
const mockApp = { messaging: () => mockMessaging, name: 'aaspaas' };

vi.mock('firebase-admin', () => ({
  default: {},
  apps: [] as typeof mockApp[],
  credential: {
    cert: vi.fn(() => ({ type: 'service_account' })),
  },
  initializeApp: vi.fn(() => mockApp),
}));

// Import AFTER mock is registered.
import * as admin from 'firebase-admin';
import { FcmPushProvider } from '../../src/modules/notifications/fcm/fcm-push.provider.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeConfigService(
  projectId: string | undefined,
  keyJson: string | undefined,
  keyPath: string | undefined = undefined,
): ConfigService {
  return {
    get: vi.fn((k: string) => {
      if (k === 'FCM_PROJECT_ID') return projectId;
      if (k === 'FIREBASE_SERVICE_ACCOUNT_KEY') return keyJson;
      if (k === 'FIREBASE_SERVICE_ACCOUNT_PATH') return keyPath;
      return undefined;
    }),
  } as unknown as ConfigService;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('FcmPushProvider', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Reset apps list so each test starts fresh.
    (admin.apps as unknown as typeof mockApp[]).length = 0;
  });

  // ── Degraded / unconfigured mode ──────────────────────────────────────────

  it('should initialize in degraded mode when credentials are missing', () => {
    const provider = new FcmPushProvider(makeConfigService(undefined, undefined));
    expect(provider.isAvailable()).toBe(false);
    expect(provider.getProviderName()).toBe('FCM');
  });

  it('should return error on send when credentials are not configured', async () => {
    const provider = new FcmPushProvider(makeConfigService(undefined, undefined));
    const result = await provider.send({ token: 'token-abc', title: 'Hello', body: 'World' });
    expect(result.success).toBe(false);
    expect(result.error).toContain('Push credentials not configured');
  });

  // ── Configured mode (JSON key string) ────────────────────────────────────

  it('should be available when project ID and JSON key are configured', () => {
    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );
    expect(provider.isAvailable()).toBe(true);
  });

  it('should call firebase-admin messaging.send and return real messageId', async () => {
    mockSend.mockResolvedValueOnce('projects/asspass-07/messages/real-id-123');

    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );

    const result = await provider.send({
      token: 'valid-device-token-1234567890',
      title: 'Hello neighbor',
      body: 'Someone commented',
      data: { notificationId: 'notif-1', type: 'POST_COMMENTED' },
      channelId: 'aaspaas_social',
    });

    expect(result.success).toBe(true);
    expect(result.messageId).toBe('projects/asspass-07/messages/real-id-123');
    expect(mockSend).toHaveBeenCalledOnce();

    // Verify FCM message structure — no private content in payload data.
    const sentMessage = mockSend.mock.calls[0][0] as Record<string, unknown>;
    const data = (sentMessage as { data?: Record<string, string> }).data ?? {};
    const sensitiveKeys = ['phoneNumber', 'email', 'address', 'privateKey', 'body'];
    for (const key of sensitiveKeys) {
      expect(data).not.toHaveProperty(key);
    }
  });

  // ── Configured mode (file path) ────────────────────────────────────────────

  it('should initialize using FIREBASE_SERVICE_ACCOUNT_PATH when KEY is absent', () => {
    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', undefined, '/secrets/firebase.json'),
    );
    expect(provider.isAvailable()).toBe(true);
    expect(vi.mocked(admin.credential.cert)).toHaveBeenCalledWith('/secrets/firebase.json');
  });

  it('should prefer FIREBASE_SERVICE_ACCOUNT_KEY over PATH', () => {
    const keyJson = JSON.stringify({ type: 'service_account' });
    new FcmPushProvider(makeConfigService('asspass-07', keyJson, '/secrets/firebase.json'));
    // cert should have been called with the parsed object (from JSON.parse), not the file path.
    const certArg = vi.mocked(admin.credential.cert).mock.calls[0][0];
    expect(typeof certArg).toBe('object');
    expect(certArg).not.toBe('/secrets/firebase.json');
  });

  // ── Invalid / empty token ─────────────────────────────────────────────────

  it('should report invalidToken when token is empty string', async () => {
    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );
    const result = await provider.send({ token: '   ', title: 'Hello', body: 'World' });
    expect(result.success).toBe(false);
    expect(result.invalidToken).toBe(true);
  });

  // ── FCM error handling ────────────────────────────────────────────────────

  it('should classify UNREGISTERED token error correctly', async () => {
    const fcmError = Object.assign(new Error('Token not registered'), {
      code: 'messaging/registration-token-not-registered',
    });
    mockSend.mockRejectedValueOnce(fcmError);

    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );
    const result = await provider.send({
      token: 'stale-device-token',
      title: 'Hi',
      body: 'Test',
    });

    expect(result.success).toBe(false);
    expect(result.invalidToken).toBe(true);
  });

  it('should return non-invalidToken failure for generic FCM errors', async () => {
    mockSend.mockRejectedValueOnce(new Error('network timeout'));

    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );
    const result = await provider.send({
      token: 'valid-token-xyz',
      title: 'Hi',
      body: 'Test',
    });

    expect(result.success).toBe(false);
    expect(result.invalidToken).toBeFalsy();
    expect(result.error).toContain('network timeout');
  });

  // ── Invalid credentials JSON ──────────────────────────────────────────────

  it('should initialize in degraded mode when JSON key is malformed', () => {
    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', 'NOT_VALID_JSON'),
    );
    expect(provider.isAvailable()).toBe(false);
  });

  // ── Multicast ─────────────────────────────────────────────────────────────

  it('should send multicast to multiple tokens', async () => {
    mockSend
      .mockResolvedValueOnce('msg-id-1')
      .mockResolvedValueOnce('msg-id-2');

    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );
    const results = await provider.sendMulticast(
      ['token-1', 'token-2'],
      'Announcement',
      'Community meeting',
      { notificationId: 'n-1', type: 'COMMUNITY_ANNOUNCEMENT' },
    );

    expect(results).toHaveLength(2);
    expect(results[0].success).toBe(true);
    expect(results[0].messageId).toBe('msg-id-1');
    expect(results[1].success).toBe(true);
    expect(results[1].messageId).toBe('msg-id-2');
  });

  it('should return empty array for empty token list in multicast', async () => {
    const provider = new FcmPushProvider(
      makeConfigService('asspass-07', JSON.stringify({ type: 'service_account' })),
    );
    const results = await provider.sendMulticast([], 'Title', 'Body');
    expect(results).toHaveLength(0);
  });

  // ── No credentials in logs ────────────────────────────────────────────────
  // (Structural test: if provider.logger.error is called, the message must
  //  not contain the service-account key value.)

  it('should not log service account key value on init failure', () => {
    const logSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const fakeKey = JSON.stringify({ private_key: 'SHOULD_NEVER_APPEAR_IN_LOGS' });

    // Force initializeApp to throw so the error path is exercised.
    vi.mocked(admin.initializeApp).mockImplementationOnce(() => {
      throw new Error('Firebase init failed for test');
    });

    new FcmPushProvider(makeConfigService('asspass-07', fakeKey));

    const logOutput = logSpy.mock.calls.map((c) => JSON.stringify(c)).join('\n');
    expect(logOutput).not.toContain('SHOULD_NEVER_APPEAR_IN_LOGS');

    logSpy.mockRestore();
  });
});


