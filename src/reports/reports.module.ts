import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';
import { FeedbackReport } from 'src/entities/feedback-report.entity';
import { ProductReport } from 'src/entities/product-report.entity';
import { VisibilityReport } from 'src/entities/visibility-report.entity';
import { ShowOfShelfReport } from 'src/entities/show-of-shelf-report.entity';
import { ProductExpiryReport } from 'src/entities/product-expiry-report.entity';
import { NonSuppliesReport } from 'src/entities/non-supplies-report.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      FeedbackReport,
      ProductReport,
      VisibilityReport,
      ShowOfShelfReport,
      ProductExpiryReport,
      NonSuppliesReport,
    ]),
  ],
  controllers: [ReportsController],
  providers: [ReportsService],
  exports: [ReportsService],
})
export class ReportsModule {}
