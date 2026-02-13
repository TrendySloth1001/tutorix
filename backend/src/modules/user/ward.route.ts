import { Router } from 'express';
import { WardController } from './ward.controller.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';

const router = Router();
const wardController = new WardController();

router.use(authMiddleware);

router.post('/', wardController.create.bind(wardController));
router.get('/', wardController.listMyWards.bind(wardController));
router.get('/:id', wardController.getById.bind(wardController));
router.patch('/:id', wardController.update.bind(wardController));
router.delete('/:id', wardController.delete.bind(wardController));

export default router;
