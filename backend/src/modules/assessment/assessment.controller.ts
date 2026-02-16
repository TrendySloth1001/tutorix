import type { Request, Response } from 'express';
import { assessmentService } from './assessment.service.js';

export class AssessmentController {
    // ── Create assessment ──
    async create(req: Request, res: Response) {
        try {
            const coachingId = req.params.coachingId as string;
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id;
            const result = await assessmentService.create(coachingId, batchId, userId, req.body);
            res.status(201).json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── List assessments for a batch ──
    async list(req: Request, res: Response) {
        try {
            const batchId = req.params.batchId as string;
            const userId = (req as any).user?.id;
            const role = req.query.role as string;
            const result = await assessmentService.listByBatch(
                batchId,
                role === 'STUDENT' ? userId : undefined
            );
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Get assessment detail ──
    async getById(req: Request, res: Response) {
        try {
            const role = req.query.role as string;
            const includeAnswers = role !== 'STUDENT';
            const result = await assessmentService.getById(req.params.assessmentId as string, includeAnswers);
            if (!result) return res.status(404).json({ error: 'Not found' });
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Update status (publish/close) ──
    async updateStatus(req: Request, res: Response) {
        try {
            const result = await assessmentService.updateStatus(req.params.assessmentId as string, req.body.status);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Delete assessment ──
    async delete(req: Request, res: Response) {
        try {
            await assessmentService.delete(req.params.assessmentId as string);
            res.json({ success: true });
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Add questions ──
    async addQuestions(req: Request, res: Response) {
        try {
            const result = await assessmentService.addQuestions(req.params.assessmentId as string, req.body.questions);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Delete question ──
    async deleteQuestion(req: Request, res: Response) {
        try {
            await assessmentService.deleteQuestion(req.params.questionId as string);
            res.json({ success: true });
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Start attempt ──
    async startAttempt(req: Request, res: Response) {
        try {
            const assessmentId = req.params.assessmentId as string;
            const userId = (req as any).user?.id;
            const result = await assessmentService.startAttempt(assessmentId, userId);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Save answer ──
    async saveAnswer(req: Request, res: Response) {
        try {
            const attemptId = req.params.attemptId as string;
            const { questionId, answer } = req.body;
            await assessmentService.saveAnswer(attemptId, questionId, answer);
            res.json({ success: true });
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Submit attempt ──
    async submitAttempt(req: Request, res: Response) {
        try {
            const attemptId = req.params.attemptId as string;
            const result = await assessmentService.submitAttempt(attemptId);
            res.json(result);
        } catch (err: any) {
            res.status(400).json({ error: err.message });
        }
    }

    // ── Get attempt result ──
    async getAttemptResult(req: Request, res: Response) {
        try {
            const attemptId = req.params.attemptId as string;
            const result = await assessmentService.getAttemptResult(attemptId);
            if (!result) return res.status(404).json({ error: 'Not found' });
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Get all attempts for assessment (teacher leaderboard) ──
    async getAttempts(req: Request, res: Response) {
        try {
            const result = await assessmentService.getAttemptsByAssessment(req.params.assessmentId as string);
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }

    // ── Get saved answers for in-progress attempt ──
    async getAttemptAnswers(req: Request, res: Response) {
        try {
            const result = await assessmentService.getAttemptAnswers(req.params.attemptId as string);
            res.json(result);
        } catch (err: any) {
            res.status(500).json({ error: err.message });
        }
    }
}
