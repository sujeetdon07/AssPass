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

@Entity('moderation_audit_logs')
@Index(['targetType', 'targetId'])
@Index(['actorId', 'createdAt'])
@Index(['action'])
export class ModerationAuditLog {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  actorId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'actorId' })
  actor?: User;

  @Column({ type: 'varchar', length: 50 })
  action!: string; // 'report_submitted', 'report_reviewed', 'report_actioned', 'report_dismissed', 'content_removed', 'content_restored', 'user_restricted'

  @Column({ type: 'varchar', length: 50 })
  targetType!: string;

  @Column({ type: 'varchar', length: 100 })
  targetId!: string;

  @Column({ type: 'uuid', nullable: true })
  reportId?: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  reason?: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata?: Record<string, any> | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
