import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { SalesRep } from '../entities/sales-rep.entity';
import { Clients } from '../entities/clients.entity';
import { Product } from '../products/entities/product.entity';
import { JourneyPlan } from '../journey-plans/entities/journey-plan.entity';
import { LoginHistory } from '../entities/login-history.entity';
import { UpliftSale } from '../entities/uplift-sale.entity';
import { UpliftSaleItem } from '../entities/uplift-sale-item.entity';
import { Task } from '../entities/task.entity';
import { Leave } from '../entities/leave.entity';
import { Store } from '../entities/store.entity';
import { StoreInventory } from '../entities/store-inventory.entity';
import { Category } from '../entities/category.entity';
import { CategoryPriceOption } from '../entities/category-price-option.entity';
import { Order } from '../orders/entities/order.entity';
import { OrderItem } from '../orders/entities/order-item.entity';
import { Users } from '../users/entities/users.entity';
import { Notice } from '../notices/entities/notice.entity';
import { LeaveType } from '../entities/leave-type.entity';
import { FeedbackReport } from '../entities/feedback-report.entity';
import { ProductReport } from '../entities/product-report.entity';
import { VisibilityReport } from '../entities/visibility-report.entity';
import { ShowOfShelfReport } from '../entities/show-of-shelf-report.entity';
import { ProductExpiryReport } from '../entities/product-expiry-report.entity';
import { NonSuppliesReport } from '../entities/non-supplies-report.entity';
import { SalesClientPayment } from '../entities/sales-client-payment.entity';

export const getDatabaseConfig = (configService: ConfigService): TypeOrmModuleOptions => {
  const useLocalDb = configService.get<string>('USE_LOCAL_DB', 'false') === 'true';
  const isProduction = configService.get<string>('NODE_ENV', 'development') === 'production';

  // Force MySQL in production
  if (isProduction) {
    console.log('🚀 Production environment - using MySQL database');
    return {
      type: 'mysql',
      host: configService.get<string>('DB_HOST'),
      port: configService.get<number>('DB_PORT', 3306),
      username: configService.get<string>('DB_USERNAME'),
      password: configService.get<string>('DB_PASSWORD'),
      database: configService.get<string>('DB_DATABASE'),
      entities: [
        SalesRep, Clients, Product, JourneyPlan, LoginHistory, UpliftSale, UpliftSaleItem,
        Task, Leave, Store, StoreInventory, Category, CategoryPriceOption, Order, OrderItem, Users, Notice, LeaveType,
        FeedbackReport, ProductReport, VisibilityReport, ShowOfShelfReport, ProductExpiryReport, NonSuppliesReport, SalesClientPayment,
      ],
      synchronize: false,
      logging: configService.get<boolean>('DB_LOGGING', false),
      charset: 'utf8mb4',
      ssl: configService.get<boolean>('DB_SSL', false),
      extra: {
        connectionLimit: 20,
        charset: 'utf8mb4',
        multipleStatements: true,
        dateStrings: true,
      },
      retryAttempts: 5,
      retryDelay: 2000,
      connectTimeout: 60000,
      keepConnectionAlive: true,
      autoLoadEntities: true,
    };
  }

  // Development with MySQL
  console.log('🔧 Development environment - using MySQL database');
  return {
    type: 'mysql',
    host: configService.get<string>('DB_HOST', 'localhost'),
    port: configService.get<number>('DB_PORT', 3306),
    username: configService.get<string>('DB_USERNAME', 'root'),
    password: configService.get<string>('DB_PASSWORD', ''),
    database: configService.get<string>('DB_DATABASE', 'citlogis_finance'),
    entities: [
      SalesRep, Clients, Product, JourneyPlan, LoginHistory, UpliftSale, UpliftSaleItem,
      Task, Leave, Store, StoreInventory, Category, CategoryPriceOption, Order, OrderItem, Users, Notice, LeaveType,
      FeedbackReport, ProductReport, VisibilityReport, ShowOfShelfReport, ProductExpiryReport, NonSuppliesReport, SalesClientPayment,
    ],
    synchronize: false,
    logging: configService.get<boolean>('DB_LOGGING', false),
    charset: 'utf8mb4',
    ssl: configService.get<boolean>('DB_SSL', false),
    extra: {
      connectionLimit: 20,
      charset: 'utf8mb4',
      multipleStatements: true,
      dateStrings: true,
    },
    retryAttempts: 5,
    retryDelay: 2000,
    connectTimeout: 60000,
    keepConnectionAlive: true,
    autoLoadEntities: true,
  };
}; 