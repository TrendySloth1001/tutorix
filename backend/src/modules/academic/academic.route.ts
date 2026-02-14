import { Router } from 'express';
import { AcademicController } from './academic.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const controller = new AcademicController();

// Public route - static masters data
router.get('/masters', controller.getMasters);

// Protected routes - user's academic profile
router.get('/profile', authMiddleware, controller.getProfile);
router.post('/profile', authMiddleware, controller.saveProfile);
router.patch('/remind-later', authMiddleware, controller.remindLater);
router.get('/onboarding-status', authMiddleware, controller.getOnboardingStatus);

export default router;
