import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';
import {
  SafetyReportTargetType,
  SafetyReportReason,
} from '../dto/create-safety-report.dto.js';

export enum SafetyModerationStatus {
  PENDING = 'pending',
  REVIEWING = 'reviewing',
  ACTIONED = 'actioned',
  DISMISSED = 'dismissed',
  DUPLICATE = 'duplicate',
}

@Entity('safety_reports')
@Index(['reporterId', 'createdAt'])
@Index(['targetType', 'targetId'])
@Index(['status'])
export class SafetyReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter?: User;

  @Index()
  @Column({
    type: 'enum',
    enum: SafetyReportTargetType,
  })
  targetType!: SafetyReportTargetType;

  @Index()
  @Column({ type: 'uuid' })
  targetId!: string;

  @Column({ type: 'uuid', nullable: true })
  secondaryId?: string | null;

  @Column({
    type: 'enum',
    enum: SafetyReportReason,
  })
  reason!: SafetyReportReason;

  @Column({ type: 'varchar', length: 2000, nullable: true })
  details?: string | null;

  @Column({
    type: 'enum',
    enum: SafetyModerationStatus,
    default: SafetyModerationStatus.PENDING,
  })
  status!: SafetyModerationStatus;

  @Column({ type: 'uuid', nullable: true })
  domainReportId?: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}
