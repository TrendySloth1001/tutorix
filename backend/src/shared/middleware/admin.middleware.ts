import type { Request, Response, NextFunction } from 'express';

/**
 * Middleware to check if the current user is an admin.
 * Must be used after authMiddleware.
 * 
 * Admin is determined by:
 * 1. User's email matches ADMIN_EMAIL from .env, OR
 * 2. User has isAdmin flag set to true in database
 */
export function adminMiddleware(req: Request, res: Response, next: NextFunction) {
    const user = (req as any).user;

    if (!user) {
        return res.status(401).json({ message: 'Authentication required' });
    }

    const adminEmail = process.env.ADMIN_EMAIL;
    const isAdmin = user.email === adminEmail || user.isAdmin === true;

    if (!isAdmin) {
        return res.status(403).json({ 
            message: 'Admin access required',
            error: 'FORBIDDEN' 
        });
    }

    next();
}
