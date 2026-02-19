import { type Request, type Response } from 'express';
import { PaymentService } from './payment.service.js';

const svc = new PaymentService();

export class PaymentController {

    /** POST /coaching/:coachingId/fee/records/:recordId/create-order */
    async createOrder(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = (req as any).user?.id;
            const data = await svc.createOrder(coachingId, recordId, userId, req.body);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** POST /coaching/:coachingId/fee/records/:recordId/verify-payment */
    async verifyPayment(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = (req as any).user?.id;
            const data = await svc.verifyPayment(coachingId, recordId, req.body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** POST /coaching/:coachingId/fee/records/:recordId/online-refund */
    async initiateOnlineRefund(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = (req as any).user?.id;
            const data = await svc.initiateOnlineRefund(coachingId, recordId, req.body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** GET /coaching/:coachingId/fee/records/:recordId/online-payments */
    async getOnlinePayments(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const data = await svc.getOnlinePayments(coachingId, recordId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** GET /payment/config */
    async getConfig(req: Request, res: Response) {
        try {
            const data = svc.getConfig();
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** PATCH /coaching/:coachingId/payment-settings */
    async updatePaymentSettings(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = (req as any).user?.id;
            const data = await svc.updatePaymentSettings(coachingId, userId, req.body);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** GET /coaching/:coachingId/payment-settings */
    async getPaymentSettings(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const data = await svc.getPaymentSettings(coachingId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }
}
