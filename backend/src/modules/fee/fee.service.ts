import prisma from '../../infra/prisma.js';
import { Prisma } from '@prisma/client';

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateFeeStructureDto {
    name: string;
    description?: string;
    amount: number;
    cycle?: string; // ONCE | MONTHLY | QUARTERLY | HALF_YEARLY | YEARLY | CUSTOM
    lateFinePerDay?: number;
    discounts?: object;
}

export interface UpdateFeeStructureDto {
    name?: string;
    description?: string;
    amount?: number;
    cycle?: string;
    lateFinePerDay?: number;
    discounts?: object;
    isActive?: boolean;
}

export interface AssignFeeDto {
    memberId: string;
    feeStructureId: string;
    customAmount?: number;
    discountAmount?: number;
    discountReason?: string;
    startDate?: string; // ISO string
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

export interface ListFeeRecordsQuery {
    memberId?: string;
    status?: string; // PENDING | PAID | OVERDUE | WAIVED | PARTIALLY_PAID
    from?: string;   // ISO date
    to?: string;     // ISO date
    page?: number;
    limit?: number;
}

// ─── Helpers ─────────────────────────────────────────────────────────

function generateReceiptNo(): string {
    const ts = Date.now().toString(36).toUpperCase();
    const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `RCP-${ts}-${rand}`;
}

/** Computes next due date from current date based on cycle. */
function nextDueDate(from: Date, cycle: string): Date {
    const d = new Date(from);
    switch (cycle) {
        case 'MONTHLY':
            d.setMonth(d.getMonth() + 1);
            break;
        case 'QUARTERLY':
            d.setMonth(d.getMonth() + 3);
            break;
        case 'HALF_YEARLY':
            d.setMonth(d.getMonth() + 6);
            break;
        case 'YEARLY':
            d.setFullYear(d.getFullYear() + 1);
            break;
        default:
            // ONCE or CUSTOM — no further cycles
            break;
    }
    return d;
}

function buildRecordTitle(structureName: string, dueDate: Date, cycle: string): string {
    const month = dueDate.toLocaleString('en-IN', { month: 'long', year: 'numeric' });
    if (cycle === 'ONCE') return structureName;
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
            },
        });
    }

    async updateStructure(coachingId: string, structureId: string, dto: UpdateFeeStructureDto) {
        await this._ensureStructureOwned(coachingId, structureId);
        return prisma.feeStructure.update({
            where: { id: structureId },
            data: {
                ...dto,
                discounts: dto.discounts != null ? dto.discounts as Prisma.InputJsonValue : Prisma.JsonNull,
            },
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
        const finalAmount = (dto.customAmount ?? structure.amount) - (dto.discountAmount ?? 0);
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
                startDate,
                endDate: dto.endDate ? new Date(dto.endDate) : null,
                isActive: true,
            },
            update: {
                customAmount: dto.customAmount ?? null,
                discountAmount: dto.discountAmount ?? 0,
                discountReason: dto.discountReason ?? null,
                isActive: true,
                endDate: dto.endDate ? new Date(dto.endDate) : null,
            },
        });

        // Create first record if none exists for current cycle
        const existingRecord = await prisma.feeRecord.findFirst({
            where: { assignmentId: assignment.id, status: { in: ['PENDING', 'PARTIALLY_PAID'] } },
        });

        if (!existingRecord) {
            await this._createFeeRecord(coachingId, assignment.id, dto.memberId, structure, finalAmount, startDate);
        }

        return assignment;
    }

    async removeFeeAssignment(coachingId: string, assignmentId: string) {
        const assignment = await prisma.feeAssignment.findFirst({ where: { id: assignmentId, coachingId } });
        if (!assignment) throw Object.assign(new Error('Assignment not found'), { status: 404 });
        return prisma.feeAssignment.update({ where: { id: assignmentId }, data: { isActive: false } });
    }

    async getMemberFeeProfile(coachingId: string, memberId: string) {
        const assignments = await prisma.feeAssignment.findMany({
            where: { coachingId, memberId, isActive: true },
            include: {
                feeStructure: true,
                records: {
                    orderBy: { dueDate: 'desc' },
                    take: 12,
                    include: { payments: true },
                },
            },
        });
        const member = await prisma.coachingMember.findFirst({
            where: { id: memberId, coachingId },
            select: MEMBER_SELECT,
        });
        if (!member) throw Object.assign(new Error('Member not found'), { status: 404 });

        return { member, assignments };
    }

    // ── Fee Records ─────────────────────────────────────────────────

    async listRecords(coachingId: string, query: ListFeeRecordsQuery) {
        const { memberId, status, from, to, page = 1, limit = 30 } = query;

        // Auto-update overdue records before returning list
        await this._markOverdueRecords(coachingId);

        const where: object = {
            coachingId,
            ...(memberId && { memberId }),
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
                include: {
                    member: { select: MEMBER_SELECT },
                    assignment: { include: { feeStructure: true } },
                    payments: { orderBy: { paidAt: 'desc' } },
                    markedBy: { select: { id: true, name: true } },
                },
            }),
        ]);

        return { total, page, limit, records };
    }

    async getRecordById(coachingId: string, recordId: string) {
        const record = await prisma.feeRecord.findFirst({
            where: { id: recordId, coachingId },
            include: {
                member: { select: MEMBER_SELECT },
                assignment: { include: { feeStructure: true } },
                payments: { orderBy: { paidAt: 'desc' } },
                markedBy: { select: { id: true, name: true } },
            },
        });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        return record;
    }

    /** Record a payment (full or partial) against a FeeRecord. */
    async recordPayment(coachingId: string, recordId: string, dto: RecordPaymentDto, userId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (record.status === 'PAID' || record.status === 'WAIVED') {
            throw Object.assign(new Error('This record is already settled'), { status: 400 });
        }

        const paidAt = dto.paidAt ? new Date(dto.paidAt) : new Date();
        const newPaidAmount = record.paidAmount + dto.amount;
        const isPaid = newPaidAmount >= record.finalAmount;

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
        if (isPaid) {
            const assignment = await prisma.feeAssignment.findUnique({
                where: { id: record.assignmentId },
                include: { feeStructure: true },
            });
            if (assignment && assignment.isActive && assignment.feeStructure.cycle !== 'ONCE') {
                const dueDate = nextDueDate(record.dueDate, assignment.feeStructure.cycle);
                const isBeforeEnd = !assignment.endDate || dueDate <= assignment.endDate;
                if (isBeforeEnd) {
                    const finalAmount = (assignment.customAmount ?? assignment.feeStructure.amount) - assignment.discountAmount;
                    await this._createFeeRecord(coachingId, assignment.id, record.memberId, assignment.feeStructure, finalAmount, dueDate);
                }
            }
        }

        return prisma.feeRecord.findUnique({
            where: { id: recordId },
            include: { payments: true },
        });
    }

    async waiveFee(coachingId: string, recordId: string, dto: WaiveFeeDto, userId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (record.status === 'PAID') throw Object.assign(new Error('Already paid'), { status: 400 });

        return prisma.feeRecord.update({
            where: { id: recordId },
            data: { status: 'WAIVED', notes: dto.notes ?? null, markedById: userId },
        });
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

    // ── Summary / Analytics ────────────────────────────────────────

    async getSummary(coachingId: string) {
        await this._markOverdueRecords(coachingId);

        const [statusGroups, totalCollected, totalPending, totalOverdue, paymentModes, monthlyCollection] = await Promise.all([
            // Count by status
            prisma.feeRecord.groupBy({
                by: ['status'],
                where: { coachingId },
                _count: true,
                _sum: { finalAmount: true },
            }),
            // Total collected
            prisma.feePayment.aggregate({
                where: { coachingId },
                _sum: { amount: true },
            }),
            // Total pending amount
            prisma.feeRecord.aggregate({
                where: { coachingId, status: { in: ['PENDING', 'PARTIALLY_PAID'] } },
                _sum: { finalAmount: true },
            }),
            // Total overdue amount
            prisma.feeRecord.aggregate({
                where: { coachingId, status: 'OVERDUE' },
                _sum: { finalAmount: true },
            }),
            // Breakdown by payment mode
            prisma.feePayment.groupBy({
                by: ['mode'],
                where: { coachingId },
                _sum: { amount: true },
                _count: true,
            }),
            // Monthly collection trend (last 12 months)
            prisma.$queryRaw<Array<{ month: string; total: number }>>`
                SELECT TO_CHAR(DATE_TRUNC('month', "paidAt"), 'YYYY-MM') AS month,
                       SUM(amount)::FLOAT AS total
                FROM "FeePayment"
                WHERE "coachingId" = ${coachingId}
                  AND "paidAt" >= NOW() - INTERVAL '12 months'
                GROUP BY 1
                ORDER BY 1
            `,
        ]);

        return {
            statusBreakdown: statusGroups,
            totalCollected: totalCollected._sum.amount ?? 0,
            totalPending: totalPending._sum.finalAmount ?? 0,
            totalOverdue: totalOverdue._sum.finalAmount ?? 0,
            paymentModes,
            monthlyCollection,
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
            where: {
                coachingId,
                ward: { parentId: userId },
            },
            include: {
                ward: { select: { id: true, name: true, picture: true } },
            },
        });

        const memberIds = [
            ...(member ? [member.id] : []),
            ...wardMembers.map(w => w.id),
        ];

        if (memberIds.length === 0) return { records: [] };

        const records = await prisma.feeRecord.findMany({
            where: { coachingId, memberId: { in: memberIds } },
            orderBy: { dueDate: 'desc' },
            include: {
                assignment: { include: { feeStructure: true } },
                payments: { orderBy: { paidAt: 'desc' } },
                member: { select: MEMBER_SELECT },
            },
        });

        return { records };
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
                title: buildRecordTitle(structure.name, dueDate, structure.cycle),
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
        await prisma.feeRecord.updateMany({
            where: {
                coachingId,
                status: 'PENDING',
                dueDate: { lt: new Date() },
            },
            data: { status: 'OVERDUE' },
        });
    }
}
