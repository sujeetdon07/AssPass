import { NotificationType } from '../enums/notification-type.enum.js';
import { NotificationCategory } from '../enums/notification-category.enum.js';

export interface CreateNotificationDto {
  recipientId: string;
  senderId?: string | null;
  type: NotificationType;
  category: NotificationCategory;
  title: string;
  body: string;
  data?: Record<string, any>;
  deepLink?: string | null;
  deduplicationKey?: string | null;
}
