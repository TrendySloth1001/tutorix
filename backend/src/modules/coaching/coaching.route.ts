import { Router } from 'express';
import { CoachingController } from './coaching.controller.js';
import { InvitationController } from './invitation.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const coachingController = new CoachingController();
const invitationController = new InvitationController();

// Public routes
router.get('/', coachingController.list.bind(coachingController));
router.get('/check-slug/:slug', coachingController.checkSlug.bind(coachingController));
router.get('/slug/:slug', coachingController.getBySlug.bind(coachingController));

// Protected routes - require authentication (must be before /:id to match correctly)
router.post('/', authMiddleware, coachingController.create.bind(coachingController));
router.get('/my', authMiddleware, coachingController.getMyCoachings.bind(coachingController));
router.patch('/:id', authMiddleware, coachingController.update.bind(coachingController));
router.delete('/:id', authMiddleware, coachingController.delete.bind(coachingController));

// Invitation routes (protected)
router.post('/:id/invite/lookup', authMiddleware, invitationController.lookup.bind(invitationController));
router.post('/:id/invite', authMiddleware, invitationController.createInvitation.bind(invitationController));
router.get('/:id/invitations', authMiddleware, invitationController.getCoachingInvitations.bind(invitationController));
router.delete('/:id/invitations/:invitationId', authMiddleware, invitationController.cancelInvitation.bind(invitationController));

// Members routes (protected)
router.get('/:id/members', authMiddleware, coachingController.getMembers.bind(coachingController));
router.post('/:id/members/ward', authMiddleware, coachingController.addWard.bind(coachingController));

// Dynamic route last
router.get('/:id', coachingController.getById.bind(coachingController));

export default router;

