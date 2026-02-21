import { Router } from 'express';
import { FeeController } from './fee.controller.js';
import { PaymentController } from '../payment/payment.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { requireCoachingRole, requireCoachingMember } from '../../shared/middleware/coaching-role.middleware.js';
import { rateLimiter } from '../../shared/middleware/rate-limiter.middleware.js';

const router = Router({ mergeParams: true }); // access :coachingId from parent
const ctrl = new FeeController();
const payCtrl = new PaymentController();

// Shared middleware stacks
const adminAuth = [authMiddleware, requireCoachingRole('ADMIN', 'OWNER')] as const;
const memberAuth = [authMiddleware, requireCoachingMember()] as const;
const reminderLimiter = rateLimiter(60_000, 10, 'fee-reminder'); // 10 reminders/min per user

// S4 fix: Rate limit payment endpoints to prevent abuse
const orderLimiter = rateLimiter(60_000, 10, 'create-order');     // 10 orders/min per user
const verifyLimiter = rateLimiter(60_000, 15, 'verify-payment');  // 15 verifications/min per user
const refundLimiter = rateLimiter(60_000, 5, 'online-refund');    // 5 refunds/min per user

// All routes under /coaching/:coachingId/fee

// ── Fee Structures (admin-only) ─────────────────────────────────────
router.get('/structures', ...adminAuth, ctrl.listStructures.bind(ctrl));
router.get('/structures/current', ...adminAuth, ctrl.getCurrentStructure.bind(ctrl));
router.get('/structures/replace-preview', ...adminAuth, ctrl.getStructureReplacePreview.bind(ctrl));
router.post('/structures', ...adminAuth, ctrl.createStructure.bind(ctrl));
router.patch('/structures/:structureId', ...adminAuth, ctrl.updateStructure.bind(ctrl));
router.delete('/structures/:structureId', ...adminAuth, ctrl.deleteStructure.bind(ctrl));

// ── Assignment preview (admin-only) ───────────────────────────────
router.get('/members/:memberId/assignment-preview', ...adminAuth, ctrl.getAssignmentPreview.bind(ctrl));

// ── Assignments (admin-only) ────────────────────────────────────────
router.post('/assign', ...adminAuth, ctrl.assignFee.bind(ctrl));
router.delete('/assignments/:assignmentId', ...adminAuth, ctrl.removeFeeAssignment.bind(ctrl));
router.patch('/assignments/:assignmentId/pause', ...adminAuth, ctrl.toggleFeePause.bind(ctrl));

// ── Member profiles & ledger (admin sees all; student sees own only) ──
router.get('/members/:memberId', ...memberAuth, ctrl.getMemberFeeProfile.bind(ctrl));
router.get('/members/:memberId/ledger', ...memberAuth, ctrl.getStudentLedger.bind(ctrl));

// ── Records (admin sees all; student can view their own record detail) ─
router.get('/records', ...adminAuth, ctrl.listRecords.bind(ctrl));
router.get('/records/:recordId', ...memberAuth, ctrl.getRecord.bind(ctrl));
router.post('/records/:recordId/pay', ...adminAuth, ctrl.recordPayment.bind(ctrl));
router.post('/records/:recordId/waive', ...adminAuth, ctrl.waiveFee.bind(ctrl));
router.post('/records/:recordId/refund', ...adminAuth, ctrl.recordRefund.bind(ctrl));

// ── Reminders (admin-only, rate-limited) ────────────────────────────
router.post('/records/:recordId/remind', ...adminAuth, reminderLimiter, ctrl.sendReminder.bind(ctrl));
router.post('/bulk-remind', ...adminAuth, reminderLimiter, ctrl.bulkRemind.bind(ctrl));

// ── Summary & Reports (admin-only) ─────────────────────────────────
router.get('/summary', ...adminAuth, ctrl.getSummary.bind(ctrl));
router.get('/overdue-report', ...adminAuth, ctrl.getOverdueReport.bind(ctrl));
router.get('/calendar', ...adminAuth, ctrl.getFeeCalendar.bind(ctrl));
router.get('/audit-log', ...adminAuth, ctrl.listAuditLog.bind(ctrl));

// ── Student-facing (any member) ────────────────────────────────────
router.get('/my', ...memberAuth, ctrl.getMyFees.bind(ctrl));
router.get('/my-transactions', ...memberAuth, ctrl.getMyTransactions.bind(ctrl));

// ── Online Payment — student-facing (any member) ───────────────────
router.post('/records/:recordId/create-order', ...memberAuth, orderLimiter, payCtrl.createOrder.bind(payCtrl));
router.post('/records/:recordId/verify-payment', ...memberAuth, verifyLimiter, payCtrl.verifyPayment.bind(payCtrl));
router.get('/records/:recordId/online-payments', ...adminAuth, payCtrl.getOnlinePayments.bind(payCtrl));
router.post('/records/:recordId/online-refund', ...adminAuth, refundLimiter, payCtrl.initiateOnlineRefund.bind(payCtrl));

// ── Multi-record payment — student-facing ──────────────────────────
router.post('/multi-pay/create-order', ...memberAuth, orderLimiter, payCtrl.createMultiOrder.bind(payCtrl));
router.post('/multi-pay/verify', ...memberAuth, verifyLimiter, payCtrl.verifyMultiPayment.bind(payCtrl));

// ── Failed order tracking ──────────────────────────────────────────
router.post('/orders/:internalOrderId/fail', ...memberAuth, payCtrl.failOrder.bind(payCtrl));
router.get('/records/:recordId/failed-orders', ...memberAuth, payCtrl.getFailedOrders.bind(payCtrl));

export default router;
