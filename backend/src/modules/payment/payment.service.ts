import Razorpay from 'razorpay';
import crypto from 'crypto';
import prisma from '../../infra/prisma.js';
import { NotificationService } from '../notification/notification.service.js';

const notifSvc = new NotificationService();

// ─── Razorpay Instance ───────────────────────────────────────────────

const razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID || '',
    key_secret: process.env.RAZORPAY_KEY_SECRET || '',
});

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateOrderDto {
    recordId: string;
    /** Amount in rupees — converted to paise internally */
    amount?: number;
}

export interface VerifyPaymentDto {
    razorpay_order_id: string;
    razorpay_payment_id: string;
    razorpay_signature: string;
}

export interface InitiateRefundDto {
    paymentId: string;      // Our FeePayment id
    amount?: number;        // Partial refund amount (rupees). Full if omitted.
    reason?: string;
}

// ─── Helpers ─────────────────────────────────────────────────────────

function generateReceiptNo(): string {
    const ts = Date.now().toString(36).toUpperCase();
    const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `RCP-${ts}-${rand}`;
}

function toPaise(rupees: number): number {
    return Math.round(rupees * 100);
}

function toRupees(paise: number): number {
    return paise / 100;
}

function getFinancialYear(date: Date = new Date()): string {
    const y = date.getFullYear();
    const m = date.getMonth();
    const startYear = m >= 3 ? y : y - 1;
    const endYear = (startYear + 1) % 100;
    return `${startYear}-${endYear.toString().padStart(2, '0')}`;
}

async function generateSequentialReceiptNo(coachingId: string): Promise<string> {
    const fy = getFinancialYear();
    const seq = await prisma.receiptSequence.upsert({
        where: { coachingId_financialYear: { coachingId, financialYear: fy } },
        create: { coachingId, financialYear: fy, lastNumber: 1 },
        update: { lastNumber: { increment: 1 } },
    });
    return `TXR/${fy}/${seq.lastNumber.toString().padStart(4, '0')}`;
}

function nextDueDateFromCycle(from: Date, cycle: string): Date {
    const d = new Date(from);
    switch (cycle) {
        case 'MONTHLY': d.setMonth(d.getMonth() + 1); break;
        case 'QUARTERLY': d.setMonth(d.getMonth() + 3); break;
        case 'HALF_YEARLY': d.setMonth(d.getMonth() + 6); break;
        case 'YEARLY': d.setFullYear(d.getFullYear() + 1); break;
    }
    return d;
}

function computeTax(
    baseAmount: number,
    taxType: string,
    gstRate: number,
    supplyType: string = 'INTRA_STATE',
    cessRate: number = 0,
): { taxAmount: number; cgstAmount: number; sgstAmount: number; igstAmount: number; cessAmount: number; totalWithTax: number } {
    if (taxType === 'NONE' || gstRate === 0) {
        return { taxAmount: 0, cgstAmount: 0, sgstAmount: 0, igstAmount: 0, cessAmount: 0, totalWithTax: baseAmount };
    }

    let taxableAmount: number;
    let gstAmount: number;
    let cess: number;

    if (taxType === 'GST_INCLUSIVE') {
        const effectiveRate = gstRate + cessRate;
        taxableAmount = baseAmount / (1 + effectiveRate / 100);
        gstAmount = taxableAmount * (gstRate / 100);
        cess = taxableAmount * (cessRate / 100);
    } else {
        taxableAmount = baseAmount;
        gstAmount = baseAmount * (gstRate / 100);
        cess = baseAmount * (cessRate / 100);
    }

    gstAmount = Math.round(gstAmount * 100) / 100;
    cess = Math.round(cess * 100) / 100;

    let cgst = 0, sgst = 0, igst = 0;
    if (supplyType === 'INTER_STATE') {
        igst = gstAmount;
    } else {
        cgst = Math.round((gstAmount / 2) * 100) / 100;
        sgst = Math.round((gstAmount / 2) * 100) / 100;
    }

    const totalTax = gstAmount + cess;
    const totalWithTax = taxType === 'GST_INCLUSIVE' ? baseAmount : baseAmount + totalTax;

    return { taxAmount: totalTax, cgstAmount: cgst, sgstAmount: sgst, igstAmount: igst, cessAmount: cess, totalWithTax: Math.round(totalWithTax * 100) / 100 };
}

// ─── Service ─────────────────────────────────────────────────────────

export class PaymentService {

    /**
     * Create a Razorpay order for a pending/overdue fee record.
     * Idempotent: reuses existing CREATED order if amount matches & < 30 min old.
     */
    async createOrder(coachingId: string, recordId: string, userId: string, dto?: CreateOrderDto) {
        // 1. Validate the fee record
        const record = await prisma.feeRecord.findFirst({
            where: { id: recordId, coachingId },
            include: {
                assignment: { include: { feeStructure: true } },
                member: { select: { userId: true, wardId: true, ward: { select: { parentId: true } } } },
            },
        });
        if (!record) throw Object.assign(new Error('Fee record not found'), { status: 404 });
        if (record.status === 'PAID' || record.status === 'WAIVED') {
            throw Object.assign(new Error('This fee is already settled'), { status: 400 });
        }

        // Verify user is the student or their parent
        const memberUserId = record.member?.userId;
        const parentUserId = record.member?.ward?.parentId;
        if (userId !== memberUserId && userId !== parentUserId) {
            throw Object.assign(new Error('You cannot pay for this fee record'), { status: 403 });
        }

        // 2. Calculate payable amount (balance = finalAmount - paidAmount)
        const balance = record.finalAmount - record.paidAmount;
        const payAmount = dto?.amount ? Math.min(dto.amount, balance) : balance;
        if (payAmount <= 0) throw Object.assign(new Error('Nothing to pay'), { status: 400 });

        const amountPaise = toPaise(payAmount);

        // 3. Idempotency — reuse existing CREATED order if < 30 min old and same amount
        const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
        const existingOrder = await prisma.razorpayOrder.findFirst({
            where: {
                recordId,
                userId,
                status: 'CREATED',
                amountPaise,
                createdAt: { gte: thirtyMinAgo },
            },
            orderBy: { createdAt: 'desc' },
        });

        if (existingOrder) {
            return {
                orderId: existingOrder.razorpayOrderId,
                amount: amountPaise,
                currency: existingOrder.currency,
                key: process.env.RAZORPAY_KEY_ID,
                record: {
                    id: record.id,
                    title: record.title,
                    balance,
                    payAmount,
                },
                internalOrderId: existingOrder.id,
            };
        }

        // 4. Create Razorpay order
        const receipt = `rcpt_${recordId.slice(0, 8)}_${Date.now()}`;
        const rzpOrder = await razorpay.orders.create({
            amount: amountPaise,
            currency: 'INR',
            receipt,
            notes: {
                coachingId,
                recordId,
                userId,
                feeTitle: record.title,
            },
        });

        // 5. Store in DB
        const order = await prisma.razorpayOrder.create({
            data: {
                coachingId,
                recordId,
                userId,
                razorpayOrderId: rzpOrder.id,
                amountPaise,
                currency: 'INR',
                receipt,
                notes: rzpOrder.notes as any,
            },
        });

        return {
            orderId: rzpOrder.id,
            amount: amountPaise,
            currency: 'INR',
            key: process.env.RAZORPAY_KEY_ID,
            record: {
                id: record.id,
                title: record.title,
                balance,
                payAmount,
            },
            internalOrderId: order.id,
        };
    }

    /**
     * Verify payment after client-side Razorpay checkout completes.
     * Uses HMAC SHA256 signature verification, then records the payment.
     */
    async verifyPayment(coachingId: string, recordId: string, dto: VerifyPaymentDto, userId: string) {
        // 1. Verify signature
        const secret = process.env.RAZORPAY_KEY_SECRET;
        if (!secret) throw Object.assign(new Error('Payment configuration error'), { status: 500 });

        const body = dto.razorpay_order_id + '|' + dto.razorpay_payment_id;
        const expectedSignature = crypto
            .createHmac('sha256', secret)
            .update(body)
            .digest('hex');

        if (expectedSignature !== dto.razorpay_signature) {
            throw Object.assign(new Error('Payment verification failed — invalid signature'), { status: 400 });
        }

        // 2. Find our order
        const order = await prisma.razorpayOrder.findUnique({
            where: { razorpayOrderId: dto.razorpay_order_id },
        });
        if (!order) throw Object.assign(new Error('Order not found'), { status: 404 });
        if (order.coachingId !== coachingId || order.recordId !== recordId) {
            throw Object.assign(new Error('Order does not match this record'), { status: 400 });
        }
        if (order.paymentRecorded) {
            // Already processed (idempotent)
            return this._getRecordWithDaysOverdue(coachingId, recordId);
        }

        // 3. Record payment in a transaction
        await this._processPayment(order.id, dto.razorpay_payment_id, dto.razorpay_signature, userId);

        // 4. Return enriched record + the specific payment for receipt
        const record = await this._getRecordWithDaysOverdue(coachingId, recordId);
        const payment = await prisma.feePayment.findFirst({
            where: { recordId, razorpayPaymentId: dto.razorpay_payment_id },
        });
        return {
            ...record,
            verifiedPayment: payment ? {
                id: payment.id,
                amount: payment.amount,
                receiptNo: payment.receiptNo,
                razorpayPaymentId: payment.razorpayPaymentId,
                razorpayOrderId: payment.razorpayOrderId,
                paidAt: payment.paidAt,
            } : null,
        };
    }

    /**
     * Admin-initiated online refund via Razorpay.
     * Creates a FeeRefund + RazorpayRefund, calls Razorpay API.
     */
    async initiateOnlineRefund(coachingId: string, recordId: string, dto: InitiateRefundDto, userId: string) {
        // 1. Find the FeePayment
        const payment = await prisma.feePayment.findFirst({
            where: { id: dto.paymentId, coachingId, recordId },
        });
        if (!payment) throw Object.assign(new Error('Payment not found'), { status: 404 });
        if (!payment.razorpayPaymentId) {
            throw Object.assign(new Error('This payment was not made through Razorpay'), { status: 400 });
        }

        // 2. Determine refund amount
        const refundAmount = dto.amount ?? payment.amount;
        if (refundAmount <= 0) throw Object.assign(new Error('Refund amount must be positive'), { status: 400 });
        if (refundAmount > payment.amount) {
            throw Object.assign(new Error('Refund cannot exceed payment amount'), { status: 400 });
        }

        // 3. Check FeeRecord
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (refundAmount > record.paidAmount) {
            throw Object.assign(new Error('Cannot refund more than total paid'), { status: 400 });
        }

        const amountPaise = toPaise(refundAmount);

        // 4. Call Razorpay refund API
        let rzpRefund: any;
        try {
            rzpRefund = await razorpay.payments.refund(payment.razorpayPaymentId, {
                amount: amountPaise,
                notes: { reason: dto.reason ?? 'Admin initiated refund', recordId, coachingId },
            });
        } catch (err: any) {
            throw Object.assign(
                new Error(`Razorpay refund failed: ${err?.error?.description || err.message}`),
                { status: 502 },
            );
        }

        // 5. Create FeeRefund + RazorpayRefund + update FeeRecord in transaction
        const newPaidAmount = record.paidAmount - refundAmount;
        const isPastDue = record.dueDate < new Date();
        const newStatus =
            newPaidAmount >= record.finalAmount - 0.01 ? 'PAID'
                : newPaidAmount <= 0 && isPastDue ? 'OVERDUE'
                    : newPaidAmount <= 0 ? 'PENDING'
                        : isPastDue ? 'OVERDUE'
                            : 'PARTIALLY_PAID';

        const result = await prisma.$transaction(async (tx) => {
            const feeRefund = await tx.feeRefund.create({
                data: {
                    coachingId,
                    recordId,
                    amount: refundAmount,
                    reason: dto.reason ?? 'Online refund via Razorpay',
                    mode: 'RAZORPAY',
                    processedById: userId,
                },
            });

            await tx.razorpayRefund.create({
                data: {
                    coachingId,
                    feeRefundId: feeRefund.id,
                    razorpayRefundId: rzpRefund.id,
                    razorpayPaymentId: payment.razorpayPaymentId!,
                    amountPaise,
                    status: 'PROCESSED',
                },
            });

            await tx.feeRecord.update({
                where: { id: recordId },
                data: { paidAmount: newPaidAmount, status: newStatus },
            });

            return feeRefund;
        });

        return this._getRecordWithDaysOverdue(coachingId, recordId);
    }

    /**
     * List Razorpay payment history for a record (used by admin to pick which payment to refund).
     */
    async getOnlinePayments(coachingId: string, recordId: string) {
        return prisma.feePayment.findMany({
            where: { coachingId, recordId, razorpayPaymentId: { not: null } },
            orderBy: { paidAt: 'desc' },
            select: {
                id: true,
                amount: true,
                razorpayPaymentId: true,
                razorpayOrderId: true,
                receiptNo: true,
                paidAt: true,
                mode: true,
            },
        });
    }

    /** Mark a CREATED order as FAILED (user cancelled or SDK error).
     * Accepts either an internal UUID (single-pay) or a razorpayOrderId "order_xxx" (multi-pay).
     * For multi-pay all rows sharing the razorpayOrderId are marked failed together.
     */
    async markOrderFailed(coachingId: string, internalOrderId: string, reason: string) {
        await prisma.razorpayOrder.updateMany({
            where: {
                coachingId,
                status: 'CREATED',
                OR: [
                    { id: internalOrderId },
                    { razorpayOrderId: internalOrderId },
                ],
            },
            data: { status: 'FAILED', failureReason: reason, failedAt: new Date() },
        });
    }

    /** Get all FAILED orders for a specific fee record (for display in history). */
    async getFailedOrders(coachingId: string, recordId: string) {
        return prisma.razorpayOrder.findMany({
            where: { coachingId, recordId, status: 'FAILED' },
            orderBy: { createdAt: 'desc' },
            select: {
                id: true,
                amountPaise: true,
                failureReason: true,
                failedAt: true,
                createdAt: true,
            },
        });
    }

    /**
     * Get Razorpay configuration (key + enabled status) for frontends.
     */
    getConfig() {
        return {
            keyId: process.env.RAZORPAY_KEY_ID || '',
            enabled: !!(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET),
        };
    }

    // ─── Internal Helpers ───────────────────────────────────────────

    /**
     * Create a combined Razorpay order for multiple fee records.
     * Allows partial payment (pay any amount towards selected records).
     */
    async createMultiOrder(coachingId: string, userId: string, dto: { recordIds: string[]; amount?: number }) {
        if (!dto.recordIds || dto.recordIds.length === 0) {
            throw Object.assign(new Error('At least one record required'), { status: 400 });
        }

        // 1. Fetch all records and validate
        const records = await prisma.feeRecord.findMany({
            where: { id: { in: dto.recordIds }, coachingId, status: { in: ['PENDING', 'PARTIALLY_PAID', 'OVERDUE'] } },
            include: { member: { select: { userId: true, wardId: true, ward: { select: { parentId: true } } } } },
        });

        if (records.length === 0) throw Object.assign(new Error('No payable records found'), { status: 400 });

        // Verify user owns all records
        for (const r of records) {
            const memberUserId = r.member?.userId;
            const parentUserId = r.member?.ward?.parentId;
            if (userId !== memberUserId && userId !== parentUserId) {
                throw Object.assign(new Error('You cannot pay for one or more of these fee records'), { status: 403 });
            }
        }

        // 2. Calculate total balance
        const totalBalance = records.reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0);
        const payAmount = dto.amount ? Math.min(dto.amount, totalBalance) : totalBalance;
        if (payAmount <= 0) throw Object.assign(new Error('Nothing to pay'), { status: 400 });

        const amountPaise = toPaise(payAmount);

        // 3. Idempotency — reuse an existing CREATED order set if < 30 min old and same amount
        const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
        const existingRows = await prisma.razorpayOrder.findMany({
            where: {
                coachingId,
                userId,
                status: 'CREATED',
                amountPaise: { gt: 0 },
                createdAt: { gte: thirtyMinAgo },
                recordId: { in: dto.recordIds },
            },
            orderBy: { createdAt: 'desc' },
        });
        // Group by razorpayOrderId — find one that covers ALL the requested records
        const byRzpId = new Map<string, typeof existingRows>();
        for (const row of existingRows) {
            if (!byRzpId.has(row.razorpayOrderId)) byRzpId.set(row.razorpayOrderId, []);
            byRzpId.get(row.razorpayOrderId)!.push(row);
        }
        for (const [rzpId, rows] of Array.from(byRzpId.entries())) {
            const coveredIds = new Set(rows.map((r: { recordId: string }) => r.recordId));
            const totalAllocated = rows.reduce((s: number, r: { amountPaise: number }) => s + r.amountPaise, 0);
            if (dto.recordIds.every(id => coveredIds.has(id)) && totalAllocated === amountPaise) {
                return {
                    orderId: rzpId,
                    amount: amountPaise,
                    currency: 'INR',
                    key: process.env.RAZORPAY_KEY_ID,
                    records: records.map(r => ({ id: r.id, title: r.title, balance: r.finalAmount - r.paidAmount })),
                    totalBalance,
                    payAmount,
                    internalOrderId: rzpId,
                };
            }
        }

        // 4. Create Razorpay order
        const receipt = `multi_${Date.now()}`;
        const rzpOrder = await razorpay.orders.create({
            amount: amountPaise,
            currency: 'INR',
            receipt,
            notes: {
                coachingId,
                userId,
                multiPay: 'true',
                recordIds: dto.recordIds.join(','),
                recordCount: String(dto.recordIds.length),
            },
        });

        // 5. Create RazorpayOrder rows for each record (proportional split)
        const orderRows = [];
        let remainingPaise = amountPaise;
        for (let i = 0; i < records.length; i++) {
            const r = records[i]!;
            const rBalance = r.finalAmount - r.paidAmount;
            // Proportional allocation: pay towards each record in order of due date
            const allocPaise = i === records.length - 1
                ? remainingPaise
                : Math.min(toPaise(rBalance), remainingPaise);
            if (allocPaise <= 0) continue;
            remainingPaise -= allocPaise;

            const row = await prisma.razorpayOrder.create({
                data: {
                    coachingId,
                    recordId: r.id,
                    userId,
                    razorpayOrderId: rzpOrder.id,
                    amountPaise: allocPaise,
                    currency: 'INR',
                    receipt: `${receipt}_${i}`,
                    notes: { multiPay: true, index: i, totalRecords: records.length } as any,
                },
            });
            orderRows.push(row);
        }

        return {
            orderId: rzpOrder.id,
            amount: amountPaise,
            currency: 'INR',
            key: process.env.RAZORPAY_KEY_ID,
            records: records.map(r => ({
                id: r.id,
                title: r.title,
                balance: r.finalAmount - r.paidAmount,
            })),
            totalBalance,
            payAmount,
            internalOrderId: rzpOrder.id, // Razorpay order_id shared across all rows
        };
    }

    /**
     * Verify a multi-record payment.
     * Distributes the paid amount across records (oldest first).
     */
    async verifyMultiPayment(coachingId: string, dto: VerifyPaymentDto, userId: string) {
        // 1. Verify signature
        const secret = process.env.RAZORPAY_KEY_SECRET;
        if (!secret) throw Object.assign(new Error('Payment configuration error'), { status: 500 });

        const body = dto.razorpay_order_id + '|' + dto.razorpay_payment_id;
        const expectedSignature = crypto.createHmac('sha256', secret).update(body).digest('hex');
        if (expectedSignature !== dto.razorpay_signature) {
            throw Object.assign(new Error('Payment verification failed'), { status: 400 });
        }

        // 2. Find all order rows for this Razorpay order
        const orders = await prisma.razorpayOrder.findMany({
            where: { razorpayOrderId: dto.razorpay_order_id, coachingId },
            orderBy: { createdAt: 'asc' },
        });
        if (orders.length === 0) throw Object.assign(new Error('Orders not found'), { status: 404 });

        // Check if already processed
        if (orders.every(o => o.paymentRecorded)) {
            return { success: true, message: 'Already processed', recordIds: orders.map(o => o.recordId) };
        }

        // 3. Process each sub-order
        for (const order of orders) {
            if (order.paymentRecorded) continue;
            await this._processPayment(order.id, dto.razorpay_payment_id, dto.razorpay_signature, userId);
        }

        return {
            success: true,
            recordIds: orders.map(o => o.recordId),
            totalPaise: orders.reduce((s, o) => s + o.amountPaise, 0),
        };
    }

    /**
     * Core payment processing — used by both verify-payment and webhook.
     * Idempotent: checks `paymentRecorded` flag.
     */
    async _processPayment(internalOrderId: string, razorpayPaymentId: string, signature: string, userId?: string) {
        // Generate sequential receipt BEFORE the transaction (can't await inside tx easily)
        const orderForReceipt = await prisma.razorpayOrder.findUniqueOrThrow({ where: { id: internalOrderId } });
        if (orderForReceipt.paymentRecorded) return; // already processed
        const receiptNo = await generateSequentialReceiptNo(orderForReceipt.coachingId);

        await prisma.$transaction(async (tx) => {
            // Lock the order row
            const order = await tx.razorpayOrder.findUniqueOrThrow({
                where: { id: internalOrderId },
            });

            if (order.paymentRecorded) return; // double-check inside tx

            const record = await tx.feeRecord.findUniqueOrThrow({
                where: { id: order.recordId },
                include: { assignment: { include: { feeStructure: true } } },
            });

            const payAmount = toRupees(order.amountPaise);
            const newPaidAmount = record.paidAmount + payAmount;
            const isPaid = newPaidAmount >= record.finalAmount - 0.01;

            // Create FeePayment
            await tx.feePayment.create({
                data: {
                    coachingId: order.coachingId,
                    recordId: order.recordId,
                    amount: payAmount,
                    mode: 'RAZORPAY',
                    transactionRef: razorpayPaymentId,
                    receiptNo,
                    razorpayOrderId: order.razorpayOrderId,
                    razorpayPaymentId,
                    paidAt: new Date(),
                    recordedById: userId ?? order.userId,
                },
            });

            // Update FeeRecord
            await tx.feeRecord.update({
                where: { id: order.recordId },
                data: {
                    paidAmount: newPaidAmount,
                    status: isPaid ? 'PAID' : 'PARTIALLY_PAID',
                    paidAt: isPaid ? new Date() : record.paidAt,
                    paymentMode: 'RAZORPAY',
                    transactionRef: razorpayPaymentId,
                    receiptNo: isPaid ? receiptNo : record.receiptNo,
                },
            });

            // Mark order as PAID
            await tx.razorpayOrder.update({
                where: { id: internalOrderId },
                data: {
                    status: 'PAID',
                    razorpayPaymentId,
                    razorpaySignature: signature,
                    paymentRecorded: true,
                },
            });

            // If paid and cycle-based, generate next record (with tax snapshot)
            if (isPaid && record.assignment && record.assignment.isActive) {
                const fs = record.assignment.feeStructure;
                const cycle = fs.cycle;
                if (cycle !== 'ONCE' && cycle !== 'INSTALLMENT') {
                    const nextDue = nextDueDateFromCycle(record.dueDate, cycle);
                    const endDate = record.assignment.endDate;
                    if (!endDate || nextDue <= endDate) {
                        const totalDiscount = record.assignment.discountAmount + (record.assignment.scholarshipAmount ?? 0);
                        const baseAmt = (record.assignment.customAmount ?? fs.amount) - totalDiscount;
                        const tax = computeTax(baseAmt, fs.taxType, fs.gstRate, fs.gstSupplyType, fs.cessRate);
                        // finalAmount = net (post-discount) + taxAmount — consistent with _createFeeRecord
                        const finalAmt = baseAmt + tax.taxAmount;
                        const grossBaseAmt = baseAmt + totalDiscount; // pre-discount amount for reference

                        // Check no duplicate
                        const dup = await tx.feeRecord.findFirst({
                            where: {
                                assignmentId: record.assignmentId,
                                dueDate: {
                                    gte: new Date(nextDue.getFullYear(), nextDue.getMonth(), 1),
                                    lt: new Date(nextDue.getFullYear(), nextDue.getMonth() + 1, 1),
                                },
                            },
                        });
                        if (!dup) {
                            await tx.feeRecord.create({
                                data: {
                                    coachingId: order.coachingId,
                                    assignmentId: record.assignmentId,
                                    memberId: record.memberId,
                                    title: `${nextDue.toLocaleString('en-IN', { month: 'long', year: 'numeric' })} — ${fs.name}`,
                                    amount: finalAmt,
                                    baseAmount: grossBaseAmt,
                                    discountAmount: totalDiscount,
                                    finalAmount: finalAmt,
                                    dueDate: nextDue,
                                    taxType: fs.taxType,
                                    taxAmount: tax.taxAmount,
                                    cgstAmount: tax.cgstAmount,
                                    sgstAmount: tax.sgstAmount,
                                    igstAmount: tax.igstAmount,
                                    cessAmount: tax.cessAmount,
                                    gstRate: fs.gstRate,
                                    sacCode: fs.sacCode,
                                    hsnCode: fs.hsnCode,
                                    lineItems: fs.lineItems != null ? fs.lineItems as any : undefined,
                                },
                            });
                        }
                    }
                }
            }
        });

        // ── Razorpay Route Transfer (move funds to coaching's bank) ───
        try {
            const coaching = await prisma.coaching.findUnique({
                where: { id: orderForReceipt.coachingId },
                select: { razorpayAccountId: true, razorpayActivated: true, platformFeePercent: true },
            });
            if (coaching?.razorpayAccountId && coaching.razorpayActivated) {
                const platformPercent = coaching.platformFeePercent ?? 1.0;
                const platformFeePaise = Math.round(orderForReceipt.amountPaise * (platformPercent / 100));
                const transferAmount = orderForReceipt.amountPaise - platformFeePaise;

                const transfer = await razorpay.payments.transfer(razorpayPaymentId, {
                    transfers: [{
                        account: coaching.razorpayAccountId,
                        amount: transferAmount,
                        currency: 'INR',
                        notes: { coachingId: orderForReceipt.coachingId, recordId: orderForReceipt.recordId },
                    }],
                });

                const transferId = transfer?.items?.[0]?.id ?? null;
                await prisma.razorpayOrder.update({
                    where: { id: internalOrderId },
                    data: { transferId, transferStatus: 'created', platformFeePaise },
                });
            }
        } catch {
            // Non-critical — record transfer failure but don't break payment
            console.error(`[PaymentService] Transfer failed for order ${internalOrderId}`);
        }

        // Send payment confirmation notification (outside transaction)
        try {
            const notifOrder = (await prisma.razorpayOrder.findUnique({
                where: { id: internalOrderId },
                include: {
                    record: {
                        select: { title: true, member: { select: { userId: true, ward: { select: { parentId: true } } } } },
                    },
                },
            }))!;
            const member = notifOrder.record.member;
            const uid: string = member?.userId ?? member?.ward?.parentId ?? '';
            if (uid) {
                await notifSvc.create({
                    userId: uid,
                    coachingId: notifOrder.coachingId,
                    type: 'FEE_PAYMENT',
                    title: 'Payment Successful',
                    message: `Your payment of ₹${toRupees(notifOrder.amountPaise).toFixed(0)} for "${notifOrder.record.title}" has been received.`,
                    data: { recordId: notifOrder.recordId, paymentId: razorpayPaymentId },
                });
            }
        } catch {
            // Non-critical — don't fail payment for notification errors
        }
    }

    async _getRecordWithDaysOverdue(coachingId: string, recordId: string) {
        const record = await prisma.feeRecord.findFirst({
            where: { id: recordId, coachingId },
            include: {
                member: {
                    select: {
                        id: true, role: true, userId: true, wardId: true,
                        user: { select: { id: true, name: true, picture: true, email: true, phone: true } },
                        ward: { select: { id: true, name: true, picture: true, parentId: true, parent: { select: { id: true, name: true, email: true, phone: true } } } },
                    },
                },
                assignment: { include: { feeStructure: true } },
                payments: { orderBy: { paidAt: 'desc' } },
                refunds: { orderBy: { refundedAt: 'desc' } },
                markedBy: { select: { id: true, name: true } },
            },
        });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        const daysOverdue = record.status === 'OVERDUE'
            ? Math.floor((Date.now() - record.dueDate.getTime()) / (1000 * 60 * 60 * 24))
            : 0;
        return { ...record, daysOverdue };
    }

    // ── Payment Settings (Bank Account + Razorpay Route) ──────────

    async getPaymentSettings(coachingId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: {
                id: true, name: true,
                gstNumber: true, panNumber: true,
                razorpayAccountId: true, razorpayActivated: true, platformFeePercent: true,
                bankAccountName: true, bankAccountNumber: true, bankIfscCode: true, bankName: true,
            },
        });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        return coaching;
    }

    async updatePaymentSettings(coachingId: string, userId: string, dto: {
        gstNumber?: string;
        panNumber?: string;
        bankAccountName?: string;
        bankAccountNumber?: string;
        bankIfscCode?: string;
        bankName?: string;
    }) {
        // Verify user is owner
        const coaching = await prisma.coaching.findUnique({ where: { id: coachingId }, select: { ownerId: true } });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        if (coaching.ownerId !== userId) throw Object.assign(new Error('Only the owner can update payment settings'), { status: 403 });

        const data: Record<string, unknown> = {};
        if (dto.gstNumber !== undefined) data.gstNumber = dto.gstNumber || null;
        if (dto.panNumber !== undefined) data.panNumber = dto.panNumber || null;
        if (dto.bankAccountName !== undefined) data.bankAccountName = dto.bankAccountName || null;
        if (dto.bankAccountNumber !== undefined) data.bankAccountNumber = dto.bankAccountNumber || null;
        if (dto.bankIfscCode !== undefined) data.bankIfscCode = dto.bankIfscCode || null;
        if (dto.bankName !== undefined) data.bankName = dto.bankName || null;

        return prisma.coaching.update({
            where: { id: coachingId },
            data,
            select: {
                id: true, name: true,
                gstNumber: true, panNumber: true,
                razorpayAccountId: true, razorpayActivated: true, platformFeePercent: true,
                bankAccountName: true, bankAccountNumber: true, bankIfscCode: true, bankName: true,
            },
        });
    }
}
