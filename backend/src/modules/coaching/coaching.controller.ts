import type { Request, Response } from 'express';
import { CoachingService } from './coaching.service.js';
import { getCoachingMasters, getSubjectsByCategory } from './masters.js';

const coachingService = new CoachingService();

export class CoachingController {
    // GET /coaching/masters - Get static coaching data (categories, subjects, etc.)
    async getMasters(req: Request, res: Response) {
        try {
            const { grouped } = req.query;

            if (grouped === 'true') {
                return res.json({
                    ...getCoachingMasters(),
                    subjectsByCategory: getSubjectsByCategory(),
                });
            }

            return res.json(getCoachingMasters());
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching - Create a new coaching
    async create(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const { name, description, logo } = req.body;

            if (!name) {
                return res.status(400).json({ message: 'Name is required' });
            }

            // Generate slug from name
            let slug = coachingService.generateSlug(name);

            // Ensure slug is unique (capped at 10 attempts)
            let isAvailable = await coachingService.isSlugAvailable(slug);
            let counter = 1;
            const MAX_SLUG_ATTEMPTS = 10;
            while (!isAvailable && counter <= MAX_SLUG_ATTEMPTS) {
                slug = `${coachingService.generateSlug(name)}-${counter}`;
                isAvailable = await coachingService.isSlugAvailable(slug);
                counter++;
            }
            if (!isAvailable) {
                return res.status(409).json({ message: 'Unable to generate a unique slug. Please try a different name.' });
            }

            const coaching = await coachingService.create(userId, {
                name,
                slug,
                description,
                logo,
            });

            res.status(201).json({ coaching });
        } catch (error: any) {
            if (error.message.includes('Foreign key constraint violated')) {
                return res.status(400).json({
                    message: 'User record not found. Please logout and login again to refresh your session.'
                });
            }
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/my - Get current user's coachings
    async getMyCoachings(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachings = await coachingService.findByOwner(userId);
            res.json({ coachings });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/joined - Get coachings where user is a member (not owner)
    async getJoinedCoachings(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachings = await coachingService.findByMember(userId);
            res.json({ coachings });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/:id - Get coaching by ID
    async getById(req: Request, res: Response) {
        try {
            const id = req.params.id as string;
            const coaching = await coachingService.findById(id);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            res.json({ coaching });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/slug/:slug - Get coaching by slug
    async getBySlug(req: Request, res: Response) {
        try {
            const slug = req.params.slug as string;
            const coaching = await coachingService.findBySlug(slug);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            res.json({ coaching });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // PATCH /coaching/:id - Update coaching
    async update(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const id = req.params.id as string;
            const { name, description, logo, coverImage, status } = req.body;

            const coaching = await coachingService.update(id, userId, {
                name,
                description,
                logo,
                coverImage,
                status,
            });

            res.json({ coaching });
        } catch (error: any) {
            if (error.message.includes('not found')) {
                return res.status(404).json({ message: error.message });
            }
            res.status(500).json({ message: error.message });
        }
    }

    // DELETE /coaching/:id - Delete coaching
    async delete(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const id = req.params.id as string;
            await coachingService.delete(id, userId);

            res.json({ message: 'Coaching deleted successfully' });
        } catch (error: any) {
            if (error.message.includes('not found')) {
                return res.status(404).json({ message: error.message });
            }
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching - List all coachings (public)
    async list(req: Request, res: Response) {
        try {
            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 10;

            const result = await coachingService.findAll(page, limit);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/check-slug/:slug - Check if slug is available
    async checkSlug(req: Request, res: Response) {
        try {
            const slug = req.params.slug as string;
            const available = await coachingService.isSlugAvailable(slug);
            res.json({ available, slug });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/explore - Find nearby coachings by lat/lng/radius
    async explore(req: Request, res: Response) {
        try {
            const lat = parseFloat(req.query.lat as string);
            const lng = parseFloat(req.query.lng as string);
            if (isNaN(lat) || isNaN(lng)) {
                return res.status(400).json({ message: 'lat and lng query params are required' });
            }
            const radius = parseFloat(req.query.radius as string) || 20;
            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 20;

            const result = await coachingService.findNearby(lat, lng, radius, page, limit);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/search?q=term - Search coachings by name
    async search(req: Request, res: Response) {
        try {
            const q = (req.query.q as string || '').trim();
            if (!q) {
                return res.json({ results: [] });
            }
            const limit = parseInt(req.query.limit as string) || 15;
            const results = await coachingService.search(q, limit);
            res.json({ results });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/:id/members - Get all members of a coaching
    async getMembers(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const members = await coachingService.getMembers(coachingId);
            res.json({ members });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching/:id/members/ward - Add a ward under a parent
    async addWard(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const { parentUserId, wardName } = req.body;

            if (!parentUserId || !wardName) {
                return res.status(400).json({ message: 'parentUserId and wardName are required' });
            }

            const ward = await coachingService.addWardMember(coachingId, parentUserId, wardName);
            res.status(201).json({ ward });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // DELETE /coaching/:id/members/:memberId - Remove a member from coaching
    async removeMember(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const memberId = req.params.memberId as string;

            await coachingService.removeMember(coachingId, memberId);
            res.json({ message: 'Member removed successfully' });
        } catch (error: any) {
            if (error.message.includes('not found')) {
                return res.status(404).json({ message: error.message });
            }
            res.status(500).json({ message: error.message });
        }
    }

    // PATCH /coaching/:id/members/:memberId - Update member role
    async updateMemberRole(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const memberId = req.params.memberId as string;
            const { role } = req.body;

            if (!role) {
                return res.status(400).json({ message: 'Role is required' });
            }

            const member = await coachingService.updateMemberRole(coachingId, memberId, role);
            res.json({ member });
        } catch (error: any) {
            if (error.message.includes('not found')) {
                return res.status(404).json({ message: error.message });
            }
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching/:id/onboarding/profile - Update coaching profile during onboarding
    async updateOnboardingProfile(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const coaching = await coachingService.findById(coachingId);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            if (coaching.ownerId !== userId) {
                return res.status(403).json({ message: 'Only owner can update coaching profile' });
            }

            const updated = await coachingService.updateProfile(coachingId, req.body);
            res.json({ coaching: updated });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching/:id/onboarding/address - Set coaching address with GPS
    async updateOnboardingAddress(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const coaching = await coachingService.findById(coachingId);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            if (coaching.ownerId !== userId) {
                return res.status(403).json({ message: 'Only owner can update coaching address' });
            }

            const address = await coachingService.setAddress(coachingId, req.body);
            res.json({ address });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching/:id/onboarding/branch - Add a branch
    async addBranch(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const coaching = await coachingService.findById(coachingId);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            if (coaching.ownerId !== userId) {
                return res.status(403).json({ message: 'Only owner can add branches' });
            }

            const branch = await coachingService.addBranch(coachingId, req.body);
            res.json({ branch });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/:id/branches - Get coaching branches
    async getBranches(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const branches = await coachingService.getBranches(coachingId);
            res.json({ branches });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // DELETE /coaching/:id/branches/:branchId - Delete a branch
    async deleteBranch(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const branchId = req.params.branchId as string;

            const coaching = await coachingService.findById(coachingId);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            if (coaching.ownerId !== userId) {
                return res.status(403).json({ message: 'Only owner can delete branches' });
            }

            await coachingService.deleteBranch(branchId, coachingId);
            res.json({ message: 'Branch deleted successfully' });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching/:id/onboarding/complete - Mark onboarding as complete
    async completeOnboarding(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) {
                return res.status(401).json({ message: 'Unauthorized' });
            }

            const coachingId = req.params.id as string;
            const coaching = await coachingService.findById(coachingId);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            if (coaching.ownerId !== userId) {
                return res.status(403).json({ message: 'Only owner can complete onboarding' });
            }

            const updated = await coachingService.completeOnboarding(coachingId);
            res.json({ coaching: updated });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/:id/full - Get coaching with all details (address, branches)
    async getFullDetails(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const coaching = await coachingService.getFullDetails(coachingId);

            if (!coaching) {
                return res.status(404).json({ message: 'Coaching not found' });
            }

            res.json({ coaching });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // ── Saved / Bookmarked Coachings ──────────────────────────────────

    // GET /coaching/saved - Get user's saved coachings
    async getSavedCoachings(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const saved = await coachingService.getSavedCoachings(userId);
            res.json({ saved });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // POST /coaching/:id/save - Save / bookmark a coaching
    async saveCoaching(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const coachingId = req.params.id as string;
            await coachingService.saveCoaching(userId, coachingId);
            res.json({ saved: true });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // DELETE /coaching/:id/save - Unsave a coaching
    async unsaveCoaching(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            if (!userId) return res.status(401).json({ message: 'Unauthorized' });

            const coachingId = req.params.id as string;
            await coachingService.unsaveCoaching(userId, coachingId);
            res.json({ saved: false });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // GET /coaching/:id/members/:memberId/academic-history
    async getMemberAcademicHistory(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const memberId = req.params.memberId as string;
            const results = await coachingService.getMemberAcademicHistory(coachingId, memberId);
            res.json({ results });
        } catch (error: any) {
            if (error.message.includes('not found')) {
                return res.status(404).json({ message: error.message });
            }
            res.status(500).json({ message: error.message });
        }
    }
}
