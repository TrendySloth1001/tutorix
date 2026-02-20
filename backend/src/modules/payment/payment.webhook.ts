import { type Request, type Response, Router } from 'express';
import crypto from 'crypto';
import prisma from '../../infra/prisma.js';
import { PaymentService } from './payment.service.js';

const paymentSvc = new PaymentService();

/**
 * Razorpay Webhook Handler.
 *
 * MUST be mounted with raw body parser (not JSON) for signature verification.
 * Mount BEFORE express.json() in the main app, or use express.raw() on this route.
 */
export const webhookRouter = Router();

webhookRouter.post('/razorpay', async (req: Request, res: Response) => {
    try {
        const signature = req.headers['x-razorpay-signature'] as string;
        const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

        if (!signature || !webhookSecret) {
            return res.status(400).json({ error: 'Missing signature or webhook secret' });
        }

        // Get raw body for signature verification
        const rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);

        // Verify HMAC SHA256 signature
        const expectedSignature = crypto
            .createHmac('sha256', webhookSecret)
            .update(rawBody)
            .digest('hex');

        const verified = crypto.timingSafeEqual(
            Buffer.from(expectedSignature, 'hex'),
            Buffer.from(signature, 'hex'),
        );

        if (!verified) {
            console.error('[Webhook] Signature verification failed');
            return res.status(400).json({ error: 'Invalid signature' });
        }

        const payload = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
        const event = payload?.event as string;
        const paymentEntity = payload?.payload?.payment?.entity;
        const orderEntity = payload?.payload?.order?.entity;
        const refundEntity = payload?.payload?.refund?.entity;

        const orderId = paymentEntity?.order_id || orderEntity?.id;
        const paymentId = paymentEntity?.id;
        const refundId = refundEntity?.id;

        // Determine coachingId from the order's notes
        let coachingId: string | undefined;
        if (orderId) {
            const order = await prisma.razorpayOrder.findUnique({
                where: { razorpayOrderId: orderId },
                select: { coachingId: true },
            });
            coachingId = order?.coachingId ?? undefined;
        }

        // Log the webhook event
        await prisma.razorpayWebhookLog.create({
            data: {
                coachingId: coachingId ?? null,
                event,
                orderId,
                paymentId,
                refundId,
                payload: payload as any,
                signature,
                verified: true,
            },
        });

        // Process the event
        switch (event) {
            case 'payment.captured':
            case 'order.paid': {
                if (!orderId || !paymentId) break;
                // Multi-pay: multiple RazorpayOrder rows may share the same razorpayOrderId
                const orders = await prisma.razorpayOrder.findMany({
                    where: { razorpayOrderId: orderId },
                });
                for (const order of orders) {
                    if (order.paymentRecorded) continue;
                    try {
                        await paymentSvc._processPayment(order.id, paymentId, signature);
                        await prisma.razorpayOrder.update({
                            where: { id: order.id },
                            data: { webhookReceived: true, webhookReceivedAt: new Date() },
                        });
                    } catch (err: any) {
                        console.error(`[Webhook] Error processing ${event} for order ${order.id}:`, err.message);
                        await prisma.razorpayWebhookLog.updateMany({
                            where: { orderId, event, processed: false },
                            data: { error: err.message },
                        });
                    }
                }
                // Mark webhook log as processed
                await prisma.razorpayWebhookLog.updateMany({
                    where: { orderId, event, processed: false },
                    data: { processed: true },
                });
                break;
            }

            case 'payment.failed': {
                if (!orderId) break;
                const failureReason = paymentEntity?.error_description ?? paymentEntity?.error_reason ?? null;
                await prisma.razorpayOrder.updateMany({
                    where: { razorpayOrderId: orderId, status: 'CREATED' },
                    data: {
                        status: 'FAILED',
                        failureReason,
                        failedAt: new Date(),
                        webhookReceived: true,
                        webhookReceivedAt: new Date(),
                    },
                });
                await prisma.razorpayWebhookLog.updateMany({
                    where: { orderId, event, processed: false },
                    data: { processed: true },
                });
                break;
            }

            case 'refund.created':
            case 'refund.processed': {
                if (!refundId) break;
                // Update our RazorpayRefund status if we have it
                const rzpRefund = await prisma.razorpayRefund.findFirst({
                    where: { razorpayRefundId: refundId },
                });
                if (rzpRefund) {
                    await prisma.razorpayRefund.update({
                        where: { id: rzpRefund.id },
                        data: { status: 'PROCESSED' },
                    });
                }
                await prisma.razorpayWebhookLog.updateMany({
                    where: { refundId, event, processed: false },
                    data: { processed: true },
                });
                break;
            }

            case 'refund.failed': {
                if (!refundId) break;
                const rzpRefund = await prisma.razorpayRefund.findFirst({
                    where: { razorpayRefundId: refundId },
                });
                if (rzpRefund) {
                    await prisma.razorpayRefund.update({
                        where: { id: rzpRefund.id },
                        data: { status: 'FAILED' },
                    });
                }
                await prisma.razorpayWebhookLog.updateMany({
                    where: { refundId, event, processed: false },
                    data: { processed: true },
                });
                break;
            }

            default:
                // Unknown event — log but don't fail
                console.log(`[Webhook] Unhandled event: ${event}`);
        }

        // Always return 200 to Razorpay (they retry on non-2xx)
        res.status(200).json({ received: true });
    } catch (err: any) {
        console.error('[Webhook] Unhandled error:', err);
        // Still return 200 to prevent Razorpay retries on our bugs
        res.status(200).json({ received: true });
    }
});
