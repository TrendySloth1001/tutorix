import { type Request, type Response } from 'express';
import { PaymentService } from './payment.service.js';
import {
    createOrderSchema, verifyPaymentSchema, initiateRefundSchema,
    multiPayCreateOrderSchema, failOrderSchema, paymentSettingsSchema,
    createLinkedAccountSchema,
    validateBody,
} from '../../shared/validation/fee.validation.js';

const svc = new PaymentService();

/** Require user.id from auth middleware, throw 401 if missing */
function requireUserId(req: Request): string {
    const userId = (req as any).user?.id;
    if (!userId) throw Object.assign(new Error('Authentication required'), { status: 401 });
    return userId;
}

export class PaymentController {

    /** POST /coaching/:coachingId/fee/records/:recordId/create-order */
    async createOrder(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = requireUserId(req);
            const body = validateBody(createOrderSchema, req.body);
            const data = await svc.createOrder(coachingId, recordId, userId, body);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** POST /coaching/:coachingId/fee/records/:recordId/verify-payment */
    async verifyPayment(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = requireUserId(req);
            const body = validateBody(verifyPaymentSchema, req.body);
            const data = await svc.verifyPayment(coachingId, recordId, body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** POST /coaching/:coachingId/fee/records/:recordId/online-refund */
    async initiateOnlineRefund(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = requireUserId(req);
            const body = validateBody(initiateRefundSchema, req.body);
            const data = await svc.initiateOnlineRefund(coachingId, recordId, body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
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
            const userId = requireUserId(req);
            const body = validateBody(paymentSettingsSchema, req.body);
            const data = await svc.updatePaymentSettings(coachingId, userId, body);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** POST /coaching/:coachingId/fee/multi-pay/create-order */
    async createMultiOrder(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const body = validateBody(multiPayCreateOrderSchema, req.body);
            const data = await svc.createMultiOrder(coachingId, userId, body);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** POST /coaching/:coachingId/fee/multi-pay/verify */
    async verifyMultiPayment(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const body = validateBody(verifyPaymentSchema, req.body);
            const data = await svc.verifyMultiPayment(coachingId, body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** GET /coaching/:coachingId/payment-settings */
    async getPaymentSettings(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const data = await svc.getPaymentSettings(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** POST /coaching/:coachingId/fee/orders/:internalOrderId/fail */
    async failOrder(req: Request, res: Response) {
        try {
            const { coachingId, internalOrderId } = req.params as { coachingId: string; internalOrderId: string };
            const userId = requireUserId(req);
            const body = validateBody(failOrderSchema, req.body);
            await svc.markOrderFailed(coachingId, internalOrderId, body.reason ?? 'User cancelled', userId);
            res.json({ ok: true });
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** GET /coaching/:coachingId/fee/records/:recordId/failed-orders */
    async getFailedOrders(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const data = await svc.getFailedOrders(coachingId, recordId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    // ── Razorpay Route Linked Account Management ──────────────────

    /** POST /coaching/:coachingId/payment-settings/linked-account */
    async createLinkedAccount(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const body = validateBody(createLinkedAccountSchema, req.body);
            const data = await svc.createLinkedAccount(coachingId, userId, body);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, fieldErrors: e.fieldErrors });
        }
    }

    /** POST /coaching/:coachingId/payment-settings/linked-account/refresh */
    async refreshLinkedAccountStatus(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const data = await svc.refreshLinkedAccountStatus(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** DELETE /coaching/:coachingId/payment-settings/linked-account */
    async deleteLinkedAccount(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const data = await svc.deleteLinkedAccount(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    /** POST /coaching/:coachingId/payment-settings/verify-bank */
    async verifyBankAccount(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const data = await svc.verifyBankAccount(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }
}