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
import { ServiceFavorite } from './service-favorite.entity.js';
import { ServiceReport } from './service-report.entity.js';

export enum ServiceCategory {
  HOME_REPAIR = 'home_repair',
  EDUCATION = 'education',
  BEAUTY = 'beauty',
  CLEANING = 'cleaning',
  PHOTOGRAPHY = 'photography',
  AUTOMOTIVE = 'automotive',
  TECHNOLOGY = 'technology',
  PERSONAL_SERVICES = 'personal_services',
  OTHER = 'other',
}

export enum ServiceStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  ARCHIVED = 'archived',
}

export enum ServiceVerificationStatus {
  UNVERIFIED = 'unverified',
  PENDING = 'pending',
  VERIFIED = 'verified',
}

@Entity('service_listings')
export class ServiceListing {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  ownerId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'ownerId' })
  owner!: User;

  @Column({ type: 'varchar', length: 150 })
  title!: string;

  @Column({ type: 'text' })
  description!: string;

  @Index()
  @Column({
    type: 'enum',
    enum: ServiceCategory,
  })
  category!: ServiceCategory;

  @Index()
  @Column({
    type: 'enum',
    enum: ServiceStatus,
    default: ServiceStatus.ACTIVE,
  })
  status!: ServiceStatus;

  @Column({
    type: 'enum',
    enum: ServiceVerificationStatus,
    default: ServiceVerificationStatus.UNVERIFIED,
  })
  verificationStatus!: ServiceVerificationStatus;

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

  @Column({ type: 'int', default: 10 })
  serviceRadiusKm!: number;

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

  @Column({ type: 'int', nullable: true })
  experienceYears?: number | null;

  @Column({ type: 'varchar', length: 200, nullable: true })
  availability?: string | null;

  @Column({
    type: 'numeric',
    precision: 12,
    scale: 2,
    nullable: true,
    transformer: {
      to: (value: number | null) => value,
      from: (value: string | number | null) =>
        value !== null && value !== undefined
          ? typeof value === 'string'
            ? parseFloat(value)
            : value
          : null,
    },
  })
  startingPrice?: number | null;

  @Column({ type: 'varchar', length: 10, default: 'INR' })
  currency!: string;

  @Column({ type: 'int', default: 0 })
  favoriteCount!: number;

  @OneToMany(() => ServiceFavorite, (fav) => fav.service)
  favorites?: ServiceFavorite[];

  @OneToMany(() => ServiceReport, (rep) => rep.service)
  reports?: ServiceReport[];

  @Index()
  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;

  @Index()
  @DeleteDateColumn({ type: 'timestamptz', nullable: true })
  deletedAt?: Date | null;
}
