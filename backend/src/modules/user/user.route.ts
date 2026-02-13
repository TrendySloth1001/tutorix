import { Router } from 'express';
import { UserController } from './user.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const userController = new UserController();

// Protected routes - require authentication
router.use(authMiddleware);

// Current user routes
router.get('/me', userController.getMe.bind(userController));
router.patch('/me', userController.updateMe.bind(userController));
router.patch('/me/roles', userController.updateRoles.bind(userController));
router.post('/me/onboarding', userController.completeOnboarding.bind(userController));

// Admin routes
router.get('/', userController.list.bind(userController));
router.get('/:id', userController.getById.bind(userController));
router.delete('/:id', userController.delete.bind(userController));

export default router;
