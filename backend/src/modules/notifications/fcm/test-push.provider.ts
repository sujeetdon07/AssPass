import { Injectable } from '@nestjs/common';
import {
  NotificationPushProvider,
  PushNotificationPayload,
  PushSendResult,
} from './notification-push.provider.interface.js';

@Injectable()
export class TestPushProvider implements NotificationPushProvider {
  public sentNotifications: PushNotificationPayload[] = [];
  public shouldFail: boolean = false;
  public failError: string = 'Simulated test error';
  public invalidTokens: Set<string> = new Set<string>();

  isAvailable(): boolean {
    return true;
  }

  getProviderName(): string {
    return 'TEST';
  }

  async send(payload: PushNotificationPayload): Promise<PushSendResult> {
    if (this.shouldFail) {
      return {
        success: false,
        error: this.failError,
      };
    }

    if (this.invalidTokens.has(payload.token)) {
      return {
        success: false,
        invalidToken: true,
        error: 'Simulated invalid/unregistered token',
      };
    }

    this.sentNotifications.push(payload);
    return {
      success: true,
      messageId: `test-msg-${Date.now()}-${this.sentNotifications.length}`,
    };
  }

  async sendMulticast(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<PushSendResult[]> {
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

  reset(): void {
    this.sentNotifications = [];
    this.shouldFail = false;
    this.invalidTokens.clear();
  }
}
