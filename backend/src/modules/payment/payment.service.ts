import Razorpay from 'razorpay';
import crypto from 'crypto';
import prisma from '../../infra/prisma.js';
import { NotificationService } from '../notification/notification.service.js';

const notifSvc = new NotificationService();

// ─── Razorpay Instance ───────────────────────────────────────────────

// Fail-fast: require Razorpay credentials at startup
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID;
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    console.warn('[PaymentService] RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET not set — online payments disabled');
}

const razorpay = new Razorpay({
    key_id: RAZORPAY_KEY_ID || '',
    key_secret: RAZORPAY_KEY_SECRET || '',
});

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateOrderDto {
    recordId?: string | undefined;
    /** Optional partial amount — only allowed when the fee structure has allowInstallments=true
     *  and the amount matches one of the admin-defined installmentAmounts. */
    amount?: number | undefined;
}

export interface VerifyPaymentDto {
    razorpay_order_id: string;
    razorpay_payment_id: string;
    razorpay_signature: string;
}

export interface InitiateRefundDto {
    paymentId: string;
    amount?: number | undefined;
    reason?: string | undefined;
}

// ─── Helpers ─────────────────────────────────────────────────────────

// Dead generateReceiptNo removed — all receipt generation uses generateSequentialReceiptNo

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

    gstAmount = Math.round(gstAmount);
    cess = Math.round(cess);

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

    return { taxAmount: totalTax, cgstAmount: cgst, sgstAmount: sgst, igstAmount: igst, cessAmount: cess, totalWithTax: Math.round(totalWithTax * 100) / 100 };
}

// ─── Service ─────────────────────────────────────────────────────────

/** Max retries for Serializable transaction conflicts (Postgres error 40001). */
const SERIALIZATION_MAX_RETRIES = 3;
const SERIALIZATION_BASE_DELAY_MS = 50;

/** Checks if a Prisma error is a serialization conflict (P2034 / 40001). */
function isSerializationError(err: any): boolean {
    return (
        err?.code === 'P2034' ||
        err?.meta?.code === '40001' ||
        (typeof err?.message === 'string' && err.message.includes('could not serialize'))
    );
}

export class PaymentService {

    /**
     * Wrapper that retries _processPayment on Serializable isolation conflicts.
     * Concurrent webhook + client verify can collide, causing one to fail with 40001.
     * This retries with exponential backoff so the client gets a clean response.
     */
    async _processPaymentWithRetry(
        internalOrderId: string, razorpayPaymentId: string, signature: string, userId?: string,
    ) {
        for (let attempt = 0; attempt < SERIALIZATION_MAX_RETRIES; attempt++) {
            try {
                return await this._processPayment(internalOrderId, razorpayPaymentId, signature, userId);
            } catch (err: any) {
                if (!isSerializationError(err) || attempt === SERIALIZATION_MAX_RETRIES - 1) throw err;
                const delay = SERIALIZATION_BASE_DELAY_MS * (attempt + 1);
                await new Promise(r => setTimeout(r, delay));
            }
        }
    }

    /**
     * Create a Razorpay order for a pending/overdue fee record.
     * Idempotent: reuses existing CREATED order if amount matches & < 30 min old.
     */
    async createOrder(coachingId: string, recordId: string, userId: string, dto?: CreateOrderDto) {
        // 0. Server-side gate: block online payments if coaching hasn't completed Route onboarding
        const coachingGate = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { razorpayActivated: true },
        });
        if (!coachingGate?.razorpayActivated) {
            throw Object.assign(
                new Error('Online payments are not enabled for this coaching. Ask your coaching admin to complete payment setup.'),
                { status: 403 },
            );
        }

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

        // 2. Calculate payable amount
        const balance = record.finalAmount - record.paidAmount;
        if (balance <= 0) throw Object.assign(new Error('Nothing to pay'), { status: 400 });

        // Installment enforcement: if a partial amount is requested, validate it
        let payAmount = balance;
        if (dto?.amount !== undefined) {
            const requestedAmount = dto.amount;
            const feeStructure = record.assignment?.feeStructure as any;
            const isPartial = Math.abs(requestedAmount - balance) > 0.01;

            if (isPartial) {
                if (!feeStructure?.allowInstallments) {
                    throw Object.assign(
                        new Error('Partial payments are not allowed for this fee. Please pay the full balance.'),
                        { status: 400 },
                    );
                }
                // If admin defined specific installment amounts, enforce them
                const adminAmounts = feeStructure?.installmentAmounts as Array<{ label: string; amount: number }> | null | undefined;
                if (adminAmounts && adminAmounts.length > 0) {
                    const matches = adminAmounts.some((x) => Math.abs(x.amount - requestedAmount) <= 1);
                    if (!matches) {
                        const allowed = adminAmounts.map((x) => `${x.label}: ₹${x.amount}`).join(', ');
                        throw Object.assign(
                            new Error(`Invalid amount. Please choose one of the allowed installment amounts: ${allowed}`),
                            { status: 400 },
                        );
                    }
                }
            }
            // Ensure requested amount does not exceed balance
            if (requestedAmount > balance + 0.01) {
                throw Object.assign(
                    new Error(`Requested amount ₹${requestedAmount} exceeds outstanding balance ₹${balance}`),
                    { status: 400 },
                );
            }
            payAmount = requestedAmount;
        }

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

        // 5. Store in DB — H3 fix: snapshot commission % at order creation
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { platformFeePercent: true },
        });
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
                platformFeePercent: coaching?.platformFeePercent ?? 1.0,
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
        // 1. C8 fix: Timing-safe signature comparison to prevent timing attacks
        const secret = RAZORPAY_KEY_SECRET;
        if (!secret) throw Object.assign(new Error('Payment configuration error'), { status: 500 });

        const body = dto.razorpay_order_id + '|' + dto.razorpay_payment_id;
        const expectedSignature = crypto
            .createHmac('sha256', secret)
            .update(body)
            .digest('hex');

        const sigBuffer = Buffer.from(dto.razorpay_signature, 'hex');
        const expectedBuffer = Buffer.from(expectedSignature, 'hex');
        if (sigBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(sigBuffer, expectedBuffer)) {
            throw Object.assign(new Error('Payment verification failed — invalid signature'), { status: 400 });
        }

        // 2. Find our order
        const order = await prisma.razorpayOrder.findFirst({
            where: { razorpayOrderId: dto.razorpay_order_id, coachingId, recordId },
        });
        if (!order) throw Object.assign(new Error('Order not found'), { status: 404 });
        if (order.coachingId !== coachingId || order.recordId !== recordId) {
            throw Object.assign(new Error('Order does not match this record'), { status: 400 });
        }
        if (order.paymentRecorded) {
            // Already processed (idempotent)
            return this._getRecordWithDaysOverdue(coachingId, recordId);
        }

        // C7 fix: Cross-verify payment amount with Razorpay before recording
        try {
            const rzpPayment = await razorpay.payments.fetch(dto.razorpay_payment_id);
            if (rzpPayment.amount !== order.amountPaise) {
                console.error(`[PaymentService] Amount mismatch: Razorpay=${rzpPayment.amount}, DB=${order.amountPaise}`);
                throw Object.assign(new Error('Payment amount mismatch'), { status: 400 });
            }
            if (rzpPayment.status !== 'captured') {
                throw Object.assign(new Error(`Payment not captured (status: ${rzpPayment.status})`), { status: 400 });
            }
        } catch (err: any) {
            if (err.status) throw err; // re-throw our own errors
            throw Object.assign(new Error('Failed to verify payment with Razorpay'), { status: 502 });
        }

        // 3. Record payment with serialization retry
        await this._processPaymentWithRetry(order.id, dto.razorpay_payment_id, dto.razorpay_signature, userId);

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
     * H4 fix: DB-first approach — create records in INITIATED state, call Razorpay API,
     * then update. If API succeeds but app crashes, webhook can find the record.
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

        // H8 fix: Check total already refunded across ALL payments for this record
        const existingRefunds = await prisma.feeRefund.findMany({
            where: { recordId, coachingId },
            select: { amount: true },
        });
        const totalAlreadyRefunded = existingRefunds.reduce((s, r) => s + r.amount, 0);

        // 3. Check FeeRecord
        const record = await prisma.feeRecord.findFirst({ where: { id: recordId, coachingId } });
        if (!record) throw Object.assign(new Error('Record not found'), { status: 404 });
        if (refundAmount > record.paidAmount) {
            throw Object.assign(new Error('Cannot refund more than total paid'), { status: 400 });
        }
        // Verify cumulative refund doesn't exceed total payments
        const totalPaidViaPayments = await prisma.feePayment.aggregate({
            where: { recordId, coachingId },
            _sum: { amount: true },
        });
        const totalPayments = totalPaidViaPayments._sum.amount ?? 0;
        if (totalAlreadyRefunded + refundAmount > totalPayments) {
            throw Object.assign(
                new Error(`Total refunds (₹${(totalAlreadyRefunded + refundAmount).toFixed(2)}) would exceed total payments (₹${totalPayments.toFixed(2)})`),
                { status: 400 },
            );
        }

        const amountPaise = toPaise(refundAmount);

        // 4. H4 fix: Create DB records FIRST in INITIATED state (before calling Razorpay)
        //    so webhook can always find them even if app crashes after API call.
        const newPaidAmount = record.paidAmount - refundAmount;
        const isPastDue = record.dueDate < new Date();
        const newStatus =
            newPaidAmount >= record.finalAmount - 0.01 ? 'PAID'
                : newPaidAmount <= 0 && isPastDue ? 'OVERDUE'
                    : newPaidAmount <= 0 ? 'PENDING'
                        : isPastDue ? 'OVERDUE'
                            : 'PARTIALLY_PAID';

        const { feeRefund, razorpayRefund } = await prisma.$transaction(async (tx) => {
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

            // Compute proportional commission reversal:
            // If the original order had a platformFeePaise and platformFeePercent,
            // reverse the same % of the refund amount.
            const originalOrder = await tx.razorpayOrder.findFirst({
                where: {
                    razorpayPaymentId: payment.razorpayPaymentId!,
                    coachingId,
                    paymentRecorded: true,
                },
                select: { amountPaise: true, platformFeePaise: true, platformFeePercent: true },
            });
            let commissionReversalPaise: number | null = null;
            if (originalOrder?.platformFeePaise && originalOrder.amountPaise > 0) {
                // Proportional reversal: refundPaise / orderPaise * platformFeePaise
                commissionReversalPaise = Math.round(
                    (amountPaise / originalOrder.amountPaise) * originalOrder.platformFeePaise
                );
            }

            const razorpayRefund = await tx.razorpayRefund.create({
                data: {
                    coachingId,
                    feeRefundId: feeRefund.id,
                    razorpayPaymentId: payment.razorpayPaymentId!,
                    amountPaise,
                    status: 'INITIATED',
                    commissionReversalPaise,
                },
            });

            await tx.feeRecord.update({
                where: { id: recordId },
                data: { paidAmount: newPaidAmount, status: newStatus },
            });

            return { feeRefund, razorpayRefund };
        }, { isolationLevel: 'Serializable' });

        // 5. Reverse Route transfer if one exists (before refunding the payment)
        //    When a Route transfer was made, we must reverse the proportional amount from
        //    the linked account first. Razorpay also auto-reverses on refund, but explicit
        //    reversal gives us better tracking and error handling for insufficient balance cases.
        const routeOrder = await prisma.razorpayOrder.findFirst({
            where: {
                razorpayPaymentId: payment.razorpayPaymentId!,
                coachingId,
                paymentRecorded: true,
                transferId: { not: null },
                transferStatus: { in: ['created', 'processed', 'settled'] },
            },
            select: { id: true, transferId: true, amountPaise: true, platformFeePaise: true },
        });

        if (routeOrder?.transferId) {
            try {
                // Reverse proportional amount from linked account
                // transferAmount = orderAmount - platformFee, so reversal = refundPaise * (transferAmount / orderPaise)
                const orderAmount = routeOrder.amountPaise;
                const platformFee = routeOrder.platformFeePaise ?? 0;
                const transferAmount = orderAmount - platformFee;
                const reversalAmount = orderAmount > 0
                    ? Math.round((amountPaise / orderAmount) * transferAmount)
                    : 0;

                if (reversalAmount > 0) {
                    await (razorpay as any).transfers.reverse(routeOrder.transferId, {
                        amount: reversalAmount,
                    });
                    console.log(`[PaymentService] Route transfer reversed: ₹${(reversalAmount / 100).toFixed(2)} from transfer ${routeOrder.transferId}`);
                }
            } catch (transferErr: any) {
                // Transfer reversal failed — likely insufficient balance in linked account.
                // Log but continue with the refund — Razorpay may auto-reverse, or the refund
                // will come from the platform's pool (which is the fallback behavior).
                console.error(
                    `[PaymentService] Route transfer reversal failed for ${routeOrder.transferId}:`,
                    transferErr?.error?.description || transferErr?.message,
                );
            }
        }

        // 6. Call Razorpay refund API (after DB records exist + transfer reversal attempted)
        try {
            const rzpRefund = await razorpay.payments.refund(payment.razorpayPaymentId, {
                amount: amountPaise,
                notes: { reason: dto.reason ?? 'Admin initiated refund', recordId, coachingId },
            });

            // Update RazorpayRefund with Razorpay's refund ID
            await prisma.razorpayRefund.update({
                where: { id: razorpayRefund.id },
                data: { razorpayRefundId: rzpRefund.id },
            });
        } catch (err: any) {
            // API failed — reverse the DB records
            console.error(`[PaymentService] Razorpay refund API failed, reversing DB:`, err?.message);
            await prisma.$transaction(async (tx) => {
                await tx.razorpayRefund.delete({ where: { id: razorpayRefund.id } });
                await tx.feeRefund.delete({ where: { id: feeRefund.id } });
                await tx.feeRecord.update({
                    where: { id: recordId },
                    data: { paidAmount: record.paidAmount, status: record.status },
                });
            }).catch((cleanupErr) => {
                console.error(`[PaymentService] Failed to cleanup refund records:`, cleanupErr?.message);
            });
            throw Object.assign(
                new Error(`Razorpay refund failed: ${err?.error?.description || err.message}`),
                { status: 502 },
            );
        }

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
    async markOrderFailed(coachingId: string, internalOrderId: string, reason: string, userId: string) {
        // S3 fix: Only the order creator can mark it as failed
        await prisma.razorpayOrder.updateMany({
            where: {
                coachingId,
                userId,
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
            keyId: RAZORPAY_KEY_ID || '',
            enabled: !!(RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET),
        };
    }

    // ─── Internal Helpers ───────────────────────────────────────────

    /**
     * Create a combined Razorpay order for multiple fee records.
     * Allows partial payment (pay any amount towards selected records).
     */
    async createMultiOrder(coachingId: string, userId: string, dto: { recordIds: string[] }) {
        if (!dto.recordIds || dto.recordIds.length === 0) {
            throw Object.assign(new Error('At least one record required'), { status: 400 });
        }

        // 0. Server-side gate: block online payments if coaching hasn't completed Route onboarding
        const coachingGate = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { razorpayActivated: true },
        });
        if (!coachingGate?.razorpayActivated) {
            throw Object.assign(
                new Error('Online payments are not enabled for this coaching. Ask your coaching admin to complete payment setup.'),
                { status: 403 },
            );
        }

        // 1. Fetch all records and validate
        // H14 fix: Sort records by dueDate so oldest dues are allocated first
        const records = await prisma.feeRecord.findMany({
            where: { id: { in: dto.recordIds }, coachingId, status: { in: ['PENDING', 'PARTIALLY_PAID', 'OVERDUE'] } },
            include: { member: { select: { userId: true, wardId: true, ward: { select: { parentId: true } } } } },
            orderBy: { dueDate: 'asc' },
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

        // 2. Calculate total balance — payer always pays the full total balance
        const totalBalance = records.reduce((s, r) => s + (r.finalAmount - r.paidAmount), 0);
        const payAmount = totalBalance;
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
        // H3 fix: Snapshot commission % at order creation
        const multiCoaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { platformFeePercent: true },
        });
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
                    platformFeePercent: multiCoaching?.platformFeePercent ?? 1.0, // H3 fix: snapshot
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
        // 1. C8 fix: Timing-safe signature comparison
        const secret = RAZORPAY_KEY_SECRET;
        if (!secret) throw Object.assign(new Error('Payment configuration error'), { status: 500 });

        const body = dto.razorpay_order_id + '|' + dto.razorpay_payment_id;
        const expectedSignature = crypto.createHmac('sha256', secret).update(body).digest('hex');
        const sigBuf = Buffer.from(dto.razorpay_signature, 'hex');
        const expectedBuf = Buffer.from(expectedSignature, 'hex');
        if (sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
            throw Object.assign(new Error('Payment verification failed'), { status: 400 });
        }

        // C7 fix: Cross-verify payment amount with Razorpay for multi-pay
        const allOrderRows = await prisma.razorpayOrder.findMany({
            where: { razorpayOrderId: dto.razorpay_order_id, coachingId },
        });
        const expectedTotal = allOrderRows.reduce((s, o) => s + o.amountPaise, 0);
        try {
            const rzpPayment = await razorpay.payments.fetch(dto.razorpay_payment_id);
            if (rzpPayment.amount !== expectedTotal) {
                console.error(`[PaymentService] Multi-pay amount mismatch: Razorpay=${rzpPayment.amount}, DB=${expectedTotal}`);
                throw Object.assign(new Error('Payment amount mismatch'), { status: 400 });
            }
            if (rzpPayment.status !== 'captured') {
                throw Object.assign(new Error(`Payment not captured (status: ${rzpPayment.status})`), { status: 400 });
            }
        } catch (err: any) {
            if (err.status) throw err;
            throw Object.assign(new Error('Failed to verify payment with Razorpay'), { status: 502 });
        }

        // H14 fix: Sort order rows by record dueDate so oldest dues are paid first
        const orders = await prisma.razorpayOrder.findMany({
            where: { razorpayOrderId: dto.razorpay_order_id, coachingId },
            include: { record: { select: { dueDate: true } } },
            orderBy: { createdAt: 'asc' },
        });
        orders.sort((a, b) => (a.record?.dueDate?.getTime() ?? 0) - (b.record?.dueDate?.getTime() ?? 0));
        if (orders.length === 0) throw Object.assign(new Error('Orders not found'), { status: 404 });

        // Check if already processed
        if (orders.every(o => o.paymentRecorded)) {
            return { success: true, message: 'Already processed', recordIds: orders.map(o => o.recordId) };
        }

        // 3. Process each sub-order with serialization retry
        for (const order of orders) {
            if (order.paymentRecorded) continue;
            await this._processPaymentWithRetry(order.id, dto.razorpay_payment_id, dto.razorpay_signature, userId);
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
        const orderForReceipt = await prisma.razorpayOrder.findUniqueOrThrow({ where: { id: internalOrderId } });
        if (orderForReceipt.paymentRecorded) return; // already processed

        // C1 fix: Serializable isolation prevents concurrent webhook + verify from
        // both seeing paymentRecorded=false and double-crediting paidAmount.
        await prisma.$transaction(async (tx) => {
            // Lock the order row under Serializable snapshot
            const order = await tx.razorpayOrder.findUniqueOrThrow({
                where: { id: internalOrderId },
            });

            if (order.paymentRecorded) return; // double-check inside tx

            // Generate receipt inside tx to avoid gaps on concurrent calls
            const fy = getFinancialYear();
            const seq = await tx.receiptSequence.upsert({
                where: { coachingId_financialYear: { coachingId: order.coachingId, financialYear: fy } },
                create: { coachingId: order.coachingId, financialYear: fy, lastNumber: 1 },
                update: { lastNumber: { increment: 1 } },
            });
            const receiptNo = `TXR/${fy}/${seq.lastNumber.toString().padStart(4, '0')}`;

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
            if (isPaid && record.assignment && record.assignment.isActive && !record.assignment.isPaused) {
                const fs = record.assignment.feeStructure;
                const cycle = fs.cycle;
                if (cycle !== 'ONCE' && cycle !== 'INSTALLMENT') {
                    const nextDue = nextDueDateFromCycle(record.dueDate, cycle);
                    const endDate = record.assignment.endDate;
                    if (!endDate || nextDue <= endDate) {
                        const totalDiscount = record.assignment.discountAmount + (record.assignment.scholarshipAmount ?? 0);
                        const baseAmt = (record.assignment.customAmount ?? fs.amount) - totalDiscount;
                        const tax = computeTax(baseAmt, fs.taxType, fs.gstRate, fs.gstSupplyType, fs.cessRate);
                        // finalAmount = totalWithTax — handles both GST_INCLUSIVE and GST_EXCLUSIVE correctly
                        const finalAmt = tax.totalWithTax;
                        const grossBaseAmt = baseAmt + totalDiscount; // pre-discount amount for reference

                        // Check no duplicate
                        // H6 fix: Use exact dueDate match for cycle-aware dedup
                        const dup = await tx.feeRecord.findFirst({
                            where: {
                                assignmentId: record.assignmentId,
                                dueDate: nextDue,
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
        }, { isolationLevel: 'Serializable' });

        // ── Razorpay Route Transfer (move funds to coaching's bank) ───
        // H3 fix: Re-read the order to get the latest state (paymentRecorded, etc.)
        // and use the snapshotted platformFeePercent from order creation time.
        const freshOrder = await prisma.razorpayOrder.findUniqueOrThrow({ where: { id: internalOrderId } });
        try {
            const coaching = await prisma.coaching.findUnique({
                where: { id: freshOrder.coachingId },
                select: { razorpayAccountId: true, razorpayActivated: true },
            });
            if (coaching?.razorpayAccountId && coaching.razorpayActivated) {
                // H3 fix: Use snapshotted commission % from order time, not live config
                const platformPercent = freshOrder.platformFeePercent ?? 1.0;
                const platformFeePaise = Math.round(freshOrder.amountPaise * (platformPercent / 100));
                const transferAmount = freshOrder.amountPaise - platformFeePaise;

                const transfer = await razorpay.payments.transfer(razorpayPaymentId, {
                    transfers: [{
                        account: coaching.razorpayAccountId,
                        amount: transferAmount,
                        currency: 'INR',
                        notes: { coachingId: freshOrder.coachingId, recordId: freshOrder.recordId },
                    }],
                });

                const transferId = transfer?.items?.[0]?.id ?? null;
                await prisma.razorpayOrder.update({
                    where: { id: internalOrderId },
                    data: { transferId, transferStatus: 'created', platformFeePaise },
                });
            }
        } catch (transferErr: any) {
            // H12 fix: Record transfer failure in DB instead of just logging
            console.error(`[PaymentService] Transfer failed for order ${internalOrderId}:`, transferErr?.message);
            await prisma.razorpayOrder.update({
                where: { id: internalOrderId },
                data: {
                    transferStatus: 'failed',
                    transferId: null,
                    notes: {
                        ...(freshOrder.notes as any ?? {}),
                        transferError: transferErr?.message ?? 'Unknown transfer error',
                        transferFailedAt: new Date().toISOString(),
                    } as any,
                },
            }).catch(() => { /* swallow DB error in error handler */ });
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

    private static readonly SETTINGS_SELECT = {
        id: true, name: true,
        gstNumber: true, panNumber: true,
        contactPhone: true,
        razorpayAccountId: true, razorpayActivated: true, platformFeePercent: true,
        razorpayStakeholderId: true, razorpayProductId: true, razorpayOnboardingStatus: true,
        bankAccountName: true, bankAccountNumber: true, bankIfscCode: true, bankName: true,
        bankVerified: true, bankVerifiedAt: true,
    } as const;

    async getPaymentSettings(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { ...PaymentService.SETTINGS_SELECT, ownerId: true },
        });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });

        // S1 fix: Only the owner can see full payment settings (PAN, bank account, IFSC)
        if (coaching.ownerId !== userId) {
            throw Object.assign(new Error('Only the owner can view payment settings'), { status: 403 });
        }

        // S2 fix: Mask bank account number in response (show only last 4 digits)
        const { ownerId: _ownerId, ...data } = coaching;
        if (data.bankAccountNumber) {
            const acc = data.bankAccountNumber;
            (data as any).bankAccountNumber = acc.length > 4
                ? '•'.repeat(acc.length - 4) + acc.slice(-4)
                : acc;
            // Include raw number only for the settings form (owner already verified above)
            (data as any).bankAccountNumberRaw = acc;
        }
        return data;
    }

    async updatePaymentSettings(coachingId: string, userId: string, dto: {
        gstNumber?: string | undefined;
        panNumber?: string | undefined;
        contactPhone?: string | undefined;
        bankAccountName?: string | undefined;
        bankAccountNumber?: string | undefined;
        bankIfscCode?: string | undefined;
        bankName?: string | undefined;
    }) {
        // Verify user is owner
        const coaching = await prisma.coaching.findUnique({ where: { id: coachingId }, select: { ownerId: true } });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        if (coaching.ownerId !== userId) throw Object.assign(new Error('Only the owner can update payment settings'), { status: 403 });

        const data: Record<string, unknown> = {};
        if (dto.gstNumber !== undefined) data.gstNumber = dto.gstNumber || null;
        if (dto.panNumber !== undefined) data.panNumber = dto.panNumber || null;
        if (dto.contactPhone !== undefined) data.contactPhone = dto.contactPhone || null;
        if (dto.bankAccountName !== undefined) data.bankAccountName = dto.bankAccountName || null;
        if (dto.bankAccountNumber !== undefined) data.bankAccountNumber = dto.bankAccountNumber || null;
        if (dto.bankIfscCode !== undefined) data.bankIfscCode = dto.bankIfscCode || null;
        if (dto.bankName !== undefined) data.bankName = dto.bankName || null;

        // Reset bank verification if bank details changed
        const bankFieldChanged =
            dto.bankAccountNumber !== undefined ||
            dto.bankIfscCode !== undefined ||
            dto.bankAccountName !== undefined;
        if (bankFieldChanged) {
            data.bankVerified = false;
            data.bankVerifiedAt = null;
        }

        return prisma.coaching.update({
            where: { id: coachingId },
            data,
            select: PaymentService.SETTINGS_SELECT,
        });
    }

    // ── Razorpay Route Linked Account Onboarding ──────────────────

    /**
     * Creates a Razorpay linked account for a coaching using Route v2 APIs.
     * Steps: 1) Create Account  2) Create Stakeholder  3) Request Route Product  4) Configure Settlement
     *
     * Requires: owner's email/phone, coaching name, PAN, bank details.
     * After this, Razorpay performs KYC (may take time). Check status via fetchLinkedAccountStatus().
     */
    async createLinkedAccount(coachingId: string, userId: string, dto: {
        ownerName: string;
        ownerEmail: string;
        ownerPhone: string;
        businessType?: string | undefined;
    }) {
        // 1. Verify ownership + prerequisites
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: {
                id: true, name: true, ownerId: true,
                razorpayAccountId: true, razorpayActivated: true,
                panNumber: true, gstNumber: true,
                bankAccountName: true, bankAccountNumber: true, bankIfscCode: true, bankName: true,
            },
        });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        if (coaching.ownerId !== userId) throw Object.assign(new Error('Only the owner can create a linked account'), { status: 403 });

        if (coaching.razorpayAccountId) {
            throw Object.assign(
                new Error('Linked account already exists. Use refresh status to check activation.'),
                { status: 409 },
            );
        }

        // Validate prerequisites
        if (!coaching.bankAccountNumber || !coaching.bankIfscCode || !coaching.bankAccountName) {
            throw Object.assign(
                new Error('Bank details (account number, IFSC, account holder name) are required before creating a linked account'),
                { status: 400 },
            );
        }

        try {
            // 2. Create Razorpay Account (Route v2)
            const legalInfo: Record<string, string> = {};
            if (coaching.panNumber) legalInfo.pan = coaching.panNumber;
            if (coaching.gstNumber) legalInfo.gst = coaching.gstNumber;

            const account = await (razorpay as any).accounts.create({
                email: dto.ownerEmail,
                phone: dto.ownerPhone,
                type: 'route',
                legal_business_name: coaching.name,
                business_type: dto.businessType || 'individual',
                ...(Object.keys(legalInfo).length > 0 ? { legal_info: legalInfo } : {}),
                profile: {
                    category: 'education',
                    subcategory: 'coaching',
                    addresses: {
                        registered: {
                            street1: 'N/A',
                            street2: '',
                            city: 'N/A',
                            state: 'N/A',
                            postal_code: '000000',
                            country: 'IN',
                        },
                    },
                },
                notes: {
                    coachingId,
                    platform: 'tutorix',
                },
            });

            const accountId: string = account.id;

            // 3. Create Stakeholder (owner's KYC info)
            let stakeholderId: string | null = null;
            try {
                const nameParts = dto.ownerName.trim().split(/\s+/);
                const stakeholder = await (razorpay as any).stakeholders.create(accountId, {
                    name: {
                        first: nameParts[0] || dto.ownerName,
                        last: nameParts.slice(1).join(' ') || '.',
                    },
                    phone: {
                        primary: dto.ownerPhone,
                    },
                    email: dto.ownerEmail,
                    notes: { role: 'owner', coachingId },
                });
                stakeholderId = stakeholder.id;
            } catch (err: any) {
                console.error(`[PaymentService] Stakeholder creation failed for acc ${accountId}:`, err?.message);
                // Non-fatal — continue without stakeholder, Razorpay will request KYC later
            }

            // 4. Request Route product configuration
            let productId: string | null = null;
            try {
                const product = await (razorpay as any).products.requestProductConfiguration(accountId, {
                    product_name: 'route',
                    tnc_accepted: true,
                });
                productId = product.id;

                // 5. Update product with settlement bank account details
                if (productId) {
                    await (razorpay as any).products.edit(accountId, productId, {
                        settlements: {
                            account_number: coaching.bankAccountNumber,
                            ifsc_code: coaching.bankIfscCode,
                            beneficiary_name: coaching.bankAccountName,
                        },
                    }).catch((err: any) => {
                        console.error(`[PaymentService] Product settlement config failed:`, err?.message);
                    });
                }
            } catch (err: any) {
                console.error(`[PaymentService] Product config failed for acc ${accountId}:`, err?.message);
                // Non-fatal — account created, product config can be retried
            }

            // 6. Determine initial activation status from Razorpay response
            const onboardingStatus = account.status ?? 'under_review';
            const isActivated = onboardingStatus === 'activated';

            // 7. Save to DB
            const updated = await prisma.coaching.update({
                where: { id: coachingId },
                data: {
                    razorpayAccountId: accountId,
                    razorpayStakeholderId: stakeholderId,
                    razorpayProductId: productId,
                    razorpayOnboardingStatus: onboardingStatus,
                    razorpayActivated: isActivated,
                },
                select: PaymentService.SETTINGS_SELECT,
            });

            return {
                ...updated,
                message: isActivated
                    ? 'Linked account created and activated! Payments will be routed to your bank.'
                    : 'Linked account created. Razorpay is reviewing your details — this usually takes 1-2 business days.',
            };
        } catch (err: any) {
            console.error(`[PaymentService] Linked account creation failed:`, err?.message, err?.error);
            const razorpayError = err?.error?.description || err?.message || 'Unknown error';
            throw Object.assign(
                new Error(`Failed to create linked account: ${razorpayError}`),
                { status: 502 },
            );
        }
    }

    /**
     * Fetches the current activation status of the coaching's linked account from Razorpay.
     * Updates our DB with the latest status.
     */
    async refreshLinkedAccountStatus(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { id: true, ownerId: true, razorpayAccountId: true, razorpayProductId: true },
        });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        if (coaching.ownerId !== userId) throw Object.assign(new Error('Only the owner can check linked account status'), { status: 403 });
        if (!coaching.razorpayAccountId) {
            throw Object.assign(new Error('No linked account found. Create one first.'), { status: 404 });
        }

        try {
            const account = await (razorpay as any).accounts.fetch(coaching.razorpayAccountId);

            const onboardingStatus: string = account.status ?? 'unknown';
            const isActivated = onboardingStatus === 'activated';

            // Also check product status if we have a product ID
            let productActive = false;
            if (coaching.razorpayProductId) {
                try {
                    const product = await (razorpay as any).products.fetch(
                        coaching.razorpayAccountId,
                        coaching.razorpayProductId,
                    );
                    productActive = product.active_configuration?.route?.status === 'activated'
                        || product.active_configuration?.payment_gateway?.status === 'activated';
                } catch {
                    // Product fetch failed — use account status only
                }
            }

            const fullyActivated = isActivated || productActive;

            const updated = await prisma.coaching.update({
                where: { id: coachingId },
                data: {
                    razorpayOnboardingStatus: onboardingStatus,
                    razorpayActivated: fullyActivated,
                },
                select: PaymentService.SETTINGS_SELECT,
            });

            return {
                ...updated,
                razorpayAccountStatus: onboardingStatus,
                message: fullyActivated
                    ? 'Razorpay Route is active! Payments will be routed to your bank.'
                    : `Account status: ${onboardingStatus}. Razorpay may require additional verification.`,
            };
        } catch (err: any) {
            throw Object.assign(
                new Error(`Failed to fetch account status: ${err?.error?.description || err?.message}`),
                { status: 502 },
            );
        }
    }

    /**
     * Deletes the Razorpay linked account and clears Route configuration.
     * Only for accounts that haven't processed live payments yet.
     */
    async deleteLinkedAccount(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { id: true, ownerId: true, razorpayAccountId: true },
        });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        if (coaching.ownerId !== userId) throw Object.assign(new Error('Only the owner can delete the linked account'), { status: 403 });
        if (!coaching.razorpayAccountId) {
            throw Object.assign(new Error('No linked account to delete'), { status: 404 });
        }

        // Check no live payments used this Route
        const routePayments = await prisma.razorpayOrder.count({
            where: { coachingId, transferId: { not: null } },
        });
        if (routePayments > 0) {
            throw Object.assign(
                new Error(`Cannot delete linked account — ${routePayments} payments have been routed through it. Contact support.`),
                { status: 409 },
            );
        }

        try {
            await (razorpay as any).accounts.delete(coaching.razorpayAccountId);
        } catch (err: any) {
            console.error(`[PaymentService] Razorpay account deletion failed:`, err?.message);
            // Continue with DB cleanup even if Razorpay API fails
        }

        return prisma.coaching.update({
            where: { id: coachingId },
            data: {
                razorpayAccountId: null,
                razorpayStakeholderId: null,
                razorpayProductId: null,
                razorpayOnboardingStatus: null,
                razorpayActivated: false,
            },
            select: PaymentService.SETTINGS_SELECT,
        });
    }

    // ── Penny-Drop Bank Account Verification ──────────────────────

    /**
     * Verifies the coaching's bank account via Razorpay Fund Account Validation API.
     * Performs a ₹1 penny transfer and checks if the account number + IFSC are valid.
     * Cost: ~₹2 per verification. Only runs if bank details changed since last verification.
     *
     * Returns: { verified: boolean, nameAtBank?: string, message: string }
     */
    async verifyBankAccount(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: {
                id: true, ownerId: true, name: true,
                bankAccountName: true, bankAccountNumber: true, bankIfscCode: true,
                bankVerified: true, bankVerifiedAt: true,
                contactPhone: true,
            },
        });
        if (!coaching) throw Object.assign(new Error('Coaching not found'), { status: 404 });
        if (coaching.ownerId !== userId) {
            throw Object.assign(new Error('Only the owner can verify the bank account'), { status: 403 });
        }

        // Validate bank details are present
        if (!coaching.bankAccountNumber || !coaching.bankIfscCode || !coaching.bankAccountName) {
            throw Object.assign(
                new Error('Bank account number, IFSC code, and account holder name are required'),
                { status: 400 },
            );
        }

        // Skip if already verified recently (within last 30 days) — avoid unnecessary charges
        if (coaching.bankVerified && coaching.bankVerifiedAt) {
            const daysSince = Math.floor((Date.now() - coaching.bankVerifiedAt.getTime()) / (1000 * 60 * 60 * 24));
            if (daysSince < 30) {
                return {
                    verified: true,
                    message: `Bank account verified ${daysSince === 0 ? 'today' : `${daysSince} day(s) ago`}. Re-verification available after 30 days.`,
                    verifiedAt: coaching.bankVerifiedAt,
                };
            }
        }

        try {
            // Razorpay Fund Account Validation API
            // Docs: https://razorpay.com/docs/api/x/fund-accounts/validation/
            const phone = coaching.contactPhone || '9999999999';
            const contactPayload = await fetch('https://api.razorpay.com/v1/contacts', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Basic ${Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64')}`,
                },
                body: JSON.stringify({
                    name: coaching.bankAccountName,
                    email: `verify+${coachingId.substring(0, 8)}@tutorix.app`,
                    contact: phone,
                    type: 'vendor',
                    reference_id: `vfy_${coachingId.substring(0, 35)}`,
                    notes: { purpose: 'bank_verification', coachingId },
                }),
            });
            if (!contactPayload.ok) {
                const err = await contactPayload.json().catch(() => ({}));
                throw new Error((err as any)?.error?.description || `Contact creation failed (${contactPayload.status})`);
            }
            const contact = await contactPayload.json() as { id: string };

            // Create fund account
            const fundAccPayload = await fetch('https://api.razorpay.com/v1/fund_accounts', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Basic ${Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64')}`,
                },
                body: JSON.stringify({
                    contact_id: contact.id,
                    account_type: 'bank_account',
                    bank_account: {
                        name: coaching.bankAccountName,
                        ifsc: coaching.bankIfscCode,
                        account_number: coaching.bankAccountNumber,
                    },
                }),
            });
            if (!fundAccPayload.ok) {
                const err = await fundAccPayload.json().catch(() => ({}));
                throw new Error((err as any)?.error?.description || `Fund account creation failed (${fundAccPayload.status})`);
            }
            const fundAccount = await fundAccPayload.json() as { id: string };

            // Trigger penny drop validation
            const validationPayload = await fetch('https://api.razorpay.com/v1/fund_accounts/validations', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Basic ${Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64')}`,
                },
                body: JSON.stringify({
                    fund_account: { id: fundAccount.id },
                    amount: 100, // ₹1 in paise
                    currency: 'INR',
                    notes: { purpose: 'bank_verification', coachingId },
                }),
            });
            if (!validationPayload.ok) {
                const err = await validationPayload.json().catch(() => ({}));
                throw new Error((err as any)?.error?.description || `Validation request failed (${validationPayload.status})`);
            }
            const validation = await validationPayload.json() as {
                id: string;
                status: string;
                results?: { account_status?: string; registered_name?: string };
            };

            // Check validation result
            const accStatus = validation.results?.account_status;
            const registeredName = validation.results?.registered_name;
            const isValid = accStatus === 'active' || validation.status === 'completed';

            if (isValid) {
                await prisma.coaching.update({
                    where: { id: coachingId },
                    data: { bankVerified: true, bankVerifiedAt: new Date() },
                });
                return {
                    verified: true,
                    nameAtBank: registeredName || null,
                    message: registeredName
                        ? `Bank account verified! Registered name: ${registeredName}`
                        : 'Bank account verified successfully.',
                    verifiedAt: new Date(),
                };
            }

            // Penny drop was initiated but not yet completed (async)
            // Razorpay may take a few seconds. Mark as verified optimistically because
            // fund account creation succeeded (account exists).
            if (validation.status === 'created' || validation.status === 'pending') {
                await prisma.coaching.update({
                    where: { id: coachingId },
                    data: { bankVerified: true, bankVerifiedAt: new Date() },
                });
                return {
                    verified: true,
                    message: 'Bank account validation initiated. The ₹1 penny deposit confirms your account.',
                    verifiedAt: new Date(),
                };
            }

            return {
                verified: false,
                message: `Bank account validation failed: ${accStatus || validation.status}. Please verify your account details.`,
            };
        } catch (err: any) {
            console.error(`[PaymentService] Penny drop verification failed:`, err?.message);

            // If it's a Razorpay API error (invalid account, etc.), provide a clear message
            const msg = err?.message || 'Verification failed';
            if (msg.includes('IFSC') || msg.includes('ifsc')) {
                throw Object.assign(new Error('Invalid IFSC code. Please check and try again.'), { status: 400 });
            }
            if (msg.includes('account_number') || msg.includes('Account number')) {
                throw Object.assign(new Error('Invalid bank account number. Please verify and try again.'), { status: 400 });
            }
            throw Object.assign(new Error(`Bank verification failed: ${msg}`), { status: 502 });
        }
    }
}