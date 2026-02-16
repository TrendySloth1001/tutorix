import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { AssignmentController } from './assignment.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router({ mergeParams: true });
const ctrl = new AssignmentController();

// Multer for assignment file uploads (images + PDFs, max 15MB each, up to 10 files)
const ALLOWED_TYPES = new Set([
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic', 'image/heif',
    'application/pdf',
]);
const ALLOWED_EXTS = new Set([
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif', '.pdf',
]);

const fileFilter = (_req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    if (ALLOWED_TYPES.has(file.mimetype)) return cb(null, true);
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (ALLOWED_EXTS.has(ext)) return cb(null, true);
    cb(new Error('Only images (JPEG, PNG, GIF, WebP, HEIC) and PDFs are allowed'));
};

const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 15 * 1024 * 1024 },
    fileFilter,
});

// All routes require auth
router.use(authMiddleware);

// ── Assignment CRUD (teacher) ──
router.post('/', upload.array('files', 10), ctrl.create.bind(ctrl));
router.get('/', ctrl.list.bind(ctrl));
router.get('/:assignmentId', ctrl.getById.bind(ctrl));
router.patch('/:assignmentId/status', ctrl.updateStatus.bind(ctrl));
router.delete('/:assignmentId', ctrl.delete.bind(ctrl));

// ── Submissions ──
router.post('/:assignmentId/submit', upload.array('files', 10), ctrl.submit.bind(ctrl));
router.get('/:assignmentId/submissions', ctrl.getSubmissions.bind(ctrl));
router.get('/:assignmentId/my-submission', ctrl.getMySubmission.bind(ctrl));
router.patch('/submissions/:submissionId/grade', ctrl.grade.bind(ctrl));

export default router;
