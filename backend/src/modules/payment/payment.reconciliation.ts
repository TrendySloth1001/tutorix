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
 * Retry all failed OR orphaned Razorpay Route transfers.
 * Scans RazorpayOrder rows where:
 *   - transferStatus = 'failed' (explicit failure)
 *   - transferStatus IS NULL AND coaching has Route enabled (DB write after transfer succeeded may have failed)
 *
 * Before retrying, checks Razorpay API to see if a transfer already exists
 * for the payment to prevent duplicate transfers.
 */
export async function retryFailedTransfers(): Promise<TransferRetryResult> {
    // Find orders that need transfer: either explicitly failed or never recorded
    const coachingsWithRoute = await prisma.coaching.findMany({
        where: { razorpayActivated: true, razorpayAccountId: { not: null } },
        select: { id: true },
    });
    const routeCoachingIds = coachingsWithRoute.map(c => c.id);

    const ordersNeedingTransfer = await prisma.razorpayOrder.findMany({
        where: {
            paymentRecorded: true,
            razorpayPaymentId: { not: null },
            coachingId: { in: routeCoachingIds },
            OR: [
                { transferStatus: 'failed' },
                { transferStatus: null },
            ],
        },
        include: {
            coaching: {
                select: { razorpayAccountId: true, razorpayActivated: true },
            },
        },
    });

    const result: TransferRetryResult = { attempted: 0, succeeded: 0, failed: 0, details: [] };

    for (const order of ordersNeedingTransfer) {
        if (!order.coaching?.razorpayAccountId || !order.coaching.razorpayActivated) continue;
        if (!order.razorpayPaymentId) continue;

        result.attempted++;

        try {
            // Check if transfer already exists on Razorpay side (prevents duplicates)
            let existingTransferId: string | null = null;
            try {
                const payment = await razorpay.payments.fetch(order.razorpayPaymentId) as any;
                const transfers = payment?.transfers?.items;
                if (transfers && transfers.length > 0) {
                    existingTransferId = transfers[0].id;
                }
            } catch { /* Razorpay API error — proceed with retry */ }

            if (existingTransferId) {
                // Transfer exists on Razorpay — just update our DB
                await prisma.razorpayOrder.update({
                    where: { id: order.id },
                    data: { transferId: existingTransferId, transferStatus: 'created' },
                });
                result.succeeded++;
                result.details.push({ orderId: order.id, status: 'success' });
                continue;
            }

            // No existing transfer — create one
            const platformPercent = order.platformFeePercent ?? 1.0;
            const platformFeePaise = Math.round(order.amountPaise * (platformPercent / 100));
            const transferAmount = order.amountPaise - platformFeePaise;

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

// ─── Ledger Integrity (paidAmount invariant) ──────────────────

export interface LedgerIntegrityResult {
    totalRecordsChecked: number;
    driftedRecords: Array<{
        recordId: string;
        coachingId: string;
        storedPaidAmount: number;
        derivedPaidAmount: number;
        delta: number;
    }>;
    overpaidRecords: Array<{
        recordId: string;
        coachingId: string;
        paidAmount: number;
        finalAmount: number;
    }>;
    summary: string;
}

/**
 * Check that every FeeRecord's paidAmount equals SUM(payments) - SUM(refunds).
 * Also flags records where paidAmount > finalAmount + 1 (overpayment).
 */
export async function checkLedgerIntegrity(): Promise<LedgerIntegrityResult> {
    // Use raw SQL for efficient aggregate comparison
    const drifted: any[] = await prisma.$queryRaw`
        SELECT
            r.id AS "recordId",
            r."coachingId",
            r."paidAmount" AS "storedPaidAmount",
            COALESCE(pay_sum.total, 0) - COALESCE(ref_sum.total, 0) AS "derivedPaidAmount"
        FROM "FeeRecord" r
        LEFT JOIN (
            SELECT "recordId", SUM(amount) as total
            FROM "FeePayment"
            GROUP BY "recordId"
        ) pay_sum ON pay_sum."recordId" = r.id
        LEFT JOIN (
            SELECT "recordId", SUM(amount) as total
            FROM "FeeRefund"
            GROUP BY "recordId"
        ) ref_sum ON ref_sum."recordId" = r.id
        WHERE ABS(r."paidAmount" - (COALESCE(pay_sum.total, 0) - COALESCE(ref_sum.total, 0))) > 0.01
    `;

    const overpaid: any[] = await prisma.$queryRaw`
        SELECT id AS "recordId", "coachingId", "paidAmount", "finalAmount"
        FROM "FeeRecord"
        WHERE "paidAmount" > "finalAmount" + 1.0
    `;

    const totalChecked = await prisma.feeRecord.count();

    return {
        totalRecordsChecked: totalChecked,
        driftedRecords: drifted.map(d => ({
            recordId: d.recordId,
            coachingId: d.coachingId,
            storedPaidAmount: Number(d.storedPaidAmount),
            derivedPaidAmount: Number(d.derivedPaidAmount),
            delta: Number(d.storedPaidAmount) - Number(d.derivedPaidAmount),
        })),
        overpaidRecords: overpaid.map(o => ({
            recordId: o.recordId,
            coachingId: o.coachingId,
            paidAmount: Number(o.paidAmount),
            finalAmount: Number(o.finalAmount),
        })),
        summary: drifted.length === 0 && overpaid.length === 0
            ? `✅ Ledger integrity OK. ${totalChecked} records checked.`
            : `⚠️ LEDGER DRIFT: ${drifted.length} records with paidAmount mismatch, ${overpaid.length} records overpaid.`,
    };
}

// ─── Health Checks (stuck orders, orphaned refunds) ────────────

export interface HealthCheckResult {
    stuckOrders: number;       // CREATED for >24h
    stuckRefunds: number;      // INITIATED for >1h without razorpayRefundId
    orphanedTransfers: number; // paymentRecorded=true but no transfer for Route-enabled coaching
    duplicatePayments: number; // same razorpayPaymentId on multiple FeePayments for same record
    details: string[];
}

/**
 * Run health checks to catch operational anomalies.
 */
export async function runHealthChecks(): Promise<HealthCheckResult> {
    const details: string[] = [];

    // 1. Stuck orders — CREATED for >24h (Razorpay orders expire after 30min,
    //    but a stuck DB row means the webhook never arrived or failed permanently)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const stuckOrders = await prisma.razorpayOrder.count({
        where: { status: 'CREATED', createdAt: { lt: oneDayAgo } },
    });
    if (stuckOrders > 0) details.push(`${stuckOrders} orders stuck in CREATED for >24h`);

    // 2. Stuck refunds — INITIATED for >1h without a razorpayRefundId
    //    (means Razorpay API was never called or the DB update after API call failed)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const stuckRefunds = await prisma.razorpayRefund.count({
        where: {
            status: 'INITIATED',
            razorpayRefundId: null,
            createdAt: { lt: oneHourAgo },
        },
    });
    if (stuckRefunds > 0) details.push(`${stuckRefunds} refunds stuck in INITIATED (no Razorpay ID) for >1h`);

    // 3. Orphaned transfers — payment recorded but no transfer for Route-enabled coaching
    const coachingsWithRoute = await prisma.coaching.findMany({
        where: { razorpayActivated: true, razorpayAccountId: { not: null } },
        select: { id: true },
    });
    const routeIds = coachingsWithRoute.map(c => c.id);
    const orphanedTransfers = routeIds.length > 0 ? await prisma.razorpayOrder.count({
        where: {
            paymentRecorded: true,
            coachingId: { in: routeIds },
            OR: [
                { transferStatus: null },
                { transferStatus: 'failed' },
            ],
        },
    }) : 0;
    if (orphanedTransfers > 0) details.push(`${orphanedTransfers} orders with missing/failed transfers for Route-enabled coachings`);

    // 4. Duplicate payments — same razorpayPaymentId + recordId (should be caught by unique constraint now, but check historical data)
    const dupes: any[] = await prisma.$queryRaw`
        SELECT "recordId", "razorpayPaymentId", COUNT(*) as cnt
        FROM "FeePayment"
        WHERE "razorpayPaymentId" IS NOT NULL
        GROUP BY "recordId", "razorpayPaymentId"
        HAVING COUNT(*) > 1
    `;
    const duplicatePayments = dupes.length;
    if (duplicatePayments > 0) details.push(`${duplicatePayments} duplicate payment groups found (same recordId + razorpayPaymentId)`);

    return {
        stuckOrders,
        stuckRefunds,
        orphanedTransfers,
        duplicatePayments,
        details: details.length > 0 ? details : ['All health checks passed'],
    };
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
} else if (command === 'check-ledger') {
    checkLedgerIntegrity()
        .then((r) => {
            console.log(r.summary);
            for (const d of r.driftedRecords) {
                console.log(`  DRIFT: ${d.recordId} — stored ₹${d.storedPaidAmount.toFixed(2)}, derived ₹${d.derivedPaidAmount.toFixed(2)} (Δ ₹${d.delta.toFixed(2)})`);
            }
            for (const o of r.overpaidRecords) {
                console.log(`  OVERPAID: ${o.recordId} — paid ₹${o.paidAmount.toFixed(2)} > final ₹${o.finalAmount.toFixed(2)}`);
            }
            process.exit(r.driftedRecords.length + r.overpaidRecords.length > 0 ? 1 : 0);
        })
        .catch((err) => { console.error(err); process.exit(2); });
} else if (command === 'health-check') {
    runHealthChecks()
        .then((r) => {
            const total = r.stuckOrders + r.stuckRefunds + r.orphanedTransfers + r.duplicatePayments;
            console.log(total === 0 ? '✅ All health checks passed' : `⚠️ ${total} issues found`);
            for (const d of r.details) {
                console.log(`  ${d}`);
            }
            process.exit(total > 0 ? 1 : 0);
        })
        .catch((err) => { console.error(err); process.exit(2); });
} else if (command === 'full') {
    // Run all checks
    (async () => {
        console.log('=== Full Payment System Audit ===\n');

        console.log('1. Razorpay ↔ DB Reconciliation');
        const recon = await reconcileDay();
        console.log(`   ${recon.summary}\n`);

        console.log('2. Ledger Integrity');
        const ledger = await checkLedgerIntegrity();
        console.log(`   ${ledger.summary}\n`);

        console.log('3. Health Checks');
        const health = await runHealthChecks();
        for (const d of health.details) console.log(`   ${d}`);
        console.log();

        console.log('4. Transfer Retry');
        const transfers = await retryFailedTransfers();
        console.log(`   ${transfers.attempted} attempted, ${transfers.succeeded} succeeded, ${transfers.failed} failed\n`);

        const totalIssues =
            recon.missingInDb.length + recon.missingInRazorpay.length + recon.amountMismatches.length +
            ledger.driftedRecords.length + ledger.overpaidRecords.length +
            health.stuckOrders + health.stuckRefunds + health.orphanedTransfers + health.duplicatePayments +
            transfers.failed;

        console.log(totalIssues === 0
            ? '✅ All systems clean.'
            : `⚠️ ${totalIssues} total issues found. Review above.`);
        process.exit(totalIssues > 0 ? 1 : 0);
    })().catch((err) => { console.error(err); process.exit(2); });
} else if (command) {
    console.error(`Unknown command: ${command}`);
    console.error('Usage: npx tsx src/modules/payment/payment.reconciliation.ts [reconcile|retry-transfers|check-ledger|health-check|full] [date]');
    process.exit(1);
}
