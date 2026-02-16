import * as Minio from 'minio';
import dotenv from 'dotenv';

dotenv.config();

if (!process.env.MINIO_ACCESS_KEY || !process.env.MINIO_SECRET_KEY) {
    console.warn('WARNING: MINIO_ACCESS_KEY / MINIO_SECRET_KEY not set — using dev defaults');
}

const minioClient = new Minio.Client({
    endPoint: process.env.MINIO_ENDPOINT || 'localhost',
    port: parseInt(process.env.MINIO_PORT || '9000'),
    useSSL: process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
});

export default minioClient;
