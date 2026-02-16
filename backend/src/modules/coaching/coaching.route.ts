import { Router } from 'express';
import { CoachingController } from './coaching.controller.js';
import { InvitationController } from './invitation.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import batchRoutes from '../batch/batch.route.js';

const router = Router();
const coachingController = new CoachingController();
const invitationController = new InvitationController();

// Public routes
router.get('/', coachingController.list.bind(coachingController));
router.get('/masters', coachingController.getMasters.bind(coachingController));
router.get('/explore', coachingController.explore.bind(coachingController));
router.get('/check-slug/:slug', coachingController.checkSlug.bind(coachingController));
router.get('/slug/:slug', coachingController.getBySlug.bind(coachingController));

// Protected routes - require authentication (must be before /:id to match correctly)
router.post('/', authMiddleware, coachingController.create.bind(coachingController));
router.get('/my', authMiddleware, coachingController.getMyCoachings.bind(coachingController));
router.get('/joined', authMiddleware, coachingController.getJoinedCoachings.bind(coachingController));
router.patch('/:id', authMiddleware, coachingController.update.bind(coachingController));
router.delete('/:id', authMiddleware, coachingController.delete.bind(coachingController));

// Onboarding routes (protected)
router.post('/:id/onboarding/profile', authMiddleware, coachingController.updateOnboardingProfile.bind(coachingController));
router.post('/:id/onboarding/address', authMiddleware, coachingController.updateOnboardingAddress.bind(coachingController));
router.post('/:id/onboarding/branch', authMiddleware, coachingController.addBranch.bind(coachingController));
router.post('/:id/onboarding/complete', authMiddleware, coachingController.completeOnboarding.bind(coachingController));
router.get('/:id/branches', coachingController.getBranches.bind(coachingController));
router.delete('/:id/branches/:branchId', authMiddleware, coachingController.deleteBranch.bind(coachingController));
router.get('/:id/full', coachingController.getFullDetails.bind(coachingController));

// Invitation routes (protected)
router.post('/:id/invite/lookup', authMiddleware, invitationController.lookup.bind(invitationController));
router.post('/:id/invite', authMiddleware, invitationController.createInvitation.bind(invitationController));
router.get('/:id/invitations', authMiddleware, invitationController.getCoachingInvitations.bind(invitationController));
router.delete('/:id/invitations/:invitationId', authMiddleware, invitationController.cancelInvitation.bind(invitationController));

// Members routes (protected)
router.get('/:id/members', authMiddleware, coachingController.getMembers.bind(coachingController));
router.post('/:id/members/ward', authMiddleware, coachingController.addWard.bind(coachingController));
router.delete('/:id/members/:memberId', authMiddleware, coachingController.removeMember.bind(coachingController));
router.patch('/:id/members/:memberId', authMiddleware, coachingController.updateMemberRole.bind(coachingController));

// Notifications routes (protected)
import { NotificationController } from '../notification/notification.controller.js';
const notificationController = new NotificationController();
router.get('/:id/notifications', authMiddleware, notificationController.getCoachingNotifications.bind(notificationController));

// Batch management routes (nested)
router.use('/:coachingId/batches', batchRoutes);

// Dynamic route last
router.get('/:id', coachingController.getById.bind(coachingController));

export default router;

