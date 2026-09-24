import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';
import { Post } from '../../feed/entities/post.entity.js';

export enum CommunityVisibility {
  PUBLIC = 'public',
  PRIVATE = 'private',
}

export enum CommunityStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  ARCHIVED = 'archived',
}

export enum CommunityCategory {
  NEIGHBORHOOD = 'neighborhood',
  SOCIETY = 'society',
  PARENTS_FAMILY = 'parents_family',
  STUDENTS = 'students',
  LOCAL_INTERESTS = 'local_interests',
  SPORTS = 'sports',
  HOBBIES = 'hobbies',
  RESIDENTS = 'residents',
  LOCAL_HELP = 'local_help',
  OTHER = 'other',
}

@Entity('communities')
export class Community {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar', length: 100 })
  name!: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 150, unique: true })
  slug!: string;

  @Column({ type: 'text' })
  description!: string;

  @Index()
  @Column({
    type: 'varchar',
    length: 50,
    default: CommunityCategory.NEIGHBORHOOD,
  })
  category!: CommunityCategory;

  @Index()
  @Column({
    type: 'enum',
    enum: CommunityVisibility,
    default: CommunityVisibility.PUBLIC,
  })
  visibility!: CommunityVisibility;

  @Index()
  @Column({
    type: 'enum',
    enum: CommunityStatus,
    default: CommunityStatus.ACTIVE,
  })
  status!: CommunityStatus;

  @Index()
  @Column({ type: 'uuid' })
  creatorId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'creatorId' })
  creator!: User;

  @Column({ type: 'varchar', length: 5, default: 'IN' })
  countryCode!: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  state?: string | null;

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

  @Column({ type: 'int', default: 1 })
  memberCount!: number;

  @Column({ type: 'int', default: 0 })
  postCount!: number;

  @Column({ type: 'varchar', length: 500, nullable: true })
  coverImageUrl?: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  avatarUrl?: string | null;

  @OneToMany('CommunityMember', (member: any) => member.community)
  members?: any[];

  @OneToMany(() => Post, (post) => post.community)
  posts?: Post[];

  @Index()
  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}
