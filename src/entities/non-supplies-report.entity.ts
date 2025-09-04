import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { SalesRep } from './sales-rep.entity';
import { Clients } from './clients.entity';

@Entity('non_supplies')
export class NonSuppliesReport {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'reportId' })
  reportId: number;

  @Column({ name: 'productName', nullable: true })
  productName: string;

  @Column({ name: 'comment', nullable: true })
  comment: string;

  @CreateDateColumn({ name: 'createdAt', type: 'datetime', precision: 3 })
  createdAt: Date;

  @Column({ name: 'clientId' })
  clientId: number;

  @Column({ name: 'userId' })
  userId: number;

  @Column({ name: 'productId', nullable: true })
  productId: number;

  // Relations
  @ManyToOne(() => SalesRep)
  @JoinColumn({ name: 'userId' })
  user: SalesRep;

  @ManyToOne(() => Clients)
  @JoinColumn({ name: 'clientId' })
  client: Clients;

  // Product relationship removed temporarily to fix TypeORM metadata issue
}
