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

@Entity('auth_sessions')
export class AuthSession {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, (user) => user.sessions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user!: User;

  /**
   * SHA-256 hash of the currently issued refresh token.
   * Storing raw refresh tokens in the database is strictly prohibited.
   */
  @Column({ type: 'varchar', length: 64 })
  refreshTokenHash!: string;

  /**
   * Device or platform metadata (e.g. "Pixel 8 Pro (Android 14)", "Web Browser").
   */
  @Column({ type: 'varchar', length: 255, nullable: true })
  deviceInfo?: string | null;

  /**
   * Client IP address at session creation.
   */
  @Column({ type: 'varchar', length: 45, nullable: true })
  ipAddress?: string | null;

  /**
   * Timestamp when the refresh token expires.
   */
  @Index()
  @Column({ type: 'timestamp with time zone' })
  expiresAt!: Date;

  /**
   * Timestamp when session was revoked (null if still active).
   * Revoked on logout or token rotation invalidation.
   */
  @Index()
  @Column({ type: 'timestamp with time zone', nullable: true })
  revokedAt?: Date | null;

  @CreateDateColumn({ type: 'timestamp with time zone' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp with time zone' })
  updatedAt!: Date;

  /**
   * Helper to determine if session is currently valid.
   */
  get isValid(): boolean {
    return this.revokedAt === null && this.expiresAt > new Date();
  }
}
