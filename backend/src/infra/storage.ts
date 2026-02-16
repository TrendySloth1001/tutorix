import minioClient from './minio.js';

export class StorageService {
    private static BUCKETS = {
        AVATARS: 'avatars',
        COACHING_LOGOS: 'coaching-logos',
        BATCH_NOTES: 'batch-notes',
    };

    private bucketsEnsured = false;

    private static PUBLIC_BUCKETS = new Set(['avatars', 'coaching-logos']);

    private async ensureBuckets() {
        if (this.bucketsEnsured) return;

        try {
            for (const bucket of Object.values(StorageService.BUCKETS)) {
                const exists = await minioClient.bucketExists(bucket);
                if (!exists) {
                    await minioClient.makeBucket(bucket);
                    // Only set public read policy for avatars and logos
                    if (StorageService.PUBLIC_BUCKETS.has(bucket)) {
                        const policy = {
                            Version: '2012-10-17',
                            Statement: [
                                {
                                    Effect: 'Allow',
                                    Principal: { AWS: ['*'] },
                                    Action: ['s3:GetBucketLocation', 's3:ListBucket'],
                                    Resource: [`arn:aws:s3:::${bucket}`],
                                },
                                {
                                    Effect: 'Allow',
                                    Principal: { AWS: ['*'] },
                                    Action: ['s3:GetObject'],
                                    Resource: [`arn:aws:s3:::${bucket}/*`],
                                },
                            ],
                        };
                        await minioClient.setBucketPolicy(bucket, JSON.stringify(policy));
                    }
                }
            }
            this.bucketsEnsured = true;
        } catch (error) {
            console.error('Failed to ensure MinIO buckets:', error);
            // We don't throw here to avoid crashing the server on start, 
            // but methods will fail if they need these buckets.
        }
    }

    async uploadFile(bucket: string, fileName: string, buffer: Buffer, contentType: string): Promise<string> {
        await this.ensureBuckets();
        await minioClient.putObject(bucket, fileName, buffer, buffer.length, {
            'Content-Type': contentType,
        });

        // Return a proxy URL that goes through our backend
        const baseUrl = process.env.API_BASE_URL || `http://localhost:${process.env.PORT || 3010}`;
        return `${baseUrl}/upload/assets/${bucket}/${fileName}`;
    }

    async getStream(bucket: string, key: string) {
        await this.ensureBuckets();
        return await minioClient.getObject(bucket, key);
    }

    async deleteFile(bucket: string, fileName: string): Promise<void> {
        await this.ensureBuckets();
        await minioClient.removeObject(bucket, fileName);
    }

    get buckets() {
        return StorageService.BUCKETS;
    }
}

export const storageService = new StorageService();
