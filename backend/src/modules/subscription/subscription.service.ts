import prisma from '../../infra/prisma.js';
import Razorpay from 'razorpay';

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

    /** Create a Razorpay subscription for a paid plan. Returns checkout URL. */
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
        const period = cycle === 'YEARLY' ? 'yearly' : 'monthly';
        const interval = cycle === 'YEARLY' ? 12 : 1; // Razorpay uses monthly intervals

        // Create or find Razorpay plan
        const razorpayPlanId = await this._getOrCreateRazorpayPlan(plan.slug, cycle, amount);

        // Create Razorpay subscription
        const rzpSub = await razorpay.subscriptions.create({
            plan_id: razorpayPlanId,
            total_count: cycle === 'YEARLY' ? 10 : 120, // 10 years or 120 months max
            quantity: 1,
            notes: {
                coachingId,
                planSlug: plan.slug,
                cycle,
            },
        } as any);

        // Get subscription end date
        const now = new Date();
        const periodEnd = cycle === 'YEARLY' ? addYears(now, 1) : addMonths(now, 1);

        // Update/create subscription record
        const existingSub = await prisma.subscription.findUnique({ where: { coachingId } });

        if (existingSub) {
            await prisma.subscription.update({
                where: { coachingId },
                data: {
                    planId: plan.id,
                    billingCycle: cycle,
                    status: 'ACTIVE',
                    currentPeriodStart: now,
                    currentPeriodEnd: periodEnd,
                    razorpaySubscriptionId: (rzpSub as any).id,
                    razorpayPlanId: razorpayPlanId,
                    cancelledAt: null,
                    pausedAt: null,
                    gracePeriodEndsAt: null,
                    pastDueAt: null,
                    failedPaymentCount: 0,
                },
            });
        } else {
            await prisma.subscription.create({
                data: {
                    coachingId,
                    planId: plan.id,
                    billingCycle: cycle,
                    status: 'ACTIVE',
                    currentPeriodStart: now,
                    currentPeriodEnd: periodEnd,
                    razorpaySubscriptionId: (rzpSub as any).id,
                    razorpayPlanId: razorpayPlanId,
                },
            });
        }

        // Update coaching storage limit based on plan
        await prisma.coaching.update({
            where: { id: coachingId },
            data: { storageLimit: plan.storageLimitBytes },
        });

        return {
            subscriptionId: (rzpSub as any).id,
            shortUrl: (rzpSub as any).short_url,
            planName: plan.name,
            amount,
            cycle,
        };
    }

    /** Cancel subscription at period end */
    async cancelSubscription(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { ownerId: true },
        });
        if (!coaching) throw new Error('Coaching not found');
        if (coaching.ownerId !== userId) throw new Error('Only the owner can cancel');

        const sub = await prisma.subscription.findUnique({ where: { coachingId } });
        if (!sub) throw new Error('No subscription found');
        if (sub.razorpaySubscriptionId) {
            // Cancel on Razorpay
            if (razorpay) {
                try {
                    await razorpay.subscriptions.cancel(sub.razorpaySubscriptionId, false); // cancel_at_cycle_end
                } catch (e: any) {
                    console.error('[SubscriptionService] Razorpay cancel error:', e.message);
                }
            }
        }

        // Downgrade to free on Razorpay cancel
        const freePlan = await prisma.plan.findUnique({ where: { slug: 'free' } });
        if (!freePlan) throw new Error('Free plan not found');

        await prisma.subscription.update({
            where: { coachingId },
            data: {
                status: 'CANCELLED',
                cancelledAt: new Date(),
                // Schedule downgrade to free at period end
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

    /** Handle Razorpay subscription.charged event */
    async handlePaymentSuccess(razorpaySubscriptionId: string, razorpayPaymentId: string, amountPaise: number) {
        const sub = await prisma.subscription.findUnique({
            where: { razorpaySubscriptionId },
            include: { plan: true },
        });
        if (!sub) {
            console.warn(`[SubscriptionService] No subscription found for ${razorpaySubscriptionId}`);
            return;
        }

        const now = new Date();
        const periodEnd = sub.billingCycle === 'YEARLY'
            ? addYears(now, 1)
            : addMonths(now, 1);

        // Idempotency check — don't process same payment twice
        const existing = await prisma.subscriptionInvoice.findUnique({
            where: { razorpayPaymentId },
        });
        if (existing) return;

        await prisma.$transaction([
            // Update subscription
            prisma.subscription.update({
                where: { id: sub.id },
                data: {
                    status: 'ACTIVE',
                    currentPeriodStart: now,
                    currentPeriodEnd: periodEnd,
                    lastPaymentAt: now,
                    lastPaymentAmount: amountPaise / 100,
                    failedPaymentCount: 0,
                    gracePeriodEndsAt: null,
                    pastDueAt: null,
                    // Apply scheduled plan change if any
                    ...(sub.scheduledPlanId ? {
                        planId: sub.scheduledPlanId,
                        billingCycle: sub.scheduledCycle ?? sub.billingCycle,
                        scheduledPlanId: null,
                        scheduledCycle: null,
                    } : {}),
                },
            }),
            // Create invoice
            prisma.subscriptionInvoice.create({
                data: {
                    subscriptionId: sub.id,
                    razorpayPaymentId,
                    amountPaise,
                    totalPaise: amountPaise,
                    status: 'PAID',
                    type: sub.lastPaymentAt ? 'RENEWAL' : 'INITIAL',
                    paidAt: now,
                    planSlug: sub.plan.slug,
                    billingCycle: sub.billingCycle,
                },
            }),
        ]);
    }

    /** Handle Razorpay subscription.payment_failed */
    async handlePaymentFailed(razorpaySubscriptionId: string, razorpayPaymentId: string, amountPaise: number) {
        const sub = await prisma.subscription.findUnique({
            where: { razorpaySubscriptionId },
        });
        if (!sub) return;

        const now = new Date();
        const gracePeriodDays = 3;

        await prisma.$transaction([
            prisma.subscription.update({
                where: { id: sub.id },
                data: {
                    status: 'PAST_DUE',
                    pastDueAt: sub.pastDueAt ?? now,
                    gracePeriodEndsAt: sub.gracePeriodEndsAt ?? new Date(now.getTime() + gracePeriodDays * 86400000),
                    failedPaymentCount: { increment: 1 },
                },
            }),
            prisma.subscriptionInvoice.create({
                data: {
                    subscriptionId: sub.id,
                    razorpayPaymentId,
                    amountPaise,
                    totalPaise: amountPaise,
                    status: 'FAILED',
                    type: 'RENEWAL',
                    failedAt: now,
                    planSlug: sub.scheduledPlanId ?? null,
                    billingCycle: sub.billingCycle,
                },
            }),
        ]);
    }

    /** Handle Razorpay subscription.cancelled */
    async handleSubscriptionCancelled(razorpaySubscriptionId: string) {
        const sub = await prisma.subscription.findUnique({
            where: { razorpaySubscriptionId },
        });
        if (!sub) return;

        // Downgrade to free
        await this.downgradeToFree(sub.coachingId);
    }

    // ── Internal Helpers ─────────────────────────────────────────────

    /** Cache Razorpay plan IDs in memory to avoid re-creating */
    private _razorpayPlanCache = new Map<string, string>();

    private async _getOrCreateRazorpayPlan(planSlug: string, cycle: 'MONTHLY' | 'YEARLY', amount: number): Promise<string> {
        if (!razorpay) throw new Error('Razorpay not configured');

        const cacheKey = `${planSlug}_${cycle}`;
        const cached = this._razorpayPlanCache.get(cacheKey);
        if (cached) return cached;

        // Check if we already have a subscription with this plan in DB
        const existingSub = await prisma.subscription.findFirst({
            where: {
                razorpayPlanId: { not: null },
                plan: { slug: planSlug },
                billingCycle: cycle,
            },
            select: { razorpayPlanId: true },
        });
        if (existingSub?.razorpayPlanId) {
            this._razorpayPlanCache.set(cacheKey, existingSub.razorpayPlanId);
            return existingSub.razorpayPlanId;
        }

        // Create Razorpay plan
        const rzpPlan = await razorpay.plans.create({
            period: 'monthly',
            interval: cycle === 'YEARLY' ? 12 : 1,
            item: {
                name: `Tutorix ${planSlug.charAt(0).toUpperCase() + planSlug.slice(1)} (${cycle.toLowerCase()})`,
                amount: toPaise(amount),
                currency: 'INR',
                description: `Tutorix ${planSlug} plan — ${cycle.toLowerCase()} billing`,
            },
        } as any);

        const planId = (rzpPlan as any).id;
        this._razorpayPlanCache.set(cacheKey, planId);
        return planId;
    }
}
