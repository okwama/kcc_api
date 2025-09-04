"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.NonSuppliesReport = void 0;
const typeorm_1 = require("typeorm");
const sales_rep_entity_1 = require("./sales-rep.entity");
const clients_entity_1 = require("./clients.entity");
let NonSuppliesReport = class NonSuppliesReport {
};
exports.NonSuppliesReport = NonSuppliesReport;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], NonSuppliesReport.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reportId' }),
    __metadata("design:type", Number)
], NonSuppliesReport.prototype, "reportId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'productName', nullable: true }),
    __metadata("design:type", String)
], NonSuppliesReport.prototype, "productName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'comment', nullable: true }),
    __metadata("design:type", String)
], NonSuppliesReport.prototype, "comment", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'createdAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], NonSuppliesReport.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'clientId' }),
    __metadata("design:type", Number)
], NonSuppliesReport.prototype, "clientId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'userId' }),
    __metadata("design:type", Number)
], NonSuppliesReport.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'productId', nullable: true }),
    __metadata("design:type", Number)
], NonSuppliesReport.prototype, "productId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => sales_rep_entity_1.SalesRep),
    (0, typeorm_1.JoinColumn)({ name: 'userId' }),
    __metadata("design:type", sales_rep_entity_1.SalesRep)
], NonSuppliesReport.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => clients_entity_1.Clients),
    (0, typeorm_1.JoinColumn)({ name: 'clientId' }),
    __metadata("design:type", clients_entity_1.Clients)
], NonSuppliesReport.prototype, "client", void 0);
exports.NonSuppliesReport = NonSuppliesReport = __decorate([
    (0, typeorm_1.Entity)('non_supplies')
], NonSuppliesReport);
//# sourceMappingURL=non-supplies-report.entity.js.map