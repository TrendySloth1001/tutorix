import prisma from '../../infra/prisma.js';
import { onAssessmentPublished } from '../notification/notification.hooks.js';

// ─── DTOs ────────────────────────────────────────────────────────────

export interface QuestionOptionDto {
    id: string;
    text: string;
    imageUrl?: string;
}

export interface CreateQuestionDto {
    type: 'MCQ' | 'MSQ' | 'NAT';
    question: string;
    imageUrl?: string;
    options?: QuestionOptionDto[];
    correctAnswer: any; // MCQ: string, MSQ: string[], NAT: { value: number, tolerance?: number }
    marks?: number;
    orderIndex?: number;
    explanation?: string;
}

export interface CreateAssessmentDto {
    title: string;
    description?: string;
    type?: string;
    durationMinutes?: number;
    startTime?: string;
    endTime?: string;
    totalMarks?: number;
    passingMarks?: number;
    shuffleQuestions?: boolean;
    shuffleOptions?: boolean;
    showResultAfter?: string;
    maxAttempts?: number;
    negativeMarking?: number;
    questions?: CreateQuestionDto[];
}

export interface SubmitAnswerDto {
    questionId: string;
    answer: any;
}

// ─── Selects ─────────────────────────────────────────────────────────

const ASSESSMENT_LIST_SELECT = {
    id: true,
    title: true,
    description: true,
    type: true,
    durationMinutes: true,
    startTime: true,
    endTime: true,
    totalMarks: true,
    passingMarks: true,
    status: true,
    maxAttempts: true,
    negativeMarking: true,
    createdAt: true,
    createdBy: { select: { id: true, name: true, picture: true } },
    _count: { select: { questions: true, attempts: true } },
} as const;

const QUESTION_SELECT = {
    id: true,
    type: true,
    question: true,
    imageUrl: true,
    options: true,
    marks: true,
    orderIndex: true,
    explanation: true,
    // correctAnswer intentionally excluded for student views
} as const;

const QUESTION_WITH_ANSWER_SELECT = {
    ...QUESTION_SELECT,
    correctAnswer: true,
} as const;

const ATTEMPT_SELECT = {
    id: true,
    startedAt: true,
    submittedAt: true,
    totalScore: true,
    maxScore: true,
    percentage: true,
    correctCount: true,
    wrongCount: true,
    skippedCount: true,
    status: true,
    user: { select: { id: true, name: true, picture: true } },
} as const;

// ─── Service ─────────────────────────────────────────────────────────

class AssessmentService {
    // ── Create assessment with questions in one transaction ──
    async create(coachingId: string, batchId: string, userId: string, dto: CreateAssessmentDto) {
        const questions = dto.questions || [];
        const totalMarks = dto.totalMarks ?? questions.reduce((sum, q) => sum + (q.marks || 1), 0);

        return prisma.$transaction(async (tx) => {
            const assessment = await tx.assessment.create({
                data: {
                    coachingId,
                    batchId,
                    title: dto.title,
                    description: dto.description ?? null,
                    type: dto.type || 'QUIZ',
                    durationMinutes: dto.durationMinutes ?? null,
                    startTime: dto.startTime ? new Date(dto.startTime) : null,
                    endTime: dto.endTime ? new Date(dto.endTime) : null,
                    totalMarks,
                    passingMarks: dto.passingMarks ?? null,
                    shuffleQuestions: dto.shuffleQuestions ?? false,
                    shuffleOptions: dto.shuffleOptions ?? false,
                    showResultAfter: dto.showResultAfter || 'SUBMIT',
                    maxAttempts: dto.maxAttempts ?? 1,
                    negativeMarking: dto.negativeMarking ?? 0,
                    status: questions.length > 0 ? 'PUBLISHED' : 'DRAFT',
                    createdById: userId,
                },
            });

            if (questions.length > 0) {
                await tx.assessmentQuestion.createMany({
                    data: questions.map((q, i) => ({
                        assessmentId: assessment.id,
                        type: q.type,
                        question: q.question,
                        imageUrl: q.imageUrl ?? null,
                        options: q.options ? JSON.parse(JSON.stringify(q.options)) : null,
                        correctAnswer: JSON.parse(JSON.stringify(q.correctAnswer)),
                        marks: q.marks || 1,
                        orderIndex: q.orderIndex ?? i,
                        explanation: q.explanation ?? null,
                    })),
                });
            }

            // Query within the same transaction to ensure data is visible
            return tx.assessment.findUnique({
                where: { id: assessment.id },
                select: {
                    ...ASSESSMENT_LIST_SELECT,
                    shuffleQuestions: true,
                    shuffleOptions: true,
                    showResultAfter: true,
                    questions: {
                        select: QUESTION_WITH_ANSWER_SELECT,
                        orderBy: { orderIndex: 'asc' },
                    },
                },
            });
        });
    }

    // ── List assessments for a batch ──
    async listByBatch(batchId: string, userId?: string) {
        const assessments = await prisma.assessment.findMany({
            where: { batchId },
            select: ASSESSMENT_LIST_SELECT,
            orderBy: { createdAt: 'desc' },
        });

        // If userId, attach attempt info
        if (userId) {
            const attempts = await prisma.assessmentAttempt.findMany({
                where: {
                    assessmentId: { in: assessments.map(a => a.id) },
                    userId,
                },
                select: {
                    id: true,
                    assessmentId: true,
                    status: true,
                    totalScore: true,
                    percentage: true,
                    submittedAt: true,
                },
                orderBy: { startedAt: 'desc' },
            });

            const attemptMap = new Map<string, typeof attempts>();
            for (const a of attempts) {
                const list = attemptMap.get(a.assessmentId) || [];
                list.push(a);
                attemptMap.set(a.assessmentId, list);
            }

            return assessments.map(a => ({
                ...a,
                myAttempts: attemptMap.get(a.id) || [],
            }));
        }

        return assessments;
    }

    // ── Get assessment detail ──
    async getById(id: string, includeAnswers = false) {
        return prisma.assessment.findUnique({
            where: { id },
            select: {
                ...ASSESSMENT_LIST_SELECT,
                shuffleQuestions: true,
                shuffleOptions: true,
                showResultAfter: true,
                questions: {
                    select: includeAnswers ? QUESTION_WITH_ANSWER_SELECT : QUESTION_SELECT,
                    orderBy: { orderIndex: 'asc' },
                },
            },
        });
    }

    // ── Publish / Close assessment ──
    async updateStatus(id: string, status: string) {
        const result = await prisma.assessment.update({
            where: { id },
            data: { status },
            select: ASSESSMENT_LIST_SELECT,
        });

        // Fire notification when assessment is published
        if (status === 'PUBLISHED') {
            onAssessmentPublished(id);
        }

        return result;
    }

    // ── Delete assessment ──
    async delete(id: string) {
        return prisma.assessment.delete({ where: { id } });
    }

    // ── Add questions to existing assessment ──
    async addQuestions(assessmentId: string, questions: CreateQuestionDto[]) {
        const lastQ = await prisma.assessmentQuestion.findFirst({
            where: { assessmentId },
            orderBy: { orderIndex: 'desc' },
            select: { orderIndex: true },
        });
        const startIdx = (lastQ?.orderIndex ?? -1) + 1;

        await prisma.assessmentQuestion.createMany({
            data: questions.map((q, i) => ({
                assessmentId,
                type: q.type,
                question: q.question,
                imageUrl: q.imageUrl ?? null,
                options: q.options ? JSON.parse(JSON.stringify(q.options)) : null,
                correctAnswer: JSON.parse(JSON.stringify(q.correctAnswer)),
                marks: q.marks || 1,
                orderIndex: q.orderIndex ?? (startIdx + i),
                explanation: q.explanation ?? null,
            })),
        });

        // Recalculate totalMarks
        const agg = await prisma.assessmentQuestion.aggregate({
            where: { assessmentId },
            _sum: { marks: true },
        });
        await prisma.assessment.update({
            where: { id: assessmentId },
            data: { totalMarks: agg._sum.marks || 0 },
        });

        return this.getById(assessmentId, true);
    }

    // ── Delete question ──
    async deleteQuestion(questionId: string) {
        const q = await prisma.assessmentQuestion.delete({
            where: { id: questionId },
            select: { assessmentId: true },
        });
        // Recalculate totalMarks
        const agg = await prisma.assessmentQuestion.aggregate({
            where: { assessmentId: q.assessmentId },
            _sum: { marks: true },
        });
        await prisma.assessment.update({
            where: { id: q.assessmentId },
            data: { totalMarks: agg._sum.marks || 0 },
        });
    }

    // ── Start attempt ──
    async startAttempt(assessmentId: string, userId: string) {
        // Check max attempts
        const assessment = await prisma.assessment.findUnique({
            where: { id: assessmentId },
            select: { maxAttempts: true, status: true, startTime: true, endTime: true },
        });
        if (!assessment) throw new Error('Assessment not found');
        if (assessment.status !== 'PUBLISHED') throw new Error('Assessment is not available');

        // Check time window
        const now = new Date();
        if (assessment.startTime && now < assessment.startTime) throw new Error('Assessment has not started yet');
        if (assessment.endTime && now > assessment.endTime) throw new Error('Assessment deadline has passed');

        // Check existing attempts
        const attemptCount = await prisma.assessmentAttempt.count({
            where: { assessmentId, userId, status: 'SUBMITTED' },
        });
        if (attemptCount >= assessment.maxAttempts) throw new Error('Maximum attempts reached');

        // Check for in-progress attempt
        const existing = await prisma.assessmentAttempt.findFirst({
            where: { assessmentId, userId, status: 'IN_PROGRESS' },
            select: { id: true },
        });
        if (existing) return { attemptId: existing.id, resumed: true };

        const attempt = await prisma.assessmentAttempt.create({
            data: { assessmentId, userId },
        });
        return { attemptId: attempt.id, resumed: false };
    }

    // ── Save individual answer (auto-save) ──
    async saveAnswer(attemptId: string, questionId: string, answer: any) {
        await prisma.assessmentAnswer.upsert({
            where: { attemptId_questionId: { attemptId, questionId } },
            create: { attemptId, questionId, answer: JSON.parse(JSON.stringify(answer)) },
            update: { answer: JSON.parse(JSON.stringify(answer)), answeredAt: new Date() },
        });
    }

    // ── Submit attempt — calculates all results ──
    async submitAttempt(attemptId: string) {
        const attempt = await prisma.assessmentAttempt.findUnique({
            where: { id: attemptId },
            select: {
                id: true,
                status: true,
                assessmentId: true,
                answers: { select: { questionId: true, answer: true } },
                assessment: {
                    select: {
                        negativeMarking: true,
                        questions: {
                            select: { id: true, type: true, correctAnswer: true, marks: true },
                        },
                    },
                },
            },
        });

        if (!attempt) throw new Error('Attempt not found');
        if (attempt.status !== 'IN_PROGRESS') throw new Error('Already submitted');

        const { questions } = attempt.assessment;
        const negMark = attempt.assessment.negativeMarking;
        const answerMap = new Map(attempt.answers.map(a => [a.questionId, a.answer]));

        let totalScore = 0;
        let maxScore = 0;
        let correctCount = 0;
        let wrongCount = 0;
        let skippedCount = 0;

        const answerUpdates: { questionId: string; isCorrect: boolean; marksAwarded: number }[] = [];

        for (const q of questions) {
            maxScore += q.marks;
            const studentAnswer = answerMap.get(q.id);

            if (studentAnswer == null) {
                skippedCount++;
                answerUpdates.push({ questionId: q.id, isCorrect: false, marksAwarded: 0 });
                continue;
            }

            const isCorrect = this._checkAnswer(q.type, q.correctAnswer, studentAnswer);
            if (isCorrect) {
                correctCount++;
                totalScore += q.marks;
                answerUpdates.push({ questionId: q.id, isCorrect: true, marksAwarded: q.marks });
            } else {
                wrongCount++;
                const penalty = negMark * q.marks;
                totalScore -= penalty;
                answerUpdates.push({ questionId: q.id, isCorrect: false, marksAwarded: -penalty });
            }
        }

        totalScore = Math.max(0, totalScore); // floor at 0
        const percentage = maxScore > 0 ? Math.round((totalScore / maxScore) * 10000) / 100 : 0;

        // Update all in a transaction — batch answer updates to avoid N+1
        return prisma.$transaction(async (tx) => {
            // Batch: group answers by result to reduce to max 3 queries instead of N
            const correctQIds = answerUpdates.filter(u => u.isCorrect).map(u => u.questionId);
            const wrongUpdates = answerUpdates.filter(u => !u.isCorrect && u.marksAwarded !== 0);
            const skippedQIds = answerUpdates.filter(u => !u.isCorrect && u.marksAwarded === 0).map(u => u.questionId);

            // Batch 1: Mark all correct answers
            if (correctQIds.length > 0) {
                await tx.assessmentAnswer.updateMany({
                    where: { attemptId, questionId: { in: correctQIds } },
                    data: { isCorrect: true },
                });
                // Set marks per question (group by marks value to minimize queries)
                const markGroups = new Map<number, string[]>();
                for (const u of answerUpdates.filter(u => u.isCorrect)) {
                    const list = markGroups.get(u.marksAwarded) ?? [];
                    list.push(u.questionId);
                    markGroups.set(u.marksAwarded, list);
                }
                for (const [marks, qIds] of Array.from(markGroups.entries())) {
                    await tx.assessmentAnswer.updateMany({
                        where: { attemptId, questionId: { in: qIds } },
                        data: { marksAwarded: marks },
                    });
                }
            }

            // Batch 2: Mark all wrong answers (group by penalty value)
            if (wrongUpdates.length > 0) {
                const penaltyGroups = new Map<number, string[]>();
                for (const u of wrongUpdates) {
                    const list = penaltyGroups.get(u.marksAwarded) ?? [];
                    list.push(u.questionId);
                    penaltyGroups.set(u.marksAwarded, list);
                }
                for (const [penalty, qIds] of Array.from(penaltyGroups.entries())) {
                    await tx.assessmentAnswer.updateMany({
                        where: { attemptId, questionId: { in: qIds } },
                        data: { isCorrect: false, marksAwarded: penalty },
                    });
                }
            }

            // Batch 3: Mark all skipped
            if (skippedQIds.length > 0) {
                await tx.assessmentAnswer.updateMany({
                    where: { attemptId, questionId: { in: skippedQIds } },
                    data: { isCorrect: false, marksAwarded: 0 },
                });
            }

            // Update attempt
            return tx.assessmentAttempt.update({
                where: { id: attemptId },
                data: {
                    status: 'SUBMITTED',
                    submittedAt: new Date(),
                    totalScore,
                    maxScore,
                    percentage,
                    correctCount,
                    wrongCount,
                    skippedCount,
                },
                select: ATTEMPT_SELECT,
            });
        });
    }

    // ── Get attempt result (with answers + explanations) ──
    async getAttemptResult(attemptId: string) {
        return prisma.assessmentAttempt.findUnique({
            where: { id: attemptId },
            select: {
                ...ATTEMPT_SELECT,
                answers: {
                    select: {
                        questionId: true,
                        answer: true,
                        isCorrect: true,
                        marksAwarded: true,
                    },
                },
                assessment: {
                    select: {
                        title: true,
                        showResultAfter: true,
                        negativeMarking: true,
                        questions: {
                            select: QUESTION_WITH_ANSWER_SELECT,
                            orderBy: { orderIndex: 'asc' },
                        },
                    },
                },
            },
        });
    }

    // ── Get all attempts for an assessment (teacher view) ──
    async getAttemptsByAssessment(assessmentId: string) {
        return prisma.assessmentAttempt.findMany({
            where: { assessmentId, status: 'SUBMITTED' },
            select: ATTEMPT_SELECT,
            orderBy: { percentage: 'desc' },
        });
    }

    // ── Get student's saved answers for an in-progress attempt ──
    async getAttemptAnswers(attemptId: string) {
        return prisma.assessmentAnswer.findMany({
            where: { attemptId },
            select: { questionId: true, answer: true, answeredAt: true },
        });
    }

    // ── Answer checking logic ──
    private _checkAnswer(type: string, correct: any, student: any): boolean {
        switch (type) {
            case 'MCQ':
                return String(correct) === String(student);
            case 'MSQ': {
                const correctSet = new Set((correct as string[]).map(String));
                const studentSet = new Set((student as string[]).map(String));
                if (correctSet.size !== studentSet.size) return false;
                for (const v of Array.from(correctSet)) if (!studentSet.has(v)) return false;
                return true;
            }
            case 'NAT': {
                const c = correct as { value: number; tolerance?: number };
                const s = student as { value: number };
                const tolerance = c.tolerance ?? 0;
                return Math.abs(c.value - s.value) <= tolerance;
            }
            default:
                return false;
        }
    }
}

export const assessmentService = new AssessmentService();
