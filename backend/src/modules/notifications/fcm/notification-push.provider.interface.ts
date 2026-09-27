export interface PushNotificationPayload {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  channelId?: string;
  sound?: string;
}

export interface PushSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
  invalidToken?: boolean;
}

export interface NotificationPushProvider {
  send(payload: PushNotificationPayload): Promise<PushSendResult>;
  sendMulticast(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<PushSendResult[]>;
  isAvailable(): boolean;
  getProviderName(): string;
}
