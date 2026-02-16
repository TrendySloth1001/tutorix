import { Router } from 'express';
import { UserController } from './user.controller.js';
import { InvitationController } from '../coaching/invitation.controller.js';
import wardRoutes from './ward.route.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const userController = new UserController();
const invitationController = new InvitationController();

// Protected routes - require authentication
router.use(authMiddleware);

// Current user routes
router.get('/me', userController.getMe.bind(userController));
router.patch('/me', userController.updateMe.bind(userController));
router.get('/me/sessions', userController.getSessions.bind(userController));
router.post('/me/onboarding', userController.completeOnboarding.bind(userController));

// User invitation routes
router.get('/invitations', invitationController.getMyInvitations.bind(invitationController));
router.post('/invitations/:invitationId/respond', invitationController.respondToInvitation.bind(invitationController));

// Ward management
router.use('/wards', wardRoutes);

// Admin routes — require isAdmin flag on authenticated user
const adminOnly = (req: any, res: any, next: any) => {
    if (!req.user?.isAdmin) return res.status(403).json({ message: 'Admin access required' });
    next();
};
router.get('/', adminOnly, userController.list.bind(userController));
router.get('/:id', adminOnly, userController.getById.bind(userController));
router.delete('/:id', adminOnly, userController.delete.bind(userController));

export default router;

