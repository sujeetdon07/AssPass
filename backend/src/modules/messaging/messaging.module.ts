import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Conversation } from './entities/conversation.entity.js';
import { ConversationParticipant } from './entities/conversation-participant.entity.js';
import { Message } from './entities/message.entity.js';
import { UserBlock } from './entities/user-block.entity.js';
import { ConversationReport } from './entities/conversation-report.entity.js';
import { User } from '../users/entities/user.entity.js';
import { AuthSession } from '../auth/entities/auth-session.entity.js';
import { MessagingService } from './messaging.service.js';
import { MessagingGateway } from './messaging.gateway.js';
import { MessagingController } from './messaging.controller.js';
import { WsJwtGuard } from './guards/ws-jwt.guard.js';
import { AuthModule } from '../auth/auth.module.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Conversation,
      ConversationParticipant,
      Message,
      UserBlock,
      ConversationReport,
      User,
      AuthSession,
    ]),
    AuthModule,
  ],
  controllers: [MessagingController],
  providers: [MessagingService, MessagingGateway, WsJwtGuard],
  exports: [MessagingService, MessagingGateway],
})
export class MessagingModule {}
