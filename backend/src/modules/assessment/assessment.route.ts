import { Router } from 'express';
import { AssessmentController } from './assessment.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { enforceQuota } from '../../shared/middleware/quota.middleware.js';

const router = Router({ mergeParams: true });
const ctrl = new AssessmentController();

// All routes require auth
router.use(authMiddleware);

// ── Assessment CRUD (teacher) ──
router.post('/', enforceQuota('ASSESSMENT'), ctrl.create.bind(ctrl));
router.get('/', ctrl.list.bind(ctrl));
router.get('/:assessmentId', ctrl.getById.bind(ctrl));
router.patch('/:assessmentId/status', ctrl.updateStatus.bind(ctrl));
router.delete('/:assessmentId', ctrl.delete.bind(ctrl));

// ── Questions ──
router.post('/:assessmentId/questions', ctrl.addQuestions.bind(ctrl));
router.delete('/questions/:questionId', ctrl.deleteQuestion.bind(ctrl));

// ── Attempts (student) ──
router.post('/:assessmentId/start', ctrl.startAttempt.bind(ctrl));
router.post('/attempts/:attemptId/answer', ctrl.saveAnswer.bind(ctrl));
router.post('/attempts/:attemptId/submit', ctrl.submitAttempt.bind(ctrl));
router.get('/attempts/:attemptId/result', ctrl.getAttemptResult.bind(ctrl));
router.get('/attempts/:attemptId/answers', ctrl.getAttemptAnswers.bind(ctrl));

// ── Teacher views ──
router.get('/:assessmentId/attempts', ctrl.getAttempts.bind(ctrl));

export default router;
