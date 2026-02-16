import { Router } from 'express';
import multer from 'multer';
import { uploadService } from './upload.service.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const ALLOWED_IMAGE_TYPES = [
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml',
];
const ALLOWED_DOC_TYPES = [
    ...ALLOWED_IMAGE_TYPES,
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
];

const imageFilter = (_req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    if (ALLOWED_IMAGE_TYPES.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only image files (JPEG, PNG, GIF, WebP, SVG) are allowed'));
};
const docFilter = (_req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    if (ALLOWED_DOC_TYPES.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Unsupported file type'));
};

const router = Router();
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB limit
    },
    fileFilter: imageFilter,
});

const uploadLarge = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 15 * 1024 * 1024, // 15MB limit for notes/assignments
    },
    fileFilter: docFilter,
});

// POST /upload/avatar - Upload user avatar
router.post('/avatar', authMiddleware, upload.single('avatar'), async (req, res) => {
    try {
        const userId = (req as any).user?.id;
        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const result = await uploadService.uploadAvatar(userId, req.file);
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
});

// POST /upload/logo - Upload a logo/image (no user update)
router.post('/logo', authMiddleware, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const result = await uploadService.uploadFile(req.file, 'logo');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
});

// POST /upload/cover - Upload a cover image
router.post('/cover', authMiddleware, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const result = await uploadService.uploadFile(req.file, 'cover');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
});

// POST /upload/note - Upload a note/assignment file (up to 15MB)
router.post('/note', authMiddleware, uploadLarge.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const result = await uploadService.uploadNoteFile(req.file);
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
});

// POST /upload/notes - Upload multiple note files (up to 15MB each, max 10 files)
router.post('/notes', authMiddleware, uploadLarge.array('files', 10), async (req, res) => {
    try {
        const files = req.files as Express.Multer.File[];
        if (!files || files.length === 0) {
            return res.status(400).json({ message: 'No files uploaded' });
        }
        const results = await uploadService.uploadNoteFiles(files);
        res.json({ files: results, totalSize: results.reduce((s, f) => s + f.size, 0) });
    } catch (error: any) {
        res.status(500).json({ message: error.message });
    }
});

// GET /upload/assets/:bucket/:key - Proxy assets from MinIO
const ALLOWED_BUCKETS = new Set(['avatars', 'coaching-logos', 'batch-notes']);
router.get('/assets/:bucket/:key', async (req, res) => {
    try {
        const bucket = req.params.bucket;
        const key = req.params.key;

        if (!key || !ALLOWED_BUCKETS.has(bucket)) {
            return res.status(400).json({ message: 'Invalid bucket or key' });
        }
        // Prevent path traversal
        if (key.includes('..') || key.includes('//')) {
            return res.status(400).json({ message: 'Invalid asset key' });
        }

        const dataStream = await uploadService.getAssetStream(bucket, key);
        dataStream.pipe(res);
    } catch (error: any) {
        res.status(404).json({ message: 'Asset not found' });
    }
});

export default router;
