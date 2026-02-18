import prisma from '../../infra/prisma.js';
import { Prisma } from '@prisma/client';

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateFeeStructureDto {
    name: string;
    description?: string;
    amount: number;
    cycle?: string; // ONCE | MONTHLY | QUARTERLY | HALF_YEARLY | YEARLY | INSTALLMENT
    lateFinePerDay?: number;
    discounts?: object;
    installmentPlan?: Array<{ label: string; dueDay: number; amount: number }>;
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

function generateReceiptNo(): string {
    const ts = Date.now().toString(36).toUpperCase();
    const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `RCP-${ts}-${rand}`;
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
        case 'MONTHLY':     d.setMonth(d.getMonth() + 1);          break;
        case 'QUARTERLY':   d.setMonth(d.getMonth() + 3);          break;
        case 'HALF_YEARLY': d.setMonth(d.getMonth() + 6);          break;
        case 'YEARLY':      d.setFullYear(d.getFullYear() + 1);    break;
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
        return prisma.feeStructure.update({
            where: { id: structureId },
            data,
        });
    }

    async deleteStructure(coachingId: string, structureId: string) {
        await this._ensureStructureOwned(coachingId, structureId);
        // Soft-delete (deactivate) if records exist, hard-delete otherwise
        const count = await prisma.feeRecord.count({ where: { assignment: { feeStructureId: structureId } } });
        if (count > 0) {
            return prisma.feeStructure.update({ where: { id: structureId }, data: { isActive: false } });
        }
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
            for (const inst of plan) {
                const dueDate = new Date(startDate);
                dueDate.setDate(inst.dueDay);
                await this._createFeeRecord(coachingId, assignment.id, dto.memberId, structure, inst.amount, dueDate, inst.label);
            }
        } else {
            // Create first record if none exists for current cycle
            const existingRecord = await prisma.feeRecord.findFirst({
                where: { assignmentId: assignment.id, status: { in: ['PENDING', 'PARTIALLY_PAID'] } },
            });
            if (!existingRecord) {
                await this._createFeeRecord(coachingId, assignment.id, dto.memberId, structure, finalAmount, startDate);
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
        const totalFee    = allRecords.reduce((s, r) => s + r.finalAmount, 0);
        const totalPaid   = allRecords.reduce((s, r) => s + r.paidAmount, 0);
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
        const finalAmountLocked = record.baseAmount - record.discountAmount + fineNow;

        const newPaidAmount = record.paidAmount + dto.amount;
        const isPaid = newPaidAmount >= finalAmountLocked - 0.01;

        await prisma.$transaction([
            prisma.feePayment.create({
                data: {
                    coachingId,
                    recordId,
                    amount: dto.amount,
                    mode: dto.mode,
                    transactionRef: dto.transactionRef ?? null,
                    receiptNo: generateReceiptNo(),
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
                    receiptNo: isPaid ? generateReceiptNo() : record.receiptNo,
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
                    const fa = (assignment.customAmount ?? assignment.feeStructure.amount) - assignment.discountAmount - (assignment.scholarshipAmount ?? 0);
                    await this._createFeeRecord(coachingId, assignment.id, record.memberId, assignment.feeStructure, fa, dueDate);
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
                    status: newPaidAmount <= 0 ? 'PENDING' : newPaidAmount < record.finalAmount ? 'PARTIALLY_PAID' : 'PAID',
                },
            }),
        ]);

        return this.getRecordById(coachingId, recordId);
    }

    /** Mark reminder sent + increment counter. */
    async sendReminder(coachingId: string, recordId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
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
            fyEnd   = new Date(startYear + 1, 2, 31, 23, 59, 59);
        }
        const pyWhere = { coachingId, ...(fyStart && fyEnd ? { paidAt: { gte: fyStart, lte: fyEnd } } : {}) };
        const recWhere = { coachingId, ...(fyStart && fyEnd ? { dueDate: { gte: fyStart, lte: fyEnd } } : {}) };

        const [statusGroups, totalCollected, totalPendingAgg, totalOverdueAgg, paymentModes, monthlyCollection, overdueCount, todayCollection] = await Promise.all([
            prisma.feeRecord.groupBy({ by: ['status'], where: recWhere, _count: true, _sum: { finalAmount: true } }),
            prisma.feePayment.aggregate({ where: pyWhere, _sum: { amount: true } }),
            prisma.feeRecord.aggregate({ where: { ...recWhere, status: { in: ['PENDING', 'PARTIALLY_PAID', 'OVERDUE'] } }, _sum: { finalAmount: true } }),
            prisma.feeRecord.aggregate({ where: { ...recWhere, status: 'OVERDUE' }, _sum: { finalAmount: true } }),
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

        return {
            statusBreakdown: statusGroups,
            totalCollected: totalCollected._sum.amount ?? 0,
            totalPending: totalPendingAgg._sum.finalAmount ?? 0,
            totalOverdue: totalOverdueAgg._sum.finalAmount ?? 0,
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
                totalDue:     enriched.filter(r => ['PENDING', 'PARTIALLY_PAID', 'OVERDUE'].includes(r.status)).reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0),
                totalPaid:    enriched.reduce((s, r) => s + r.paidAmount, 0),
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
        structure: { name: string; cycle: string; lateFinePerDay: number },
        finalAmount: number,
        dueDate: Date,
        customTitle?: string,
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

        return prisma.feeRecord.create({
            data: {
                coachingId,
                assignmentId,
                memberId,
                title: customTitle ?? buildRecordTitle(structure.name, dueDate, structure.cycle),
                amount: finalAmount,
                baseAmount: finalAmount,
                discountAmount: 0,
                fineAmount: 0,
                finalAmount,
                dueDate,
                status: 'PENDING',
            },
        });
    }

    private async _markOverdueRecords(coachingId: string) {
        // 1. Mark new PENDING → OVERDUE and compute initial fine
        const newOverdue = await prisma.feeRecord.findMany({
            where: { coachingId, status: 'PENDING', dueDate: { lt: new Date() } },
            include: { assignment: { include: { feeStructure: { select: { lateFinePerDay: true } } } } },
        });
        for (const r of newOverdue) {
            const days = calcDaysOverdue(r.dueDate);
            const lateFine = r.assignment?.feeStructure?.lateFinePerDay ?? 0;
            const fineAmount = lateFine > 0 ? lateFine * days : 0;
            await prisma.feeRecord.update({
                where: { id: r.id },
                data: { status: 'OVERDUE', fineAmount, finalAmount: r.baseAmount - r.discountAmount + fineAmount },
            });
        }

        // 2. Refresh accrued fine on already-OVERDUE records (daily tick)
        const alreadyOverdue = await prisma.feeRecord.findMany({
            where: { coachingId, status: 'OVERDUE' },
            include: { assignment: { include: { feeStructure: { select: { lateFinePerDay: true } } } } },
        });
        for (const r of alreadyOverdue) {
            const lateFine = r.assignment?.feeStructure?.lateFinePerDay ?? 0;
            if (lateFine > 0) {
                const fineAmount = lateFine * calcDaysOverdue(r.dueDate);
                if (Math.abs(fineAmount - r.fineAmount) > 0.01) {
                    await prisma.feeRecord.update({
                        where: { id: r.id },
                        data: { fineAmount, finalAmount: r.baseAmount - r.discountAmount + fineAmount },
                    });
                }
            }
        }
    }
}
