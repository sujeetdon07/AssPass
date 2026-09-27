import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

@Entity('notification_preferences')
export class NotificationPreference {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid', unique: true })
  userId!: string;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user?: User;

  @Column({ type: 'boolean', default: true })
  messagesEnabled!: boolean;

  @Column({ type: 'boolean', default: true })
  socialEnabled!: boolean;

  @Column({ type: 'boolean', default: true })
  communityEnabled!: boolean;

  @Column({ type: 'boolean', default: true })
  marketplaceEnabled!: boolean;

  @Column({ type: 'boolean', default: true })
  businessEnabled!: boolean;

  @Column({ type: 'boolean', default: true })
  systemEnabled!: boolean;

  @Column({ type: 'boolean', default: true })
  pushEnabled!: boolean;

  @Column({ type: 'boolean', default: false })
  emailEnabled!: boolean;

  @Column({ type: 'boolean', default: false })
  smsEnabled!: boolean;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;
}
