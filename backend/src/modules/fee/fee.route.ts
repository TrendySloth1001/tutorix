import { Router } from 'express';
import { FeeController } from './fee.controller.js';
import { PaymentController } from '../payment/payment.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router({ mergeParams: true }); // access :coachingId from parent
const ctrl = new FeeController();
const payCtrl = new PaymentController();

// All routes under /coaching/:coachingId/fee

// ── Fee Structures ──────────────────────────────────────────────────
router.get('/structures', authMiddleware, ctrl.listStructures.bind(ctrl));
router.post('/structures', authMiddleware, ctrl.createStructure.bind(ctrl));
router.patch('/structures/:structureId', authMiddleware, ctrl.updateStructure.bind(ctrl));
router.delete('/structures/:structureId', authMiddleware, ctrl.deleteStructure.bind(ctrl));

// ── Assignments ─────────────────────────────────────────────────────
router.post('/assign', authMiddleware, ctrl.assignFee.bind(ctrl));
router.delete('/assignments/:assignmentId', authMiddleware, ctrl.removeFeeAssignment.bind(ctrl));
router.get('/members/:memberId', authMiddleware, ctrl.getMemberFeeProfile.bind(ctrl));

// ── Records ─────────────────────────────────────────────────────────
router.get('/records', authMiddleware, ctrl.listRecords.bind(ctrl));
router.get('/records/:recordId', authMiddleware, ctrl.getRecord.bind(ctrl));
router.post('/records/:recordId/pay', authMiddleware, ctrl.recordPayment.bind(ctrl));
router.post('/records/:recordId/waive', authMiddleware, ctrl.waiveFee.bind(ctrl));
router.post('/records/:recordId/remind', authMiddleware, ctrl.sendReminder.bind(ctrl));

// ── Summary & My Fees ────────────────────────────────────────────────
router.get('/summary', authMiddleware, ctrl.getSummary.bind(ctrl));
router.get('/my', authMiddleware, ctrl.getMyFees.bind(ctrl));
router.get('/calendar', authMiddleware, ctrl.getFeeCalendar.bind(ctrl));

// ── New endpoints ────────────────────────────────────────────────────
router.patch('/assignments/:assignmentId/pause', authMiddleware, ctrl.toggleFeePause.bind(ctrl));
router.post('/records/:recordId/refund', authMiddleware, ctrl.recordRefund.bind(ctrl));
router.post('/bulk-remind', authMiddleware, ctrl.bulkRemind.bind(ctrl));
router.get('/overdue-report', authMiddleware, ctrl.getOverdueReport.bind(ctrl));
router.get('/members/:memberId/ledger', authMiddleware, ctrl.getStudentLedger.bind(ctrl));

// ── Online Payment (Razorpay) ─────────────────────────────────────────
router.post('/records/:recordId/create-order', authMiddleware, payCtrl.createOrder.bind(payCtrl));
router.post('/records/:recordId/verify-payment', authMiddleware, payCtrl.verifyPayment.bind(payCtrl));
router.get('/records/:recordId/online-payments', authMiddleware, payCtrl.getOnlinePayments.bind(payCtrl));
router.post('/records/:recordId/online-refund', authMiddleware, payCtrl.initiateOnlineRefund.bind(payCtrl));

export default router;
