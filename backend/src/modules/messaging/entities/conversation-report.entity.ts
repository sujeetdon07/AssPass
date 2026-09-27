import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

export enum ConversationReportReason {
  SPAM = 'spam',
  HARASSMENT = 'harassment',
  INAPPROPRIATE = 'inappropriate',
  FRAUD = 'fraud',
  OTHER = 'other',
}

export enum ConversationReportStatus {
  PENDING = 'pending',
  REVIEWED = 'reviewed',
  DISMISSED = 'dismissed',
}

@Entity('conversation_reports')
export class ConversationReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter?: User;

  @Index()
  @Column({ type: 'uuid' })
  conversationId!: string;

  @ManyToOne('Conversation', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conversationId' })
  conversation?: any;

  @Column({ type: 'uuid', nullable: true })
  messageId?: string | null;

  @ManyToOne('Message', { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'messageId' })
  message?: any;

  @Column({
    type: 'enum',
    enum: ConversationReportReason,
  })
  reason!: ConversationReportReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  description?: string | null;

  @Column({
    type: 'enum',
    enum: ConversationReportStatus,
    default: ConversationReportStatus.PENDING,
  })
  status!: ConversationReportStatus;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;
}
