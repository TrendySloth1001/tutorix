import { storageService } from '../../infra/storage.js';
import prisma from '../../infra/prisma.js';

export class UploadService {
    async uploadAvatar(userId: string, file: Express.Multer.File) {
        const fileName = `avatar-${userId}-${Date.now()}.${file.originalname.split('.').pop()}`;

        // Upload to MinIO
        const imageUrl = await storageService.uploadFile(
            storageService.buckets.AVATARS,
            fileName,
            file.buffer,
            file.mimetype
        );

        // Update user profile in database
        const user = await prisma.user.update({
            where: { id: userId },
            data: { picture: imageUrl },
        });

        return { user, imageUrl };
    }

    async uploadFile(file: Express.Multer.File, prefix: string = 'file') {
        const fileName = `${prefix}-${Date.now()}.${file.originalname.split('.').pop()}`;

        const imageUrl = await storageService.uploadFile(
            storageService.buckets.AVATARS,
            fileName,
            file.buffer,
            file.mimetype
        );

        return { url: imageUrl };
    }

    async uploadNoteFile(file: Express.Multer.File) {
        const ext = file.originalname.split('.').pop() || 'bin';
        const fileName = `note-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

        const url = await storageService.uploadFile(
            storageService.buckets.BATCH_NOTES,
            fileName,
            file.buffer,
            file.mimetype
        );

        return { url, fileName: file.originalname, size: file.size, mimeType: file.mimetype };
    }

    async getAssetStream(bucket: string, key: string) {
        return await storageService.getStream(bucket, key);
    }
}

export const uploadService = new UploadService();
