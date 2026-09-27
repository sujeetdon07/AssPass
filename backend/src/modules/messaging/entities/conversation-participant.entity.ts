import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

@Entity('conversation_participants')
@Unique('UQ_conversation_participants_conv_user', ['conversationId', 'userId'])
export class ConversationParticipant {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  conversationId!: string;

  @ManyToOne('Conversation', 'participants', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conversationId' })
  conversation?: any;

  @Index()
  @Column({ type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user?: User;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  joinedAt!: Date;

  @Column({ type: 'uuid', nullable: true })
  lastReadMessageId?: string | null;

  @Column({ type: 'timestamp with time zone', nullable: true })
  lastReadAt?: Date | null;

  @Column({ type: 'timestamp with time zone', nullable: true })
  mutedAt?: Date | null;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;
}
