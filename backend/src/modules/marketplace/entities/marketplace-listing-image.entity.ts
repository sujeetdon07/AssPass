import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import type { MarketplaceListing } from './marketplace-listing.entity.js';

@Entity('marketplace_listing_images')
export class MarketplaceListingImage {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  listingId!: string;

  @ManyToOne('MarketplaceListing', 'images', {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'listingId' })
  listing?: MarketplaceListing;

  @Column({ type: 'varchar', length: 500 })
  url!: string;

  @Column({ type: 'int', default: 0 })
  displayOrder!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
