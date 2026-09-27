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
import type { MarketplaceListing } from './marketplace-listing.entity.js';

export enum MarketplaceReportReason {
  SPAM = 'spam',
  SCAM = 'scam',
  HARASSMENT = 'harassment',
  INAPPROPRIATE = 'inappropriate',
  MISINFORMATION = 'misinformation',
  OTHER = 'other',
}

export enum MarketplaceReportStatus {
  PENDING = 'pending',
  REVIEWED = 'reviewed',
  DISMISSED = 'dismissed',
}

@Entity('marketplace_reports')
@Unique(['listingId', 'reporterId'])
export class MarketplaceReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  listingId!: string;

  @ManyToOne('MarketplaceListing', 'reports', {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'listingId' })
  listing?: MarketplaceListing;

  @Index()
  @Column({ type: 'uuid' })
  reporterId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter!: User;

  @Column({
    type: 'enum',
    enum: MarketplaceReportReason,
  })
  reason!: MarketplaceReportReason;

  @Column({ type: 'varchar', length: 500, nullable: true })
  details?: string | null;

  @Column({
    type: 'enum',
    enum: MarketplaceReportStatus,
    default: MarketplaceReportStatus.PENDING,
  })
  status!: MarketplaceReportStatus;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
