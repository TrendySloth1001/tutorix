/**
 * Payment Reconciliation & Transfer Retry
 *
 * H5 fix: Financial reconciliation — compares Razorpay captured payments against FeePayment rows.
 * M1 fix: Retries failed transfers for Razorpay Route.
 *
 * Usage:
 *   npx tsx src/modules/payment/payment.reconciliation.ts reconcile
 *   npx tsx src/modules/payment/payment.reconciliation.ts retry-transfers
 *
 * Or import and call from a cron job / admin endpoint.
 */

import Razorpay from 'razorpay';
import prisma from '../../infra/prisma.js';

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID ?? '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET ?? '';

const razorpay = new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET });

// ─── Reconciliation ────────────────────────────────────────────

export interface ReconciliationResult {
    date: string;
    razorpayTotal: number;
    dbTotal: number;
    difference: number;
    missingInDb: string[];        // Razorpay payment IDs not found in FeePayment
    missingInRazorpay: string[];  // DB razorpayPaymentIds not found in Razorpay
    amountMismatches: Array<{ paymentId: string; razorpayAmount: number; dbAmount: number }>;
    summary: string;
}

/**
 * Reconcile a single day's captured payments.
 * Compares Razorpay's payment list (via API) against FeePayment rows.
 *
 * @param date ISO date string, e.g. "2026-02-20". Defaults to yesterday.
 */
export async function reconcileDay(date?: string): Promise<ReconciliationResult> {
    const targetDate = date ? new Date(date) : new Date(Date.now() - 24 * 60 * 60 * 1000);
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    const fromTs = Math.floor(startOfDay.getTime() / 1000);
    const toTs = Math.floor(endOfDay.getTime() / 1000);

    // 1. Fetch all captured payments from Razorpay for this day
    const rzpPayments: any[] = [];
    let skip = 0;
    const count = 100;
    let hasMore = true;
    while (hasMore) {
        const batch: any = await razorpay.payments.all({
            from: fromTs,
            to: toTs,
            count,
            skip,
        });
        const items = batch?.items ?? [];
        rzpPayments.push(...items.filter((p: any) => p.status === 'captured'));
        hasMore = items.length === count;
        skip += count;
    }

    // 2. Fetch all Razorpay FeePayments from DB for this day
    const dbPayments = await prisma.feePayment.findMany({
        where: {
            mode: 'RAZORPAY',
            paidAt: { gte: startOfDay, lte: endOfDay },
            razorpayPaymentId: { not: null },
        },
        select: {
            razorpayPaymentId: true,
            amount: true,
        },
    });

    // 3. Build lookup maps
    const rzpById = new Map<string, number>();
    for (const p of rzpPayments) {
        rzpById.set(p.id, p.amount); // amount in paise
    }

    const dbById = new Map<string, number>();
    for (const p of dbPayments) {
        if (p.razorpayPaymentId) {
            // DB stores in rupees, convert to paise for comparison
            const existing = dbById.get(p.razorpayPaymentId) ?? 0;
            dbById.set(p.razorpayPaymentId, existing + Math.round(p.amount * 100));
        }
    }

    // 4. Compare
    const missingInDb: string[] = [];
    const amountMismatches: Array<{ paymentId: string; razorpayAmount: number; dbAmount: number }> = [];
    let razorpayTotal = 0;

    for (const [payId, rzpAmountPaise] of rzpById) {
        razorpayTotal += rzpAmountPaise;
        const dbAmountPaise = dbById.get(payId);
        if (dbAmountPaise === undefined) {
            missingInDb.push(payId);
        } else if (Math.abs(rzpAmountPaise - dbAmountPaise) > 1) {
            amountMismatches.push({ paymentId: payId, razorpayAmount: rzpAmountPaise, dbAmount: dbAmountPaise });
        }
    }

    const missingInRazorpay: string[] = [];
    let dbTotal = 0;
    for (const [payId, dbAmountPaise] of dbById) {
        dbTotal += dbAmountPaise;
        if (!rzpById.has(payId)) {
            missingInRazorpay.push(payId);
        }
    }

    const difference = razorpayTotal - dbTotal;
    const dateStr = startOfDay.toISOString().slice(0, 10);
    const isClean = missingInDb.length === 0 && missingInRazorpay.length === 0 && amountMismatches.length === 0;

    return {
        date: dateStr,
        razorpayTotal,
        dbTotal,
        difference,
        missingInDb,
        missingInRazorpay,
        amountMismatches,
        summary: isClean
            ? `✅ ${dateStr}: Reconciled. Razorpay ₹${(razorpayTotal / 100).toFixed(2)} = DB ₹${(dbTotal / 100).toFixed(2)}`
            : `⚠️ ${dateStr}: MISMATCH. Razorpay ₹${(razorpayTotal / 100).toFixed(2)} vs DB ₹${(dbTotal / 100).toFixed(2)} (Δ ₹${(difference / 100).toFixed(2)}). Missing in DB: ${missingInDb.length}. Missing in Razorpay: ${missingInRazorpay.length}. Amount mismatches: ${amountMismatches.length}.`,
    };
}

// ─── Transfer Retry ────────────────────────────────────────────

export interface TransferRetryResult {
    attempted: number;
    succeeded: number;
    failed: number;
    details: Array<{ orderId: string; status: 'success' | 'failed'; error?: string }>;
}

/**
 * Retry all failed Razorpay Route transfers.
 * Scans RazorpayOrder rows with transferStatus='failed' and paymentRecorded=true.
 */
export async function retryFailedTransfers(): Promise<TransferRetryResult> {
    const failedOrders = await prisma.razorpayOrder.findMany({
        where: {
            transferStatus: 'failed',
            paymentRecorded: true,
            razorpayPaymentId: { not: null },
        },
        include: {
            coaching: {
                select: { razorpayAccountId: true, razorpayActivated: true },
            },
        },
    });

    const result: TransferRetryResult = { attempted: 0, succeeded: 0, failed: 0, details: [] };

    for (const order of failedOrders) {
        if (!order.coaching?.razorpayAccountId || !order.coaching.razorpayActivated) {
            continue; // coaching doesn't have Route enabled
        }
        if (!order.razorpayPaymentId) continue;

        result.attempted++;

        // Use snapshotted commission % (H3 fix), fallback to 1%
        const platformPercent = order.platformFeePercent ?? 1.0;
        const platformFeePaise = Math.round(order.amountPaise * (platformPercent / 100));
        const transferAmount = order.amountPaise - platformFeePaise;

        try {
            const transfer = await razorpay.payments.transfer(order.razorpayPaymentId, {
                transfers: [{
                    account: order.coaching.razorpayAccountId,
                    amount: transferAmount,
                    currency: 'INR',
                    notes: { coachingId: order.coachingId, recordId: order.recordId, retry: 'true' },
                }],
            });

            const transferId = transfer?.items?.[0]?.id ?? null;
            await prisma.razorpayOrder.update({
                where: { id: order.id },
                data: { transferId, transferStatus: 'created', platformFeePaise },
            });

            result.succeeded++;
            result.details.push({ orderId: order.id, status: 'success' });
        } catch (err: any) {
            result.failed++;
            result.details.push({ orderId: order.id, status: 'failed', error: err?.message });
            console.error(`[TransferRetry] Failed for order ${order.id}:`, err?.message);
        }
    }

    return result;
}

// ─── CLI Entrypoint ────────────────────────────────────────────

const command = process.argv[2];

if (command === 'reconcile') {
    const date = process.argv[3]; // optional: "2026-02-20"
    reconcileDay(date)
        .then((r) => {
            console.log(r.summary);
            if (r.missingInDb.length > 0) {
                console.log('  Missing in DB:', r.missingInDb.join(', '));
            }
            if (r.missingInRazorpay.length > 0) {
                console.log('  Missing in Razorpay:', r.missingInRazorpay.join(', '));
            }
            if (r.amountMismatches.length > 0) {
                console.log('  Amount mismatches:');
                for (const m of r.amountMismatches) {
                    console.log(`    ${m.paymentId}: Razorpay ₹${(m.razorpayAmount / 100).toFixed(2)} vs DB ₹${(m.dbAmount / 100).toFixed(2)}`);
                }
            }
            process.exit(r.missingInDb.length + r.missingInRazorpay.length + r.amountMismatches.length > 0 ? 1 : 0);
        })
        .catch((err) => { console.error(err); process.exit(2); });
} else if (command === 'retry-transfers') {
    retryFailedTransfers()
        .then((r) => {
            console.log(`Transfer retry: ${r.attempted} attempted, ${r.succeeded} succeeded, ${r.failed} failed`);
            for (const d of r.details) {
                console.log(`  ${d.orderId}: ${d.status}${d.error ? ` (${d.error})` : ''}`);
            }
            process.exit(r.failed > 0 ? 1 : 0);
        })
        .catch((err) => { console.error(err); process.exit(2); });
} else if (command) {
    console.error(`Unknown command: ${command}`);
    console.error('Usage: npx tsx src/modules/payment/payment.reconciliation.ts [reconcile|retry-transfers] [date]');
    process.exit(1);
}
