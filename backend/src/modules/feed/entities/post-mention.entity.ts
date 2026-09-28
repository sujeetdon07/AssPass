import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Post } from './post.entity.js';
import { User } from '../../users/entities/user.entity.js';

@Entity('post_mentions')
@Unique('UQ_post_mentions_post_user_range', ['postId', 'mentionedUserId', 'start', 'length'])
export class PostMention {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  postId!: string;

  @ManyToOne(() => Post, (post) => post.mentions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'postId' })
  post!: Post;

  @Index()
  @Column({ type: 'uuid' })
  mentionedUserId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'mentionedUserId' })
  mentionedUser!: User;

  @Column({ type: 'int' })
  start!: number;

  @Column({ type: 'int' })
  length!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
}
