import type { Request, Response } from 'express';
import { UserService } from './user.service.js';

const userService = new UserService();

export class UserController {
    // GET /user/me - Get current user profile
    async getMe(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const user = await userService.findById(userId);
            if (!user) {
                return res.status(404).json({ message: 'User not found' });
            }

            res.json({ user });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // PATCH /user/me - Update current user profile
    async updateMe(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const updateData: any = {};

            // Name and Phone should never be set to null via this endpoint.
            // Even if they are nullable in DB, we want to maintain existing values.
            if (req.body.name !== undefined && req.body.name !== null) {
                updateData.name = req.body.name;
            }
            if (req.body.phone !== undefined && req.body.phone !== null) {
                updateData.phone = req.body.phone;
            }

            // Picture is allowed to be null (for removal)
            if (req.body.picture !== undefined) {
                updateData.picture = req.body.picture;
            }

            // Privacy settings for invite search
            if (typeof req.body.showEmailInSearch === 'boolean') {
                updateData.showEmailInSearch = req.body.showEmailInSearch;
            }
            if (typeof req.body.showPhoneInSearch === 'boolean') {
                updateData.showPhoneInSearch = req.body.showPhoneInSearch;
            }
            if (typeof req.body.showWardsInSearch === 'boolean') {
                updateData.showWardsInSearch = req.body.showWardsInSearch;
            }

            const user = await userService.update(userId, updateData);

            res.json({ user });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // PATCH /user/me/roles - Update user roles
    async updateRoles(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const { isAdmin, isTeacher, isParent, isWard } = req.body;
            const user = await userService.updateRoles(userId, {
                isAdmin,
                isTeacher,
                isParent,
                isWard,
            });

            res.json({ user });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /user/me/sessions - Get current user login sessions
    async getSessions(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const sessions = await userService.getSessions(userId);
            res.json({ sessions });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /user/me/onboarding - Complete onboarding
    async completeOnboarding(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const user = await userService.completeOnboarding(userId);
            res.json({ user });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /user/:id - Get user by ID (admin only)
    async getById(req: Request, res: Response) {
        try {
            const id = req.params.id as string;
            const user = await userService.findById(id);

            if (!user) {
                return res.status(404).json({ message: 'User not found' });
            }

            res.json({ user });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /user - List all users (admin only)
    async list(req: Request, res: Response) {
        try {
            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 10;

            const result = await userService.findAll(page, limit);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // DELETE /user/:id - Delete user (admin only)
    async delete(req: Request, res: Response) {
        try {
            const id = req.params.id as string;
            await userService.delete(id);
            res.json({ message: 'User deleted successfully' });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }
}
