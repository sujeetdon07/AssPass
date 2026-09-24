import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
  OneToMany,
} from 'typeorm';
import { AuthSession } from '../../auth/entities/auth-session.entity.js';

export enum UserStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  DELETED = 'deleted',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /**
   * Normalized phone number in E.164 format (e.g. +919876543210).
   * Unique index ensures single user per phone number.
   */
  @Index({ unique: true })
  @Column({ type: 'varchar', length: 20, unique: true })
  phoneNumber!: string;

  /**
   * Public display name set during onboarding (e.g. "Sujeet Sharma").
   */
  @Column({ type: 'varchar', length: 100, nullable: true })
  displayName?: string | null;

  /**
   * Optional avatar image URL or asset key.
   */
  @Column({ type: 'varchar', length: 500, nullable: true })
  avatarUrl?: string | null;

  /**
   * Account lifecycle status.
   */
  @Column({
    type: 'enum',
    enum: UserStatus,
    default: UserStatus.ACTIVE,
  })
  accountStatus!: UserStatus;

  /**
   * Whether the user has completed the mandatory onboarding flow.
   * True: User can access main community shell routes.
   * False: User must complete basic profile & locality setup.
   */
  @Column({ type: 'boolean', default: false })
  onboardingCompleted!: boolean;

  // ── Locality Foundation (Privacy Preserving) ──────────────────────────────────
  // Aaspaas NEVER stores or exposes exact residential coordinates publicly.
  // These approximate locality fields define the neighborhood boundary.

  @Index()
  @Column({ type: 'varchar', length: 5, default: 'IN', nullable: true })
  countryCode?: string | null;

  @Index()
  @Column({ type: 'varchar', length: 100, nullable: true })
  state?: string | null;

  @Index()
  @Column({ type: 'varchar', length: 100, nullable: true })
  district?: string | null;

  @Index()
  @Column({ type: 'varchar', length: 100, nullable: true })
  city?: string | null;

  @Index()
  @Column({ type: 'varchar', length: 150, nullable: true })
  locality?: string | null;

  @Column({ type: 'varchar', length: 150, nullable: true })
  neighborhood?: string | null;

  // ── Timestamps ───────────────────────────────────────────────────────────────

  @Column({ type: 'timestamp with time zone', nullable: true })
  lastLoginAt?: Date | null;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;

  @OneToMany(() => AuthSession, (session) => session.user)
  sessions?: AuthSession[];
}
