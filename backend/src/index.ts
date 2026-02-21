import express from 'express';
import * as corsNamespace from 'cors';
const cors = (corsNamespace as any).default || corsNamespace;
import dotenv from 'dotenv';
dotenv.config();

// BigInt JSON serialization — Prisma returns BigInt for large numeric fields.
// Without this, JSON.stringify throws "Do not know how to serialize a BigInt".
(BigInt.prototype as any).toJSON = function () {
  const n = Number(this);
  if (!Number.isSafeInteger(n)) return this.toString();
  return n;
};
import authRoutes from './modules/auth/auth.route.js';
import userRoutes from './modules/user/user.route.js';
import coachingRoutes from './modules/coaching/coaching.route.js';
import uploadRoutes from './modules/upload/upload.route.js';
import notificationRoutes from './modules/notification/notification.route.js';
import academicRoutes from './modules/academic/academic.route.js';
import adminRoutes from './modules/admin/admin.route.js';
// import { webhookRouter } from './modules/payment/payment.webhook.js'; // Uncomment for production
import { webhookRouter } from './modules/payment/payment.webhook.js';
import { PaymentController } from './modules/payment/payment.controller.js';
import { requestLoggerMiddleware } from './shared/middleware/request-logger.middleware.js';
import { authMiddleware } from './shared/middleware/auth.middleware.js';
import { rateLimiter } from './shared/middleware/rate-limiter.middleware.js';
import { AdminLogsController } from './modules/admin/logs.controller.js';


const app = express();
const port = process.env.PORT || 3010;

// Only trust first proxy hop (not all)
app.set('trust proxy', 1);

// CORS: restrict to known origins
const allowedOrigins = (process.env.CORS_ORIGINS || '').split(',').filter(Boolean);
app.use(cors(allowedOrigins.length > 0 ? {
  origin: allowedOrigins,
  credentials: true,
} : undefined));

// C6 fix: Webhook route MUST be mounted BEFORE express.json() with express.raw()
// so the body arrives as a raw Buffer for accurate signature verification.
app.use('/webhooks', express.raw({ type: 'application/json' }), webhookRouter);

app.use(express.json({ limit: '100kb' }));

// Request logging middleware
app.use(requestLoggerMiddleware);

// Frontend error logging endpoint (accessible to all authenticated users)
const logsController = new AdminLogsController();
app.post('/api/logs/frontend', authMiddleware, logsController.logFrontendError.bind(logsController));

app.use('/auth', authRoutes);
app.use('/user', userRoutes);
app.use('/coaching', coachingRoutes);
app.use('/upload', uploadRoutes);
app.use('/notifications', notificationRoutes);
app.use('/academic', academicRoutes);
app.use('/admin', adminRoutes);

// Payment config (Razorpay key for frontend)
const paymentCtrl = new PaymentController();
app.get('/payment/config', authMiddleware, paymentCtrl.getConfig.bind(paymentCtrl));

// Coaching payment settings (bank account, GST, etc.)
const settingsLimiter = rateLimiter(60_000, 15, 'payment-settings');    // 15 reads/writes per min
const verifyBankLimiter = rateLimiter(300_000, 3, 'verify-bank');       // 3 penny drops per 5 min (costs ₹2 each)
const linkedAccountLimiter = rateLimiter(60_000, 5, 'linked-account');  // 5 linked account ops per min

app.get('/coaching/:coachingId/payment-settings', authMiddleware, settingsLimiter, paymentCtrl.getPaymentSettings.bind(paymentCtrl));
app.patch('/coaching/:coachingId/payment-settings', authMiddleware, settingsLimiter, paymentCtrl.updatePaymentSettings.bind(paymentCtrl));

// Razorpay Route linked account management
app.post('/coaching/:coachingId/payment-settings/linked-account', authMiddleware, linkedAccountLimiter, paymentCtrl.createLinkedAccount.bind(paymentCtrl));
app.post('/coaching/:coachingId/payment-settings/linked-account/refresh', authMiddleware, linkedAccountLimiter, paymentCtrl.refreshLinkedAccountStatus.bind(paymentCtrl));
app.delete('/coaching/:coachingId/payment-settings/linked-account', authMiddleware, linkedAccountLimiter, paymentCtrl.deleteLinkedAccount.bind(paymentCtrl));

// Bank account penny-drop verification
app.post('/coaching/:coachingId/payment-settings/verify-bank', authMiddleware, verifyBankLimiter, paymentCtrl.verifyBankAccount.bind(paymentCtrl));

app.get('/hello', (req, res) => {
  res.json({ message: 'Hello from Express TypeScript!' });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
