import type { Request, Response } from 'express';
import { WardService } from './ward.service.js';

const wardService = new WardService();

export class WardController {
    // POST /user/wards - Create a new ward
    async create(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const { name, picture } = req.body;
            if (!name) {
                return res.status(400).json({ message: 'Name is required' });
            }

            const ward = await wardService.create({
                name,
                picture,
                parentId: userId
            });

            res.status(201).json({ ward });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /user/wards - List all wards for the current parent
    async listMyWards(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const wards = await wardService.findByParentId(userId);
            res.json({ wards });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /user/wards/:id - Get ward by ID
    async getById(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            const wardId = req.params.id as string;

            const ward = await wardService.findById(wardId);
            if (!ward) {
                return res.status(404).json({ message: 'Ward not found' });
            }
            if (ward.parentId !== userId && !(req as any).user?.isAdmin) {
                return res.status(403).json({ message: 'Forbidden' });
            }

            res.json({ ward });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // PATCH /user/wards/:id - Update a ward
    async update(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            const wardId = req.params.id as string;

            const ward = await wardService.findById(wardId);
            if (!ward) {
                return res.status(404).json({ message: 'Ward not found' });
            }
            if (ward.parentId !== userId) {
                return res.status(403).json({ message: 'Forbidden' });
            }

            const updateData: Record<string, any> = {};
            if (req.body.name !== undefined) updateData.name = req.body.name;
            if (req.body.picture !== undefined) updateData.picture = req.body.picture;
            if (req.body.dob !== undefined) updateData.dob = req.body.dob;
            if (req.body.school !== undefined) updateData.school = req.body.school;
            if (req.body.class !== undefined) updateData.class = req.body.class;

            const updatedWard = await wardService.update(wardId, updateData);
            res.json({ ward: updatedWard });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // DELETE /user/wards/:id - Delete a ward
    async delete(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            const wardId = req.params.id as string;

            const ward = await wardService.findById(wardId);
            if (!ward) {
                return res.status(404).json({ message: 'Ward not found' });
            }
            if (ward.parentId !== userId) {
                return res.status(403).json({ message: 'Forbidden' });
            }

            await wardService.delete(wardId);
            res.json({ message: 'Ward deleted successfully' });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }
}
