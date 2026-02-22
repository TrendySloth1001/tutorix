/**
 * Razorpay webhook handler for subscription billing events.
 *
 * Option B — handles `payment_link.paid` from Payment Links API.
 * Option A subscription.* events are commented out until Plans API is activated.
 *
 * Mounted under /webhooks/subscription with express.raw() body parsing
 * for signature verification.
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
            // ── Option B: Payment Links ────────────────────────────────
            case 'payment_link.paid': {
                const plinkEntity = payload.payload?.payment_link?.entity;
                const paymentEntity = payload.payload?.payment?.entity;
                if (plinkEntity?.id) {
                    await subscriptionService.handlePaymentLinkPaid(
                        plinkEntity,
                        paymentEntity,
                    );
                }
                break;
            }

            /* ── Option A: Razorpay Subscriptions (uncomment when activated) ──
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

            case 'subscription.paused':
            case 'subscription.resumed': {
                console.log(`[SubscriptionWebhook] ${event} — no action taken`);
                break;
            }
            ── End Option A ──────────────────────────────────────────── */

            default:
                console.log(`[SubscriptionWebhook] Unhandled event: ${event}`);
        }

        // Always return 200 to Razorpay to acknowledge receipt
        res.json({ status: 'ok' });
    } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error('[SubscriptionWebhook] Error:', msg);
        // Still return 200 to prevent Razorpay retries on our bugs
        res.json({ status: 'ok' });
    }
});

export { router as subscriptionWebhookRouter };
