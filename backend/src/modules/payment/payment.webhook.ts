import { type Request, type Response, Router } from 'express';
import crypto from 'crypto';
import prisma from '../../infra/prisma.js';
import { PaymentService } from './payment.service.js';
import { NotificationService } from '../notification/notification.service.js';

const paymentSvc = new PaymentService();
const notifSvc = new NotificationService();

/**
 * Razorpay Webhook Handler.
 *
 * MUST be mounted with express.raw({ type: 'application/json' }) body parser
 * for correct signature verification. Mount BEFORE express.json() in the main app.
 */
export const webhookRouter = Router();

webhookRouter.post('/razorpay', async (req: Request, res: Response) => {
    try {
        const signature = req.headers['x-razorpay-signature'] as string;
        const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

        if (!signature || !webhookSecret) {
            return res.status(400).json({ error: 'Missing signature or webhook secret' });
        }

        // C5 fix: Require raw Buffer body for accurate signature verification.
        // If body is not a Buffer, the JSON parser ran first — signature will be wrong.
        let rawBody: string;
        if (Buffer.isBuffer(req.body)) {
            rawBody = req.body.toString('utf8');
        } else if (typeof req.body === 'string') {
            rawBody = req.body;
        } else {
            console.error('[Webhook] Body is not a raw Buffer — express.raw() middleware may be missing');
            return res.status(400).json({ error: 'Webhook requires raw body' });
        }

        // Verify HMAC SHA256 signature (already timing-safe)
        const expectedSignature = crypto
            .createHmac('sha256', webhookSecret)
            .update(rawBody)
            .digest('hex');

        // Guard: both must be valid hex of same length
        let sigBuf: Buffer, expectedBuf: Buffer;
        try {
            sigBuf = Buffer.from(signature, 'hex');
            expectedBuf = Buffer.from(expectedSignature, 'hex');
        } catch {
            return res.status(400).json({ error: 'Invalid signature format' });
        }
        if (sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(expectedBuf, sigBuf)) {
            console.error('[Webhook] Signature verification failed');
            return res.status(400).json({ error: 'Invalid signature' });
        }

        const payload = JSON.parse(rawBody);
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
            const order = await prisma.razorpayOrder.findFirst({
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
                        // M11 fix: Return 500 for transient/DB errors so Razorpay retries
                        if (!err.status || err.status >= 500) {
                            return res.status(500).json({ error: 'Transient processing error' });
                        }
                    }
                }
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
                    include: {
                        feeRefund: { select: { id: true, recordId: true, amount: true, coachingId: true } },
                    },
                });
                if (rzpRefund) {
                    await prisma.razorpayRefund.update({
                        where: { id: rzpRefund.id },
                        data: { status: 'FAILED' },
                    });

                    // H10 fix: Reverse the FeeRecord.paidAmount since refund was not actually sent
                    if (rzpRefund.feeRefund) {
                        const { recordId, amount, coachingId: refCoachingId } = rzpRefund.feeRefund;
                        const record = await prisma.feeRecord.findUnique({ where: { id: recordId } });
                        if (record) {
                            const restoredPaidAmount = record.paidAmount + amount;
                            const newStatus =
                                restoredPaidAmount >= record.finalAmount - 0.01 ? 'PAID'
                                    : restoredPaidAmount > 0 ? 'PARTIALLY_PAID'
                                        : record.dueDate < new Date() ? 'OVERDUE'
                                            : 'PENDING';
                            await prisma.feeRecord.update({
                                where: { id: recordId },
                                data: { paidAmount: restoredPaidAmount, status: newStatus },
                            });
                        }

                        // Notify admin about failed refund
                        if (refCoachingId) {
                            const coaching = await prisma.coaching.findUnique({
                                where: { id: refCoachingId },
                                select: { ownerId: true },
                            });
                            if (coaching?.ownerId) {
                                await notifSvc.create({
                                    userId: coaching.ownerId,
                                    coachingId: refCoachingId,
                                    type: 'FEE_PAYMENT',
                                    title: 'Refund Failed',
                                    message: `Razorpay refund of ₹${amount.toFixed(0)} failed. The student's balance has been restored.`,
                                    data: { recordId, refundId },
                                }).catch(() => {});
                            }
                        }
                    }
                }
                await prisma.razorpayWebhookLog.updateMany({
                    where: { refundId, event, processed: false },
                    data: { processed: true },
                });
                break;
            }

            // M14 fix: Handle dispute/chargeback events from Razorpay
            case 'payment.dispute.created':
            case 'payment.dispute.won':
            case 'payment.dispute.lost':
            case 'payment.dispute.closed': {
                const disputeEntity = payload?.payload?.dispute?.entity;
                const disputePaymentId = disputeEntity?.payment_id;
                if (disputePaymentId && coachingId) {
                    // Find the order associated with this payment
                    const disputeOrder = await prisma.razorpayOrder.findFirst({
                        where: { razorpayPaymentId: disputePaymentId },
                        select: { id: true, recordId: true, coachingId: true },
                    });

                    // Notify coaching owner about the dispute
                    const coaching = await prisma.coaching.findUnique({
                        where: { id: coachingId },
                        select: { ownerId: true },
                    });
                    if (coaching?.ownerId) {
                        const disputeStatus = event.split('.').pop()!;
                        const amount = disputeEntity?.amount ? disputeEntity.amount / 100 : 0;
                        await notifSvc.create({
                            userId: coaching.ownerId,
                            coachingId,
                            type: 'FEE_PAYMENT',
                            title: `Payment Dispute ${disputeStatus.charAt(0).toUpperCase() + disputeStatus.slice(1)}`,
                            message: `A payment dispute of ₹${amount.toFixed(0)} has been ${disputeStatus}. ${
                                disputeStatus === 'lost' ? 'The disputed amount will be deducted from your settlements.' : ''
                            }`.trim(),
                            data: { paymentId: disputePaymentId, recordId: disputeOrder?.recordId, disputeId: disputeEntity?.id },
                        }).catch(() => {});
                    }

                    // If dispute is lost, reverse the payment on the fee record
                    if (event === 'payment.dispute.lost' && disputeOrder) {
                        const disputeAmount = disputeEntity?.amount ? disputeEntity.amount / 100 : 0;
                        if (disputeAmount > 0) {
                            const record = await prisma.feeRecord.findUnique({ where: { id: disputeOrder.recordId } });
                            if (record) {
                                const newPaidAmount = Math.max(0, record.paidAmount - disputeAmount);
                                const isPastDue = record.dueDate < new Date();
                                const newStatus =
                                    newPaidAmount >= record.finalAmount - 0.01 ? 'PAID'
                                        : newPaidAmount > 0 ? (isPastDue ? 'OVERDUE' : 'PARTIALLY_PAID')
                                            : isPastDue ? 'OVERDUE' : 'PENDING';
                                await prisma.feeRecord.update({
                                    where: { id: disputeOrder.recordId },
                                    data: { paidAmount: newPaidAmount, status: newStatus },
                                });
                            }
                        }
                    }
                }
                await prisma.razorpayWebhookLog.updateMany({
                    where: { event, processed: false, paymentId: disputePaymentId },
                    data: { processed: true },
                });
                break;
            }

            // Handle transfer events for Route (Razorpay marketplace)
            case 'transfer.processed':
            case 'transfer.settled':
            case 'transfer.failed': {
                const transferEntity = payload?.payload?.transfer?.entity;
                const transferId = transferEntity?.id;
                if (transferId) {
                    const status = event === 'transfer.failed' ? 'failed'
                        : event === 'transfer.settled' ? 'settled' : 'processed';
                    await prisma.razorpayOrder.updateMany({
                        where: { transferId },
                        data: { transferStatus: status },
                    });
                }
                await prisma.razorpayWebhookLog.updateMany({
                    where: { event, processed: false },
                    data: { processed: true },
                });
                break;
            }

            default:
                // Unknown event — log but don't fail
                console.log(`[Webhook] Unhandled event: ${event}`);
        }

        // Always return 200 to Razorpay for successfully processed events
        res.status(200).json({ received: true });
    } catch (err: any) {
        console.error('[Webhook] Unhandled error:', err);
        // M11 fix: Return 500 for unhandled errors so Razorpay retries
        // Only return 200 if the error is permanent (bad data, not our fault)
        res.status(500).json({ error: 'Internal webhook processing error' });
    }
});
