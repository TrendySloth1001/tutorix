import type { Request, Response, NextFunction } from 'express';

/**
 * Simple in-memory rate limiter per user per action.
 * For production, consider Redis-backed rate limiting.
 *
 * @param windowMs   Time window in milliseconds
 * @param maxHits    Maximum requests per window
 * @param keyPrefix  Unique prefix for this limiter instance
 */
export function rateLimiter(windowMs: number, maxHits: number, keyPrefix: string) {
    const hits = new Map<string, { count: number; reset: number }>();

    // Cleanup stale entries every 5 minutes
    setInterval(() => {
        const now = Date.now();
        for (const [key, val] of hits) {
            if (now > val.reset) hits.delete(key);
        }
    }, 5 * 60 * 1000).unref();

    return (req: Request, res: Response, next: NextFunction) => {
        const userId = (req as any).user?.id ?? req.ip;
        const key = `${keyPrefix}:${userId}`;
        const now = Date.now();

        const entry = hits.get(key);
        if (!entry || now > entry.reset) {
            hits.set(key, { count: 1, reset: now + windowMs });
            return next();
        }

        entry.count++;
        if (entry.count > maxHits) {
            const retryAfterSec = Math.ceil((entry.reset - now) / 1000);
            res.set('Retry-After', String(retryAfterSec));
            return res.status(429).json({
                error: 'Too many requests. Please try again later.',
                retryAfterSeconds: retryAfterSec,
            });
        }

        return next();
    };
}
