import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Event } from './entities/event.entity.js';
import { EventRsvp } from './entities/event-rsvp.entity.js';
import { Community } from '../communities/entities/community.entity.js';
import { CommunityMember } from '../communities/entities/community-member.entity.js';
import { User } from '../users/entities/user.entity.js';
import { AuthModule } from '../auth/auth.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { EventsService } from './events.service.js';
import { EventsController } from './events.controller.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Event,
      EventRsvp,
      Community,
      CommunityMember,
      User,
    ]),
    AuthModule,
    NotificationsModule,
  ],
  controllers: [EventsController],
  providers: [EventsService],
  exports: [EventsService],
})
export class EventsModule {}
