import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { MessagingService } from './messaging.service.js';
import { MessagingEvents } from './events/messaging-events.constants.js';
import { WsJwtGuard, AuthenticatedSocketUser } from './guards/ws-jwt.guard.js';
import { SendMessageDto } from './dto/send-message.dto.js';

@WebSocketGateway({
  namespace: '/messaging',
  cors: {
    origin: '*',
    credentials: true,
  },
})
export class MessagingGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(MessagingGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly messagingService: MessagingService,
    private readonly wsJwtGuard: WsJwtGuard,
  ) {}

  afterInit(server: Server) {
    server.use(async (socket, next) => {
      try {
        const user = await this.wsJwtGuard.authenticateSocket(socket);
        if (!user) {
          return next(new Error('Authentication required.'));
        }
        next();
      } catch (err: any) {
        next(new Error(err?.message || 'Authentication error'));
      }
    });
  }

  /**
   * Handle new WebSocket connection and authenticate user.
   */
  async handleConnection(client: Socket) {
    try {
      let user = client.data?.user as AuthenticatedSocketUser | undefined;
      if (!user) {
        user = (await this.wsJwtGuard.authenticateSocket(client)) || undefined;
      }
      if (!user) {
        this.logger.warn(`[MessagingGateway] Unauthorized socket connection rejected: ${client.id}`);
        client.emit(MessagingEvents.SERVER_ERROR, { message: 'Authentication required.' });
        client.disconnect(true);
        return;
      }

      // Join user-specific room for targeted notifications & direct events
      await client.join(`user:${user.userId}`);

      // Set presence to online
      await this.messagingService.setPresence(user.userId, true);

      this.logger.log(`[MessagingGateway] User connected: ${user.userId} (socket ${client.id})`);
    } catch (err) {
      this.logger.error(`[MessagingGateway] Connection error for ${client.id}:`, err);
      client.disconnect(true);
    }
  }

  /**
   * Handle socket disconnection.
   */
  async handleDisconnect(client: Socket) {
    const user = client.data?.user as AuthenticatedSocketUser | undefined;
    if (user?.userId) {
      // Check if user has other active sockets before marking offline
      const sockets = await this.server.in(`user:${user.userId}`).fetchSockets();
      if (sockets.length <= 1) {
        await this.messagingService.setPresence(user.userId, false);
      }
      this.logger.log(`[MessagingGateway] User disconnected: ${user.userId} (socket ${client.id})`);
    }
  }

  /**
   * Join a conversation room.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_CONVERSATION_JOIN)
  async handleJoinConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const user = client.data?.user as AuthenticatedSocketUser;
    if (!user) throw new WsException('Unauthorized');

    try {
      // Validates participant membership & blocking
      await this.messagingService.getConversationById(data.conversationId, user.userId);

      await client.join(`conv:${data.conversationId}`);

      client.emit(MessagingEvents.SERVER_CONVERSATION_JOINED, {
        conversationId: data.conversationId,
      });
    } catch (err: any) {
      client.emit(MessagingEvents.SERVER_ERROR, {
        message: err.message || 'Could not join conversation.',
      });
    }
  }

  /**
   * Leave a conversation room.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_CONVERSATION_LEAVE)
  async handleLeaveConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    await client.leave(`conv:${data.conversationId}`);
  }

  /**
   * Send a direct message in real time.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_MESSAGE_SEND)
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { conversationId: string; clientMessageId: string; content: string },
  ) {
    const user = client.data?.user as AuthenticatedSocketUser;
    if (!user) throw new WsException('Unauthorized');

    try {
      const dto: SendMessageDto = {
        clientMessageId: payload.clientMessageId,
        content: payload.content,
      };

      const { message, recipientId } = await this.messagingService.sendMessage(
        payload.conversationId,
        user.userId,
        dto,
      );

      const messagePayload = {
        id: message.id,
        conversationId: message.conversationId,
        senderId: message.senderId,
        clientMessageId: message.clientMessageId,
        content: message.content,
        messageType: message.messageType,
        createdAt: message.createdAt,
        readAt: message.readAt,
      };

      // 1. Emit acknowledgement to sender
      client.emit(MessagingEvents.SERVER_MESSAGE_ACK, {
        messageId: message.id,
        clientMessageId: message.clientMessageId,
        conversationId: message.conversationId,
        status: 'sent',
        createdAt: message.createdAt,
      });

      // 2. Emit new message to conversation room (excluding sender)
      client.to(`conv:${payload.conversationId}`).emit(MessagingEvents.SERVER_MESSAGE_NEW, messagePayload);

      // 3. Emit new message to recipient's personal user room (for unread counter / inbox updates)
      this.server.to(`user:${recipientId}`).emit(MessagingEvents.SERVER_MESSAGE_NEW, messagePayload);
      this.server.to(`user:${recipientId}`).emit(MessagingEvents.SERVER_CONVERSATION_UPDATE, {
        conversationId: payload.conversationId,
        lastMessage: messagePayload,
      });
    } catch (err: any) {
      client.emit(MessagingEvents.SERVER_ERROR, {
        clientMessageId: payload.clientMessageId,
        message: err.message || 'Failed to send message.',
        statusCode: err.status || 500,
      });
    }
  }

  /**
   * Mark messages in conversation as read.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_MESSAGE_READ)
  async handleMessageRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const user = client.data?.user as AuthenticatedSocketUser;
    if (!user) throw new WsException('Unauthorized');

    try {
      const result = await this.messagingService.markAsRead(data.conversationId, user.userId);

      // Notify the other participant in the conversation room
      client.to(`conv:${data.conversationId}`).emit(MessagingEvents.SERVER_MESSAGE_READ, {
        conversationId: data.conversationId,
        readerId: user.userId,
        readAt: result.readAt,
      });
    } catch (err: any) {
      client.emit(MessagingEvents.SERVER_ERROR, {
        message: err.message || 'Failed to mark messages as read.',
      });
    }
  }

  /**
   * Typing indicator started.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_TYPING_START)
  async handleTypingStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const user = client.data?.user as AuthenticatedSocketUser;
    if (!user) return;

    const allowed = await this.messagingService.shouldEmitTyping(user.userId, data.conversationId);
    if (allowed) {
      client.to(`conv:${data.conversationId}`).emit(MessagingEvents.SERVER_TYPING_START, {
        conversationId: data.conversationId,
        userId: user.userId,
      });
    }
  }

  /**
   * Typing indicator stopped.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_TYPING_STOP)
  async handleTypingStop(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const user = client.data?.user as AuthenticatedSocketUser;
    if (!user) return;

    client.to(`conv:${data.conversationId}`).emit(MessagingEvents.SERVER_TYPING_STOP, {
      conversationId: data.conversationId,
      userId: user.userId,
    });
  }

  /**
   * Check user presence.
   */
  @SubscribeMessage(MessagingEvents.CLIENT_PRESENCE_SUBSCRIBE)
  async handlePresenceSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { userId: string },
  ) {
    const isOnline = await this.messagingService.isUserOnline(data.userId);
    client.emit(MessagingEvents.SERVER_PRESENCE_UPDATE, {
      userId: data.userId,
      status: isOnline ? 'online' : 'offline',
    });
  }

  /**
   * Emit an event to a user's personal room across all active sockets.
   */
  emitToUser(userId: string, event: string, payload: unknown): void {
    if (this.server) {
      this.server.to(`user:${userId}`).emit(event, payload);
    }
  }
}

