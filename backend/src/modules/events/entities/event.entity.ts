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
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';
import { Community } from '../../communities/entities/community.entity.js';
import { EventRsvp } from './event-rsvp.entity.js';

export enum EventCategory {
  SOCIAL = 'social',
  CULTURAL = 'cultural',
  SPORTS = 'sports',
  WORKSHOP = 'workshop',
  VOLUNTEERING = 'volunteering',
  NEIGHBORHOOD = 'neighborhood',
  OTHER = 'other',
}

export enum EventStatus {
  ACTIVE = 'active',
  CANCELLED = 'cancelled',
  COMPLETED = 'completed',
}

@Entity('events')
@Index('idx_events_status_startAt', ['status', 'startAt'])
@Index('idx_events_locality_startAt', ['locality', 'startAt'])
@Index('idx_events_creator_createdAt', ['creatorId', 'createdAt'])
@Index('idx_events_category_startAt', ['category', 'startAt'])
export class Event {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  creatorId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'creatorId' })
  creator?: User;

  @Index()
  @Column({ type: 'uuid', nullable: true })
  communityId?: string | null;

  @ManyToOne(() => Community, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'communityId' })
  community?: Community | null;

  @Column({ type: 'varchar', length: 150 })
  title!: string;

  @Column({ type: 'text' })
  description!: string;

  @Column({
    type: 'enum',
    enum: EventCategory,
    default: EventCategory.NEIGHBORHOOD,
  })
  category!: EventCategory;

  @Column({
    type: 'enum',
    enum: EventStatus,
    default: EventStatus.ACTIVE,
  })
  status!: EventStatus;

  @Column({ type: 'timestamp with time zone' })
  startAt!: Date;

  @Column({ type: 'timestamp with time zone' })
  endAt!: Date;

  @Column({ type: 'varchar', length: 50, default: 'Asia/Kolkata' })
  timezone!: string;

  @Column({ type: 'varchar', length: 200 })
  venue!: string;

  @Column({ type: 'text' })
  address!: string;

  @Column({ type: 'varchar', length: 150, nullable: true })
  locality?: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  city?: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  state?: string | null;

  @Column({ type: 'varchar', length: 5, default: 'IN' })
  countryCode!: string;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location?: any;

  @Column({ type: 'varchar', length: 500, nullable: true })
  coverImageUrl?: string | null;

  @Column({ type: 'int', default: 0 })
  participantCount!: number;

  @Column({ type: 'timestamp with time zone', nullable: true })
  cancelledAt?: Date | null;

  @Column({ type: 'text', nullable: true })
  cancellationReason?: string | null;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;

  @DeleteDateColumn({ type: 'timestamp with time zone', nullable: true })
  deletedAt?: Date | null;

  @OneToMany(() => EventRsvp, (rsvp) => rsvp.event)
  rsvps?: EventRsvp[];
}
