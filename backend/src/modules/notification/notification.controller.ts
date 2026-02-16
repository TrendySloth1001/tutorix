import type { Request, Response } from 'express';
import { NotificationService } from './notification.service.js';
import prisma from '../../infra/prisma.js';

const notificationService = new NotificationService();

export class NotificationController {
    /**
     * GET /coaching/:id/notifications
     */
    async getCoachingNotifications(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const { limit, offset } = req.query;

            // Authorization check: User must be a member of the coaching or owner
            const userId = (req as any).user.id;
            const member = await prisma.coachingMember.findUnique({
                where: {
                    coachingId_userId: { coachingId, userId },
                },
            });

            if (!member) {
                // Not a member — check if owner
                const coaching = await prisma.coaching.findUnique({ where: { id: coachingId } });
                if (coaching?.ownerId !== userId) {
                    return res.status(403).json({ error: 'Not authorized' });
                }
            }

            const notifications = await notificationService.getCoachingNotifications(
                coachingId,
                limit ? Number(limit) : 20,
                offset ? Number(offset) : 0
            );

            const unreadCount = await notificationService.getCoachingUnreadCount(coachingId);

            return res.json({ notifications, unreadCount });
        } catch (error: any) {
            console.error('NotificationController Error:', error);
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * GET /notifications/me - Get personal notifications for authenticated user
     */
    async getUserNotifications(req: Request, res: Response) {
        try {
            const userId = (req as any).user.id;
            const { limit, offset } = req.query;

            const notifications = await notificationService.getUserNotifications(
                userId,
                limit ? Number(limit) : 20,
                offset ? Number(offset) : 0
            );

            const unreadCount = await notificationService.getUserUnreadCount(userId);

            return res.json({ notifications, unreadCount });
        } catch (error: any) {
            console.error('NotificationController Error:', error);
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * PATCH /notifications/:id/read
     */
    async markAsRead(req: Request, res: Response) {
        try {
            const { id } = req.params as { id: string };
            const userId = (req as any).user?.id;
            // Verify ownership
            const notification = await prisma.notification.findUnique({ where: { id }, select: { userId: true, coachingId: true } });
            if (!notification) return res.status(404).json({ error: 'Not found' });
            if (notification.userId && notification.userId !== userId) return res.status(403).json({ error: 'Forbidden' });

            const result = await notificationService.markAsRead(id);
            return res.json(result);
        } catch (error: any) {
            console.error('NotificationController Error:', error);
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * DELETE /notifications/:id
     */
    async delete(req: Request, res: Response) {
        try {
            const { id } = req.params as { id: string };
            const userId = (req as any).user?.id;
            const notification = await prisma.notification.findUnique({ where: { id }, select: { userId: true, coachingId: true } });
            if (!notification) return res.status(404).json({ error: 'Not found' });
            if (notification.userId && notification.userId !== userId) return res.status(403).json({ error: 'Forbidden' });

            await notificationService.deleteNotification(id);
            return res.json({ success: true });
        } catch (error: any) {
            console.error('NotificationController Error:', error);
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * PATCH /notifications/:id/archive - Mark notification as archived
     */
    async archive(req: Request, res: Response) {
        try {
            const { id } = req.params as { id: string };
            const userId = (req as any).user?.id;
            const notification = await prisma.notification.findUnique({ where: { id }, select: { userId: true, coachingId: true } });
            if (!notification) return res.status(404).json({ error: 'Not found' });
            if (notification.userId && notification.userId !== userId) return res.status(403).json({ error: 'Forbidden' });

            const result = await notificationService.archiveNotification(id);
            return res.json(result);
        } catch (error: any) {
            console.error('NotificationController Error:', error);
            return res.status(500).json({ error: error.message });
        }
    }
}
