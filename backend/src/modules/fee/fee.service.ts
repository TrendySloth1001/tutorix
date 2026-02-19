import prisma from '../../infra/prisma.js';
import { Prisma } from '@prisma/client';
import { NotificationService } from '../notification/notification.service.js';

const notifSvc = new NotificationService();

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateFeeStructureDto {
    name: string;
    description?: string;
    amount: number;
    cycle?: string; // ONCE | MONTHLY | QUARTERLY | HALF_YEARLY | YEARLY | INSTALLMENT
    lateFinePerDay?: number;
    discounts?: object;
    installmentPlan?: Array<{ label: string; dueDay: number; amount: number }>;
    // Tax fields
    taxType?: string;        // NONE | GST_INCLUSIVE | GST_EXCLUSIVE
    gstRate?: number;        // 0, 5, 12, 18, 28
    sacCode?: string;
    hsnCode?: string;
    gstSupplyType?: string;  // INTRA_STATE | INTER_STATE
    cessRate?: number;
    // Line item breakdowns
    lineItems?: Array<{ label: string; amount: number }>;
}

export interface UpdateFeeStructureDto {
    name?: string;
    description?: string;
    amount?: number;
    cycle?: string;
    lateFinePerDay?: number;
    discounts?: object;
    installmentPlan?: object;
    isActive?: boolean;
    taxType?: string;
    gstRate?: number;
    sacCode?: string;
    hsnCode?: string;
    gstSupplyType?: string;
    cessRate?: number;
    lineItems?: Array<{ label: string; amount: number }> | null;
}

export interface AssignFeeDto {
    memberId: string;
    feeStructureId: string;
    customAmount?: number;
    discountAmount?: number;
    discountReason?: string;
    scholarshipTag?: string;
    scholarshipAmount?: number;
    startDate?: string;
    endDate?: string;
}

export interface RecordPaymentDto {
    amount: number;
    mode: string; // CASH | ONLINE | UPI | BANK_TRANSFER | CHEQUE | OTHER
    transactionRef?: string;
    notes?: string;
    paidAt?: string; // ISO string — allows back-dating
}

export interface WaiveFeeDto {
    notes?: string;
}

export interface RecordRefundDto {
    amount: number;
    reason?: string;
    mode?: string;
    refundedAt?: string;
}

export interface BulkRemindDto {
    statusFilter?: string;
    memberIds?: string[];
}

export interface ListFeeRecordsQuery {
    memberId?: string;
    status?: string;
    from?: string;
    to?: string;
    page?: number;
    limit?: number;
    search?: string;
}

// ─── Helpers ─────────────────────────────────────────────────────────

/** Returns Indian financial year string: "2025-26" for dates between Apr 2025 – Mar 2026 */
function getFinancialYear(date: Date = new Date()): string {
    const y = date.getFullYear();
    const m = date.getMonth(); // 0-indexed
    const startYear = m >= 3 ? y : y - 1; // Apr onwards = current FY
    const endYear = (startYear + 1) % 100;
    return `${startYear}-${endYear.toString().padStart(2, '0')}`;
}

/** Generate sequential receipt number: TXR/2025-26/0042 */
async function generateSequentialReceiptNo(coachingId: string): Promise<string> {
    const fy = getFinancialYear();
    const seq = await prisma.receiptSequence.upsert({
        where: { coachingId_financialYear: { coachingId, financialYear: fy } },
        create: { coachingId, financialYear: fy, lastNumber: 1 },
        update: { lastNumber: { increment: 1 } },
    });
    return `TXR/${fy}/${seq.lastNumber.toString().padStart(4, '0')}`;
}

/** Legacy random receipt (fallback, kept for compatibility) */
function generateReceiptNo(): string {
    const ts = Date.now().toString(36).toUpperCase();
    const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `RCP-${ts}-${rand}`;
}

// ── Tax Computation ─────────────────────────────────────────────────

interface TaxBreakdown {
    taxAmount: number;
    cgstAmount: number;
    sgstAmount: number;
    igstAmount: number;
    cessAmount: number;
    taxableAmount: number; // base amount before tax
    totalWithTax: number;  // inclusive of tax
}

/**
 * Compute GST breakdown for a given base amount.
 * @param baseAmount  The pre-tax amount
 * @param taxType     NONE | GST_INCLUSIVE | GST_EXCLUSIVE
 * @param gstRate     GST rate in percentage (0, 5, 12, 18, 28)
 * @param supplyType  INTRA_STATE → CGST+SGST | INTER_STATE → IGST
 * @param cessRate    Additional cess percentage
 */
function computeTax(
    baseAmount: number,
    taxType: string,
    gstRate: number,
    supplyType: string = 'INTRA_STATE',
    cessRate: number = 0,
): TaxBreakdown {
    if (taxType === 'NONE' || gstRate === 0) {
        return { taxAmount: 0, cgstAmount: 0, sgstAmount: 0, igstAmount: 0, cessAmount: 0, taxableAmount: baseAmount, totalWithTax: baseAmount };
    }

    let taxableAmount: number;
    let gstAmount: number;
    let cess: number;

    if (taxType === 'GST_INCLUSIVE') {
        // Reverse-calculate: base includes tax
        const effectiveRate = gstRate + cessRate;
        taxableAmount = baseAmount / (1 + effectiveRate / 100);
        gstAmount = taxableAmount * (gstRate / 100);
        cess = taxableAmount * (cessRate / 100);
    } else {
        // GST_EXCLUSIVE: tax is on top
        taxableAmount = baseAmount;
        gstAmount = baseAmount * (gstRate / 100);
        cess = baseAmount * (cessRate / 100);
    }

    // Round to 2 decimals
    gstAmount = Math.round(gstAmount * 100) / 100;
    cess = Math.round(cess * 100) / 100;
    taxableAmount = Math.round(taxableAmount * 100) / 100;

    let cgst = 0, sgst = 0, igst = 0;
    if (supplyType === 'INTER_STATE') {
        igst = gstAmount;
    } else {
        cgst = Math.round((gstAmount / 2) * 100) / 100;
        sgst = Math.round((gstAmount / 2) * 100) / 100;
    }

    const totalTax = gstAmount + cess;
    const totalWithTax = taxType === 'GST_INCLUSIVE' ? baseAmount : baseAmount + totalTax;

    return { taxAmount: totalTax, cgstAmount: cgst, sgstAmount: sgst, igstAmount: igst, cessAmount: cess, taxableAmount, totalWithTax: Math.round(totalWithTax * 100) / 100 };
}

function calcDaysOverdue(dueDate: Date): number {
    const now = new Date();
    if (dueDate >= now) return 0;
    return Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24));
}

/** Computes next due date from current date based on cycle. */
function nextDueDateFromCycle(from: Date, cycle: string): Date {
    const d = new Date(from);
    switch (cycle) {
        case 'MONTHLY': d.setMonth(d.getMonth() + 1); break;
        case 'QUARTERLY': d.setMonth(d.getMonth() + 3); break;
        case 'HALF_YEARLY': d.setMonth(d.getMonth() + 6); break;
        case 'YEARLY': d.setFullYear(d.getFullYear() + 1); break;
        default: break;
    }
    return d;
}

function buildRecordTitle(structureName: string, dueDate: Date, cycle: string): string {
    const month = dueDate.toLocaleString('en-IN', { month: 'long', year: 'numeric' });
    if (cycle === 'ONCE' || cycle === 'INSTALLMENT') return structureName;
    return `${month} — ${structureName}`;
}

// ─── Member select for records ────────────────────────────────────────

const MEMBER_SELECT = {
    id: true,
    role: true,
    userId: true,
    wardId: true,
    user: { select: { id: true, name: true, picture: true, email: true, phone: true } },
    ward: { select: { id: true, name: true, picture: true, parentId: true, parent: { select: { id: true, name: true, email: true, phone: true } } } },
} as const;

const RECORD_INCLUDE = {
    member: { select: MEMBER_SELECT },
    assignment: { include: { feeStructure: true } },
    payments: { orderBy: { paidAt: 'desc' as const } },
    refunds: { orderBy: { refundedAt: 'desc' as const } },
    markedBy: { select: { id: true, name: true } },
} as const;

// ─── Service ─────────────────────────────────────────────────────────

export class FeeService {

    // ── Fee Structures ─────────────────────────────────────────────

    async listStructures(coachingId: string) {
        return prisma.feeStructure.findMany({
            where: { coachingId },
            orderBy: { createdAt: 'desc' },
            include: {
                _count: { select: { assignments: true } },
            },
        });
    }

    async createStructure(coachingId: string, dto: CreateFeeStructureDto) {
        return prisma.feeStructure.create({
            data: {
                coachingId,
                name: dto.name,
                description: dto.description ?? null,
                amount: dto.amount,
                cycle: dto.cycle ?? 'MONTHLY',
                lateFinePerDay: dto.lateFinePerDay ?? 0,
                discounts: dto.discounts != null ? dto.discounts as Prisma.InputJsonValue : Prisma.JsonNull,
                installmentPlan: dto.installmentPlan != null ? dto.installmentPlan as Prisma.InputJsonValue : Prisma.JsonNull,
                // Tax
                taxType: dto.taxType ?? 'NONE',
                gstRate: dto.gstRate ?? 0,
                sacCode: dto.sacCode ?? null,
                hsnCode: dto.hsnCode ?? null,
                gstSupplyType: dto.gstSupplyType ?? 'INTRA_STATE',
                cessRate: dto.cessRate ?? 0,
                // Line items
                lineItems: dto.lineItems != null ? dto.lineItems as Prisma.InputJsonValue : Prisma.JsonNull,
            },
        });
    }

    async updateStructure(coachingId: string, structureId: string, dto: UpdateFeeStructureDto) {
        await this._ensureStructureOwned(coachingId, structureId);
        const data: Record<string, unknown> = {};
        if (dto.name !== undefined) data.name = dto.name;
        if (dto.description !== undefined) data.description = dto.description ?? null;
        if (dto.amount !== undefined) data.amount = dto.amount;
        if (dto.cycle !== undefined) data.cycle = dto.cycle;
        if (dto.lateFinePerDay !== undefined) data.lateFinePerDay = dto.lateFinePerDay;
        if (dto.isActive !== undefined) data.isActive = dto.isActive;
        if (dto.discounts !== undefined) {
            data.discounts = dto.discounts != null ? dto.discounts as Prisma.InputJsonValue : Prisma.JsonNull;
        }
        if (dto.installmentPlan !== undefined) {
            data.installmentPlan = dto.installmentPlan != null ? dto.installmentPlan as Prisma.InputJsonValue : Prisma.JsonNull;
        }
        // Tax fields
        if (dto.taxType !== undefined) data.taxType = dto.taxType;
        if (dto.gstRate !== undefined) data.gstRate = dto.gstRate;
        if (dto.sacCode !== undefined) data.sacCode = dto.sacCode ?? null;
        if (dto.hsnCode !== undefined) data.hsnCode = dto.hsnCode ?? null;
        if (dto.gstSupplyType !== undefined) data.gstSupplyType = dto.gstSupplyType;
        if (dto.cessRate !== undefined) data.cessRate = dto.cessRate;
        if (dto.lineItems !== undefined) {
            data.lineItems = dto.lineItems != null ? dto.lineItems as Prisma.InputJsonValue : Prisma.JsonNull;
        }
        return prisma.feeStructure.update({
            where: { id: structureId },
            data,
        });
    }

    async deleteStructure(coachingId: string, structureId: string) {
        await this._ensureStructureOwned(coachingId, structureId);
        // Check if any fee records exist under this structure
        const recordCount = await prisma.feeRecord.count({ where: { assignment: { feeStructureId: structureId } } });
        if (recordCount > 0) {
            // Soft-delete: deactivate structure + all its assignments
            await prisma.feeAssignment.updateMany({ where: { feeStructureId: structureId }, data: { isActive: false } });
            return prisma.feeStructure.update({ where: { id: structureId }, data: { isActive: false } });
        }
        // No records: safe to hard-delete (cascades to assignments)
        return prisma.feeStructure.delete({ where: { id: structureId } });
    }

    // ── Assignments ─────────────────────────────────────────────────

    /** Assign a fee structure to a member and create the first FeeRecord. */
    async assignFee(coachingId: string, dto: AssignFeeDto, assignedById: string) {
        const structure = await this._ensureStructureOwned(coachingId, dto.feeStructureId);

        // Upsert assignment
        const totalDiscount = (dto.discountAmount ?? 0) + (dto.scholarshipAmount ?? 0);
        const finalAmount = (dto.customAmount ?? structure.amount) - totalDiscount;
        const startDate = dto.startDate ? new Date(dto.startDate) : new Date();

        const assignment = await prisma.feeAssignment.upsert({
            where: { feeStructureId_memberId: { feeStructureId: dto.feeStructureId, memberId: dto.memberId } },
            create: {
                coachingId,
                feeStructureId: dto.feeStructureId,
                memberId: dto.memberId,
                customAmount: dto.customAmount ?? null,
                discountAmount: dto.discountAmount ?? 0,
                discountReason: dto.discountReason ?? null,
                scholarshipTag: dto.scholarshipTag ?? null,
                scholarshipAmount: dto.scholarshipAmount ?? null,
                startDate,
                endDate: dto.endDate ? new Date(dto.endDate) : null,
                isActive: true,
                isPaused: false,
            },
            update: {
                customAmount: dto.customAmount ?? null,
                discountAmount: dto.discountAmount ?? 0,
                discountReason: dto.discountReason ?? null,
                scholarshipTag: dto.scholarshipTag ?? null,
                scholarshipAmount: dto.scholarshipAmount ?? null,
                isActive: true,
                endDate: dto.endDate ? new Date(dto.endDate) : null,
            },
        });

        // For INSTALLMENT cycle: create records for each installment
        if (structure.cycle === 'INSTALLMENT' && structure.installmentPlan) {
            const plan = structure.installmentPlan as Array<{ label: string; dueDay: number; amount: number }>;
            for (let idx = 0; idx < plan.length; idx++) {
                const inst = plan[idx]!;
                const dueDate = new Date(startDate);
                dueDate.setMonth(dueDate.getMonth() + idx);
                dueDate.setDate(inst.dueDay);
                await this._createFeeRecord(coachingId, assignment.id, dto.memberId, structure, inst.amount, dueDate, inst.label);
            }
        } else {
            // Create first record if none exists for current cycle
            const existingRecord = await prisma.feeRecord.findFirst({
                where: { assignmentId: assignment.id, status: { in: ['PENDING', 'PARTIALLY_PAID'] } },
            });
            if (!existingRecord) {
                await this._createFeeRecord(coachingId, assignment.id, dto.memberId, structure, finalAmount, startDate, undefined, totalDiscount);
            }
        }

        return assignment;
    }

    async removeFeeAssignment(coachingId: string, assignmentId: string) {
        const assignment = await prisma.feeAssignment.findFirst({ where: { id: assignmentId, coachingId } });
        if (!assignment) throw Object.assign(new Error('Assignment not found'), { status: 404 });
        return prisma.feeAssignment.update({ where: { id: assignmentId }, data: { isActive: false } });
    }

    async toggleFeePause(coachingId: string, assignmentId: string, pause: boolean, note?: string) {
        const a = await prisma.feeAssignment.findFirst({ where: { id: assignmentId, coachingId } });
        if (!a) throw Object.assign(new Error('Assignment not found'), { status: 404 });
        return prisma.feeAssignment.update({
            where: { id: assignmentId },
            data: {
                isPaused: pause,
                pausedAt: pause ? new Date() : null,
                pauseNote: pause ? (note ?? null) : null,
            },
        });
    }

    async getMemberFeeProfile(coachingId: string, memberId: string) {
        await this._markOverdueRecords(coachingId);
        const [assignments, member] = await Promise.all([
            prisma.feeAssignment.findMany({
                where: { coachingId, memberId, isActive: true },
                include: {
                    feeStructure: true,
                    records: {
                        orderBy: { dueDate: 'asc' },
                        include: { payments: true, refunds: true },
                    },
                },
            }),
            prisma.coachingMember.findFirst({ where: { id: memberId, coachingId }, select: MEMBER_SELECT }),
        ]);
        if (!member) throw Object.assign(new Error('Member not found'), { status: 404 });

        const allRecords = assignments.flatMap(a => a.records);
        const totalFee = allRecords.reduce((s, r) => s + r.finalAmount, 0);
        const totalPaid = allRecords.reduce((s, r) => s + r.paidAmount, 0);
        const totalRefund = allRecords.flatMap(r => r.refunds).reduce((s, rf) => s + rf.amount, 0);
        const nextDueBill = allRecords
            .filter(r => r.status === 'PENDING' || r.status === 'PARTIALLY_PAID')
            .sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime())[0] ?? null;

        const enriched = assignments.map(a => ({
            ...a,
            records: a.records.map(r => ({ ...r, daysOverdue: r.status === 'OVERDUE' ? calcDaysOverdue(r.dueDate) : 0 })),
        }));

        return {
            member,
            assignments: enriched,
            ledger: {
                totalFee,
                totalPaid,
                totalRefunded: totalRefund,
                balance: totalFee - totalPaid - totalRefund,
                totalOverdue: allRecords.filter(r => r.status === 'OVERDUE').reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0),
                nextDue: nextDueBill,
            },
        };
    }

    // ── Fee Records ─────────────────────────────────────────────────

    async listRecords(coachingId: string, query: ListFeeRecordsQuery) {
        const { memberId, status, from, to, page = 1, limit = 30, search } = query;

        // Auto-update overdue records before returning list
        await this._markOverdueRecords(coachingId);

        let memberIds: string[] | undefined;
        if (search && !memberId) {
            const matches = await prisma.coachingMember.findMany({
                where: {
                    coachingId,
                    OR: [
                        { user: { name: { contains: search, mode: 'insensitive' } } },
                        { ward: { name: { contains: search, mode: 'insensitive' } } },
                    ],
                },
                select: { id: true },
            });
            if (matches.length === 0) return { total: 0, page, limit, records: [] };
            memberIds = matches.map(m => m.id);
        }

        const where = {
            coachingId,
            ...(memberId ? { memberId } : memberIds ? { memberId: { in: memberIds } } : {}),
            ...(status && { status }),
            ...(from || to ? {
                dueDate: {
                    ...(from && { gte: new Date(from) }),
                    ...(to && { lte: new Date(to) }),
                },
            } : {}),
        };

        const [total, records] = await Promise.all([
            prisma.feeRecord.count({ where }),
            prisma.feeRecord.findMany({
                where,
                orderBy: { dueDate: 'desc' },
                skip: (page - 1) * limit,
                take: limit,
                include: RECORD_INCLUDE,
            }),
        ]);

        return {
            total, page, limit,
            records: records.map(r => ({ ...r, daysOverdue: r.status === 'OVERDUE' ? calcDaysOverdue(r.dueDate) : 0 })),
        };
    }

    async getRecordById(coachingId: string, recordId: string) {
        const record = await prisma.feeRecord.findFirst({
            where: { id: recordId, coachingId },
            include: RECORD_INCLUDE,
        });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        return { ...record, daysOverdue: record.status === 'OVERDUE' ? calcDaysOverdue(record.dueDate) : 0 };
    }

    /** Record a payment (full or partial) against a FeeRecord. */
    async recordPayment(coachingId: string, recordId: string, dto: RecordPaymentDto, userId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (record.status === 'PAID' || record.status === 'WAIVED') {
            throw Object.assign(new Error('This record is already settled'), { status: 400 });
        }
        if (dto.amount <= 0) throw Object.assign(new Error('Amount must be positive'), { status: 400 });

        const paidAt = dto.paidAt ? new Date(dto.paidAt) : new Date();

        // Lock current fine at payment time
        const assignment = await prisma.feeAssignment.findUnique({
            where: { id: record.assignmentId },
            include: { feeStructure: true },
        });
        const lateFine = assignment?.feeStructure?.lateFinePerDay ?? 0;
        const days = calcDaysOverdue(record.dueDate);
        const fineNow = lateFine > 0 && days > 0 ? lateFine * days : record.fineAmount;
        const finalAmountLocked = record.baseAmount - record.discountAmount + fineNow + record.taxAmount;

        const newPaidAmount = record.paidAmount + dto.amount;
        const isPaid = newPaidAmount >= finalAmountLocked - 0.01;

        // Generate sequential receipt number for each payment
        const paymentReceiptNo = await generateSequentialReceiptNo(coachingId);

        await prisma.$transaction([
            prisma.feePayment.create({
                data: {
                    coachingId,
                    recordId,
                    amount: dto.amount,
                    mode: dto.mode,
                    transactionRef: dto.transactionRef ?? null,
                    receiptNo: paymentReceiptNo,
                    notes: dto.notes ?? null,
                    paidAt,
                    recordedById: userId,
                },
            }),
            prisma.feeRecord.update({
                where: { id: recordId },
                data: {
                    paidAmount: newPaidAmount,
                    fineAmount: fineNow,
                    finalAmount: finalAmountLocked,
                    status: isPaid ? 'PAID' : 'PARTIALLY_PAID',
                    paidAt: isPaid ? paidAt : record.paidAt,
                    markedById: userId,
                    paymentMode: dto.mode,
                    transactionRef: dto.transactionRef ?? null,
                    receiptNo: isPaid ? paymentReceiptNo : record.receiptNo,
                },
            }),
        ]);

        // If paid and cycle-based, generate next record
        if (isPaid && assignment && assignment.isActive && !assignment.isPaused) {
            const cycle = assignment.feeStructure.cycle;
            if (cycle !== 'ONCE' && cycle !== 'INSTALLMENT') {
                const dueDate = nextDueDateFromCycle(record.dueDate, cycle);
                const isBeforeEnd = !assignment.endDate || dueDate <= assignment.endDate;
                if (isBeforeEnd) {
                    const totalDiscount = assignment.discountAmount + (assignment.scholarshipAmount ?? 0);
                    const fa = (assignment.customAmount ?? assignment.feeStructure.amount) - totalDiscount;
                    await this._createFeeRecord(coachingId, assignment.id, record.memberId, assignment.feeStructure, fa, dueDate, undefined, totalDiscount);
                }
            }
        }

        return prisma.feeRecord.findUniqueOrThrow({
            where: { id: recordId },
            include: RECORD_INCLUDE,
        });
    }

    async waiveFee(coachingId: string, recordId: string, dto: WaiveFeeDto, userId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (record.status === 'PAID') throw Object.assign(new Error('Already paid'), { status: 400 });

        await prisma.feeRecord.update({
            where: { id: recordId },
            data: { status: 'WAIVED', notes: dto.notes ?? null, markedById: userId },
        });
        // Re-fetch full record to avoid fromJson parse errors on frontend
        return this.getRecordById(coachingId, recordId);
    }

    async recordRefund(coachingId: string, recordId: string, dto: RecordRefundDto, userId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (dto.amount <= 0) throw Object.assign(new Error('Refund amount must be positive'), { status: 400 });
        if (dto.amount > record.paidAmount) throw Object.assign(new Error('Cannot refund more than paid amount'), { status: 400 });

        const refundedAt = dto.refundedAt ? new Date(dto.refundedAt) : new Date();
        const newPaidAmount = record.paidAmount - dto.amount;

        const isPastDue = record.dueDate < new Date();
        const newStatus =
            newPaidAmount >= record.finalAmount - 0.01 ? 'PAID'
                : newPaidAmount <= 0 && isPastDue ? 'OVERDUE'
                    : newPaidAmount <= 0 ? 'PENDING'
                        : isPastDue ? 'OVERDUE'
                            : 'PARTIALLY_PAID';

        await prisma.$transaction([
            prisma.feeRefund.create({
                data: {
                    coachingId,
                    recordId,
                    amount: dto.amount,
                    reason: dto.reason ?? null,
                    mode: dto.mode ?? 'CASH',
                    refundedAt,
                    processedById: userId,
                },
            }),
            prisma.feeRecord.update({
                where: { id: recordId },
                data: {
                    paidAmount: newPaidAmount,
                    status: newStatus,
                },
            }),
        ]);

        return this.getRecordById(coachingId, recordId);
    }

    /** Mark reminder sent + increment counter + create notification for the student/parent. */
    async sendReminder(coachingId: string, recordId: string) {
        const record = await prisma.feeRecord.findFirst({
            where: { id: recordId, coachingId },
            include: {
                member: {
                    select: {
                        userId: true,
                        ward: { select: { parentId: true } },
                    },
                },
            },
        });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });

        // Determine who to notify: member's own user, or the ward's parent
        const targetUserId = record.member?.userId ?? record.member?.ward?.parentId ?? null;
        const balance = record.finalAmount - record.paidAmount;

        if (targetUserId) {
            await notifSvc.create({
                userId: targetUserId,
                coachingId,
                type: 'FEE_REMINDER',
                title: '📋 Fee Payment Reminder',
                message: `Your fee "${record.title}" of ₹${balance.toFixed(0)} is due. Please pay at the earliest to avoid additional fines.`,
                data: { recordId, amount: balance, dueDate: record.dueDate },
            });
        }

        return prisma.feeRecord.update({
            where: { id: recordId },
            data: { reminderSentAt: new Date(), reminderCount: { increment: 1 } },
        });
    }

    async bulkRemind(coachingId: string, dto: BulkRemindDto) {
        const statusFilter = dto.statusFilter ?? 'OVERDUE';
        const where = {
            coachingId,
            status: statusFilter,
            ...(dto.memberIds?.length ? { memberId: { in: dto.memberIds } } : {}),
        };

        // Fetch all matching records with member info to send targeted notifications
        const records = await prisma.feeRecord.findMany({
            where,
            include: {
                member: {
                    select: {
                        userId: true,
                        ward: { select: { parentId: true } },
                    },
                },
            },
        });

        // Send notifications in parallel (ignore individual failures)
        await Promise.allSettled(
            records.map((record) => {
                const targetUserId = record.member?.userId ?? record.member?.ward?.parentId ?? null;
                if (!targetUserId) return Promise.resolve();
                const balance = record.finalAmount - record.paidAmount;
                return notifSvc.create({
                    userId: targetUserId,
                    coachingId,
                    type: 'FEE_REMINDER',
                    title: '📋 Fee Payment Reminder',
                    message: `Your fee "${record.title}" of ₹${balance.toFixed(0)} is due. Please pay at the earliest to avoid additional fines.`,
                    data: { recordId: record.id, amount: balance, dueDate: record.dueDate },
                });
            }),
        );

        const result = await prisma.feeRecord.updateMany({
            where,
            data: { reminderSentAt: new Date(), reminderCount: { increment: 1 } },
        });
        return { reminded: result.count };
    }

    // ── Summary / Analytics ────────────────────────────────────────

    async getSummary(coachingId: string, financialYear?: string) {
        await this._markOverdueRecords(coachingId);

        // Financial year: "2025-26" → April 2025 – March 2026
        let fyStart: Date | undefined, fyEnd: Date | undefined;
        if (financialYear) {
            const fy: string = financialYear;
            const parts = fy.split('-');
            const startYear = parseInt(parts[0] ?? '2025', 10);
            fyStart = new Date(startYear, 3, 1);
            fyEnd = new Date(startYear + 1, 2, 31, 23, 59, 59);
        }
        const pyWhere = { coachingId, ...(fyStart && fyEnd ? { paidAt: { gte: fyStart, lte: fyEnd } } : {}) };
        const recWhere = { coachingId, ...(fyStart && fyEnd ? { dueDate: { gte: fyStart, lte: fyEnd } } : {}) };

        const refundWhere = { coachingId, ...(fyStart && fyEnd ? { refundedAt: { gte: fyStart, lte: fyEnd } } : {}) };

        const [statusGroups, totalCollected, totalRefunded, outstandingRecords, paymentModes, monthlyCollection, overdueCount, todayCollection] = await Promise.all([
            prisma.feeRecord.groupBy({ by: ['status'], where: recWhere, _count: true, _sum: { finalAmount: true } }),
            prisma.feePayment.aggregate({ where: pyWhere, _sum: { amount: true } }),
            prisma.feeRefund.aggregate({ where: refundWhere, _sum: { amount: true } }),
            // Fetch outstanding records to compute actual balance (finalAmount - paidAmount)
            prisma.feeRecord.findMany({
                where: { ...recWhere, status: { in: ['PENDING', 'PARTIALLY_PAID', 'OVERDUE'] } },
                select: { finalAmount: true, paidAmount: true, status: true },
            }),
            prisma.feePayment.groupBy({ by: ['mode'], where: pyWhere, _sum: { amount: true }, _count: true }),
            prisma.$queryRaw<Array<{ month: string; total: number; count: number }>>`
                SELECT TO_CHAR(DATE_TRUNC('month', "paidAt"), 'YYYY-MM') AS month,
                       SUM(amount)::FLOAT AS total,
                       COUNT(*)::INT AS count
                FROM "FeePayment"
                WHERE "coachingId" = ${coachingId}
                  ${fyStart ? Prisma.sql`AND "paidAt" >= ${fyStart}` : Prisma.empty}
                  ${fyEnd ? Prisma.sql`AND "paidAt" <= ${fyEnd}` : Prisma.sql`AND "paidAt" >= NOW() - INTERVAL '12 months'`}
                GROUP BY 1 ORDER BY 1
            `,
            prisma.feeRecord.count({ where: { coachingId, status: 'OVERDUE' } }),
            prisma.feePayment.aggregate({
                where: { coachingId, paidAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) } },
                _sum: { amount: true },
            }),
        ]);

        // Calculate actual outstanding balance (not inflated finalAmount)
        const totalPending = outstandingRecords.reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0);
        const totalOverdue = outstandingRecords.filter(r => r.status === 'OVERDUE').reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0);

        return {
            statusBreakdown: statusGroups,
            totalCollected: (totalCollected._sum.amount ?? 0) - (totalRefunded._sum.amount ?? 0),
            totalRefunded: totalRefunded._sum.amount ?? 0,
            totalPending,
            totalOverdue,
            overdueCount,
            todayCollection: todayCollection._sum.amount ?? 0,
            paymentModes,
            monthlyCollection,
            financialYear: financialYear ?? null,
        };
    }

    /** Overdue students report with days overdue per record. */
    async getOverdueReport(coachingId: string) {
        await this._markOverdueRecords(coachingId);
        const records = await prisma.feeRecord.findMany({
            where: { coachingId, status: 'OVERDUE' },
            orderBy: { dueDate: 'asc' },
            include: {
                member: { select: MEMBER_SELECT },
                assignment: { include: { feeStructure: { select: { name: true, lateFinePerDay: true } } } },
            },
        });
        return records.map(r => ({
            ...r,
            daysOverdue: calcDaysOverdue(r.dueDate),
            accruedFine: (r.assignment?.feeStructure?.lateFinePerDay ?? 0) * calcDaysOverdue(r.dueDate),
        }));
    }

    /** Full student financial ledger with running balance timeline. */
    async getStudentLedger(coachingId: string, memberId: string) {
        await this._markOverdueRecords(coachingId);
        const [member, records] = await Promise.all([
            prisma.coachingMember.findFirst({ where: { id: memberId, coachingId }, select: MEMBER_SELECT }),
            prisma.feeRecord.findMany({
                where: { coachingId, memberId },
                orderBy: { dueDate: 'asc' },
                include: {
                    payments: { orderBy: { paidAt: 'asc' } },
                    refunds: { orderBy: { refundedAt: 'asc' } },
                    assignment: { include: { feeStructure: { select: { name: true, cycle: true, lateFinePerDay: true } } } },
                },
            }),
        ]);
        if (!member) throw Object.assign(new Error('Member not found'), { status: 404 });

        type RawEntry = { date: Date; type: 'RECORD' | 'PAYMENT' | 'REFUND'; label: string; amount: number; mode?: string; ref?: string | null; receiptNo?: string | null; status?: string; recordId: string };
        const raw: RawEntry[] = [];
        let totalCharged = 0, totalPaid = 0, totalRefunded = 0;

        for (const r of records) {
            totalCharged += r.finalAmount;
            raw.push({ date: r.dueDate, type: 'RECORD', label: r.title, amount: r.finalAmount, status: r.status, recordId: r.id });
            for (const p of r.payments) {
                totalPaid += p.amount;
                raw.push({ date: p.paidAt, type: 'PAYMENT', label: `Payment (${p.mode})`, amount: p.amount, mode: p.mode, ref: p.transactionRef, receiptNo: p.receiptNo, recordId: r.id });
            }
            for (const rf of r.refunds) {
                totalRefunded += rf.amount;
                raw.push({ date: rf.refundedAt, type: 'REFUND', label: 'Refund', amount: -rf.amount, mode: rf.mode, recordId: r.id });
            }
        }
        raw.sort((a, b) => a.date.getTime() - b.date.getTime());

        let running = 0;
        const timeline = raw.map(e => {
            if (e.type === 'RECORD') running += e.amount;
            else running -= Math.abs(e.amount);
            return { ...e, runningBalance: running };
        });

        const nextDueBill = records
            .filter(r => r.status === 'PENDING' || r.status === 'PARTIALLY_PAID')
            .sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime())[0];

        return {
            member,
            summary: {
                totalCharged, totalPaid, totalRefunded,
                balance: totalCharged - totalPaid - totalRefunded,
                totalOverdue: records.filter(r => r.status === 'OVERDUE').reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0),
                nextDueDate: nextDueBill?.dueDate ?? null,
                nextDueAmount: nextDueBill ? nextDueBill.finalAmount - nextDueBill.paidAmount : 0,
            },
            records: records.map(r => ({ ...r, daysOverdue: r.status === 'OVERDUE' ? calcDaysOverdue(r.dueDate) : 0 })),
            timeline,
        };
    }

    /** Fees for the logged-in student/parent. */
    async getMyTransactions(coachingId: string, userId: string) {
        // Resolve memberIds for this user (direct + wards)
        const member = await prisma.coachingMember.findFirst({ where: { coachingId, userId } });
        const wardMembers = await prisma.coachingMember.findMany({ where: { coachingId, ward: { parentId: userId } } });
        const memberIds = [...(member ? [member.id] : []), ...wardMembers.map(w => w.id)];
        if (memberIds.length === 0) return [];

        const records = await prisma.feeRecord.findMany({
            where: { coachingId, memberId: { in: memberIds } },
            select: { id: true, title: true, finalAmount: true },
        });
        const recordIds = records.map(r => r.id);
        const recordMap = Object.fromEntries(records.map(r => [r.id, r]));

        // Fetch FeePayments + ALL RazorpayOrders in parallel
        const [payments, allOrders] = await Promise.all([
            prisma.feePayment.findMany({
                where: { coachingId, recordId: { in: recordIds } },
                orderBy: { paidAt: 'desc' },
                select: {
                    id: true, recordId: true, amount: true, paidAt: true,
                    mode: true, receiptNo: true, razorpayPaymentId: true,
                    razorpayOrderId: true, notes: true,
                },
            }),
            prisma.razorpayOrder.findMany({
                where: { coachingId, userId, recordId: { in: recordIds } },
                orderBy: { createdAt: 'desc' },
                select: {
                    id: true, recordId: true, razorpayOrderId: true,
                    razorpayPaymentId: true, status: true, amountPaise: true,
                    receipt: true, notes: true, paymentRecorded: true,
                    failureReason: true, failedAt: true,
                    transferId: true, transferStatus: true, platformFeePaise: true,
                    createdAt: true, updatedAt: true,
                },
            }),
        ]);

        // Group RazorpayOrders by razorpayOrderId (multi-pay uses same Razorpay orderId)
        const orderGroups = new Map<string, typeof allOrders>();
        for (const o of allOrders) {
            if (!orderGroups.has(o.razorpayOrderId)) orderGroups.set(o.razorpayOrderId, []);
            orderGroups.get(o.razorpayOrderId)!.push(o);
        }

        // Helper: produce human-readable reason from raw failureReason
        function humanReason(raw: string | null, isMulti: boolean): string {
            const r = (raw ?? '').trim();
            if (!r || r === 'undefined' || r === 'null') {
                return isMulti ? 'Multi-fee payment not completed' : 'Payment not completed';
            }
            // Known Razorpay codes
            if (r.includes('BAD_REQUEST_ERROR')) return 'Request error — payment could not be initiated';
            if (r.includes('GATEWAY_ERROR'))     return 'Payment gateway error — please retry';
            if (r.includes('NETWORK_ERROR'))     return 'Network error — check your connection';
            if (r.includes('Payment cancelled') || r === 'Payment cancelled') return 'Payment cancelled by user';
            if (r.includes('Payment failed'))    return 'Payment declined by bank or gateway';
            return r;
        }

        const txns: object[] = [];

        // 1. Confirmed FeePayments
        for (const p of payments) {
            txns.push({
                type: 'PAYMENT',
                id: p.id,
                recordId: p.recordId,
                recordTitle: recordMap[p.recordId]?.title ?? '',
                amount: p.amount,
                date: p.paidAt,
                mode: p.mode,
                receiptNo: p.receiptNo,
                razorpayPaymentId: p.razorpayPaymentId,
                razorpayOrderId: p.razorpayOrderId,
                notes: p.notes,
            });
        }

        // 2. All RazorpayOrder groups — skip PAID (already in FeePayments) to avoid duplicates
        for (const [rzpId, rows] of Array.from(orderGroups.entries())) {
            const first = rows[0]!;
            const status = first.status; // all rows in group share same razorpayOrderId, status changes together
            if (status === 'PAID') continue; // covered by FeePayment rows above

            const isMulti = rows.length > 1 || (first.notes as any)?.multiPay === true;
            const totalPaise = rows.reduce((s: number, r: { amountPaise: number }) => s + r.amountPaise, 0);
            const recordEntries = rows.map((r: { recordId: string; amountPaise: number }) => ({
                id: r.recordId,
                title: recordMap[r.recordId]?.title ?? '',
                amount: r.amountPaise / 100,
            }));
            const combinedTitle = isMulti
                ? recordEntries.map((r: { title: string }) => r.title).filter(Boolean).join(', ')
                : (recordMap[first.recordId]?.title ?? '');

            const rawReason = rows.find((r: { failureReason: string | null }) => r.failureReason)?.failureReason ?? null;

            txns.push({
                type: 'ORDER',
                id: first.id,
                razorpayOrderId: rzpId,
                razorpayPaymentId: first.razorpayPaymentId,
                status,                                    // CREATED | FAILED | EXPIRED
                totalAmount: totalPaise / 100,
                date: first.failedAt ?? first.createdAt,
                failureReason: status === 'FAILED' ? humanReason(rawReason, isMulti) : null,
                failedAt: first.failedAt,
                receipt: first.receipt,
                paymentRecorded: first.paymentRecorded,
                transferId: first.transferId,
                transferStatus: first.transferStatus,
                platformFeePaise: first.platformFeePaise,
                isMultiPay: isMulti,
                records: recordEntries,
                recordTitle: combinedTitle,
                createdAt: first.createdAt,
            });
        }

        // Sort newest first
        txns.sort((a: any, b: any) => new Date(b.date).getTime() - new Date(a.date).getTime());
        return txns;
    }

    async getMyFees(coachingId: string, userId: string) {
        await this._markOverdueRecords(coachingId);

        // Find member record for this user (or ward of this user)
        const member = await prisma.coachingMember.findFirst({
            where: { coachingId, userId },
        });
        // Also check wards
        const wardMembers = await prisma.coachingMember.findMany({
            where: { coachingId, ward: { parentId: userId } },
            include: { ward: { select: { id: true, name: true, picture: true } } },
        });

        const memberIds = [
            ...(member ? [member.id] : []),
            ...wardMembers.map(w => w.id),
        ];

        if (memberIds.length === 0) return { records: [], summary: { totalDue: 0, totalPaid: 0, totalOverdue: 0 } };

        const records = await prisma.feeRecord.findMany({
            where: { coachingId, memberId: { in: memberIds } },
            orderBy: { dueDate: 'desc' },
            include: {
                assignment: { include: { feeStructure: true } },
                payments: { orderBy: { paidAt: 'desc' } },
                refunds: { orderBy: { refundedAt: 'desc' } },
                member: { select: MEMBER_SELECT },
            },
        });

        const enriched = records.map(r => ({ ...r, daysOverdue: r.status === 'OVERDUE' ? calcDaysOverdue(r.dueDate) : 0 }));
        return {
            records: enriched,
            summary: {
                totalDue: enriched.filter(r => ['PENDING', 'PARTIALLY_PAID', 'OVERDUE'].includes(r.status)).reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0),
                totalPaid: enriched.reduce((s, r) => s + r.paidAmount, 0),
                totalOverdue: enriched.filter(r => r.status === 'OVERDUE').reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0),
            },
        };
    }

    // ── Internal helpers ────────────────────────────────────────────

    private async _ensureStructureOwned(coachingId: string, structureId: string) {
        const s = await prisma.feeStructure.findFirst({ where: { id: structureId, coachingId } });
        if (!s) throw Object.assign(new Error('Fee structure not found'), { status: 404 });
        return s;
    }

    private async _createFeeRecord(
        coachingId: string,
        assignmentId: string,
        memberId: string,
        structure: {
            name: string; cycle: string; lateFinePerDay: number; amount: number;
            taxType?: string; gstRate?: number; sacCode?: string | null; hsnCode?: string | null;
            gstSupplyType?: string; cessRate?: number; lineItems?: unknown;
        },
        netAmount: number,
        dueDate: Date,
        customTitle?: string,
        discountAmount: number = 0,
    ) {
        // Check no duplicate for this assignment + dueDate month
        const existing = await prisma.feeRecord.findFirst({
            where: {
                assignmentId,
                dueDate: {
                    gte: new Date(dueDate.getFullYear(), dueDate.getMonth(), 1),
                    lt: new Date(dueDate.getFullYear(), dueDate.getMonth() + 1, 1),
                },
            },
        });
        if (existing) return existing;

        // Compute tax on the net (post-discount) amount
        const taxType = structure.taxType ?? 'NONE';
        const gstRate = structure.gstRate ?? 0;
        const supplyType = structure.gstSupplyType ?? 'INTRA_STATE';
        const cessRate = structure.cessRate ?? 0;
        const tax = computeTax(netAmount, taxType, gstRate, supplyType, cessRate);

        // finalAmount = net (post-discount) + tax portion.
        // For GST_EXCLUSIVE: tax.taxAmount is on top → correct.
        // For GST_INCLUSIVE: tax.taxAmount is extracted from the inclusive price and we
        // still add it back so finalAmount = taxableAmount + taxAmount = invoiced total.
        // This matches the formula: baseAmount − discountAmount + taxAmount used everywhere else.
        const recordFinalAmount = netAmount + tax.taxAmount;
        // baseAmount = structure amount (pre-discount), discountAmount = total discount
        const baseAmount = netAmount + discountAmount;

        return prisma.feeRecord.create({
            data: {
                coachingId,
                assignmentId,
                memberId,
                title: customTitle ?? buildRecordTitle(structure.name, dueDate, structure.cycle),
                amount: recordFinalAmount,
                baseAmount,
                discountAmount,
                fineAmount: 0,
                finalAmount: recordFinalAmount,
                dueDate,
                status: 'PENDING',
                // Tax snapshot
                taxType,
                taxAmount: tax.taxAmount,
                cgstAmount: tax.cgstAmount,
                sgstAmount: tax.sgstAmount,
                igstAmount: tax.igstAmount,
                cessAmount: tax.cessAmount,
                gstRate,
                sacCode: structure.sacCode ?? null,
                hsnCode: structure.hsnCode ?? null,
                // Line items snapshot
                lineItems: structure.lineItems != null ? structure.lineItems as Prisma.InputJsonValue : Prisma.JsonNull,
            },
        });
    }

    private async _markOverdueRecords(coachingId: string) {
        // 1. Mark new PENDING → OVERDUE and compute initial fine
        const newOverdue = await prisma.feeRecord.findMany({
            where: { coachingId, status: 'PENDING', dueDate: { lt: new Date() } },
            include: { assignment: { include: { feeStructure: { select: { lateFinePerDay: true } } } } },
        });
        if (newOverdue.length > 0) {
            await Promise.all(newOverdue.map(r => {
                const days = calcDaysOverdue(r.dueDate);
                const lateFine = r.assignment?.feeStructure?.lateFinePerDay ?? 0;
                const fineAmount = lateFine > 0 ? lateFine * days : 0;
                return prisma.feeRecord.update({
                    where: { id: r.id },
                    data: { status: 'OVERDUE', fineAmount, finalAmount: r.baseAmount - r.discountAmount + fineAmount + r.taxAmount },
                });
            }));
        }

        // 2. Refresh accrued fine on already-OVERDUE records (daily tick)
        const alreadyOverdue = await prisma.feeRecord.findMany({
            where: { coachingId, status: 'OVERDUE' },
            include: { assignment: { include: { feeStructure: { select: { lateFinePerDay: true } } } } },
        });
        const overdueUpdates: { id: string; fineAmount: number; finalAmount: number }[] = [];
        for (const r of alreadyOverdue) {
            const lateFine = r.assignment?.feeStructure?.lateFinePerDay ?? 0;
            if (lateFine > 0) {
                const fineAmount = lateFine * calcDaysOverdue(r.dueDate);
                if (Math.abs(fineAmount - r.fineAmount) > 0.01) {
                    overdueUpdates.push({ id: r.id, fineAmount, finalAmount: r.baseAmount - r.discountAmount + fineAmount + r.taxAmount });
                }
            }
        }
        // Batch update overdue records to avoid N+1 queries
        if (overdueUpdates.length > 0) {
            await Promise.all(overdueUpdates.map(u =>
                prisma.feeRecord.update({ where: { id: u.id }, data: { fineAmount: u.fineAmount, finalAmount: u.finalAmount } })
            ));
        }
    }


    // ── Calendar ─────────────────────────────────────────────────────────

    async getFeeCalendar(coachingId: string, from: Date, to: Date) {
        // 1. Get payments in range
        // FeePayment -> record (FeeRecord) -> assignment (FeeAssignment) -> coachingId
        const payments = await prisma.feePayment.findMany({
            where: {
                record: {
                    assignment: { coachingId, isActive: true },
                },
                paidAt: { gte: from, lte: to },
            },
            select: { amount: true, paidAt: true },
        });

        // 2. Get dues in range (records due between from/to)
        // FeeRecord -> assignment (FeeAssignment) -> coachingId
        const dues = await prisma.feeRecord.findMany({
            where: {
                assignment: { coachingId, isActive: true },
                dueDate: { gte: from, lte: to },
                status: { not: 'WAIVED' },
            },
            select: { finalAmount: true, dueDate: true },
        });

        const map = new Map<string, { collected: number; due: number }>();
        const toKey = (d: Date) => d.toISOString().substring(0, 10);

        // Process payments (COLLECTED)
        for (const p of payments) {
            const k = toKey(p.paidAt);
            const e = map.get(k) || { collected: 0, due: 0 };
            e.collected += Number(p.amount);
            map.set(k, e);
        }

        // Process dues (DUE)
        for (const d of dues) {
            const k = toKey(d.dueDate);
            const e = map.get(k) || { collected: 0, due: 0 };
            e.due += Number(d.finalAmount);
            map.set(k, e);
        }

        return Array.from(map.entries()).map(([date, stats]) => ({
            date,
            collected: stats.collected,
            due: stats.due,
        }));
    }
}
