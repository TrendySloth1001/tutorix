import { Router } from 'express';
import { NotificationController } from './notification.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const controller = new NotificationController();

// All routes require authentication
router.use(authMiddleware);

// Get user's personal notifications
router.get('/me', controller.getUserNotifications.bind(controller));

// Mark as read
router.patch('/:id/read', controller.markAsRead.bind(controller));

// Delete
router.delete('/:id', controller.delete.bind(controller));

export default router;
