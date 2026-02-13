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

    async getAssetStream(bucket: string, key: string) {
        return await storageService.getStream(bucket, key);
    }
}

export const uploadService = new UploadService();
