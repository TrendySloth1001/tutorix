import { Router } from 'express';
import { BatchController } from './batch.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { enforceQuota } from '../../shared/middleware/quota.middleware.js';
import assessmentRoutes from '../assessment/assessment.route.js';
import assignmentRoutes from '../assessment/assignment.route.js';

const router = Router({ mergeParams: true }); // mergeParams to access :coachingId from parent
const ctrl = new BatchController();

// All routes are nested under /coaching/:coachingId/batches
// and require authentication

// Batch CRUD
router.post('/', authMiddleware, enforceQuota('BATCH'), ctrl.create.bind(ctrl));
router.get('/', authMiddleware, ctrl.list.bind(ctrl));
router.get('/my', authMiddleware, ctrl.getMyBatches.bind(ctrl));
router.get('/recent-notes', authMiddleware, ctrl.getRecentNotes.bind(ctrl));
router.get('/dashboard-feed', authMiddleware, ctrl.getDashboardFeed.bind(ctrl));
router.get('/storage', authMiddleware, ctrl.getStorage.bind(ctrl)); // Storage usage
router.get('/:batchId', authMiddleware, ctrl.getById.bind(ctrl));
router.patch('/:batchId', authMiddleware, ctrl.update.bind(ctrl));
router.delete('/:batchId', authMiddleware, ctrl.delete.bind(ctrl));

// Batch Members
router.post('/:batchId/members', authMiddleware, ctrl.addMembers.bind(ctrl));
router.get('/:batchId/members', authMiddleware, ctrl.getMembers.bind(ctrl));
router.get('/:batchId/members/available', authMiddleware, ctrl.getAvailableMembers.bind(ctrl));
router.delete('/:batchId/members/:batchMemberId', authMiddleware, ctrl.removeMember.bind(ctrl));

// Batch Notes (study material)
router.post('/:batchId/notes', authMiddleware, ctrl.createNote.bind(ctrl));
router.get('/:batchId/notes', authMiddleware, ctrl.listNotes.bind(ctrl));
router.delete('/:batchId/notes/:noteId', authMiddleware, ctrl.deleteNote.bind(ctrl));

// Batch Notices (announcements)
router.post('/:batchId/notices', authMiddleware, ctrl.createNotice.bind(ctrl));
router.get('/:batchId/notices', authMiddleware, ctrl.listNotices.bind(ctrl));
router.delete('/:batchId/notices/:noticeId', authMiddleware, ctrl.deleteNotice.bind(ctrl));

// Assessment & Assignment sub-routes
router.use('/:batchId/assessments', assessmentRoutes);
router.use('/:batchId/assignments', assignmentRoutes);

export default router;
