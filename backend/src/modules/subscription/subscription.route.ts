import { Router } from 'express';
import { SubscriptionController } from './subscription.controller.js';
import { CreditController } from './credit.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { rateLimiter } from '../../shared/middleware/rate-limiter.middleware.js';

const router = Router();
const ctrl = new SubscriptionController();
const creditCtrl = new CreditController();

const subLimiter = rateLimiter(60_000, 20, 'subscription');

// Public: list plans (cacheable)
router.get('/plans', ctrl.listPlans.bind(ctrl));

// Credits: user-level credit balance
router.get('/credits', authMiddleware, subLimiter, creditCtrl.getBalance.bind(creditCtrl));

// NOTE: Coaching-level subscription routes (/coaching/:coachingId/subscription/...)
// are registered directly on the app in src/index.ts because this router is
// mounted at /subscription, which would prefix them incorrectly.

export default router;
