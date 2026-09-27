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
import type { Event } from './event.entity.js';

export enum EventRsvpStatus {
  GOING = 'going',
  INTERESTED = 'interested',
  NOT_GOING = 'not_going',
}

@Entity('event_rsvps')
@Unique('UQ_event_rsvps_event_user', ['eventId', 'userId'])
@Index('idx_event_rsvps_event_status', ['eventId', 'status'])
@Index('idx_event_rsvps_user_createdAt', ['userId', 'createdAt'])
export class EventRsvp {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  eventId!: string;

  @ManyToOne('Event', 'rsvps', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'eventId' })
  event?: Event;

  @Index()
  @Column({ type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user?: User;

  @Column({
    type: 'enum',
    enum: EventRsvpStatus,
    default: EventRsvpStatus.GOING,
  })
  status!: EventRsvpStatus;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;
}
