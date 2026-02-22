/**
 * Razorpay webhook handler for subscription billing events.
 *
 * Mounted alongside the existing payment webhook under /webhooks/subscription
 * with express.raw() body parsing for signature verification.
 */
import { Router } from 'express';
import type { Request, Response } from 'express';
import crypto from 'crypto';
import { SubscriptionService } from './subscription.service.js';

const router = Router();
const subscriptionService = new SubscriptionService();

const WEBHOOK_SECRET = process.env.RAZORPAY_SUBSCRIPTION_WEBHOOK_SECRET || process.env.RAZORPAY_WEBHOOK_SECRET || '';

function verifySignature(body: Buffer, signature: string): boolean {
    if (!WEBHOOK_SECRET) return false;
    const expected = crypto
        .createHmac('sha256', WEBHOOK_SECRET)
        .update(body)
        .digest('hex');
    return crypto.timingSafeEqual(
        Buffer.from(expected, 'hex'),
        Buffer.from(signature, 'hex'),
    );
}

router.post('/', async (req: Request, res: Response) => {
    try {
        const signature = req.headers['x-razorpay-signature'] as string;
        const body = req.body as Buffer;

        if (!signature || !body) {
            return res.status(400).json({ message: 'Missing signature or body' });
        }

        if (!verifySignature(body, signature)) {
            console.warn('[SubscriptionWebhook] Signature verification failed');
            return res.status(401).json({ message: 'Invalid signature' });
        }

        const payload = JSON.parse(body.toString());
        const event = payload.event as string;

        console.log(`[SubscriptionWebhook] Received event: ${event}`);

        switch (event) {
            case 'subscription.charged': {
                const subEntity = payload.payload?.subscription?.entity;
                const paymentEntity = payload.payload?.payment?.entity;
                if (subEntity?.id && paymentEntity?.id) {
                    await subscriptionService.handlePaymentSuccess(
                        subEntity.id,
                        paymentEntity.id,
                        paymentEntity.amount ?? 0,
                    );
                }
                break;
            }

            case 'subscription.payment_failed': {
                const subEntity = payload.payload?.subscription?.entity;
                const paymentEntity = payload.payload?.payment?.entity;
                if (subEntity?.id) {
                    await subscriptionService.handlePaymentFailed(
                        subEntity.id,
                        paymentEntity?.id ?? `failed_${Date.now()}`,
                        paymentEntity?.amount ?? 0,
                    );
                }
                break;
            }

            case 'subscription.cancelled':
            case 'subscription.expired': {
                const subEntity = payload.payload?.subscription?.entity;
                if (subEntity?.id) {
                    await subscriptionService.handleSubscriptionCancelled(subEntity.id);
                }
                break;
            }

            case 'subscription.paused': {
                // Future: handle pause
                console.log('[SubscriptionWebhook] Subscription paused — no action taken');
                break;
            }

            case 'subscription.resumed': {
                // Future: handle resume
                console.log('[SubscriptionWebhook] Subscription resumed — no action taken');
                break;
            }

            default:
                console.log(`[SubscriptionWebhook] Unhandled event: ${event}`);
        }

        // Always return 200 to Razorpay to acknowledge receipt
        res.json({ status: 'ok' });
    } catch (error: any) {
        console.error('[SubscriptionWebhook] Error:', error.message);
        // Still return 200 to prevent Razorpay retries on our bugs
        res.json({ status: 'ok' });
    }
});

export { router as subscriptionWebhookRouter };
