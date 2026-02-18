import type { Request, Response, NextFunction } from 'express';
import prisma from '../../infra/prisma.js';

/**
 * In-memory log buffer with periodic + threshold flush.
 * Reduces DB writes from 1-per-request to 1-per-batch.
 */
const LOG_BUFFER: Array<{
    type: string;
    level: string;
    userId: string | null;
    userEmail: string | null;
    userName: string | null;
    userRoles: string[];
    method: string | null;
    path: string | null;
    statusCode: number | null;
    duration: number | null;
    ip: string | null;
    userAgent: string | null;
    message: string | null;
    error: string | null;
    stackTrace: string | null;
    metadata: any;
}> = [];

const FLUSH_INTERVAL_MS = 5_000; // Flush every 5 seconds
const FLUSH_THRESHOLD = 50;      // Or when buffer hits 50 entries

async function flushLogBuffer() {
    if (LOG_BUFFER.length === 0) return;

    // Drain buffer atomically
    const batch = LOG_BUFFER.splice(0, LOG_BUFFER.length);

    try {
        await prisma.log.createMany({ data: batch });
    } catch (err) {
        console.error(`Failed to flush ${batch.length} log entries:`, err);
        // Don't re-add — logs are best-effort, avoid memory leak on persistent failures
    }
}

// Periodic flush timer
setInterval(flushLogBuffer, FLUSH_INTERVAL_MS).unref();

// Flush on process exit
process.on('beforeExit', () => flushLogBuffer());

/** Routes to skip logging entirely (high-frequency, low-value) */
const SKIP_ROUTES = new Set(['/health', '/healthz', '/ping', '/favicon.ico']);

/**
 * Middleware to log all API requests.
 * Buffers logs in-memory and flushes in batches.
 */
export function requestLoggerMiddleware(req: Request, res: Response, next: NextFunction) {
    // Skip health checks and other noise
    if (SKIP_ROUTES.has(req.path)) return next();

    const startTime = Date.now();
    
    // Capture the original res.json to intercept status code
    const originalJson = res.json.bind(res);
    
    res.json = function (body: any) {
        const duration = Date.now() - startTime;
        const user = (req as any).user;
        const statusCode = res.statusCode;
        
        LOG_BUFFER.push({
            type: 'API_REQUEST',
            level: statusCode >= 500 ? 'ERROR' : statusCode >= 400 ? 'WARN' : 'INFO',
            userId: user?.id ?? null,
            userEmail: user?.email ?? null,
            userName: user?.name ?? null,
            userRoles: getUserRoles(user),
            method: req.method,
            path: req.path,
            statusCode,
            duration,
            ip: getClientIp(req),
            userAgent: req.get('user-agent') ?? null,
            message: null,
            error: null,
            stackTrace: null,
            metadata: {
                query: req.query,
                params: req.params,
                body: isSensitiveRoute(req.path) ? undefined : req.body,
            },
        });

        // Flush if threshold reached
        if (LOG_BUFFER.length >= FLUSH_THRESHOLD) {
            flushLogBuffer().catch(() => {});
        }
        
        return originalJson(body);
    };
    
    next();
}

/**
 * Get user roles as an array of strings.
 */
function getUserRoles(user: any): string[] {
    if (!user) return [];
    const roles: string[] = [];
    if (user.isAdmin) roles.push('ADMIN');
    if (user.isTeacher) roles.push('TEACHER');
    if (user.isParent) roles.push('PARENT');
    if (user.isWard) roles.push('WARD');
    return roles;
}

/**
 * Extract client IP address.
 */
function getClientIp(req: Request): string {
    return (
        (req.headers['x-forwarded-for'] as string)?.split(',')[0] ||
        req.socket.remoteAddress ||
        'unknown'
    );
}

/**
 * Check if route is sensitive (don't log request body).
 */
function isSensitiveRoute(path: string): boolean {
    const sensitivePatterns = [
        '/auth/login',
        '/auth/register',
        '/auth/google',
        '/user/password',
    ];
    return sensitivePatterns.some(pattern => path.includes(pattern));
}
