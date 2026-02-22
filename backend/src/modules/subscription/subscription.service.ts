import prisma from '../../infra/prisma.js';
import Razorpay from 'razorpay';
import { CreditService } from './credit.service.js';

// ─── Razorpay Instance (Tutorix master account) ─────────────────────

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID;
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;

const razorpay = RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET
    ? new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET })
    : null;

// ─── Helpers ─────────────────────────────────────────────────────────

function toPaise(rupees: number): number {
    return Math.round(rupees * 100);
}

function addMonths(date: Date, months: number): Date {
    const d = new Date(date);
    d.setMonth(d.getMonth() + months);
    return d;
}

function addYears(date: Date, years: number): Date {
    const d = new Date(date);
    d.setFullYear(d.getFullYear() + years);
    return d;
}

function getFinancialYear(date: Date = new Date()): string {
    const y = date.getFullYear();
    const m = date.getMonth();
    const startYear = m >= 3 ? y : y - 1;
    const endYear = (startYear + 1) % 100;
    return `${startYear}-${endYear.toString().padStart(2, '0')}`;
}

// ─── Types ───────────────────────────────────────────────────────────

export interface SubscriptionUsage {
    students: { used: number; limit: number; percent: number };
    parents: { used: number; limit: number; percent: number };
    teachers: { used: number; limit: number; percent: number };
    admins: { used: number; limit: number; percent: number };
    batches: { used: number; limit: number; percent: number };
    assessmentsThisMonth: { used: number; limit: number; percent: number };
    storage: { usedBytes: number; limitBytes: number; percent: number };
}

// ─── Service ─────────────────────────────────────────────────────────

export class SubscriptionService {

    // ── Plans ────────────────────────────────────────────────────────

    async listPlans() {
        return prisma.plan.findMany({
            orderBy: { order: 'asc' },
        });
    }

    async getPlanBySlug(slug: string) {
        return prisma.plan.findUnique({ where: { slug } });
    }

    // ── Subscription CRUD ────────────────────────────────────────────

    /** Get the coaching's current subscription (with plan). Creates a free one if none exists. */
    async getOrCreateSubscription(coachingId: string) {
        let sub = await prisma.subscription.findUnique({
            where: { coachingId },
            include: { plan: true },
        });

        if (!sub) {
            const freePlan = await prisma.plan.findUnique({ where: { slug: 'free' } });
            if (!freePlan) throw new Error('Free plan not found. Run seed-plans.');

            sub = await prisma.subscription.create({
                data: {
                    coachingId,
                    planId: freePlan.id,
                    billingCycle: 'MONTHLY',
                    status: 'ACTIVE',
                    currentPeriodStart: new Date(),
                    currentPeriodEnd: addYears(new Date(), 100), // Free = never expires
                },
                include: { plan: true },
            });
        }

        return sub;
    }

    /** Get subscription without auto-create (for middleware checks) */
    async getSubscription(coachingId: string) {
        return prisma.subscription.findUnique({
            where: { coachingId },
            include: { plan: true },
        });
    }

    // ── Usage Counting ───────────────────────────────────────────────

    async getUsage(coachingId: string): Promise<SubscriptionUsage> {
        const sub = await this.getOrCreateSubscription(coachingId);
        const plan = sub.plan;

        // Count members by role
        const memberCounts = await prisma.coachingMember.groupBy({
            by: ['role'],
            where: { coachingId, status: 'active' },
            _count: true,
        });

        const countByRole = (role: string) =>
            memberCounts.find(m => m.role === role)?._count ?? 0;

        // Count batches
        const batchCount = await prisma.batch.count({
            where: { coachingId, status: 'active' },
        });

        // Count assessments this month
        const now = new Date();
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
        const assessmentCount = await prisma.assessment.count({
            where: {
                coachingId,
                createdAt: { gte: monthStart },
            },
        });

        // Storage used
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { storageUsed: true },
        });
        const storageUsed = Number(coaching?.storageUsed ?? 0);
        const storageLimit = Number(plan.storageLimitBytes);

        const usage = (used: number, limit: number) => ({
            used,
            limit,
            percent: limit <= 0 ? 0 : Math.min(100, Math.round((used / limit) * 100)),
        });

        // -1 = unlimited
        return {
            students: usage(countByRole('STUDENT'), plan.maxStudents),
            parents: usage(
                // Parents are counted via users who have ward enrollments in this coaching
                await prisma.coachingMember.count({
                    where: { coachingId, status: 'active', role: 'STUDENT', wardId: { not: null } },
                }),
                plan.maxParents,
            ),
            teachers: usage(countByRole('TEACHER'), plan.maxTeachers),
            admins: usage(countByRole('ADMIN'), plan.maxAdmins),
            batches: usage(batchCount, plan.maxBatches),
            assessmentsThisMonth: usage(assessmentCount, plan.maxAssessmentsPerMonth),
            storage: {
                usedBytes: storageUsed,
                limitBytes: storageLimit,
                percent: storageLimit <= 0 ? 0 : Math.min(100, Math.round((storageUsed / storageLimit) * 100)),
            },
        };
    }

    // ── Quota Checks (used by middleware) ────────────────────────────

    async checkQuota(coachingId: string, dimension: string, increment: number = 1): Promise<{ allowed: boolean; message?: string }> {
        const sub = await this.getOrCreateSubscription(coachingId);
        const plan = sub.plan;

        // Check subscription status
        if (sub.status === 'EXPIRED' || sub.status === 'CANCELLED') {
            return { allowed: false, message: 'Your subscription has expired. Please renew to continue.' };
        }

        // Grace period — allow reads but block writes
        if (sub.status === 'PAST_DUE' && sub.gracePeriodEndsAt && new Date() > sub.gracePeriodEndsAt) {
            return { allowed: false, message: 'Payment overdue. Please update your payment method to continue.' };
        }

        switch (dimension) {
            case 'STUDENT': {
                if (plan.maxStudents === -1) return { allowed: true };
                const count = await prisma.coachingMember.count({ where: { coachingId, role: 'STUDENT', status: 'active' } });
                if (count + increment > plan.maxStudents) {
                    return { allowed: false, message: `Student limit reached (${plan.maxStudents}). Upgrade your plan to add more students.` };
                }
                return { allowed: true };
            }
            case 'TEACHER': {
                if (plan.maxTeachers === -1) return { allowed: true };
                const count = await prisma.coachingMember.count({ where: { coachingId, role: 'TEACHER', status: 'active' } });
                if (count + increment > plan.maxTeachers) {
                    return { allowed: false, message: `Teacher limit reached (${plan.maxTeachers}). Upgrade your plan to add more teachers.` };
                }
                return { allowed: true };
            }
            case 'ADMIN': {
                if (plan.maxAdmins === -1) return { allowed: true };
                const count = await prisma.coachingMember.count({ where: { coachingId, role: 'ADMIN', status: 'active' } });
                if (count + increment > plan.maxAdmins) {
                    return { allowed: false, message: `Admin limit reached (${plan.maxAdmins}). Upgrade your plan.` };
                }
                return { allowed: true };
            }
            case 'BATCH': {
                if (plan.maxBatches === -1) return { allowed: true };
                const count = await prisma.batch.count({ where: { coachingId, status: 'active' } });
                if (count + increment > plan.maxBatches) {
                    return { allowed: false, message: `Batch limit reached (${plan.maxBatches}). Upgrade your plan to create more batches.` };
                }
                return { allowed: true };
            }
            case 'ASSESSMENT': {
                if (plan.maxAssessmentsPerMonth === -1) return { allowed: true };
                const now = new Date();
                const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
                const count = await prisma.assessment.count({ where: { coachingId, createdAt: { gte: monthStart } } });
                if (count + increment > plan.maxAssessmentsPerMonth) {
                    return { allowed: false, message: `Monthly assessment limit reached (${plan.maxAssessmentsPerMonth}). Upgrade your plan.` };
                }
                return { allowed: true };
            }
            case 'RAZORPAY': {
                if (!plan.hasRazorpay) {
                    return { allowed: false, message: 'Online fee collection requires a paid plan. Upgrade to Basic or higher.' };
                }
                return { allowed: true };
            }
            case 'AUTO_REMIND': {
                if (!plan.hasAutoRemind) {
                    return { allowed: false, message: 'Auto-reminders require Standard or higher plan.' };
                }
                return { allowed: true };
            }
            case 'FEE_REPORTS': {
                if (!plan.hasFeeReports) {
                    return { allowed: false, message: 'Fee reports require Premium plan.' };
                }
                return { allowed: true };
            }
            case 'FEE_LEDGER': {
                if (!plan.hasFeeLedger) {
                    return { allowed: false, message: 'Fee ledger requires Premium plan.' };
                }
                return { allowed: true };
            }
            default:
                return { allowed: true };
        }
    }

    /** Check feature flag directly */
    async hasFeature(coachingId: string, feature: string): Promise<boolean> {
        const sub = await this.getOrCreateSubscription(coachingId);
        const plan = sub.plan as any;
        return !!plan[feature];
    }

    // ── Subscribe / Upgrade / Downgrade ──────────────────────────────

    /**
     * Create a Razorpay Payment Link for a paid plan.
     *
     * Option B — uses Payment Links API (works without Plans API activation).
     * The subscription is NOT activated here; it remains on the current plan
     * until the `payment_link.paid` webhook fires and calls handlePaymentLinkPaid().
     *
     * Credits are checked and applied automatically:
     *  - If credits fully cover the amount → activate immediately, no payment link.
     *  - If credits partially cover → create payment link for the net amount,
     *    redeem credits only after payment confirmation.
     */
    async createSubscription(coachingId: string, planSlug: string, cycle: 'MONTHLY' | 'YEARLY', userId: string) {
        if (!razorpay) throw new Error('Razorpay not configured');

        const plan = await prisma.plan.findUnique({ where: { slug: planSlug } });
        if (!plan) throw new Error('Plan not found');
        if (plan.slug === 'free') throw new Error('Cannot subscribe to free plan');

        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { id: true, name: true, ownerId: true },
        });
        if (!coaching) throw new Error('Coaching not found');
        if (coaching.ownerId !== userId) throw new Error('Only the coaching owner can manage subscriptions');

        const amount = cycle === 'YEARLY' ? plan.priceYearly : plan.priceMonthly;
        const amountPaise = toPaise(amount);

        // Ensure subscription record exists (may still be on free plan)
        const sub = await this.getOrCreateSubscription(coachingId);

        // ── Credits ──────────────────────────────────────────────────
        const creditService = new CreditService();
        const creditBalancePaise = await creditService.getBalancePaise(userId);
        const creditAppliedPaise = Math.min(creditBalancePaise, amountPaise);
        const netAmountPaise = amountPaise - creditAppliedPaise;

        // ── Fully covered by credits ─────────────────────────────────
        if (netAmountPaise <= 0) {
            // Redeem credits immediately and activate the subscription
            await creditService.redeemCredit(userId, amountPaise, sub.id);

            const now = new Date();
            const periodEnd = cycle === 'YEARLY' ? addYears(now, 1) : addMonths(now, 1);

            await prisma.$transaction([
                prisma.subscription.update({
                    where: { id: sub.id },
                    data: {
                        planId: plan.id,
                        billingCycle: cycle,
                        status: 'ACTIVE',
                        currentPeriodStart: now,
                        currentPeriodEnd: periodEnd,
                        lastPaymentAt: now,
                        lastPaymentAmount: amount,
                        failedPaymentCount: 0,
                        cancelledAt: null,
                        pausedAt: null,
                        gracePeriodEndsAt: null,
                        pastDueAt: null,
                        scheduledPlanId: null,
                        scheduledCycle: null,
                    },
                }),
                prisma.subscriptionInvoice.create({
                    data: {
                        subscriptionId: sub.id,
                        razorpayPaymentId: `credit_${sub.id}_${Date.now()}`,
                        amountPaise,
                        creditAppliedPaise: amountPaise,
                        totalPaise: 0,
                        status: 'PAID',
                        type: sub.lastPaymentAt ? 'RENEWAL' : 'INITIAL',
                        paidAt: now,
                        planSlug: plan.slug,
                        billingCycle: cycle,
                        notes: `Fully paid with credits (\u20B9${(amountPaise / 100).toFixed(2)})`,
                    },
                }),
            ]);

            // Update coaching storage limit
            await prisma.coaching.update({
                where: { id: coachingId },
                data: { storageLimit: plan.storageLimitBytes },
            });

            console.log(`[SubscriptionService] Activated ${planSlug}/${cycle} for coaching ${coachingId} — fully covered by credits`);

            const newBalance = await creditService.getBalancePaise(userId);

            return {
                subscriptionId: sub.id,
                shortUrl: '', // no payment link needed
                planName: plan.name,
                amount,
                cycle,
                creditAppliedRupees: amountPaise / 100,
                creditBalanceRupees: newBalance / 100,
                netAmount: 0,
                fullyPaidByCredits: true,
            };
        }

        // ── Partial or no credits — create Payment Link ──────────────
        const callbackUrl = `tutorix://subscription/payment-complete?coachingId=${coachingId}`;

        const paymentLink = await (razorpay as any).paymentLink.create({
            amount: netAmountPaise,
            currency: 'INR',
            accept_partial: false,
            description: `Tutorix ${plan.name} — ${cycle.toLowerCase()} subscription`,
            expire_by: Math.floor(Date.now() / 1000) + 86400, // 24-hour expiry
            reference_id: `${sub.id.replace(/-/g, '').slice(0, 24)}_${Date.now().toString(36)}`,
            notes: {
                coachingId,
                subscriptionId: sub.id,
                planSlug: plan.slug,
                cycle,
                creditAppliedPaise: creditAppliedPaise.toString(),
                originalAmountPaise: amountPaise.toString(),
            },
            callback_url: callbackUrl,
            callback_method: 'get',
        });

        const plinkId = paymentLink.id as string;
        const shortUrl = paymentLink.short_url as string;

        // Store payment link ID on the subscription for webhook lookup
        await prisma.subscription.update({
            where: { id: sub.id },
            data: { razorpaySubscriptionId: plinkId },
        });

        console.log(`[SubscriptionService] Payment link created: ${plinkId} for coaching ${coachingId} (credits: \u20B9${(creditAppliedPaise / 100).toFixed(2)})`);

        return {
            subscriptionId: plinkId,
            shortUrl,
            planName: plan.name,
            amount,
            cycle,
            creditAppliedRupees: creditAppliedPaise / 100,
            creditBalanceRupees: creditBalancePaise / 100,
            netAmount: netAmountPaise / 100,
            fullyPaidByCredits: false,
        };
    }

    /* ── OPTION A — Razorpay Subscriptions (requires Plans API activation) ────
     * Replace createSubscription above with this when Razorpay activates the
     * Subscriptions product on your account.
     *
     * async createSubscription_optionA(coachingId, planSlug, cycle, userId) {
     *   const razorpayPlanId = await this._getOrCreateRazorpayPlan(planSlug, cycle, amount);
     *   const rzpSub = await razorpay.subscriptions.create({ plan_id: razorpayPlanId, ... });
     *   // Activate immediately, store razorpaySubscriptionId = rzpSub.id
     * }
     * ─────────────────────────────────────────────────────────────────────────── */

    /**
     * Cancel subscription at period end.
     *
     * Option B — no Razorpay subscription to cancel; just mark in DB.
     * The coaching keeps the paid plan until currentPeriodEnd, then downgrades.
     */
    async cancelSubscription(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { ownerId: true },
        });
        if (!coaching) throw new Error('Coaching not found');
        if (coaching.ownerId !== userId) throw new Error('Only the owner can cancel');

        const sub = await prisma.subscription.findUnique({
            where: { coachingId },
            include: { plan: true },
        });
        if (!sub) throw new Error('No subscription found');
        if (sub.plan.slug === 'free') throw new Error('Cannot cancel a free plan');

        /* OPTION A — Razorpay Subscriptions (uncomment when Plans API is activated)
        if (sub.razorpaySubscriptionId && razorpay) {
            try {
                await razorpay.subscriptions.cancel(sub.razorpaySubscriptionId, false);
            } catch (e: any) {
                console.error('[SubscriptionService] Razorpay cancel error:', e.message);
            }
        }
        */

        const freePlan = await prisma.plan.findUnique({ where: { slug: 'free' } });
        if (!freePlan) throw new Error('Free plan not found');

        await prisma.subscription.update({
            where: { coachingId },
            data: {
                status: 'CANCELLED',
                cancelledAt: new Date(),
                scheduledPlanId: freePlan.id,
            },
        });

        return { message: 'Subscription will be cancelled at the end of the current billing period.' };
    }

    /** Switch to free plan immediately */
    async downgradeToFree(coachingId: string) {
        const freePlan = await prisma.plan.findUnique({ where: { slug: 'free' } });
        if (!freePlan) throw new Error('Free plan not found');

        await prisma.subscription.upsert({
            where: { coachingId },
            create: {
                coachingId,
                planId: freePlan.id,
                billingCycle: 'MONTHLY',
                status: 'ACTIVE',
                currentPeriodStart: new Date(),
                currentPeriodEnd: addYears(new Date(), 100),
            },
            update: {
                planId: freePlan.id,
                billingCycle: 'MONTHLY',
                status: 'ACTIVE',
                currentPeriodEnd: addYears(new Date(), 100),
                razorpaySubscriptionId: null,
                razorpayPlanId: null,
                cancelledAt: null,
                scheduledPlanId: null,
                scheduledCycle: null,
                gracePeriodEndsAt: null,
                pastDueAt: null,
                failedPaymentCount: 0,
            },
        });

        // Reset storage limit
        await prisma.coaching.update({
            where: { id: coachingId },
            data: { storageLimit: freePlan.storageLimitBytes },
        });
    }

    // ── Invoices ─────────────────────────────────────────────────────

    async getInvoices(coachingId: string) {
        const sub = await prisma.subscription.findUnique({ where: { coachingId } });
        if (!sub) return [];

        return prisma.subscriptionInvoice.findMany({
            where: { subscriptionId: sub.id },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });
    }

    // ── Webhook Handlers ─────────────────────────────────────────────

    /**
     * Handle payment_link.paid webhook event (Option B).
     *
     * Activates the paid plan and creates an invoice record.
     * If credits were applied at purchase time, redeems them now that payment is confirmed.
     * Called from the webhook router when Razorpay confirms payment.
     */
    async handlePaymentLinkPaid(paymentLinkEntity: any, paymentEntity: any) {
        const plinkId = paymentLinkEntity.id as string;
        const notes = paymentLinkEntity.notes ?? {};
        const coachingId = notes.coachingId as string;
        const planSlug = notes.planSlug as string;
        const cycle = (notes.cycle as 'MONTHLY' | 'YEARLY') ?? 'MONTHLY';
        const creditAppliedPaise = parseInt(notes.creditAppliedPaise || '0', 10);
        const originalAmountPaise = parseInt(notes.originalAmountPaise || '0', 10);

        if (!coachingId || !planSlug) {
            console.warn(`[SubscriptionService] payment_link.paid missing notes: ${plinkId}`);
            return;
        }

        // Look up subscription by coachingId (reliable even if plink ID was overwritten)
        const sub = await prisma.subscription.findUnique({
            where: { coachingId },
            include: { plan: true },
        });
        if (!sub) {
            console.warn(`[SubscriptionService] No subscription for coaching ${coachingId}`);
            return;
        }

        const plan = await prisma.plan.findUnique({ where: { slug: planSlug } });
        if (!plan) {
            console.warn(`[SubscriptionService] Plan not found: ${planSlug}`);
            return;
        }

        const razorpayPaymentId = paymentEntity?.id as string | undefined;
        const paidAmountPaise = (paymentEntity?.amount as number) ?? 0;
        // Full invoice amount = what was paid + credits applied
        const fullAmountPaise = originalAmountPaise || (paidAmountPaise + creditAppliedPaise);

        // Idempotency — don't process same payment twice
        if (razorpayPaymentId) {
            const existing = await prisma.subscriptionInvoice.findUnique({
                where: { razorpayPaymentId },
            });
            if (existing) return;
        }

        // ── Redeem credits if any were applied at purchase time ───────
        if (creditAppliedPaise > 0) {
            const coaching = await prisma.coaching.findUnique({
                where: { id: coachingId },
                select: { ownerId: true },
            });
            if (coaching) {
                const creditService = new CreditService();
                await creditService.redeemCredit(coaching.ownerId, creditAppliedPaise, sub.id);
                console.log(`[SubscriptionService] Redeemed \u20B9${(creditAppliedPaise / 100).toFixed(2)} credits for coaching ${coachingId}`);
            }
        }

        const now = new Date();
        const periodEnd = cycle === 'YEARLY' ? addYears(now, 1) : addMonths(now, 1);

        // Build invoice notes string
        const invoiceNotes: string[] = [`Payment Link: ${plinkId}`];
        if (creditAppliedPaise > 0) {
            invoiceNotes.push(`Credits Applied: \u20B9${(creditAppliedPaise / 100).toFixed(2)}`);
        }

        await prisma.$transaction([
            // Activate subscription on the paid plan
            prisma.subscription.update({
                where: { id: sub.id },
                data: {
                    planId: plan.id,
                    billingCycle: cycle,
                    status: 'ACTIVE',
                    currentPeriodStart: now,
                    currentPeriodEnd: periodEnd,
                    lastPaymentAt: now,
                    lastPaymentAmount: fullAmountPaise / 100,
                    failedPaymentCount: 0,
                    cancelledAt: null,
                    pausedAt: null,
                    gracePeriodEndsAt: null,
                    pastDueAt: null,
                    scheduledPlanId: null,
                    scheduledCycle: null,
                },
            }),
            // Create invoice record
            prisma.subscriptionInvoice.create({
                data: {
                    subscriptionId: sub.id,
                    razorpayPaymentId: razorpayPaymentId ?? `plink_${plinkId}_${Date.now()}`,
                    amountPaise: fullAmountPaise,
                    creditAppliedPaise,
                    totalPaise: paidAmountPaise,
                    status: 'PAID',
                    type: sub.lastPaymentAt ? 'RENEWAL' : 'INITIAL',
                    paidAt: now,
                    planSlug: plan.slug,
                    billingCycle: cycle,
                    notes: invoiceNotes.join(' | '),
                },
            }),
        ]);

        // Update coaching storage limit based on new plan
        await prisma.coaching.update({
            where: { id: coachingId },
            data: { storageLimit: plan.storageLimitBytes },
        });

        console.log(`[SubscriptionService] Activated ${planSlug}/${cycle} for coaching ${coachingId} via payment link ${plinkId}`);
    }

    /**
     * Verify a pending payment link by fetching its current status from Razorpay.
     *
     * Called by the frontend after the user returns from the payment browser.
     * If the payment link is paid, activates the subscription (same logic as webhook).
     *
     * Returns { status, activated } so the frontend knows the outcome.
     */
    async verifyPaymentLink(coachingId: string, userId: string): Promise<{ status: string; activated: boolean }> {
        if (!razorpay) throw new Error('Razorpay not configured');

        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { ownerId: true },
        });
        if (!coaching) throw new Error('Coaching not found');
        if (coaching.ownerId !== userId) throw new Error('Only the owner can verify');

        const sub = await prisma.subscription.findUnique({
            where: { coachingId },
            include: { plan: true },
        });
        if (!sub) throw new Error('No subscription found');

        // If already on a paid plan and active, no need to verify
        if (sub.status === 'ACTIVE' && sub.plan.slug !== 'free') {
            return { status: 'paid', activated: true };
        }

        const plinkId = sub.razorpaySubscriptionId;
        if (!plinkId || !plinkId.startsWith('plink_')) {
            return { status: 'no_pending_payment', activated: false };
        }

        // Fetch payment link from Razorpay
        const plink = await (razorpay as any).paymentLink.fetch(plinkId);
        const plinkStatus = plink.status as string; // created | paid | expired | cancelled

        console.log(`[SubscriptionService] Payment link ${plinkId} status: ${plinkStatus}`);

        if (plinkStatus === 'paid') {
            // Check if already processed (idempotency)
            const alreadyInvoiced = await prisma.subscriptionInvoice.findFirst({
                where: { notes: { contains: plinkId } },
            });
            if (!alreadyInvoiced) {
                // Extract details from notes and activate
                const payments = plink.payments ?? [];
                const lastPayment = payments[payments.length - 1] ?? {};
                await this.handlePaymentLinkPaid(plink, lastPayment);
            }
            return { status: 'paid', activated: true };
        }

        return { status: plinkStatus, activated: false };
    }

    /* ── OPTION A — Razorpay Subscription Webhook Handlers ─────────────────────
     * Uncomment these when switching to Razorpay Subscriptions API.
     *
     * handlePaymentSuccess(razorpaySubscriptionId, razorpayPaymentId, amountPaise)
     *   → Handles subscription.charged — renews period, creates PAID invoice.
     *
     * handlePaymentFailed(razorpaySubscriptionId, razorpayPaymentId, amountPaise)
     *   → Handles subscription.payment_failed — sets PAST_DUE + grace period.
     *
     * handleSubscriptionCancelled(razorpaySubscriptionId)
     *   → Handles subscription.cancelled/expired — downgrades to free.
     *
     * _getOrCreateRazorpayPlan(planSlug, cycle, amount)
     *   → Creates/caches Razorpay Plans via razorpay.plans.create().
     * ───────────────────────────────────────────────────────────────────────── */
}
