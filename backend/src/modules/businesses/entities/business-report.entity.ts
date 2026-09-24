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

export enum BusinessReportReason {
  INCORRECT_INFO = 'incorrect_info',
  SPAM = 'spam',
  FRAUD_SCAM = 'fraud_scam',
  INAPPROPRIATE = 'inappropriate',
  DUPLICATE = 'duplicate',
  CLOSED_BUSINESS = 'closed_business',
  OTHER = 'other',
}

export enum BusinessReportStatus {
  PENDING = 'pending',
  REVIEWED = 'reviewed',
  DISMISSED = 'dismissed',
}

@Entity('business_reports')
@Unique(['businessId', 'reporterId'])
export class BusinessReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  businessId!: string;

  @ManyToOne('Business', 'reports', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'businessId' })
  business?: any;

  @Index()
  @Column({ type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter!: User;

  @Column({
    type: 'enum',
    enum: BusinessReportReason,
  })
  reason!: BusinessReportReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  details?: string | null;

  @Column({
    type: 'enum',
    enum: BusinessReportStatus,
    default: BusinessReportStatus.PENDING,
  })
  status!: BusinessReportStatus;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
