/**
 * Quota enforcement middleware.
 *
 * Usage:
 *   router.post('/invite', authMiddleware, enforceQuota('STUDENT'), ctrl.invite);
 *   router.post('/batch',  authMiddleware, enforceQuota('BATCH'),   ctrl.create);
 *
 * The middleware extracts coachingId from req.params (supports both
 * :coachingId and :id patterns used across routes).
 */
import type { Request, Response, NextFunction } from 'express';
import { SubscriptionService } from '../../modules/subscription/subscription.service.js';

const subscriptionService = new SubscriptionService();

// In-memory TTL cache to avoid hammering DB on every request
const quotaCache = new Map<string, { result: { allowed: boolean; message?: string }; expiresAt: number }>();
const CACHE_TTL_MS = 10_000; // 10 seconds

export function enforceQuota(dimension: string, increment: number = 1) {
    return async (req: Request, res: Response, next: NextFunction) => {
        try {
            const coachingId = (req.params as any).coachingId || (req.params as any).id;
            if (!coachingId) {
                // No coaching context — skip quota check (shouldn't happen with proper routing)
                return next();
            }

            const cacheKey = `${coachingId}:${dimension}`;
            const now = Date.now();
            const cached = quotaCache.get(cacheKey);

            let result: { allowed: boolean; message?: string };

            if (cached && cached.expiresAt > now) {
                result = cached.result;
            } else {
                result = await subscriptionService.checkQuota(coachingId, dimension, increment);
                quotaCache.set(cacheKey, { result, expiresAt: now + CACHE_TTL_MS });
            }

            if (!result.allowed) {
                return res.status(402).json({
                    message: result.message,
                    code: 'QUOTA_EXCEEDED',
                    dimension,
                });
            }

            next();
        } catch (error: any) {
            // Don't block operations if quota check fails — log and continue
            console.error('[enforceQuota] Error:', error.message);
            next();
        }
    };
}

/** Invalidate quota cache for a coaching (call after member/batch create/delete) */
export function invalidateQuotaCache(coachingId: string) {
    for (const key of quotaCache.keys()) {
        if (key.startsWith(`${coachingId}:`)) {
            quotaCache.delete(key);
        }
    }
}
