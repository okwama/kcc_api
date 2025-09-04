import { SalesRep } from './sales-rep.entity';
import { Clients } from './clients.entity';
export declare class NonSuppliesReport {
    id: number;
    reportId: number;
    productName: string;
    comment: string;
    createdAt: Date;
    clientId: number;
    userId: number;
    productId: number;
    user: SalesRep;
    client: Clients;
}
