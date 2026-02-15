import type { Request, Response } from 'express';
import { BatchService } from './batch.service.js';
import prisma from '../../infra/prisma.js';

const batchService = new BatchService();

export class BatchController {

    // ── Batch CRUD ────────────────────────────────────────────────────

    async create(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;

            // Verify admin/owner
            const coaching = await this.verifyCoachingAdmin(coachingId, userId);
            if (!coaching) {
                return res.status(403).json({ message: 'Only admins can create batches' });
            }

            const { name, subject, description, startTime, endTime, days, maxStudents } = req.body;
            if (!name) {
                return res.status(400).json({ message: 'Batch name is required' });
            }

            const batch = await batchService.create(coachingId, {
                name, subject, description, startTime, endTime, days, maxStudents,
            });

            res.status(201).json({ batch });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async list(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const status = req.query.status as string | undefined;

            const batches = await batchService.list(coachingId, status);
            res.json({ batches });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async getById(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const batch = await batchService.getById(batchId);

            if (!batch) {
                return res.status(404).json({ message: 'Batch not found' });
            }
            res.json({ batch });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async update(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id as string;

            const coaching = await this.verifyCoachingAdmin(coachingId, userId);
            if (!coaching) {
                return res.status(403).json({ message: 'Only admins can update batches' });
            }

            const { name, subject, description, startTime, endTime, days, maxStudents, status } = req.body;
            const batch = await batchService.update(batchId, {
                name, subject, description, startTime, endTime, days, maxStudents, status,
            });

            res.json({ batch });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async delete(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id as string;

            const coaching = await this.verifyCoachingAdmin(coachingId, userId);
            if (!coaching) {
                return res.status(403).json({ message: 'Only admins can delete batches' });
            }

            await batchService.delete(batchId);
            res.json({ success: true });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // ── Members ───────────────────────────────────────────────────────

    async addMembers(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id as string;

            const coaching = await this.verifyCoachingAdmin(coachingId, userId);
            if (!coaching) {
                return res.status(403).json({ message: 'Only admins can add members to batches' });
            }

            const { memberIds, role } = req.body;
            if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
                return res.status(400).json({ message: 'memberIds array is required' });
            }

            await batchService.addMembers(batchId, memberIds, role || 'STUDENT');
            const members = await batchService.getMembers(batchId);
            res.json({ members });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async removeMember(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchMemberId = req.params.batchMemberId as string;
            const userId = (req as any).user?.id as string;

            const coaching = await this.verifyCoachingAdmin(coachingId, userId);
            if (!coaching) {
                return res.status(403).json({ message: 'Only admins can remove batch members' });
            }

            await batchService.removeMember(batchMemberId);
            res.json({ success: true });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async getMembers(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const members = await batchService.getMembers(batchId);
            res.json({ members });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async getAvailableMembers(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const role = req.query.role as string | undefined;
            const members = await batchService.getAvailableMembers(coachingId, batchId, role);
            res.json({ members });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // ── Notes ─────────────────────────────────────────────────────────

    async createNote(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;

            // Teachers + admins can upload notes
            const access = await batchService.verifyBatchTeacher(batchId, userId);
            if (!access) {
                return res.status(403).json({ message: 'Only teachers/admins can upload notes' });
            }

            const { title, description, attachments } = req.body;
            if (!title) {
                return res.status(400).json({ message: 'Title is required' });
            }

            // Check storage quota before creating
            const totalSize = (attachments || []).reduce((s: number, a: any) => s + (a.fileSize || 0), 0);
            if (totalSize > 0) {
                const usage = await batchService.getStorageUsage(coachingId);
                if (usage.used + totalSize > usage.limit) {
                    return res.status(413).json({
                        message: 'Storage limit exceeded',
                        used: usage.used,
                        limit: usage.limit,
                    });
                }
            }

            const note = await batchService.createNote(batchId, userId, {
                title, description, attachments,
            });

            // Update storage counter
            if (totalSize > 0) {
                await batchService.addStorageUsage(coachingId, totalSize);
            }

            res.status(201).json({ note });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async listNotes(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const notes = await batchService.listNotes(batchId);
            res.json({ notes });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async deleteNote(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const coachingId = req.params.coachingId as string;
            const noteId = req.params.noteId as string;
            const userId = (req as any).user?.id as string;

            const access = await batchService.verifyBatchTeacher(batchId, userId);
            if (!access) {
                return res.status(403).json({ message: 'Only teachers/admins can delete notes' });
            }

            // Subtract storage before deleting
            const bytes = await batchService.getNoteAttachmentsSize(noteId);
            await batchService.deleteNote(noteId);
            if (bytes > 0) {
                await batchService.subtractStorageUsage(coachingId, bytes);
            }

            res.json({ success: true });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async getStorage(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const usage = await batchService.getStorageUsage(coachingId);
            res.json(usage);
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // ── Notices ───────────────────────────────────────────────────────

    async createNotice(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id as string;

            const access = await batchService.verifyBatchTeacher(batchId, userId);
            if (!access) {
                return res.status(403).json({ message: 'Only teachers/admins can send notices' });
            }

            const { title, message, priority } = req.body;
            if (!title || !message) {
                return res.status(400).json({ message: 'Title and message are required' });
            }

            const notice = await batchService.createNotice(batchId, userId, {
                title, message, priority,
            });
            res.status(201).json({ notice });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async listNotices(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const notices = await batchService.listNotices(batchId);
            res.json({ notices });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async deleteNotice(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const noticeId = req.params.noticeId as string;
            const userId = (req as any).user?.id as string;

            const access = await batchService.verifyBatchTeacher(batchId, userId);
            if (!access) {
                return res.status(403).json({ message: 'Only teachers/admins can delete notices' });
            }

            await batchService.deleteNotice(noticeId);
            res.json({ success: true });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // ── My Batches ────────────────────────────────────────────────────

    async getMyBatches(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            const batches = await batchService.getMyBatches(coachingId, userId);
            res.json({ batches });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    async getRecentNotes(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const userId = (req as any).user?.id as string;
            const notes = await batchService.getRecentNotes(userId, coachingId);
            res.json({ notes });
        } catch (error: any) {
            res.status(500).json({ message: error.message });
        }
    }

    // ── Private helpers ───────────────────────────────────────────────

    private async verifyCoachingAdmin(coachingId: string, userId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { id: true, ownerId: true },
        });
        if (!coaching) return null;
        if (coaching.ownerId === userId) return coaching;

        const admin = await prisma.coachingMember.findFirst({
            where: { coachingId, userId, role: 'ADMIN', status: 'active' },
        });
        return admin ? coaching : null;
    }
}
