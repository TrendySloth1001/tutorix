import type { Request, Response } from 'express';
import { SubscriptionService } from './subscription.service.js';

const subscriptionService = new SubscriptionService();

/** Safely extract a human-readable message from any thrown value. */
function errorMsg(error: unknown): string {
    if (error instanceof Error) return error.message;
    if (typeof error === 'object' && error !== null) {
        const e = error as any;
        // Razorpay SDK errors: { error: { code, description, ... } }
        if (e.error?.description) return e.error.description;
        if (e.message) return String(e.message);
        if (e.statusMessage) return String(e.statusMessage);
    }
    if (typeof error === 'string') return error;
    return 'An unexpected error occurred';
}

export class SubscriptionController {

    // GET /subscription/plans — List all available plans
    async listPlans(_req: Request, res: Response) {
        try {
            const plans = await subscriptionService.listPlans();
            res.json({ plans });
        } catch (error: unknown) {
            res.status(500).json({ message: errorMsg(error) });
        }
    }

    // GET /coaching/:coachingId/subscription — Get current subscription + usage
    async getSubscription(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const coaching = await this._verifyAccess(coachingId, userId);
            if (!coaching) return res.status(403).json({ message: 'Not a member of this coaching' });

            const subscription = await subscriptionService.getOrCreateSubscription(coachingId);
            const usage = await subscriptionService.getUsage(coachingId);

            res.json({ subscription, usage });
        } catch (error: unknown) {
            res.status(500).json({ message: errorMsg(error) });
        }
    }

    // GET /coaching/:coachingId/subscription/usage — Get usage only
    async getUsage(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const coaching = await this._verifyAccess(coachingId, userId);
            if (!coaching) return res.status(403).json({ message: 'Not a member' });

            const usage = await subscriptionService.getUsage(coachingId);
            res.json({ usage });
        } catch (error: unknown) {
            res.status(500).json({ message: errorMsg(error) });
        }
    }

    // POST /coaching/:coachingId/subscription/subscribe — Start a paid subscription
    async subscribe(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const { planSlug, cycle } = req.body;

            if (!planSlug || !cycle) {
                return res.status(400).json({ message: 'planSlug and cycle are required' });
            }

            if (!['MONTHLY', 'YEARLY'].includes(cycle)) {
                return res.status(400).json({ message: 'cycle must be MONTHLY or YEARLY' });
            }

            const validSlugs = ['basic', 'standard', 'premium'];
            if (!validSlugs.includes(planSlug)) {
                return res.status(400).json({ message: 'Invalid plan. Choose basic, standard, or premium.' });
            }

            const result = await subscriptionService.createSubscription(coachingId, planSlug, cycle, userId);
            res.json(result);
        } catch (error: unknown) {
            const msg = errorMsg(error);
            if (msg.includes('Only the coaching owner')) {
                return res.status(403).json({ message: msg });
            }
            console.error('[SubscriptionController] subscribe error:', error);
            res.status(500).json({ message: msg });
        }
    }

    // POST /coaching/:coachingId/subscription/cancel — Cancel at period end
    async cancel(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const result = await subscriptionService.cancelSubscription(coachingId, userId);
            res.json(result);
        } catch (error: unknown) {
            const msg = errorMsg(error);
            if (msg.includes('Only the owner')) {
                return res.status(403).json({ message: msg });
            }
            res.status(500).json({ message: msg });
        }
    }

    // GET /coaching/:coachingId/subscription/invoices — List billing invoices
    async getInvoices(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const coaching = await this._verifyAccess(coachingId, userId);
            if (!coaching) return res.status(403).json({ message: 'Not a member' });

            const invoices = await subscriptionService.getInvoices(coachingId);
            res.json({ invoices });
        } catch (error: unknown) {
            res.status(500).json({ message: errorMsg(error) });
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────

    private async _verifyAccess(coachingId: string, userId: string) {
        const { PrismaClient } = await import('@prisma/client');
        const prisma = (await import('../../infra/prisma.js')).default;

        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { ownerId: true },
        });
        if (!coaching) return null;

        // Owner always has access
        if (coaching.ownerId === userId) return coaching;

        // Check membership
        const member = await prisma.coachingMember.findFirst({
            where: { coachingId, userId, status: 'active' },
        });
        return member ? coaching : null;
    }
}
