import { Router } from 'express';
import multer from 'multer';
import { uploadService } from './upload.service.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB limit
    },
});

const uploadLarge = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 15 * 1024 * 1024, // 15MB limit for notes/assignments
    },
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

// GET /upload/assets/:bucket/:key - Proxy assets from MinIO
router.get('/assets/:bucket/:key', async (req, res) => {
    try {
        const bucket = req.params.bucket;
        const key = req.params.key;

        if (!key) {
            return res.status(400).json({ message: 'Missing asset key' });
        }

        const dataStream = await uploadService.getAssetStream(bucket, key);
        dataStream.pipe(res);
    } catch (error: any) {
        res.status(404).json({ message: 'Asset not found' });
    }
});

export default router;
