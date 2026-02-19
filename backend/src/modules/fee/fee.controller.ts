import { type Request, type Response } from 'express';
import { FeeService } from './fee.service.js';

const svc = new FeeService();

export class FeeController {

    // ── Fee Structures ─────────────────────────────────────────────

    async listStructures(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const data = await svc.listStructures(coachingId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async createStructure(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const data = await svc.createStructure(coachingId, req.body);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async updateStructure(req: Request, res: Response) {
        try {
            const { coachingId, structureId } = req.params as { coachingId: string; structureId: string };
            const data = await svc.updateStructure(coachingId, structureId, req.body);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async deleteStructure(req: Request, res: Response) {
        try {
            const { coachingId, structureId } = req.params as { coachingId: string; structureId: string };
            await svc.deleteStructure(coachingId, structureId);
            res.json({ success: true });
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    // ── Assignments ──────────────────────────────────────────────

    async assignFee(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = (req as any).user?.id;
            const data = await svc.assignFee(coachingId, req.body, userId);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async removeFeeAssignment(req: Request, res: Response) {
        try {
            const { coachingId, assignmentId } = req.params as { coachingId: string; assignmentId: string };
            await svc.removeFeeAssignment(coachingId, assignmentId);
            res.json({ success: true });
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getMemberFeeProfile(req: Request, res: Response) {
        try {
            const { coachingId, memberId } = req.params as { coachingId: string; memberId: string };
            const data = await svc.getMemberFeeProfile(coachingId, memberId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    // ── Fee Records ──────────────────────────────────────────────

    async listRecords(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const { memberId, status, from, to, page, limit, search } = req.query as Record<string, string | undefined>;
            const query: Record<string, any> = { page: page ? parseInt(page) : undefined, limit: limit ? parseInt(limit) : undefined };
            if (memberId !== undefined) query.memberId = memberId;
            if (status !== undefined) query.status = status;
            if (from !== undefined) query.from = from;
            if (to !== undefined) query.to = to;
            if (search !== undefined) query.search = search;
            const data = await svc.listRecords(coachingId, query);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getFeeCalendar(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const { from, to } = req.query as { from: string; to: string };

            if (!from || !to) throw { status: 400, message: 'Missing from/to dates' };

            const data = await svc.getFeeCalendar(coachingId, new Date(from), new Date(to));
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getRecord(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const data = await svc.getRecordById(coachingId, recordId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async recordPayment(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = (req as any).user?.id;
            const data = await svc.recordPayment(coachingId, recordId, req.body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async waiveFee(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = (req as any).user?.id;
            const data = await svc.waiveFee(coachingId, recordId, req.body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async sendReminder(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const data = await svc.sendReminder(coachingId, recordId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    // ── Summary & My Fees ────────────────────────────────────────

    async getSummary(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const { fy } = req.query as { fy?: string };
            const data = await svc.getSummary(coachingId, fy);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getMyFees(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = (req as any).user?.id;
            const data = await svc.getMyFees(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getMyTransactions(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = (req as any).user?.id;
            const data = await svc.getMyTransactions(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    // ── New endpoints ─────────────────────────────────────────────

    async toggleFeePause(req: Request, res: Response) {
        try {
            const { coachingId, assignmentId } = req.params as { coachingId: string; assignmentId: string };
            const { pause, note } = req.body as { pause: boolean; note?: string };
            const data = await svc.toggleFeePause(coachingId, assignmentId, pause, note);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async recordRefund(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = (req as any).user?.id;
            const data = await svc.recordRefund(coachingId, recordId, req.body, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async bulkRemind(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const data = await svc.bulkRemind(coachingId, req.body ?? {});
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getOverdueReport(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const data = await svc.getOverdueReport(coachingId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getStudentLedger(req: Request, res: Response) {
        try {
            const { coachingId, memberId } = req.params as { coachingId: string; memberId: string };
            const data = await svc.getStudentLedger(coachingId, memberId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }
}
