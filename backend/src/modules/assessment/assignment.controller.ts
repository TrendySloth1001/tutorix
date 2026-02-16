import type { Request, Response } from 'express';
import { assignmentService } from './assignment.service.js';
import { storageService } from '../../infra/storage.js';
import crypto from 'crypto';

export class AssignmentController {
    // ── Create assignment ──
    async create(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id;
            const files = (req as any).files as Express.Multer.File[] | undefined;

            let fileUrls: { url: string; fileName: string; fileType: string; fileSize: number; mimeType: string }[] = [];
            if (files && files.length > 0) {
                fileUrls = await Promise.all(
                    files.map(async (f) => {
                        const ext = f.originalname.split('.').pop() || 'bin';
                        const key = `assignments/${coachingId as string}/${batchId as string}/${crypto.randomUUID()}.${ext}`;
                        const url = await storageService.uploadFile('batch-notes', key, f.buffer, f.mimetype);
                        const isImage = f.mimetype.startsWith('image/');
                        return {
                            url,
                            fileName: f.originalname,
                            fileType: isImage ? 'image' : 'pdf',
                            fileSize: f.size,
                            mimeType: f.mimetype,
                        };
                    })
                );
            }

            const body = typeof req.body.data === 'string' ? JSON.parse(req.body.data) : req.body;
            const result = await assignmentService.create(coachingId, batchId, userId, body, fileUrls);
            res.status(201).json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── List assignments ──
    async list(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id;
            const role = req.query.role as string;
            const result = await assignmentService.listByBatch(
                batchId,
                role === 'STUDENT' ? userId : undefined
            );
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Get assignment detail ──
    async getById(req: Request, res: Response) {
        try {
            const result = await assignmentService.getById(req.params.assignmentId as string);
            if (!result) return res.status(404).json({ error: 'Not found' });
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Update status ──
    async updateStatus(req: Request, res: Response) {
        try {
            const result = await assignmentService.updateStatus(req.params.assignmentId as string, req.body.status);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Delete ──
    async delete(req: Request, res: Response) {
        try {
            await assignmentService.delete(req.params.assignmentId as string);
            res.json({ success: true });
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Submit assignment (student) ──
    async submit(req: Request, res: Response) {
        try {
            const assignmentId = req.params.assignmentId as string;
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id;
            const files = (req as any).files as Express.Multer.File[];

            if (!files || files.length === 0) {
                return res.status(400).json({ error: 'At least one file is required' });
            }

            const fileUrls = await Promise.all(
                files.map(async (f) => {
                    const ext = f.originalname.split('.').pop() || 'bin';
                    const key = `submissions/${coachingId}/${batchId}/${userId}/${crypto.randomUUID()}.${ext}`;
                    const url = await storageService.uploadFile('batch-notes', key, f.buffer, f.mimetype);
                    const isImage = f.mimetype.startsWith('image/');
                    return {
                        url,
                        fileName: f.originalname,
                        fileType: isImage ? 'image' : 'pdf',
                        fileSize: f.size,
                        mimeType: f.mimetype,
                    };
                })
            );

            const result = await assignmentService.submit(assignmentId, userId, fileUrls);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Get submissions (teacher) ──
    async getSubmissions(req: Request, res: Response) {
        try {
            const result = await assignmentService.getSubmissions(req.params.assignmentId as string);
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Get my submission (student) ──
    async getMySubmission(req: Request, res: Response) {
        try {
            const userId = (req as any).user?.id;
            const result = await assignmentService.getMySubmission(req.params.assignmentId as string, userId);
            res.json(result || null);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Grade submission ──
    async grade(req: Request, res: Response) {
        try {
            const result = await assignmentService.gradeSubmission(req.params.submissionId as string, req.body);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }
}
