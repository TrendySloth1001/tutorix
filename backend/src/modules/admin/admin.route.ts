import { Router } from 'express';
import { AdminLogsController } from './logs.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { adminMiddleware } from '../../shared/middleware/admin.middleware.js';

const router = Router();
const logsController = new AdminLogsController();

// All admin routes require authentication + admin role
router.use(authMiddleware, adminMiddleware);

// Logs endpoints
router.get('/logs', logsController.getLogs.bind(logsController));
router.get('/logs/stats', logsController.getStats.bind(logsController));
router.delete('/logs/cleanup', logsController.cleanupOldLogs.bind(logsController));

export default router;
