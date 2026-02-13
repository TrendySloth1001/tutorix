import { Router } from 'express';
import { CoachingController } from './coaching.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const coachingController = new CoachingController();

// Public routes
router.get('/', coachingController.list.bind(coachingController));
router.get('/check-slug/:slug', coachingController.checkSlug.bind(coachingController));
router.get('/slug/:slug', coachingController.getBySlug.bind(coachingController));

// Protected routes - require authentication (must be before /:id to match correctly)
router.post('/', authMiddleware, coachingController.create.bind(coachingController));
router.get('/my', authMiddleware, coachingController.getMyCoachings.bind(coachingController));
router.patch('/:id', authMiddleware, coachingController.update.bind(coachingController));
router.delete('/:id', authMiddleware, coachingController.delete.bind(coachingController));

// Dynamic route last
router.get('/:id', coachingController.getById.bind(coachingController));

export default router;
