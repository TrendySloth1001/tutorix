import prisma from '../../infra/prisma.js';
import { Prisma } from '@prisma/client';
import { NotificationService } from '../notification/notification.service.js';

const notifSvc = new NotificationService();

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateFeeStructureDto {
    name: string;
    description?: string | undefined;
    amount: number;
    cycle?: string | undefined;
    lateFinePerDay?: number | undefined;
    discounts?: object | undefined;
    installmentPlan?: Array<{ label: string; dueDay: number; amount: number }> | undefined;
    taxType?: string | undefined;
    gstRate?: number | undefined;
    sacCode?: string | undefined;
    hsnCode?: string | undefined;
    gstSupplyType?: string | undefined;
    cessRate?: number | undefined;
    lineItems?: Array<{ label: string; amount: number }> | undefined;
    // installment control fields
    allowInstallments?: boolean | undefined;
    installmentCount?: number | undefined;
    installmentAmounts?: Array<{ label: string; amount: number }> | undefined;
}

export interface UpdateFeeStructureDto {
    name?: string | undefined;
    description?: string | null | undefined;
    amount?: number | undefined;
    cycle?: string | undefined;
    lateFinePerDay?: number | undefined;
    discounts?: object | undefined;
    installmentPlan?: object | undefined;
    isActive?: boolean | undefined;
    taxType?: string | null | undefined;
    gstRate?: number | null | undefined;
    sacCode?: string | null | undefined;
    hsnCode?: string | null | undefined;
    gstSupplyType?: string | null | undefined;
    cessRate?: number | null | undefined;
    lineItems?: Array<{ label: string; amount: number }> | null | undefined;
    // installment control fields
    allowInstallments?: boolean | undefined;
    installmentCount?: number | undefined;
    installmentAmounts?: Array<{ label: string; amount: number }> | null | undefined;
}

export interface AssignFeeDto {
    memberId: string;
    feeStructureId: string;
    customAmount?: number | undefined;
    discountAmount?: number | undefined;
    discountReason?: string | undefined;
    scholarshipTag?: string | undefined;
    scholarshipAmount?: number | undefined;
    startDate?: string | undefined;
    endDate?: string | undefined;
}

export interface RecordPaymentDto {
    amount: number;
    mode: string;
    transactionRef?: string | undefined;
    notes?: string | undefined;
    paidAt?: string | undefined;
}

export interface WaiveFeeDto {
    notes?: string | undefined;
}

export interface RecordRefundDto {
    amount: number;
    reason?: string | undefined;
    mode?: string | undefined;
    refundedAt?: string | undefined;
}

export interface BulkRemindDto {
    statusFilter?: string | undefined;
    memberIds?: string[] | undefined;
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

export interface ListAuditLogQuery {
    entityType?: string | undefined;
    entityId?: string | undefined;
    event?: string | undefined;
    from?: string | undefined;
    to?: string | undefined;
    page?: number | undefined;
    limit?: number | undefined;
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

/** Generate sequential receipt number INSIDE a transaction context: TXR/2025-26/0042 */
async function generateSequentialReceiptNo(coachingId: string, tx?: any): Promise<string> {
    const db = tx ?? prisma;
    const fy = getFinancialYear();
    const seq = await db.receiptSequence.upsert({
        where: { coachingId_financialYear: { coachingId, financialYear: fy } },
        create: { coachingId, financialYear: fy, lastNumber: 1 },
        update: { lastNumber: { increment: 1 } },
    });
    return `TXR/${fy}/${seq.lastNumber.toString().padStart(6, '0')}`;
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

    // Round gstAmount and cess to nearest whole rupee so CGST+SGST always
    // sums to the displayed total (avoids 252+252=504 ≠ 503 rounding drift).
    gstAmount = Math.round(gstAmount);
    cess = Math.round(cess);
    taxableAmount = Math.round(taxableAmount * 100) / 100; // keep 2dp for reference

    let cgst = 0, sgst = 0, igst = 0;
    if (supplyType === 'INTER_STATE') {
        igst = gstAmount;
    } else {
        // Integer floor/ceil split: cgst + sgst === gstAmount exactly at 0dp
        cgst = Math.floor(gstAmount / 2);
        sgst = gstAmount - cgst;
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
        case 'CUSTOM':
            // Custom cycles don't auto-generate; return far future to stop auto-creation
            d.setFullYear(d.getFullYear() + 100);
            break;
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

// Per-coaching debounce cache for _markOverdueRecords (avoids N+1 queries on every read)
const _overdueLastRun = new Map<string, number>();
const OVERDUE_DEBOUNCE_MS = 5 * 60 * 1000; // 5 minutes

// Separate debounce for the self-heal scan (runs more frequently than the overdue sweep)
const _healLastRun = new Map<string, number>();
const HEAL_DEBOUNCE_MS = 60 * 1000; // 60 seconds

// ─── Audit Logger ─────────────────────────────────────────────────────

interface AuditParams {
    coachingId: string;
    entityType: string;
    entityId: string;
    event: string;
    actorId?: string | null;    // null / undefined → SYSTEM
    feeStructureId?: string | null;
    before?: object | null;
    after?: object | null;
    meta?: object | null;
    note?: string | null;
}

/** Fire-and-forget audit log write — never throws so it doesn't break main flow. */
async function writeAuditLog(params: AuditParams): Promise<void> {
    try {
        await prisma.feeAuditLog.create({
            data: {
                coachingId: params.coachingId,
                entityType: params.entityType,
                entityId: params.entityId,
                event: params.event,
                actorType: params.actorId ? 'ADMIN' : 'SYSTEM',
                actorId: params.actorId ?? null,
                feeStructureId: params.feeStructureId ?? null,
                before: params.before != null ? params.before as Prisma.InputJsonValue : Prisma.JsonNull,
                after: params.after != null ? params.after as Prisma.InputJsonValue : Prisma.JsonNull,
                meta: params.meta != null ? params.meta as Prisma.InputJsonValue : Prisma.JsonNull,
                note: params.note ?? null,
            },
        });
    } catch (err) {
        // Audit log failure must never crash the main operation
        console.error('[FeeAuditLog] write failed:', err);
    }
}

export class FeeService {

    // ── Fee Structures ─────────────────────────────────────────────

    async listStructures(coachingId: string) {
        return prisma.feeStructure.findMany({
            where: { coachingId, isActive: true },
            orderBy: [{ createdAt: 'desc' }],
            include: {
                _count: { select: { assignments: true } },
            },
        });
    }

    /**
     * Get the current (active) fee structure for a coaching.
     * Returns the one with isCurrent=true, or the most recently created active one.
     */
    async getCurrentStructure(coachingId: string) {
        const current = await prisma.feeStructure.findFirst({
            where: { coachingId, isCurrent: true, isActive: true },
            include: { _count: { select: { assignments: true } } },
        });
        return current;
    }

    /**
     * Preview info for "warning" bottom sheet before replacing a structure.
     * Returns the current structure + count + sample member names.
     */
    async getStructureReplacePreview(coachingId: string) {
        const current = await prisma.feeStructure.findFirst({
            where: { coachingId, isCurrent: true, isActive: true },
            include: { _count: { select: { assignments: true } } },
        });
        if (!current) return { hasCurrent: false, current: null, memberCount: 0, memberNames: [] };

        // Get up to 10 member names mapped to the current structure
        const assignments = await prisma.feeAssignment.findMany({
            where: { feeStructureId: current.id, isActive: true },
            take: 10,
            include: {
                member: {
                    select: {
                        user: { select: { name: true } },
                        ward: { select: { name: true } },
                    },
                },
            },
        });
        const memberNames = assignments.map((a) => a.member.user?.name ?? a.member.ward?.name ?? 'Unknown');
        const totalCount = current._count.assignments;

        return { hasCurrent: true, current, memberCount: totalCount, memberNames };
    }

    async createStructure(coachingId: string, dto: CreateFeeStructureDto, actorId?: string) {
        // Each structure is independent — multiple can coexist per coaching.
        // No "current" enforcement or demotion.
        const created = await prisma.feeStructure.create({
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
                // Installment controls
                allowInstallments: dto.allowInstallments ?? false,
                installmentCount: dto.installmentCount ?? 0,
                installmentAmounts: dto.installmentAmounts != null ? dto.installmentAmounts as Prisma.InputJsonValue : Prisma.JsonNull,
            },
        });

        void writeAuditLog({
            coachingId,
            entityType: 'STRUCTURE',
            entityId: created.id,
            event: 'STRUCTURE_CREATED',
            actorId: actorId ?? null,
            feeStructureId: created.id,
            after: { id: created.id, name: created.name, amount: created.amount, cycle: created.cycle },
        });

        return created;
    }

    async updateStructure(coachingId: string, structureId: string, dto: UpdateFeeStructureDto, actorId?: string) {
        const before = await this._ensureStructureOwned(coachingId, structureId);
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
        // Installment control fields
        if (dto.allowInstallments !== undefined) data.allowInstallments = dto.allowInstallments;
        if (dto.installmentCount !== undefined) data.installmentCount = dto.installmentCount;
        if (dto.installmentAmounts !== undefined) {
            data.installmentAmounts = dto.installmentAmounts != null ? dto.installmentAmounts as Prisma.InputJsonValue : Prisma.JsonNull;
        }

        const installmentSettingChanged =
            dto.allowInstallments !== undefined ||
            dto.installmentCount !== undefined ||
            dto.installmentAmounts !== undefined;

        const priceOrTaxChanged =
            dto.amount !== undefined ||
            dto.taxType !== undefined ||
            dto.gstRate !== undefined ||
            dto.gstSupplyType !== undefined ||
            dto.cessRate !== undefined;

        const updated = await prisma.feeStructure.update({
            where: { id: structureId },
            data,
        });

        // Audit log
        void writeAuditLog({
            coachingId,
            entityType: 'STRUCTURE',
            entityId: structureId,
            event: installmentSettingChanged ? 'INSTALLMENT_SETTINGS_CHANGED' : 'STRUCTURE_UPDATED',
            actorId: actorId ?? null,
            feeStructureId: structureId,
            before: { name: before.name, amount: before.amount, taxType: before.taxType, gstRate: before.gstRate,
                      allowInstallments: before.allowInstallments, installmentCount: before.installmentCount },
            after: { name: updated.name, amount: updated.amount, taxType: updated.taxType, gstRate: updated.gstRate,
                     allowInstallments: updated.allowInstallments, installmentCount: updated.installmentCount },
        });

        // Cascade price/tax changes to all PENDING unpaid records linked to this structure
        if (priceOrTaxChanged && updated.cycle !== 'INSTALLMENT') {
            const assignments = await prisma.feeAssignment.findMany({
                where: { feeStructureId: structureId, isActive: true },
                select: { id: true, customAmount: true, discountAmount: true, scholarshipAmount: true },
            });

            await Promise.all(assignments.map(async (a) => {
                const totalDiscount = a.discountAmount + (a.scholarshipAmount ?? 0);
                const netAmount = (a.customAmount ?? updated.amount) - totalDiscount;
                if (netAmount < 0) return; // skip — negative net is a data integrity issue

                const tax = computeTax(
                    netAmount,
                    updated.taxType ?? 'NONE',
                    updated.gstRate ?? 0,
                    updated.gstSupplyType ?? 'INTRA_STATE',
                    updated.cessRate ?? 0,
                );
                const newFinal = tax.totalWithTax;
                const grossBase = netAmount + totalDiscount;

                // 1. PENDING with no payments — batch update
                await prisma.feeRecord.updateMany({
                    where: { assignmentId: a.id, status: 'PENDING', paidAmount: 0 },
                    data: {
                        baseAmount: grossBase,
                        discountAmount: totalDiscount,
                        amount: newFinal,
                        finalAmount: newFinal,
                        taxType: updated.taxType ?? 'NONE',
                        taxAmount: tax.taxAmount,
                        cgstAmount: tax.cgstAmount,
                        sgstAmount: tax.sgstAmount,
                        igstAmount: tax.igstAmount,
                        cessAmount: tax.cessAmount,
                        gstRate: updated.gstRate ?? 0,
                        sacCode: updated.sacCode ?? null,
                        hsnCode: updated.hsnCode ?? null,
                    },
                });

                // 2. OVERDUE with no payments — update individually to preserve accrued fine
                //    finalAmount = newFinal (net+tax) + existing fineAmount
                const overdueUnpaid = await prisma.feeRecord.findMany({
                    where: { assignmentId: a.id, status: 'OVERDUE', paidAmount: 0 },
                    select: { id: true, fineAmount: true },
                });
                await Promise.all(overdueUnpaid.map(r =>
                    prisma.feeRecord.update({
                        where: { id: r.id },
                        data: {
                            baseAmount: grossBase,
                            discountAmount: totalDiscount,
                            amount: newFinal,
                            finalAmount: newFinal + r.fineAmount,
                            taxType: updated.taxType ?? 'NONE',
                            taxAmount: tax.taxAmount,
                            cgstAmount: tax.cgstAmount,
                            sgstAmount: tax.sgstAmount,
                            igstAmount: tax.igstAmount,
                            cessAmount: tax.cessAmount,
                            gstRate: updated.gstRate ?? 0,
                            sacCode: updated.sacCode ?? null,
                            hsnCode: updated.hsnCode ?? null,
                        },
                    }),
                ));
            }));
        }

        return updated;
    }

    async deleteStructure(coachingId: string, structureId: string, actorId?: string) {
        const structure = await this._ensureStructureOwned(coachingId, structureId);
        // Check if any fee records exist under this structure
        const recordCount = await prisma.feeRecord.count({ where: { assignment: { feeStructureId: structureId } } });
        let result;
        if (recordCount > 0) {
            // Soft-delete: deactivate structure + all its assignments
            await prisma.feeAssignment.updateMany({ where: { feeStructureId: structureId }, data: { isActive: false } });
            result = await prisma.feeStructure.update({ where: { id: structureId }, data: { isActive: false, isCurrent: false } });
        } else {
            // No records: safe to hard-delete (cascades to assignments)
            result = await prisma.feeStructure.delete({ where: { id: structureId } });
        }

        void writeAuditLog({
            coachingId,
            entityType: 'STRUCTURE',
            entityId: structureId,
            event: 'STRUCTURE_DELETED',
            actorId: actorId ?? null,
            feeStructureId: structureId,
            before: { name: structure.name, amount: structure.amount },
            meta: { softDelete: recordCount > 0 },
        });

        return result;
    }

    // ── Assignments ─────────────────────────────────────────────────

    /** Assign a fee structure to a member and create the first FeeRecord. */
    async assignFee(coachingId: string, dto: AssignFeeDto, assignedById: string) {
        const structure = await this._ensureStructureOwned(coachingId, dto.feeStructureId);

        // M4: Verify member belongs to this coaching
        const memberExists = await prisma.coachingMember.findFirst({
            where: { id: dto.memberId, coachingId },
            select: { id: true },
        });
        if (!memberExists) throw Object.assign(new Error('Member not found in this coaching'), { status: 404 });

        // One assignment per member per coaching — if structure is changing, clean up old records
        const existingAssignment = await prisma.feeAssignment.findFirst({
            where: { coachingId, memberId: dto.memberId },
            select: { id: true, feeStructureId: true },
        });
        let structureChanged = false;
        if (existingAssignment && existingAssignment.feeStructureId !== dto.feeStructureId) {
            structureChanged = true;
            // 1. Hard-delete fully unpaid records — no payment history to preserve
            await prisma.feeRecord.deleteMany({
                where: {
                    assignmentId: existingAssignment.id,
                    paidAmount: 0,
                    status: { in: ['PENDING', 'OVERDUE'] },
                },
            });
            // 2. Auto-waive partially-paid records using the same business rule as waiveFee:
            //    finalAmount = paidAmount (remaining balance forgiven), status = WAIVED.
            //    The collected amount stays — no refund, no manual labour needed.
            const partialRecords = await prisma.feeRecord.findMany({
                where: { assignmentId: existingAssignment.id, status: 'PARTIALLY_PAID' },
                select: { id: true, paidAmount: true, finalAmount: true },
            });
            await Promise.all(partialRecords.map(r =>
                prisma.feeRecord.update({
                    where: { id: r.id },
                    data: {
                        status: 'WAIVED',
                        finalAmount: r.paidAmount, // zero out remaining balance
                        notes: 'Remaining balance auto-waived — fee structure reassigned by admin',
                    },
                }),
            ));
            for (const r of partialRecords) {
                void writeAuditLog({
                    coachingId,
                    entityType: 'RECORD',
                    entityId: r.id,
                    event: 'FEE_WAIVED',
                    actorId: assignedById,
                    before: { status: 'PARTIALLY_PAID', finalAmount: r.finalAmount, paidAmount: r.paidAmount },
                    after: { status: 'WAIVED', notes: 'Remaining balance auto-waived — fee structure reassigned by admin' },
                });
            }
        }

        // Build amounts
        const totalDiscount = (dto.discountAmount ?? 0) + (dto.scholarshipAmount ?? 0);
        const finalAmount = (dto.customAmount ?? structure.amount) - totalDiscount;

        // H5: Guard against negative finalAmount
        if (finalAmount < 0) {
            throw Object.assign(new Error('Total discount + scholarship cannot exceed the fee amount'), { status: 400 });
        }

        const startDate = dto.startDate ? new Date(dto.startDate) : new Date();

        const assignment = await prisma.feeAssignment.upsert({
            where: { coachingId_memberId: { coachingId, memberId: dto.memberId } },
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
                feeStructureId: dto.feeStructureId,
                customAmount: dto.customAmount ?? null,
                discountAmount: dto.discountAmount ?? 0,
                discountReason: dto.discountReason ?? null,
                scholarshipTag: dto.scholarshipTag ?? null,
                scholarshipAmount: dto.scholarshipAmount ?? null,
                isActive: true,
                endDate: dto.endDate ? new Date(dto.endDate) : null,
            },
        });

        // For INSTALLMENT cycle: create records for each installment with per-installment amounts
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

        // H7: Update PENDING and OVERDUE unpaid records for non-installment cycles
        if (structure.cycle !== 'INSTALLMENT') {
            const tax = computeTax(finalAmount, structure.taxType ?? 'NONE', structure.gstRate ?? 0, structure.gstSupplyType ?? 'INTRA_STATE', structure.cessRate ?? 0);
            const updatedFinalAmount = tax.totalWithTax;
            const grossBase = finalAmount + totalDiscount;
            const taxSnapshot = {
                taxType: structure.taxType ?? 'NONE',
                taxAmount: tax.taxAmount,
                cgstAmount: tax.cgstAmount,
                sgstAmount: tax.sgstAmount,
                igstAmount: tax.igstAmount,
                cessAmount: tax.cessAmount,
                gstRate: structure.gstRate ?? 0,
                sacCode: structure.sacCode ?? null,
                hsnCode: structure.hsnCode ?? null,
            };
            // 1. PENDING with no payments
            await prisma.feeRecord.updateMany({
                where: { assignmentId: assignment.id, status: 'PENDING', paidAmount: 0 },
                data: { baseAmount: grossBase, discountAmount: totalDiscount, amount: updatedFinalAmount, finalAmount: updatedFinalAmount, ...taxSnapshot },
            });
            // 2. OVERDUE with no payments — preserve accrued fine in finalAmount
            const overdueUnpaid = await prisma.feeRecord.findMany({
                where: { assignmentId: assignment.id, status: 'OVERDUE', paidAmount: 0 },
                select: { id: true, fineAmount: true },
            });
            await Promise.all(overdueUnpaid.map(r =>
                prisma.feeRecord.update({
                    where: { id: r.id },
                    data: { baseAmount: grossBase, discountAmount: totalDiscount, amount: updatedFinalAmount, finalAmount: updatedFinalAmount + r.fineAmount, ...taxSnapshot },
                }),
            ));
        }

        void writeAuditLog({
            coachingId,
            entityType: 'ASSIGNMENT',
            entityId: assignment.id,
            event: 'ASSIGNMENT_CREATED',
            actorId: assignedById,
            feeStructureId: dto.feeStructureId,
            after: {
                memberId: dto.memberId,
                feeStructureId: dto.feeStructureId,
                customAmount: dto.customAmount ?? null,
                discountAmount: totalDiscount,
                scholarshipTag: dto.scholarshipTag ?? null,
            },
        });

        return assignment;
    }

    async removeFeeAssignment(coachingId: string, assignmentId: string, actorId?: string) {
        const assignment = await prisma.feeAssignment.findFirst({ where: { id: assignmentId, coachingId } });
        if (!assignment) throw Object.assign(new Error('Assignment not found'), { status: 404 });
        const result = await prisma.feeAssignment.update({ where: { id: assignmentId }, data: { isActive: false } });
        void writeAuditLog({
            coachingId,
            entityType: 'ASSIGNMENT',
            entityId: assignmentId,
            event: 'ASSIGNMENT_REMOVED',
            actorId: actorId ?? null,
            feeStructureId: assignment.feeStructureId,
            before: { memberId: assignment.memberId, isActive: true },
            after: { isActive: false },
        });
        return result;
    }

    async toggleFeePause(coachingId: string, assignmentId: string, pause: boolean, note?: string, actorId?: string) {
        const a = await prisma.feeAssignment.findFirst({ where: { id: assignmentId, coachingId } });
        if (!a) throw Object.assign(new Error('Assignment not found'), { status: 404 });
        const result = await prisma.feeAssignment.update({
            where: { id: assignmentId },
            data: {
                isPaused: pause,
                pausedAt: pause ? new Date() : null,
                pauseNote: pause ? (note ?? null) : null,
            },
        });
        void writeAuditLog({
            coachingId,
            entityType: 'ASSIGNMENT',
            entityId: assignmentId,
            event: pause ? 'ASSIGNMENT_PAUSED' : 'ASSIGNMENT_UNPAUSED',
            actorId: actorId ?? null,
            feeStructureId: a.feeStructureId,
            meta: { note: note ?? null },
        });
        return result;
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

        // H1 fix: paidAmount is already net-of-refunds, so balance = totalFee - totalPaid.
        // totalRefunded is reported separately for display purposes only.
        return {
            member,
            assignments: enriched,
            ledger: {
                totalFee,
                totalPaid,
                totalRefunded: totalRefund,
                balance: totalFee - totalPaid,
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
        if (dto.amount <= 0) throw Object.assign(new Error('Amount must be positive'), { status: 400 });
        const paidAt = dto.paidAt ? new Date(dto.paidAt) : new Date();

        // C3 fix: Use interactive transaction with Serializable isolation to prevent
        // concurrent payments from double-crediting.
        const result = await prisma.$transaction(async (tx) => {
            // Read record INSIDE the transaction for consistent snapshot
            const record = await tx.feeRecord.findFirst({ where: { id: recordId, coachingId } });
            if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
            if (record.status === 'PAID' || record.status === 'WAIVED') {
                throw Object.assign(new Error('This record is already settled'), { status: 400 });
            }

            // Lock current fine at payment time
            const assignment = await tx.feeAssignment.findUnique({
                where: { id: record.assignmentId },
                include: { feeStructure: true },
            });
            const lateFine = assignment?.feeStructure?.lateFinePerDay ?? 0;
            const days = calcDaysOverdue(record.dueDate);
            const fineNow = lateFine > 0 && days > 0 ? lateFine * days : record.fineAmount;
            const netFee = record.baseAmount - record.discountAmount;
            // Always recompute tax from live structure (fixes stale/zero snapshot on old records)
            const fs = assignment?.feeStructure;
            const liveTax = computeTax(
                netFee,
                fs?.taxType ?? record.taxType ?? 'NONE',
                fs?.gstRate ?? record.gstRate ?? 0,
                fs?.gstSupplyType ?? 'INTRA_STATE',
                fs?.cessRate ?? 0,
            );
            const liveTaxType = fs?.taxType ?? record.taxType ?? 'NONE';
            const finalAmountLocked = netFee + fineNow + (liveTaxType === 'GST_INCLUSIVE' ? 0 : liveTax.taxAmount);

            // Guard against overpayment
            const balance = finalAmountLocked - record.paidAmount;
            if (dto.amount > balance + 0.01) {
                throw Object.assign(new Error(`Amount exceeds outstanding balance of ₹${balance.toFixed(2)}`), { status: 400 });
            }

            const newPaidAmount = record.paidAmount + dto.amount;
            const isPaid = newPaidAmount >= finalAmountLocked - 0.01;

            // Generate sequential receipt number INSIDE transaction
            const paymentReceiptNo = await generateSequentialReceiptNo(coachingId, tx);

            await tx.feePayment.create({
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
            });

            await tx.feeRecord.update({
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
                    // Refresh tax snapshot from live structure so receipt shows correct values
                    taxType: liveTaxType,
                    taxAmount: liveTax.taxAmount,
                    cgstAmount: liveTax.cgstAmount,
                    sgstAmount: liveTax.sgstAmount,
                    igstAmount: liveTax.igstAmount,
                    cessAmount: liveTax.cessAmount,
                    gstRate: fs?.gstRate ?? record.gstRate ?? 0,
                    sacCode: fs?.sacCode ?? record.sacCode ?? null,
                    hsnCode: fs?.hsnCode ?? record.hsnCode ?? null,
                },
            });

            return { isPaid, assignment, record };
        }, { isolationLevel: 'Serializable' });

        // After transaction: if paid and cycle-based, generate next record
        if (result.isPaid && result.assignment && result.assignment.isActive && !result.assignment.isPaused) {
            const cycle = result.assignment.feeStructure.cycle;
            if (cycle !== 'ONCE' && cycle !== 'INSTALLMENT') {
                const dueDate = nextDueDateFromCycle(result.record.dueDate, cycle);
                const isBeforeEnd = !result.assignment.endDate || dueDate <= result.assignment.endDate;
                if (isBeforeEnd) {
                    const totalDiscount = result.assignment.discountAmount + (result.assignment.scholarshipAmount ?? 0);
                    const fa = (result.assignment.customAmount ?? result.assignment.feeStructure.amount) - totalDiscount;
                    await this._createFeeRecord(coachingId, result.assignment.id, result.record.memberId, result.assignment.feeStructure, fa, dueDate, undefined, totalDiscount);
                }
            }
        }

        const updatedRecord = await prisma.feeRecord.findUniqueOrThrow({
            where: { id: recordId },
            include: RECORD_INCLUDE,
        });

        void writeAuditLog({
            coachingId,
            entityType: 'PAYMENT',
            entityId: recordId,
            event: 'PAYMENT_RECORDED',
            actorId: userId,
            after: {
                amount: dto.amount,
                mode: dto.mode,
                transactionRef: dto.transactionRef ?? null,
                isPaid: result.isPaid,
            },
        });

        return updatedRecord;
    }

    async waiveFee(coachingId: string, recordId: string, dto: WaiveFeeDto, userId: string) {
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (record.status === 'PAID') throw Object.assign(new Error('Already paid'), { status: 400 });
        // L7: Guard against waiving an already-waived record
        if (record.status === 'WAIVED') throw Object.assign(new Error('Already waived'), { status: 400 });

        // When waiving a partially paid record, set finalAmount = paidAmount
        // so remaining balance becomes zero (partial payment is kept, rest forgiven).
        const waiveData: Record<string, unknown> = {
            status: 'WAIVED',
            notes: dto.notes ?? null,
            markedById: userId,
        };
        if (record.paidAmount > 0) {
            waiveData.finalAmount = record.paidAmount;
        }

        await prisma.feeRecord.update({
            where: { id: recordId },
            data: waiveData,
        });

        void writeAuditLog({
            coachingId,
            entityType: 'RECORD',
            entityId: recordId,
            event: 'FEE_WAIVED',
            actorId: userId,
            before: { status: record.status, finalAmount: record.finalAmount, paidAmount: record.paidAmount },
            after: { status: 'WAIVED', notes: dto.notes ?? null },
        });

        // Re-fetch full record to avoid fromJson parse errors on frontend
        return this.getRecordById(coachingId, recordId);
    }

    async recordRefund(coachingId: string, recordId: string, dto: RecordRefundDto, userId: string) {
        if (dto.amount <= 0) throw Object.assign(new Error('Refund amount must be positive'), { status: 400 });

        const refundedAt = dto.refundedAt ? new Date(dto.refundedAt) : new Date();

        // C4 fix: Interactive transaction with Serializable isolation to prevent
        // concurrent refunds from over-refunding.
        await prisma.$transaction(async (tx) => {
            const record = await tx.feeRecord.findFirst({ where: { id: recordId, coachingId } });
            if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
            if (dto.amount > record.paidAmount) {
                throw Object.assign(new Error('Cannot refund more than paid amount'), { status: 400 });
            }

            const newPaidAmount = record.paidAmount - dto.amount;

            const isPastDue = record.dueDate < new Date();
            const newStatus =
                newPaidAmount >= record.finalAmount - 0.01 ? 'PAID'
                    : newPaidAmount <= 0 && isPastDue ? 'OVERDUE'
                        : newPaidAmount <= 0 ? 'PENDING'
                            : isPastDue ? 'OVERDUE'
                                : 'PARTIALLY_PAID';

            await tx.feeRefund.create({
                data: {
                    coachingId,
                    recordId,
                    amount: dto.amount,
                    reason: dto.reason ?? null,
                    mode: dto.mode ?? 'CASH',
                    refundedAt,
                    processedById: userId,
                },
            });

            await tx.feeRecord.update({
                where: { id: recordId },
                data: {
                    paidAmount: newPaidAmount,
                    status: newStatus,
                },
            });
        }, { isolationLevel: 'Serializable' });

        void writeAuditLog({
            coachingId,
            entityType: 'REFUND',
            entityId: recordId,
            event: 'REFUND_ISSUED',
            actorId: userId,
            after: { amount: dto.amount, mode: dto.mode ?? 'CASH', reason: dto.reason ?? null },
        });

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
                title: 'Fee Payment Reminder',
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
                    title: 'Fee Payment Reminder',
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

        // H2 fix: Running balance tracks what the student owes.
        // RECORD  → increases balance (student charged)
        // PAYMENT → decreases balance (student paid)
        // REFUND  → increases balance (money returned, student owes again)
        // Note: refund entries have negative `amount` (-rf.amount), so we handle sign explicitly.
        let running = 0;
        const timeline = raw.map(e => {
            if (e.type === 'RECORD') running += e.amount;
            else if (e.type === 'PAYMENT') running -= e.amount;
            else if (e.type === 'REFUND') running += Math.abs(e.amount); // refund increases outstanding
            return { ...e, runningBalance: running };
        });

        const nextDueBill = records
            .filter(r => r.status === 'PENDING' || r.status === 'PARTIALLY_PAID')
            .sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime())[0];

        // H2 fix: paidAmount already reflects refunds (recordRefund decrements paidAmount),
        // so balance = totalCharged - totalPaid. totalRefunded is informational only.
        return {
            member,
            summary: {
                totalCharged, totalPaid, totalRefunded,
                balance: totalCharged - totalPaid,
                totalOverdue: records.filter(r => r.status === 'OVERDUE').reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0),
                nextDueDate: nextDueBill?.dueDate ?? null,
                nextDueAmount: nextDueBill ? nextDueBill.finalAmount - nextDueBill.paidAmount : 0,
            },
            records: records.map(r => ({ ...r, daysOverdue: r.status === 'OVERDUE' ? calcDaysOverdue(r.dueDate) : 0 })),
            timeline,
        };
    }

    /** Fees for the logged-in student/parent. */
    async getMyTransactions(coachingId: string, userId: string, pagination: { page: number; limit: number } = { page: 1, limit: 20 }) {
        const { page, limit } = pagination;
        // Resolve memberIds for this user (direct + wards)
        const member = await prisma.coachingMember.findFirst({ where: { coachingId, userId } });
        const wardMembers = await prisma.coachingMember.findMany({ where: { coachingId, ward: { parentId: userId } } });
        const memberIds = [...(member ? [member.id] : []), ...wardMembers.map(w => w.id)];
        if (memberIds.length === 0) return { transactions: [], total: 0, page, limit };

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
        //    Also skip stale CREATED orders (checkout sessions abandoned > 30 min ago)
        const staleThreshold = Date.now() - 30 * 60 * 1000;
        for (const [rzpId, rows] of Array.from(orderGroups.entries())) {
            const first = rows[0]!;
            const status = first.status; // all rows in group share same razorpayOrderId, status changes together
            if (status === 'PAID') continue; // covered by FeePayment rows above
            if (status === 'CREATED' && new Date(first.createdAt).getTime() < staleThreshold) continue; // stale checkout

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

        // Sort newest first, then paginate (M8 fix)
        txns.sort((a: any, b: any) => new Date(b.date).getTime() - new Date(a.date).getTime());

        const total = txns.length;
        const skip = (page - 1) * limit;
        const paginated = txns.slice(skip, skip + limit);

        return { transactions: paginated, total, page, limit };
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

    //Internal helpers

    async listAuditLog(coachingId: string, query: ListAuditLogQuery) {
        const page = query.page ?? 1;
        const limit = Math.min(query.limit ?? 50, 100);
        const skip = (page - 1) * limit;

        const where: Record<string, unknown> = { coachingId };
        if (query.entityType) where.entityType = query.entityType;
        if (query.entityId) where.entityId = query.entityId;
        if (query.event) where.event = query.event;
        if (query.from || query.to) {
            where.createdAt = {};
            if (query.from) (where.createdAt as Record<string, unknown>).gte = new Date(query.from);
            if (query.to) (where.createdAt as Record<string, unknown>).lte = new Date(query.to);
        }

        const [total, logs] = await Promise.all([
            prisma.feeAuditLog.count({ where }),
            prisma.feeAuditLog.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
                include: {
                    actor: { select: { id: true, name: true, email: true, picture: true } },
                    feeStructure: { select: { id: true, name: true } },
                },
            }),
        ]);

        return { total, page, limit, logs };
    }

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
        // H6 fix: Cycle-aware dedup — use exact dueDate match instead of month boundary
        // Monthly: same month. But QUARTERLY/YEARLY records share no month overlap,
        // so the original month-only check would never dedup them. Exact date match is safe
        // because nextDueDateFromCycle produces deterministic dates.
        const existing = await prisma.feeRecord.findFirst({
            where: {
                assignmentId,
                dueDate,
            },
        });
        if (existing) return existing;

        // Compute tax on the net (post-discount) amount
        const taxType = structure.taxType ?? 'NONE';
        const gstRate = structure.gstRate ?? 0;
        const supplyType = structure.gstSupplyType ?? 'INTRA_STATE';
        const cessRate = structure.cessRate ?? 0;
        const tax = computeTax(netAmount, taxType, gstRate, supplyType, cessRate);

        // finalAmount = totalWithTax — handles both GST_INCLUSIVE and GST_EXCLUSIVE correctly.
        // GST_EXCLUSIVE: totalWithTax = net + tax. GST_INCLUSIVE: totalWithTax = net (tax is inside).
        const recordFinalAmount = tax.totalWithTax;
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
        const TAX_SELECT = { lateFinePerDay: true, taxType: true, gstRate: true, gstSupplyType: true, cessRate: true, sacCode: true, hsnCode: true } as const;

        // ── Self-heal (own 60s debounce, runs before the overdue gate) ──
        // Fixes PENDING records whose finalAmount / taxAmount are stale (created before
        // tax was configured, or before cascade fixes were deployed).
        // No dueDate filter: records past due but still PENDING are caught here first,
        // then immediately converted to OVERDUE by the sweep below.
        const lastHeal = _healLastRun.get(coachingId) ?? 0;
        if (Date.now() - lastHeal >= HEAL_DEBOUNCE_MS) {
            _healLastRun.set(coachingId, Date.now());
            // Fix PENDING + OVERDUE unpaid records with stale tax snapshots
            const staleUnpaid = await prisma.feeRecord.findMany({
                where: { coachingId, status: { in: ['PENDING', 'OVERDUE'] }, paidAmount: 0 },
                include: { assignment: { include: { feeStructure: { select: TAX_SELECT } } } },
            });
            const healFixes: Promise<unknown>[] = [];
            for (const r of staleUnpaid) {
                const fs = r.assignment?.feeStructure;
                const netFee = r.baseAmount - r.discountAmount;
                const liveTax = computeTax(
                    netFee,
                    fs?.taxType ?? r.taxType ?? 'NONE',
                    fs?.gstRate ?? r.gstRate ?? 0,
                    fs?.gstSupplyType ?? 'INTRA_STATE',
                    fs?.cessRate ?? 0,
                );
                const expectedFinal = liveTax.totalWithTax + r.fineAmount;
                const taxStale = Math.abs(liveTax.taxAmount - r.taxAmount) > 0.01;
                const amountWrong = Math.abs(r.finalAmount - expectedFinal) > 0.01;
                if (taxStale || amountWrong) {
                    const taxType = fs?.taxType ?? r.taxType ?? 'NONE';
                    healFixes.push(prisma.feeRecord.update({
                        where: { id: r.id },
                        data: {
                            amount: liveTax.totalWithTax,
                            finalAmount: expectedFinal,
                            taxType,
                            taxAmount: liveTax.taxAmount,
                            cgstAmount: liveTax.cgstAmount,
                            sgstAmount: liveTax.sgstAmount,
                            igstAmount: liveTax.igstAmount,
                            cessAmount: liveTax.cessAmount,
                            gstRate: fs?.gstRate ?? r.gstRate ?? 0,
                            sacCode: fs?.sacCode ?? r.sacCode ?? null,
                            hsnCode: fs?.hsnCode ?? r.hsnCode ?? null,
                        },
                    }));
                }
            }
            if (healFixes.length > 0) await Promise.all(healFixes);
        }

        // ── Overdue sweep (5-minute debounce) ──
        const lastRun = _overdueLastRun.get(coachingId) ?? 0;
        if (Date.now() - lastRun < OVERDUE_DEBOUNCE_MS) return;
        _overdueLastRun.set(coachingId, Date.now());

        // H3 fix: Mark both PENDING and PARTIALLY_PAID → OVERDUE when past due
        // Include full tax config from feeStructure so we can recompute accurately (stale snapshot fix)
        const newOverdue = await prisma.feeRecord.findMany({
            where: { coachingId, status: { in: ['PENDING', 'PARTIALLY_PAID'] }, dueDate: { lt: new Date() } },
            include: { assignment: { include: { feeStructure: { select: TAX_SELECT } } } },
        });
        if (newOverdue.length > 0) {
            await Promise.all(newOverdue.map(r => {
                const days = calcDaysOverdue(r.dueDate);
                const fs = r.assignment?.feeStructure;
                const lateFine = fs?.lateFinePerDay ?? 0;
                const fineAmount = lateFine > 0 ? lateFine * days : 0;
                const netFee = r.baseAmount - r.discountAmount;
                // Recompute tax from live structure — fixes records with stale/zero snapshot
                const liveTax = computeTax(
                    netFee,
                    fs?.taxType ?? r.taxType ?? 'NONE',
                    fs?.gstRate ?? r.gstRate ?? 0,
                    fs?.gstSupplyType ?? 'INTRA_STATE',
                    fs?.cessRate ?? 0,
                );
                const taxType = fs?.taxType ?? r.taxType ?? 'NONE';
                const newFinalAmount = liveTax.totalWithTax + fineAmount;
                return prisma.feeRecord.update({
                    where: { id: r.id },
                    data: {
                        status: 'OVERDUE', fineAmount, finalAmount: newFinalAmount,
                        // Refresh tax snapshot from live structure
                        taxType, taxAmount: liveTax.taxAmount,
                        cgstAmount: liveTax.cgstAmount, sgstAmount: liveTax.sgstAmount,
                        igstAmount: liveTax.igstAmount, cessAmount: liveTax.cessAmount,
                        gstRate: fs?.gstRate ?? r.gstRate ?? 0,
                        sacCode: fs?.sacCode ?? r.sacCode ?? null,
                        hsnCode: fs?.hsnCode ?? r.hsnCode ?? null,
                    },
                });
            }));
        }

        // H4 fix: Refresh accrued fine on OVERDUE records (includes formerly PARTIALLY_PAID)
        const alreadyOverdue = await prisma.feeRecord.findMany({
            where: { coachingId, status: 'OVERDUE' },
            include: { assignment: { include: { feeStructure: { select: TAX_SELECT } } } },
        });
        type OverdueUpdate = { id: string; fineAmount: number; finalAmount: number; taxType: string; taxAmount: number; cgstAmount: number; sgstAmount: number; igstAmount: number; cessAmount: number; gstRate: number; sacCode: string | null; hsnCode: string | null };
        const overdueUpdates: OverdueUpdate[] = [];
        for (const r of alreadyOverdue) {
            const fs = r.assignment?.feeStructure;
            const lateFine = fs?.lateFinePerDay ?? 0;
            const netFee = r.baseAmount - r.discountAmount;
            const liveTax = computeTax(
                netFee,
                fs?.taxType ?? r.taxType ?? 'NONE',
                fs?.gstRate ?? r.gstRate ?? 0,
                fs?.gstSupplyType ?? 'INTRA_STATE',
                fs?.cessRate ?? 0,
            );
            const taxType = fs?.taxType ?? r.taxType ?? 'NONE';
            const fineAmount = lateFine > 0 ? lateFine * calcDaysOverdue(r.dueDate) : r.fineAmount;
            const updatedFinal = liveTax.totalWithTax + fineAmount;
            // Update if fine changed OR tax snapshot is stale (taxAmount mismatch)
            const taxStale = Math.abs(liveTax.taxAmount - r.taxAmount) > 0.01;
            const fineChanged = Math.abs(fineAmount - r.fineAmount) > 0.01;
            if (fineChanged || taxStale) {
                overdueUpdates.push({
                    id: r.id, fineAmount, finalAmount: updatedFinal,
                    taxType, taxAmount: liveTax.taxAmount,
                    cgstAmount: liveTax.cgstAmount, sgstAmount: liveTax.sgstAmount,
                    igstAmount: liveTax.igstAmount, cessAmount: liveTax.cessAmount,
                    gstRate: fs?.gstRate ?? r.gstRate ?? 0,
                    sacCode: fs?.sacCode ?? r.sacCode ?? null,
                    hsnCode: fs?.hsnCode ?? r.hsnCode ?? null,
                });
            }
        }
        if (overdueUpdates.length > 0) {
            await Promise.all(overdueUpdates.map(u =>
                prisma.feeRecord.update({ where: { id: u.id }, data: u })
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
