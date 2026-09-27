import { Notification } from '../entities/notification.entity.js';
import { toPublicProfile, PublicProfileProjection } from '../../messaging/serializers/public-profile.serializer.js';

export interface NotificationResponse {
  id: string;
  recipientId: string;
  senderId?: string | null;
  sender?: PublicProfileProjection | null;
  type: string;
  category: string;
  title: string;
  body: string;
  data: Record<string, any>;
  deepLink?: string | null;
  isRead: boolean;
  readAt?: string | null;
  createdAt: string;
}

export function serializeNotification(notification: Notification): NotificationResponse {
  return {
    id: notification.id,
    recipientId: notification.recipientId,
    senderId: notification.senderId ?? null,
    sender: notification.sender ? toPublicProfile(notification.sender) : null,
    type: notification.type,
    category: notification.category,
    title: notification.title,
    body: notification.body,
    data: notification.data || {},
    deepLink: notification.deepLink ?? null,
    isRead: notification.isRead,
    readAt: notification.readAt ? notification.readAt.toISOString() : null,
    createdAt: notification.createdAt instanceof Date ? notification.createdAt.toISOString() : notification.createdAt,
  };
}
