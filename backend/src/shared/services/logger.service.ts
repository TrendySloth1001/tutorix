import prisma from '../../infra/prisma.js';

export interface LogEntry {
    type: 'API_REQUEST' | 'API_ERROR' | 'FRONTEND_ERROR' | 'SYSTEM';
    level?: 'INFO' | 'WARN' | 'ERROR' | 'FATAL';
    userId?: string | undefined;
    userEmail?: string | undefined;
    userName?: string | undefined;
    userRoles?: string[] | undefined;
    method?: string | undefined;
    path?: string | undefined;
    statusCode?: number | undefined;
    duration?: number | undefined;
    ip?: string | undefined;
    userAgent?: string | undefined;
    message?: string | undefined;
    error?: string | undefined;
    stackTrace?: string | undefined;
    metadata?: Record<string, any> | undefined;
}

export class LoggerService {
    /**
     * Create a log entry in the database.
     * Non-blocking - errors are caught and logged to console only.
     */
    static async log(entry: LogEntry): Promise<void> {
        try {
            await prisma.log.create({
                data: {
                    type: entry.type,
                    level: entry.level || 'INFO',
                    userId: entry.userId ?? null,
                    userEmail: entry.userEmail ?? null,
                    userName: entry.userName ?? null,
                    userRoles: entry.userRoles || [],
                    method: entry.method ?? null,
                    path: entry.path ?? null,
                    statusCode: entry.statusCode ?? null,
                    duration: entry.duration ?? null,
                    ip: entry.ip ?? null,
                    userAgent: entry.userAgent ?? null,
                    message: entry.message ?? null,
                    error: entry.error ?? null,
                    stackTrace: entry.stackTrace ?? null,
                    metadata: entry.metadata || {},
                },
            });
        } catch (error) {
            // Don't throw - logging should never crash the app
            console.error('Failed to save log to database:', error);
        }
    }

    /**
     * Log an API request.
     */
    static async logRequest(data: {
        userId?: string | undefined;
        userEmail?: string | undefined;
        userName?: string | undefined;
        userRoles?: string[] | undefined;
        method: string;
        path: string;
        statusCode: number;
        duration: number;
        ip?: string | undefined;
        userAgent?: string | undefined;
        metadata?: Record<string, any> | undefined;
    }): Promise<void> {
        await this.log({
            type: 'API_REQUEST',
            level: data.statusCode >= 500 ? 'ERROR' : data.statusCode >= 400 ? 'WARN' : 'INFO',
            ...data,
        });
    }

    /**
     * Log an API error.
     */
    static async logError(data: {
        userId?: string;
        userEmail?: string;
        userName?: string;
        userRoles?: string[];
        method?: string;
        path?: string;
        statusCode?: number;
        ip?: string;
        userAgent?: string;
        message: string;
        error: string;
        stackTrace?: string;
        metadata?: Record<string, any>;
    }): Promise<void> {
        await this.log({
            type: 'API_ERROR',
            level: 'ERROR',
            ...data,
        });
    }

    /**
     * Log a frontend error (sent from client).
     */
    static async logFrontendError(data: {
        userId?: string;
        userEmail?: string;
        userName?: string;
        message: string;
        error: string;
        stackTrace?: string;
        metadata?: Record<string, any>;
    }): Promise<void> {
        await this.log({
            type: 'FRONTEND_ERROR',
            level: 'ERROR',
            ...data,
        });
    }

    /**
     * Query logs (admin only).
     */
    static async getLogs(filters: {
        type?: string;
        level?: string;
        userId?: string;
        startDate?: Date;
        endDate?: Date;
        limit?: number;
        offset?: number;
    }) {
        const where: any = {};

        if (filters.type) where.type = filters.type;
        if (filters.level) where.level = filters.level;
        if (filters.userId) where.userId = filters.userId;
        if (filters.startDate || filters.endDate) {
            where.createdAt = {};
            if (filters.startDate) where.createdAt.gte = filters.startDate;
            if (filters.endDate) where.createdAt.lte = filters.endDate;
        }

        const [logs, total] = await Promise.all([
            prisma.log.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                take: filters.limit || 50,
                skip: filters.offset || 0,
            }),
            prisma.log.count({ where }),
        ]);

        return { logs, total };
    }

    /**
     * Get log statistics (admin only).
     */
    static async getStats(startDate?: Date, endDate?: Date) {
        const where: any = {};
        if (startDate || endDate) {
            where.createdAt = {};
            if (startDate) where.createdAt.gte = startDate;
            if (endDate) where.createdAt.lte = endDate;
        }

        const [
            totalLogs,
            errorCount,
            warnCount,
            apiRequestCount,
            apiErrorCount,
            frontendErrorCount,
        ] = await Promise.all([
            prisma.log.count({ where }),
            prisma.log.count({ where: { ...where, level: 'ERROR' } }),
            prisma.log.count({ where: { ...where, level: 'WARN' } }),
            prisma.log.count({ where: { ...where, type: 'API_REQUEST' } }),
            prisma.log.count({ where: { ...where, type: 'API_ERROR' } }),
            prisma.log.count({ where: { ...where, type: 'FRONTEND_ERROR' } }),
        ]);

        return {
            totalLogs,
            errorCount,
            warnCount,
            apiRequestCount,
            apiErrorCount,
            frontendErrorCount,
        };
    }

    /**
     * Delete old logs (cleanup task).
     */
    static async deleteOldLogs(daysToKeep: number = 30): Promise<number> {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

        const result = await prisma.log.deleteMany({
            where: {
                createdAt: { lt: cutoffDate },
            },
        });

        return result.count;
    }
}
