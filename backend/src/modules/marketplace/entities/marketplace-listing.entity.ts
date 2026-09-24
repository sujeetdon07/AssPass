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
import { MarketplaceListingImage } from './marketplace-listing-image.entity.js';
import { MarketplaceFavorite } from './marketplace-favorite.entity.js';
import { MarketplaceReport } from './marketplace-report.entity.js';

export enum MarketplaceCategory {
  ELECTRONICS = 'electronics',
  MOBILES = 'mobiles',
  COMPUTERS = 'computers',
  FURNITURE = 'furniture',
  HOME_KITCHEN = 'home_kitchen',
  VEHICLES = 'vehicles',
  BOOKS = 'books',
  FASHION = 'fashion',
  KIDS = 'kids',
  SPORTS = 'sports',
  OTHER = 'other',
}

export enum MarketplaceCondition {
  NEW = 'new',
  LIKE_NEW = 'like_new',
  GOOD = 'good',
  FAIR = 'fair',
  USED = 'used',
}

export enum MarketplaceListingStatus {
  ACTIVE = 'active',
  SOLD = 'sold',
  ARCHIVED = 'archived',
}

@Entity('marketplace_listings')
export class MarketplaceListing {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  sellerId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'sellerId' })
  seller!: User;

  @Column({ type: 'varchar', length: 120 })
  title!: string;

  @Column({ type: 'text' })
  description!: string;

  @Index()
  @Column({
    type: 'enum',
    enum: MarketplaceCategory,
  })
  category!: MarketplaceCategory;

  @Index()
  @Column({
    type: 'numeric',
    precision: 12,
    scale: 2,
    default: 0,
    transformer: {
      to: (value: number) => value,
      from: (value: string | number) => (typeof value === 'string' ? parseFloat(value) : value),
    },
  })
  price!: number;

  @Column({ type: 'varchar', length: 10, default: 'INR' })
  currency!: string;

  @Index()
  @Column({
    type: 'enum',
    enum: MarketplaceCondition,
  })
  condition!: MarketplaceCondition;

  @Index()
  @Column({
    type: 'enum',
    enum: MarketplaceListingStatus,
    default: MarketplaceListingStatus.ACTIVE,
  })
  status!: MarketplaceListingStatus;

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

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location?: any;

  @Column({ type: 'int', default: 0 })
  favoriteCount!: number;

  @OneToMany(() => MarketplaceListingImage, (img) => img.listing, {
    cascade: true,
    eager: true,
  })
  images!: MarketplaceListingImage[];

  @OneToMany(() => MarketplaceFavorite, (fav) => fav.listing)
  favorites?: MarketplaceFavorite[];

  @OneToMany(() => MarketplaceReport, (rep) => rep.listing)
  reports?: MarketplaceReport[];

  @Index()
  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;

  @Index()
  @DeleteDateColumn({ type: 'timestamptz', nullable: true })
  deletedAt?: Date | null;
}
