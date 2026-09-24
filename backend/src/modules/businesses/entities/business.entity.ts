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
import { BusinessImage } from './business-image.entity.js';
import { BusinessService } from './business-service.entity.js';
import { BusinessFavorite } from './business-favorite.entity.js';
import { BusinessReport } from './business-report.entity.js';

export enum BusinessCategory {
  FOOD_DINING = 'food_dining',
  GROCERY = 'grocery',
  SHOPPING = 'shopping',
  HEALTH = 'health',
  BEAUTY = 'beauty',
  FITNESS = 'fitness',
  EDUCATION = 'education',
  ELECTRONICS = 'electronics',
  HOME_REPAIR = 'home_repair',
  AUTOMOTIVE = 'automotive',
  PROFESSIONAL = 'professional',
  OTHER = 'other',
}

export enum BusinessStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  ARCHIVED = 'archived',
}

export enum BusinessVerificationStatus {
  UNVERIFIED = 'unverified',
  PENDING = 'pending',
  VERIFIED = 'verified',
}

@Entity('businesses')
export class Business {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  ownerId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'ownerId' })
  owner!: User;

  @Column({ type: 'varchar', length: 150 })
  name!: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 180 })
  slug!: string;

  @Column({ type: 'text' })
  description!: string;

  @Index()
  @Column({
    type: 'enum',
    enum: BusinessCategory,
  })
  category!: BusinessCategory;

  @Index()
  @Column({
    type: 'enum',
    enum: BusinessStatus,
    default: BusinessStatus.ACTIVE,
  })
  status!: BusinessStatus;

  @Column({
    type: 'enum',
    enum: BusinessVerificationStatus,
    default: BusinessVerificationStatus.UNVERIFIED,
  })
  verificationStatus!: BusinessVerificationStatus;

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

  @Column({ type: 'varchar', length: 250, nullable: true })
  address?: string | null;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location?: any;

  @Column({ type: 'varchar', length: 25, nullable: true })
  contactPhone?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  contactEmail?: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  website?: string | null;

  @Column({ type: 'varchar', length: 50, default: 'Asia/Kolkata' })
  timezone!: string;

  @Column({ type: 'jsonb', nullable: true })
  operatingHours?: any;

  @Column({ type: 'int', default: 0 })
  favoriteCount!: number;

  @OneToMany(() => BusinessImage, (img) => img.business, {
    cascade: true,
    eager: true,
  })
  images!: BusinessImage[];

  @OneToMany(() => BusinessService, (svc) => svc.business, {
    cascade: true,
    eager: true,
  })
  services!: BusinessService[];

  @OneToMany(() => BusinessFavorite, (fav) => fav.business)
  favorites?: BusinessFavorite[];

  @OneToMany(() => BusinessReport, (rep) => rep.business)
  reports?: BusinessReport[];

  @Index()
  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;

  @Index()
  @DeleteDateColumn({ type: 'timestamptz', nullable: true })
  deletedAt?: Date | null;
}
