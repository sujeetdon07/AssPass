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

export enum CommunityRole {
  OWNER = 'owner',
  MODERATOR = 'moderator',
  MEMBER = 'member',
}

export enum CommunityMemberStatus {
  ACTIVE = 'active',
  PENDING = 'pending',
  BANNED = 'banned',
}

@Entity('community_members')
@Unique(['communityId', 'userId'])
export class CommunityMember {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  communityId!: string;

  @ManyToOne('Community', 'members', {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'communityId' })
  community!: any;

  @Index()
  @Column({ type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user!: User;

  @Index()
  @Column({
    type: 'enum',
    enum: CommunityRole,
    default: CommunityRole.MEMBER,
  })
  role!: CommunityRole;

  @Index()
  @Column({
    type: 'enum',
    enum: CommunityMemberStatus,
    default: CommunityMemberStatus.ACTIVE,
  })
  status!: CommunityMemberStatus;

  @CreateDateColumn({ type: 'timestamptz' })
  joinedAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}
