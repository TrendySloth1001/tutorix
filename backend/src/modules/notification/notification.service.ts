import prisma from '../../infra/prisma.js';

export interface CreateNotificationDto {
    coachingId?: string;
    userId?: string;
    type: string;
    title: string;
    message: string;
    data?: any;
}

export class NotificationService {
    /**
     * Get notifications for a coaching (admin view).
     * Excludes archived notifications.
     */
    async getCoachingNotifications(coachingId: string, limit = 20, offset = 0) {
        return prisma.notification.findMany({
            where: { coachingId, archived: false },
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip: offset,
        });
    }

    /**
     * Get personal notifications for a user.
     * Excludes archived notifications.
     */
    async getUserNotifications(userId: string, limit = 20, offset = 0) {
        return prisma.notification.findMany({
            where: { userId, archived: false },
            orderBy: { createdAt: 'desc' },
            take: limit,
            skip: offset,
        });
    }

    /**
     * Get Unread count for coaching (excludes archived)
     */
    async getCoachingUnreadCount(coachingId: string) {
        return prisma.notification.count({
            where: { coachingId, read: false, archived: false },
        });
    }

    /**
     * Get Unread count for user (excludes archived)
     */
    async getUserUnreadCount(userId: string) {
        return prisma.notification.count({
            where: { userId, read: false, archived: false },
        });
    }

    /**
     * Mark a notification as read.
     */
    async markAsRead(notificationId: string) {
        return prisma.notification.update({
            where: { id: notificationId },
            data: { read: true },
        });
    }

    /**
     * Delete a notification.
     */
    async deleteNotification(notificationId: string) {
        return prisma.notification.delete({
            where: { id: notificationId },
        });
    }

    /**
     * Archive a notification (mark as archived instead of deleting).
     */
    async archiveNotification(notificationId: string) {
        return prisma.notification.update({
            where: { id: notificationId },
            data: { archived: true },
        });
    }

    /**
     * Create a notification (internal use).
     */
    async create(data: CreateNotificationDto) {
        return prisma.notification.create({
            data: {
                ...(data.coachingId && { coachingId: data.coachingId }),
                ...(data.userId && { userId: data.userId }),
                type: data.type,
                title: data.title,
                message: data.message,
                data: data.data,
            },
        });
    }
}
