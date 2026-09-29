import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

export enum MessageType {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE',
}

@Entity('messages')
@Unique('UQ_messages_sender_clientMessageId', ['senderId', 'clientMessageId'])
@Index('IDX_messages_conv_createdAt', ['conversationId', 'createdAt'])
export class Message {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  conversationId!: string;

  @ManyToOne('Conversation', 'messages', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conversationId' })
  conversation?: any;

  @Index()
  @Column({ type: 'uuid' })
  senderId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'senderId' })
  sender?: User;

  @Column({ type: 'varchar', length: 100 })
  clientMessageId!: string;

  @Column({ type: 'text', nullable: true })
  content?: string | null;

  @Column({
    type: 'enum',
    enum: MessageType,
    default: MessageType.TEXT,
  })
  messageType!: MessageType;

  @Column({ type: 'text', nullable: true })
  mediaUrl?: string | null;

  @Column({ type: 'text', nullable: true })
  mediaThumbnailUrl?: string | null;

  @Column({ type: 'int', nullable: true })
  mediaWidth?: number | null;

  @Column({ type: 'int', nullable: true })
  mediaHeight?: number | null;

  @Column({ type: 'int', nullable: true })
  mediaSize?: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  mediaMimeType?: string | null;

  @Column({ type: 'timestamp with time zone', nullable: true })
  readAt?: Date | null;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;

  @DeleteDateColumn({ type: 'timestamp with time zone', nullable: true })
  deletedAt?: Date | null;
}
