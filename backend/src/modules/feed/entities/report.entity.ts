import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

export enum ReportTargetType {
  POST = 'post',
  COMMENT = 'comment',
  COMMUNITY = 'community',
}

export enum ReportReason {
  SPAM = 'spam',
  HARASSMENT = 'harassment',
  INAPPROPRIATE = 'inappropriate',
  MISLEADING = 'misleading',
  ILLEGAL_CONTENT = 'illegal_content',
  OTHER = 'other',
}

export enum ReportStatus {
  PENDING = 'pending',
  REVIEWED = 'reviewed',
  DISMISSED = 'dismissed',
}

@Entity('reports')
@Unique(['reporterId', 'targetType', 'targetId'])
export class Report {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter!: User;

  @Index()
  @Column({
    type: 'enum',
    enum: ReportTargetType,
  })
  targetType!: ReportTargetType;

  @Index()
  @Column({ type: 'uuid' })
  targetId!: string;

  @Column({
    type: 'enum',
    enum: ReportReason,
  })
  reason!: ReportReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  details?: string | null;

  @Column({
    type: 'enum',
    enum: ReportStatus,
    default: ReportStatus.PENDING,
  })
  status!: ReportStatus;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
