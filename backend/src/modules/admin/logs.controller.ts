import type { Request, Response } from 'express';
import { LoggerService } from '../../shared/services/logger.service.js';

export class AdminLogsController {
    /**
     * GET /admin/logs
     * Get logs with optional filters.
     * 
     * Query params:
     * - type: API_REQUEST | API_ERROR | FRONTEND_ERROR | SYSTEM
     * - level: INFO | WARN | ERROR | FATAL
     * - userId: filter by user ID
     * - startDate: ISO date string
     * - endDate: ISO date string
     * - limit: number of logs to return (default: 50, max: 500)
     * - offset: pagination offset
     */
    async getLogs(req: Request, res: Response) {
        try {
            const {
                type,
                level,
                userId,
                startDate,
                endDate,
                limit,
                offset,
            } = req.query;

            const filters: any = {
                type: type as string,
                level: level as string,
                userId: userId as string,
                startDate: startDate ? new Date(startDate as string) : undefined,
                endDate: endDate ? new Date(endDate as string) : undefined,
                limit: Math.min(parseInt(limit as string) || 50, 500),
                offset: parseInt(offset as string) || 0,
            };

            const result = await LoggerService.getLogs(filters);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    /**
     * GET /admin/logs/stats
     * Get log statistics.
     * 
     * Query params:
     * - startDate: ISO date string
     * - endDate: ISO date string
     */
    async getStats(req: Request, res: Response) {
        try {
            const { startDate, endDate } = req.query;

            const stats = await LoggerService.getStats(
                startDate ? new Date(startDate as string) : undefined,
                endDate ? new Date(endDate as string) : undefined,
            );

            res.json(stats);
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    /**
     * POST /admin/logs/frontend
     * Log a frontend error (can also be called by authenticated users).
     * 
     * Body:
     * - message: error message
     * - error: error string
     * - stackTrace: optional stack trace
     * - metadata: optional metadata object
     */
    async logFrontendError(req: Request, res: Response) {
        try {
            const { message, error, stackTrace, metadata } = req.body;
            const user = (req as any).user;

            if (!message || !error) {
                return res.status(400).json({ 
                    message: 'message and error fields are required' 
                });
            }

            await LoggerService.logFrontendError({
                userId: user?.id,
                userEmail: user?.email,
                userName: user?.name,
                message,
                error,
                stackTrace,
                metadata,
            });

            res.json({ success: true, message: 'Error logged' });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    /**
     * DELETE /admin/logs/cleanup
     * Delete logs older than specified days.
     * 
     * Query params:
     * - days: number of days to keep (default: 30)
     */
    async cleanupOldLogs(req: Request, res: Response) {
        try {
            const days = parseInt(req.query.days as string) || 30;
            const deletedCount = await LoggerService.deleteOldLogs(days);

            res.json({ 
                success: true,
                message: `Deleted ${deletedCount} logs older than ${days} days`,
                deletedCount,
            });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }
}
