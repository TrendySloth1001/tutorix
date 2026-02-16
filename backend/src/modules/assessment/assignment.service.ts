import prisma from '../../infra/prisma.js';
import { onAssignmentCreated } from '../notification/notification.hooks.js';

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateAssignmentDto {
    title: string;
    description?: string;
    dueDate?: string;
    allowLateSubmission?: boolean;
    totalMarks?: number;
}

export interface GradeSubmissionDto {
    marks: number;
    feedback?: string;
}

// ─── Selects ─────────────────────────────────────────────────────────

const ASSIGNMENT_LIST_SELECT = {
    id: true,
    title: true,
    description: true,
    dueDate: true,
    allowLateSubmission: true,
    totalMarks: true,
    status: true,
    createdAt: true,
    createdBy: { select: { id: true, name: true, picture: true } },
    attachments: {
        select: { id: true, url: true, fileName: true, fileType: true, fileSize: true },
    },
    _count: { select: { submissions: true } },
} as const;

const SUBMISSION_SELECT = {
    id: true,
    marks: true,
    feedback: true,
    gradedAt: true,
    isLate: true,
    status: true,
    submittedAt: true,
    user: { select: { id: true, name: true, picture: true } },
    files: {
        select: { id: true, url: true, fileName: true, fileType: true, fileSize: true },
    },
} as const;

// ─── Service ─────────────────────────────────────────────────────────

class AssignmentService {
    // ── Create assignment ──
    async create(
        coachingId: string,
        batchId: string,
        userId: string,
        dto: CreateAssignmentDto,
        fileUrls?: { url: string; fileName: string; fileType: string; fileSize: number; mimeType?: string }[]
    ) {
        const result = await prisma.assignment.create({
            data: {
                coachingId,
                batchId,
                title: dto.title,
                description: dto.description ?? null,
                dueDate: dto.dueDate ? new Date(dto.dueDate) : null,
                allowLateSubmission: dto.allowLateSubmission ?? false,
                totalMarks: dto.totalMarks ?? null,
                createdById: userId,
                ...(fileUrls && fileUrls.length > 0
                    ? { attachments: { create: fileUrls } }
                    : {}),
            },
            select: ASSIGNMENT_LIST_SELECT,
        });

        // Fire notification for new assignment
        onAssignmentCreated(result.id, dto.title, batchId, coachingId);

        return result;
    }

    // ── List assignments for a batch ──
    async listByBatch(batchId: string, userId?: string) {
        const assignments = await prisma.assignment.findMany({
            where: { batchId },
            select: ASSIGNMENT_LIST_SELECT,
            orderBy: { createdAt: 'desc' },
        });

        if (userId) {
            const submissions = await prisma.assignmentSubmission.findMany({
                where: {
                    assignmentId: { in: assignments.map(a => a.id) },
                    userId,
                },
                select: {
                    assignmentId: true,
                    status: true,
                    marks: true,
                    submittedAt: true,
                    isLate: true,
                },
            });
            const subMap = new Map(submissions.map(s => [s.assignmentId, s]));
            return assignments.map(a => ({
                ...a,
                mySubmission: subMap.get(a.id) || null,
            }));
        }

        return assignments;
    }

    // ── Get assignment detail ──
    async getById(id: string) {
        return prisma.assignment.findUnique({
            where: { id },
            select: {
                ...ASSIGNMENT_LIST_SELECT,
            },
        });
    }

    // ── Close assignment ──
    async updateStatus(id: string, status: string) {
        return prisma.assignment.update({
            where: { id },
            data: { status },
            select: ASSIGNMENT_LIST_SELECT,
        });
    }

    // ── Delete assignment ──
    async delete(id: string) {
        return prisma.assignment.delete({ where: { id } });
    }

    // ── Submit assignment (student) ──
    async submit(
        assignmentId: string,
        userId: string,
        fileUrls: { url: string; fileName: string; fileType: string; fileSize: number; mimeType?: string }[]
    ) {
        const assignment = await prisma.assignment.findUnique({
            where: { id: assignmentId },
            select: { dueDate: true, allowLateSubmission: true, status: true },
        });
        if (!assignment) throw new Error('Assignment not found');
        if (assignment.status !== 'ACTIVE') throw new Error('Assignment is closed');

        const now = new Date();
        const isLate = assignment.dueDate ? now > assignment.dueDate : false;
        if (isLate && !assignment.allowLateSubmission) {
            throw new Error('Submission deadline has passed');
        }

        // Upsert — student can resubmit
        const existing = await prisma.assignmentSubmission.findUnique({
            where: { assignmentId_userId: { assignmentId, userId } },
        });

        if (existing) {
            // Delete old files, add new ones
            return prisma.$transaction(async (tx) => {
                await tx.assignmentSubmissionFile.deleteMany({
                    where: { submissionId: existing.id },
                });
                return tx.assignmentSubmission.update({
                    where: { id: existing.id },
                    data: {
                        isLate,
                        status: 'SUBMITTED',
                        submittedAt: now,
                        marks: null,
                        feedback: null,
                        gradedAt: null,
                        files: { create: fileUrls },
                    },
                    select: SUBMISSION_SELECT,
                });
            });
        }

        return prisma.assignmentSubmission.create({
            data: {
                assignmentId,
                userId,
                isLate,
                files: { create: fileUrls },
            },
            select: SUBMISSION_SELECT,
        });
    }

    // ── Get all submissions for an assignment (teacher view) ──
    async getSubmissions(assignmentId: string) {
        return prisma.assignmentSubmission.findMany({
            where: { assignmentId },
            select: SUBMISSION_SELECT,
            orderBy: { submittedAt: 'desc' },
        });
    }

    // ── Get student's submission ──
    async getMySubmission(assignmentId: string, userId: string) {
        return prisma.assignmentSubmission.findUnique({
            where: { assignmentId_userId: { assignmentId, userId } },
            select: SUBMISSION_SELECT,
        });
    }

    // ── Grade submission (teacher) ──
    async gradeSubmission(submissionId: string, dto: GradeSubmissionDto) {
        return prisma.assignmentSubmission.update({
            where: { id: submissionId },
            data: {
                marks: dto.marks,
                feedback: dto.feedback ?? null,
                gradedAt: new Date(),
                status: 'GRADED',
            },
            select: SUBMISSION_SELECT,
        });
    }
}

export const assignmentService = new AssignmentService();
