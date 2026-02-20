import { type Request, type Response } from 'express';
import { FeeService } from './fee.service.js';
import {
    validateBody,
    createFeeStructureSchema,
    updateFeeStructureSchema,
    assignFeeSchema,
    recordPaymentSchema,
    waiveFeeSchema,
    recordRefundSchema,
    bulkRemindSchema,
    paginationSchema,
    financialYearSchema,
} from '../../shared/validation/fee.validation.js';

const svc = new FeeService();

/** Extract userId from auth middleware — throws if not present (M6 fix). */
function requireUserId(req: Request): string {
    const userId = (req as any).user?.id;
    if (!userId) throw Object.assign(new Error('Authentication required'), { status: 401 });
    return userId;
}

export class FeeController {

    // ── Fee Structures ─────────────────────────────────────────────

    async listStructures(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const data = await svc.listStructures(coachingId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
        }
    }

    async createStructure(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const dto = validateBody(createFeeStructureSchema, req.body);
            const data = await svc.createStructure(coachingId, dto);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
        }
    }

    async updateStructure(req: Request, res: Response) {
        try {
            const { coachingId, structureId } = req.params as { coachingId: string; structureId: string };
            const dto = validateBody(updateFeeStructureSchema, req.body);
            const data = await svc.updateStructure(coachingId, structureId, dto);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
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
            const userId = requireUserId(req);
            const dto = validateBody(assignFeeSchema, req.body);
            const data = await svc.assignFee(coachingId, dto, userId);
            res.status(201).json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
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
            const role: string = (req as any).coachingRole ?? '';
            // Non-admin users may only view their own profile
            if (role !== 'ADMIN' && role !== 'OWNER') {
                const ownMemberId: string = (req as any).coachingMemberId ?? '';
                if (ownMemberId !== memberId) {
                    return res.status(403).json({ error: 'You can only view your own fee profile' });
                }
            }
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
            // Validate pagination (M9 fix)
            const pagination = validateBody(paginationSchema, { page: page ?? 1, limit: limit ?? 30 });
            const query: Record<string, any> = { page: pagination.page, limit: pagination.limit };
            if (memberId !== undefined) query.memberId = memberId;
            if (status !== undefined) query.status = status;
            if (from !== undefined) query.from = from;
            if (to !== undefined) query.to = to;
            if (search !== undefined) query.search = search;
            const data = await svc.listRecords(coachingId, query);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
        }
    }

    async getFeeCalendar(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const { from, to } = req.query as { from: string; to: string };

            if (!from || !to) {
                throw Object.assign(new Error('Missing from/to dates'), { status: 400 });
            }
            const fromDate = new Date(from);
            const toDate = new Date(to);
            if (isNaN(fromDate.getTime()) || isNaN(toDate.getTime())) {
                throw Object.assign(new Error('Invalid from/to date format'), { status: 400 });
            }

            const data = await svc.getFeeCalendar(coachingId, fromDate, toDate);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getRecord(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const role: string = (req as any).coachingRole ?? '';
            const data = await svc.getRecordById(coachingId, recordId);
            // Non-admin users may only view records that belong to them
            if (role !== 'ADMIN' && role !== 'OWNER') {
                const ownMemberId: string = (req as any).coachingMemberId ?? '';
                if (data.memberId !== ownMemberId) {
                    return res.status(403).json({ error: 'You can only view your own fee records' });
                }
            }
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async recordPayment(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = requireUserId(req);
            const dto = validateBody(recordPaymentSchema, req.body);
            const data = await svc.recordPayment(coachingId, recordId, dto, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
        }
    }

    async waiveFee(req: Request, res: Response) {
        try {
            const { coachingId, recordId } = req.params as { coachingId: string; recordId: string };
            const userId = requireUserId(req);
            const dto = validateBody(waiveFeeSchema, req.body ?? {});
            const data = await svc.waiveFee(coachingId, recordId, dto, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
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
            // Validate financial year format if provided (M10 fix)
            if (fy) {
                validateBody(financialYearSchema, fy);
            }
            const data = await svc.getSummary(coachingId, fy);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
        }
    }

    async getMyFees(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            const data = await svc.getMyFees(coachingId, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }

    async getMyTransactions(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const userId = requireUserId(req);
            // Pagination for transactions (M8 fix)
            const { page, limit } = req.query as { page?: string; limit?: string };
            const pagination = validateBody(paginationSchema, { page: page ?? 1, limit: limit ?? 50 });
            const data = await svc.getMyTransactions(coachingId, userId, pagination);
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
            const userId = requireUserId(req);
            const dto = validateBody(recordRefundSchema, req.body);
            const data = await svc.recordRefund(coachingId, recordId, dto, userId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
        }
    }

    async bulkRemind(req: Request, res: Response) {
        try {
            const { coachingId } = req.params as { coachingId: string };
            const dto = validateBody(bulkRemindSchema, req.body ?? {});
            const data = await svc.bulkRemind(coachingId, dto);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message, ...(e.fieldErrors ? { fieldErrors: e.fieldErrors } : {}) });
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
            const role: string = (req as any).coachingRole ?? '';
            if (role !== 'ADMIN' && role !== 'OWNER') {
                const ownMemberId: string = (req as any).coachingMemberId ?? '';
                if (ownMemberId !== memberId) {
                    return res.status(403).json({ error: 'You can only view your own ledger' });
                }
            }
            const data = await svc.getStudentLedger(coachingId, memberId);
            res.json(data);
        } catch (e: any) {
            res.status(e.status ?? 500).json({ error: e.message });
        }
    }
}
