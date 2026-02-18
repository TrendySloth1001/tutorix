import type { Request, Response, NextFunction } from 'express';
import { LoggerService } from '../services/logger.service.js';

/**
 * Middleware to log all API requests.
 * Captures method, path, status code, duration, user info, etc.
 * 
 * Usage: Add to Express app before routes:
 * app.use(requestLoggerMiddleware);
 */
export function requestLoggerMiddleware(req: Request, res: Response, next: NextFunction) {
    const startTime = Date.now();
    
    // Capture the original res.json to intercept status code
    const originalJson = res.json.bind(res);
    
    res.json = function (body: any) {
        const duration = Date.now() - startTime;
        const user = (req as any).user;
        
        // Log the request asynchronously (don't block response)
        const userAgent = req.get('user-agent');
        LoggerService.logRequest({
            userId: user?.id,
            userEmail: user?.email,
            userName: user?.name,
            userRoles: getUserRoles(user),
            method: req.method,
            path: req.path,
            statusCode: res.statusCode,
            duration,
            ip: getClientIp(req),
            userAgent: userAgent,
            metadata: {
                query: req.query,
                params: req.params,
                // Don't log body for sensitive routes
                body: isSensitiveRoute(req.path) ? undefined : req.body,
            },
        }).catch(err => {
            console.error('Failed to log request:', err);
        });
        
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
