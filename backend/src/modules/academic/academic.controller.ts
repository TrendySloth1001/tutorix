import type { Request, Response } from 'express';
import { AcademicService } from './academic.service.js';
import {
    getAcademicMasters,
    getCompetitiveExamsByCategory,
    getClassesGrouped,
    getSubjectsForClassAndStream,
} from './masters.js';

export class AcademicController {
    private service = new AcademicService();

    /**
     * GET /academic/masters
     * Returns all static academic master data (boards, classes, streams, exams, subjects)
     */
    getMasters = async (req: Request, res: Response) => {
        try {
            const { classId, streamId, grouped } = req.query;

            // If filtering by class/stream for subjects
            if (classId) {
                const subjects = getSubjectsForClassAndStream(
                    classId as string,
                    streamId as string | undefined
                );
                return res.json({ subjects });
            }

            // If requesting grouped view
            if (grouped === 'true') {
                return res.json({
                    ...getAcademicMasters(),
                    classesGrouped: getClassesGrouped(),
                    competitiveExamsByCategory: getCompetitiveExamsByCategory(),
                });
            }

            // Default: return all masters
            return res.json(getAcademicMasters());
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    };

    /**
     * GET /academic/profile
     * Get current user's academic profile
     */
    getProfile = async (req: Request, res: Response) => {
        try {
            const userId = (req as any).user.id;
            const profile = await this.service.getProfile(userId);
            return res.json(profile);
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    };

    /**
     * POST /academic/profile
     * Save/update user's academic profile
     */
    saveProfile = async (req: Request, res: Response) => {
        try {
            const userId = (req as any).user.id;
            const profile = await this.service.saveProfile(userId, req.body);
            return res.json(profile);
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    };

    /**
     * PATCH /academic/remind-later
     * Set "remind me later" with 2-day buffer
     */
    remindLater = async (req: Request, res: Response) => {
        try {
            const userId = (req as any).user.id;
            const result = await this.service.setRemindLater(userId);
            return res.json(result);
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    };

    /**
     * GET /academic/onboarding-status
     * Check if user needs to complete academic onboarding
     */
    getOnboardingStatus = async (req: Request, res: Response) => {
        try {
            const userId = (req as any).user.id;
            const status = await this.service.getOnboardingStatus(userId);
            return res.json(status);
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    };
}
