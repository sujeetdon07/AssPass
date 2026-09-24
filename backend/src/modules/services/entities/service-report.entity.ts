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

export enum ServiceReportReason {
  INCORRECT_INFO = 'incorrect_info',
  SPAM = 'spam',
  FRAUD_SCAM = 'fraud_scam',
  INAPPROPRIATE = 'inappropriate',
  DUPLICATE = 'duplicate',
  CLOSED_BUSINESS = 'closed_business',
  OTHER = 'other',
}

export enum ServiceReportStatus {
  PENDING = 'pending',
  REVIEWED = 'reviewed',
  DISMISSED = 'dismissed',
}

@Entity('service_reports')
@Unique(['serviceId', 'reporterId'])
export class ServiceReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  serviceId!: string;

  @ManyToOne('ServiceListing', 'reports', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'serviceId' })
  service?: any;

  @Index()
  @Column({ type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter!: User;

  @Column({
    type: 'enum',
    enum: ServiceReportReason,
  })
  reason!: ServiceReportReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  details?: string | null;

  @Column({
    type: 'enum',
    enum: ServiceReportStatus,
    default: ServiceReportStatus.PENDING,
  })
  status!: ServiceReportStatus;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
