import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Notification } from './entities/notification.entity.js';
import { DeviceToken } from './entities/device-token.entity.js';
import { NotificationPreference } from './entities/notification-preference.entity.js';
import { User } from '../users/entities/user.entity.js';
import { NotificationsService } from './notifications.service.js';
import { NotificationsController } from './notifications.controller.js';
import { MessagingModule } from '../messaging/messaging.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { NOTIFICATION_PUSH_PROVIDER } from './fcm/push-provider.token.js';
import { FcmPushProvider } from './fcm/fcm-push.provider.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Notification,
      DeviceToken,
      NotificationPreference,
      User,
    ]),
    MessagingModule,
    AuthModule,
  ],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    {
      provide: NOTIFICATION_PUSH_PROVIDER,
      useClass: FcmPushProvider,
    },
  ],
  exports: [NotificationsService, NOTIFICATION_PUSH_PROVIDER],
})
export class NotificationsModule {}
