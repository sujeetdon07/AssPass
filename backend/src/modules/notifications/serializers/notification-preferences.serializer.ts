import { NotificationPreference } from '../entities/notification-preference.entity.js';

export interface NotificationPreferencesResponse {
  userId: string;
  messagesEnabled: boolean;
  socialEnabled: boolean;
  communityEnabled: boolean;
  marketplaceEnabled: boolean;
  businessEnabled: boolean;
  systemEnabled: boolean;
  pushEnabled: boolean;
  emailEnabled: boolean;
  smsEnabled: boolean;
  updatedAt: string;
}

export function serializeNotificationPreferences(
  prefs: NotificationPreference,
): NotificationPreferencesResponse {
  return {
    userId: prefs.userId,
    messagesEnabled: prefs.messagesEnabled,
    socialEnabled: prefs.socialEnabled,
    communityEnabled: prefs.communityEnabled,
    marketplaceEnabled: prefs.marketplaceEnabled,
    businessEnabled: prefs.businessEnabled,
    systemEnabled: prefs.systemEnabled,
    pushEnabled: prefs.pushEnabled,
    emailEnabled: prefs.emailEnabled,
    smsEnabled: prefs.smsEnabled,
    updatedAt: prefs.updatedAt instanceof Date ? prefs.updatedAt.toISOString() : String(prefs.updatedAt),
  };
}
