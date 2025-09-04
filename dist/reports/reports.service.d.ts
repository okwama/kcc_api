import { Repository } from 'typeorm';
import { FeedbackReport } from '../entities/feedback-report.entity';
import { ProductReport } from '../entities/product-report.entity';
import { VisibilityReport } from '../entities/visibility-report.entity';
import { ShowOfShelfReport } from '../entities/show-of-shelf-report.entity';
import { ProductExpiryReport } from '../entities/product-expiry-report.entity';
import { NonSuppliesReport } from '../entities/non-supplies-report.entity';
export declare class ReportsService {
    private feedbackReportRepository;
    private productReportRepository;
    private visibilityReportRepository;
    private showOfShelfReportRepository;
    private productExpiryReportRepository;
    private nonSuppliesReportRepository;
    constructor(feedbackReportRepository: Repository<FeedbackReport>, productReportRepository: Repository<ProductReport>, visibilityReportRepository: Repository<VisibilityReport>, showOfShelfReportRepository: Repository<ShowOfShelfReport>, productExpiryReportRepository: Repository<ProductExpiryReport>, nonSuppliesReportRepository: Repository<NonSuppliesReport>);
    submitReport(reportData: any): Promise<any>;
    getReportsByJourneyPlan(journeyPlanId: number): Promise<any>;
    findAll(): Promise<any>;
}
