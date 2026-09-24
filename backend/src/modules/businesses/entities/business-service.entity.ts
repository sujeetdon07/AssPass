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

@Entity('business_services')
export class BusinessService {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'uuid' })
  businessId!: string;

  @ManyToOne('Business', 'services', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'businessId' })
  business?: any;

  @Column({ type: 'varchar', length: 120 })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description?: string | null;

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

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}
