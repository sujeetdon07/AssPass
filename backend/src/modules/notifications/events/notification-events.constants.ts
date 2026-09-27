export const NotificationEvents = {
  SERVER_NOTIFICATION_NEW: 'notification:new',
  SERVER_NOTIFICATION_READ: 'notification:read',
  SERVER_NOTIFICATION_UNREAD_COUNT: 'notification:unread-count',
} as const;

export type NotificationEventName = (typeof NotificationEvents)[keyof typeof NotificationEvents];
