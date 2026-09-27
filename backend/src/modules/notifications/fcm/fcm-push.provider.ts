import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import {
  NotificationPushProvider,
  PushNotificationPayload,
  PushSendResult,
} from './notification-push.provider.interface.js';

@Injectable()
export class FcmPushProvider implements NotificationPushProvider {
  private readonly logger = new Logger(FcmPushProvider.name);
  private readonly isConfigured: boolean = false;
  private readonly projectId?: string;
  private readonly messaging?: admin.messaging.Messaging;

  constructor(private readonly configService: ConfigService) {
    this.projectId = this.configService.get<string>('FCM_PROJECT_ID');

    // Credentials: prefer an inline JSON string (CI/secrets manager),
    // then fall back to a file path (local dev with downloaded key file).
    // NEVER log credential values.
    const serviceAccountKey = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_KEY');
    const serviceAccountPath = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');

    if (!this.projectId || (!serviceAccountKey && !serviceAccountPath)) {
      this.isConfigured = false;
      this.logger.warn(
        '[FcmPushProvider] Firebase credentials not configured. ' +
          'Push delivery disabled; notifications will be in-app only. ' +
          'Set FCM_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT_KEY (or FIREBASE_SERVICE_ACCOUNT_PATH) ' +
          'in your environment to enable real FCM delivery.',
      );
      return;
    }

    try {
      const fbAdmin: any = (admin as any).initializeApp ? admin : ((admin as any).default ?? admin);
      const apps: any[] = fbAdmin.apps ?? (admin as any).apps ?? [];
      // Reuse the Firebase app if already initialized (e.g., after hot-reload).
      const existingApp = apps.find((a: any) => a?.name === 'aaspaas');

      let credential: admin.credential.Credential;

      if (serviceAccountKey) {
        // JSON string from environment/secrets manager.
        const parsed = JSON.parse(serviceAccountKey) as admin.ServiceAccount;
        credential = fbAdmin.credential.cert(parsed);
      } else {
        // File path to downloaded service-account JSON.
        credential = fbAdmin.credential.cert(serviceAccountPath!);
      }

      const app =
        existingApp ??
        fbAdmin.initializeApp(
          {
            credential,
            projectId: this.projectId,
          },
          'aaspaas',
        );

      this.messaging = app.messaging();
      this.isConfigured = true;
      this.logger.log(
        `[FcmPushProvider] Initialized for Firebase project: ${this.projectId}`,
      );
    } catch (err) {
      this.isConfigured = false;
      // Log the error type but never log the credential value itself.
      this.logger.error(
        '[FcmPushProvider] Failed to initialize Firebase Admin SDK. ' +
          'Check that FIREBASE_SERVICE_ACCOUNT_KEY contains valid JSON or ' +
          'FIREBASE_SERVICE_ACCOUNT_PATH points to a valid file.',
        err instanceof Error ? err.message : String(err),
      );
    }
  }

  isAvailable(): boolean {
    return this.isConfigured;
  }

  getProviderName(): string {
    return 'FCM';
  }

  async send(payload: PushNotificationPayload): Promise<PushSendResult> {
    if (!this.isConfigured || !this.messaging) {
      return {
        success: false,
        error: 'Push credentials not configured',
      };
    }

    if (!payload.token || payload.token.trim().length === 0) {
      return {
        success: false,
        invalidToken: true,
        error: 'Empty or invalid device token',
      };
    }

    try {
      const message: admin.messaging.Message = {
        token: payload.token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: payload.channelId ?? 'aaspaas_default',
            sound: payload.sound ?? 'default',
          },
        },
        // Data payload — only safe routing metadata, no private content.
        data: payload.data ?? {},
      };

      const messageId = await this.messaging.send(message);

      this.logger.debug(
        `[FcmPushProvider] Delivered to token …${payload.token.slice(-10)}: ${messageId}`,
      );

      return { success: true, messageId };
    } catch (err: any) {
      // Classify unregistered/invalid token errors so callers can deactivate them.
      const errorCode: string = err?.code ?? err?.errorInfo?.code ?? '';
      const isUnregistered =
        errorCode === 'messaging/registration-token-not-registered' ||
        errorCode === 'messaging/invalid-registration-token' ||
        errorCode === 'messaging/invalid-argument' ||
        (err?.message as string | undefined)?.includes('UNREGISTERED') ||
        (err?.message as string | undefined)?.includes('invalid-registration-token');

      if (isUnregistered) {
        this.logger.warn(
          `[FcmPushProvider] Unregistered/invalid token detected — will be deactivated.`,
        );
      } else {
        this.logger.error(
          `[FcmPushProvider] FCM send failed (code=${errorCode}):`,
          err?.message ?? err,
        );
      }

      return {
        success: false,
        invalidToken: isUnregistered,
        error: err?.message || 'FCM send failed',
      };
    }
  }

  async sendMulticast(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<PushSendResult[]> {
    if (!tokens.length) return [];
    return Promise.all(
      tokens.map((token) =>
        this.send({
          token,
          title,
          body,
          data,
        }),
      ),
    );
  }
}

