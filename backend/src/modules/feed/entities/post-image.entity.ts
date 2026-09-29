import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Post } from './post.entity.js';

@Entity('post_images')
@Index('IDX_post_images_postId_sortOrder', ['postId', 'sortOrder'])
export class PostImage {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index('IDX_post_images_postId')
  @Column({ type: 'uuid' })
  postId!: string;

  @ManyToOne(() => Post, (post) => post.images, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'postId' })
  post!: Post;

  @Column({ type: 'text' })
  url!: string;

  @Column({ type: 'text' })
  thumbnailUrl!: string;

  @Column({ type: 'text', nullable: true })
  mediumUrl?: string | null;

  @Column({ type: 'int', nullable: true })
  width?: number | null;

  @Column({ type: 'int', nullable: true })
  height?: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  mimeType?: string | null;

  @Column({ type: 'int', nullable: true })
  size?: number | null;

  @Column({ type: 'int', default: 0 })
  sortOrder!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
