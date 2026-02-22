import prisma from '../../infra/prisma.js';

// ─── Credit Service ──────────────────────────────────────────────────
// Manages credit balances issued when a coaching is deleted mid-subscription.
// Credits = 50% of the remaining subscription value (in paise).
// Can only be redeemed against new subscriptions, never cashed out.

export class CreditService {

    // ── Balance ──────────────────────────────────────────────────────

    /** Get or create the user's credit balance. */
    async getBalance(userId: string) {
        let balance = await prisma.creditBalance.findUnique({
            where: { userId },
            include: {
                transactions: {
                    orderBy: { createdAt: 'desc' },
                    take: 20,
                },
            },
        });

        if (!balance) {
            balance = await prisma.creditBalance.create({
                data: { userId },
                include: {
                    transactions: {
                        orderBy: { createdAt: 'desc' },
                        take: 20,
                    },
                },
            });
        }

        return balance;
    }

    /** Get just the numeric balance in paise. */
    async getBalancePaise(userId: string): Promise<number> {
        const bal = await prisma.creditBalance.findUnique({
            where: { userId },
            select: { balancePaise: true },
        });
        return bal?.balancePaise ?? 0;
    }

    // ── Issue Credit ─────────────────────────────────────────────────

    /**
     * Calculate and issue credit when a coaching is deleted mid-subscription.
     * Credit = 50% of the pro-rated remaining value.
     */
    async issueDeleteCredit(userId: string, coachingId: string, coachingName: string) {
        // Find the coaching's subscription
        const sub = await prisma.subscription.findUnique({
            where: { coachingId },
            include: { plan: true },
        });

        if (!sub || !sub.plan || sub.plan.slug === 'free') {
            return { creditIssuedPaise: 0, message: 'No paid subscription — no credit issued.' };
        }

        // Calculate remaining value
        const now = new Date();
        const periodStart = sub.currentPeriodStart;
        const periodEnd = sub.currentPeriodEnd;
        const totalPeriodMs = periodEnd.getTime() - periodStart.getTime();
        const elapsedMs = Math.max(0, now.getTime() - periodStart.getTime());
        const remainingFraction = Math.max(0, 1 - (elapsedMs / totalPeriodMs));

        // Determine the full period cost in paise
        const periodCostRupees = sub.billingCycle === 'YEARLY'
            ? sub.plan.priceYearly
            : sub.plan.priceMonthly;
        const periodCostPaise = Math.round(periodCostRupees * 100);

        // Pro-rated remaining × 50%
        const remainingPaise = Math.round(periodCostPaise * remainingFraction);
        const creditPaise = Math.round(remainingPaise * 0.5);

        if (creditPaise <= 0) {
            return { creditIssuedPaise: 0, message: 'Subscription period nearly ended — no credit issued.' };
        }

        // Issue the credit in a transaction
        await prisma.$transaction(async (tx) => {
            // Upsert balance
            const balance = await tx.creditBalance.upsert({
                where: { userId },
                create: { userId, balancePaise: creditPaise },
                update: { balancePaise: { increment: creditPaise } },
            });

            // Record transaction
            await tx.creditTransaction.create({
                data: {
                    creditBalanceId: balance.id,
                    type: 'CREDIT',
                    amountPaise: creditPaise,
                    description: `50% credit from deleting "${coachingName}" (${sub.billingCycle.toLowerCase()} ${sub.plan!.name} plan)`,
                    coachingId,
                },
            });
        });

        return {
            creditIssuedPaise: creditPaise,
            creditIssuedRupees: (creditPaise / 100).toFixed(2),
            message: `₹${(creditPaise / 100).toFixed(0)} credit issued to your account.`,
        };
    }

    // ── Redeem Credit ────────────────────────────────────────────────

    /**
     * Redeem credits against a new subscription purchase.
     * Returns the amount actually redeemed (may be less than requested if balance is lower).
     */
    async redeemCredit(userId: string, amountPaise: number, subscriptionId: string): Promise<number> {
        if (amountPaise <= 0) return 0;

        const balance = await this.getBalance(userId);
        const redeemable = Math.min(amountPaise, balance.balancePaise);

        if (redeemable <= 0) return 0;

        await prisma.$transaction(async (tx) => {
            await tx.creditBalance.update({
                where: { userId },
                data: { balancePaise: { decrement: redeemable } },
            });

            await tx.creditTransaction.create({
                data: {
                    creditBalanceId: balance.id,
                    type: 'DEBIT',
                    amountPaise: redeemable,
                    description: `Redeemed against new subscription`,
                    subscriptionId,
                },
            });
        });

        return redeemable;
    }
}
