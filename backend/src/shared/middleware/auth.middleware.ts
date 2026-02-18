import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import prisma from '../../infra/prisma.js';
import redis from '../../infra/redis.js';

dotenv.config();

export interface AuthenticatedRequest extends Request {
    user?: {
        id: string;
        email: string;
    };
}

// Cache verified user IDs in Redis to avoid DB hit on every single request.
// TTL = 5 minutes. On user deletion, the cache expires naturally.
const USER_EXISTS_TTL = 300; // 5 min

export const authMiddleware = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ message: 'No token provided' });
        }

        const token = authHeader.split(' ')[1];
        if (!token) {
            return res.status(401).json({ message: 'Invalid token format' });
        }

        const jwtSecret = process.env.JWT_SECRET;
        if (!jwtSecret) {
            console.error('FATAL: JWT_SECRET environment variable is not set');
            return res.status(500).json({ message: 'Server configuration error' });
        }

        const decoded = jwt.verify(token, jwtSecret) as any as {
            id: string;
            email: string;
        };

        // Check Redis cache before hitting DB
        const cacheKey = `user:exists:${decoded.id}`;
        let exists: boolean;
        try {
            const cached = await redis.get(cacheKey);
            exists = cached === '1';
        } catch {
            exists = false; // Redis down — fall through to DB
        }

        if (!exists) {
            const user = await prisma.user.findUnique({
                where: { id: decoded.id },
                select: { id: true },
            });

            if (!user) {
                return res.status(401).json({ message: 'User session is invalid or expired. Please re-login.' });
            }

            // Cache the result
            try { await redis.set(cacheKey, '1', 'EX', USER_EXISTS_TTL); } catch { /* best-effort */ }
        }

        (req as AuthenticatedRequest).user = decoded;
        next();
    } catch (error) {
        return res.status(401).json({ message: 'Invalid or expired token' });
    }
};
