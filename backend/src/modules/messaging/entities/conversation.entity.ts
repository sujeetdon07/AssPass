import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  Index,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

@Entity('conversations')
@Unique('UQ_conversations_user1_user2', ['user1Id', 'user2Id'])
export class Conversation {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /**
   * Canonical ordering: user1Id must be lexicographically smaller than user2Id.
   */
  @Index()
  @Column({ type: 'uuid' })
  user1Id!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user1Id' })
  user1?: User;

  @Index()
  @Column({ type: 'uuid' })
  user2Id!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user2Id' })
  user2?: User;

  @Index()
  @Column({ type: 'timestamp with time zone', default: () => 'now()' })
  lastMessageAt!: Date;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;

  @DeleteDateColumn({ type: 'timestamp with time zone', nullable: true })
  deletedAt?: Date | null;

  @OneToMany('ConversationParticipant', 'conversation')
  participants?: any[];

  @OneToMany('Message', 'conversation')
  messages?: any[];
}
