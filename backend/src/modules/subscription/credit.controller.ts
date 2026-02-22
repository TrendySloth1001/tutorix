import type { Request, Response } from 'express';
import { CreditService } from './credit.service.js';

const creditService = new CreditService();

export class CreditController {

    // GET /subscription/credits — Get the user's credit balance + recent transactions
    async getBalance(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id as string;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const balance = await creditService.getBalance(userId);

            res.json({
                balancePaise: balance.balancePaise,
                balanceRupees: (balance.balancePaise / 100).toFixed(2),
                transactions: balance.transactions.map((t: any) => ({
                    id: t.id,
                    type: t.type,
                    amountPaise: t.amountPaise,
                    amountRupees: (t.amountPaise / 100).toFixed(2),
                    description: t.description,
                    coachingId: t.coachingId,
                    subscriptionId: t.subscriptionId,
                    createdAt: t.createdAt,
                })),
            });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }
}
