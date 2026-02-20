import type { Request, Response, NextFunction } from 'express';
import prisma from '../../infra/prisma.js';

/**
 * Middleware factory: verifies the authenticated user is a member of the coaching
 * identified by `:coachingId` param AND has one of the required roles.
 *
 * Must be used AFTER authMiddleware.
 *
 * Usage:
 *   router.post('/structures', authMiddleware, requireCoachingRole('ADMIN', 'OWNER'), ctrl.createStructure);
 *   router.get('/my', authMiddleware, requireCoachingMember(), ctrl.getMyFees);  // any member
 *
 * Role hierarchy: OWNER > ADMIN > TEACHER > STUDENT
 * 'OWNER' is a virtual role — it means the user is the coaching's `ownerId`.
 */
export function requireCoachingRole(...allowedRoles: string[]) {
    return async (req: Request, res: Response, next: NextFunction) => {
        try {
            const user = (req as any).user;
            if (!user?.id) {
                return res.status(401).json({ error: 'Authentication required' });
            }

            const coachingId = req.params.coachingId as string;
            if (!coachingId) {
                return res.status(400).json({ error: 'Missing coachingId parameter' });
            }

            // Check if user is the coaching owner
            const coaching = await prisma.coaching.findUnique({
                where: { id: coachingId },
                select: { ownerId: true },
            });
            if (!coaching) {
                return res.status(404).json({ error: 'Coaching not found' });
            }

            const isOwner = coaching.ownerId === user.id;

            // Owners pass all role checks
            if (isOwner) {
                (req as any).coachingRole = 'OWNER';
                return next();
            }

            // Find membership
            const member = await prisma.coachingMember.findFirst({
                where: { coachingId, userId: user.id },
                select: { id: true, role: true },
            });

            if (!member) {
                // Also check if the user is a parent of a ward in this coaching
                const wardMember = await prisma.coachingMember.findFirst({
                    where: { coachingId, ward: { parentId: user.id } },
                    select: { id: true, role: true },
                });
                if (!wardMember) {
                    return res.status(403).json({ error: 'You are not a member of this coaching' });
                }
                // Parents inherit STUDENT role for ward access
                (req as any).coachingRole = 'STUDENT';
                (req as any).coachingMemberId = wardMember.id;

                if (allowedRoles.length === 0 || allowedRoles.includes('STUDENT')) {
                    return next();
                }
                return res.status(403).json({ error: 'Insufficient permissions for this action' });
            }

            (req as any).coachingRole = member.role;
            (req as any).coachingMemberId = member.id;

            // If no roles specified, any member passes
            if (allowedRoles.length === 0) {
                return next();
            }

            // ADMIN role in our system implicitly covers OWNER check on non-ownership routes
            if (allowedRoles.includes(member.role)) {
                return next();
            }

            return res.status(403).json({ error: 'Insufficient permissions for this action' });
        } catch (err: any) {
            console.error('[CoachingRoleMiddleware] Error:', err.message);
            return res.status(500).json({ error: 'Authorization check failed' });
        }
    };
}

/**
 * Shorthand: require any coaching membership (no specific role).
 * Validates the user belongs to the coaching.
 */
export function requireCoachingMember() {
    return requireCoachingRole();
}
