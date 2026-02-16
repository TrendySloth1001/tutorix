import prisma from '../../infra/prisma.js';
import { NotificationService } from './notification.service.js';

const notificationService = new NotificationService();

/**
 * Create a coaching-level notification when something is published/created in a batch.
 * This ensures students see updates in the coaching notifications feed.
 */
async function notifyCoaching(
    coachingId: string,
    type: string,
    title: string,
    message: string,
    data?: Record<string, any>
) {
    try {
        await notificationService.create({
            coachingId,
            type,
            title,
            message,
            data,
        });
    } catch (err) {
        // Don't let notification failures break the primary flow
        console.error('[NotificationHook] Failed to create notification:', err);
    }
}

/**
 * Called when an assessment is published.
 * Gets the coachingId from the batch and sends a coaching notification.
 */
export async function onAssessmentPublished(assessmentId: string) {
    try {
        const assessment = await prisma.assessment.findUnique({
            where: { id: assessmentId },
            select: {
                title: true,
                type: true,
                batchId: true,
                batch: {
                    select: {
                        name: true,
                        coachingId: true,
                    },
                },
                _count: { select: { questions: true } },
            },
        });

        if (!assessment?.batch) return;

        const isQuiz = assessment.type === 'QUIZ';
        const label = isQuiz ? 'Quiz' : 'Test';

        await notifyCoaching(
            assessment.batch.coachingId,
            isQuiz ? 'NEW_QUIZ' : 'NEW_ASSESSMENT',
            `New ${label}: ${assessment.title}`,
            `A new ${label.toLowerCase()} with ${assessment._count.questions} question(s) has been published in ${assessment.batch.name}.`,
            {
                assessmentId,
                batchId: assessment.batchId,
                batchName: assessment.batch.name,
                type: assessment.type,
            }
        );
    } catch (err) {
        console.error('[NotificationHook] onAssessmentPublished error:', err);
    }
}

/**
 * Called when a new assignment is created.
 */
export async function onAssignmentCreated(
    assignmentId: string,
    title: string,
    batchId: string,
    coachingId: string
) {
    try {
        const batch = await prisma.batch.findUnique({
            where: { id: batchId },
            select: { name: true },
        });

        await notifyCoaching(
            coachingId,
            'NEW_ASSIGNMENT',
            `New Assignment: ${title}`,
            `A new assignment has been posted in ${batch?.name ?? 'your batch'}.`,
            {
                assignmentId,
                batchId,
                batchName: batch?.name,
            }
        );
    } catch (err) {
        console.error('[NotificationHook] onAssignmentCreated error:', err);
    }
}

/**
 * Called when a batch notice is created.
 */
export async function onNoticeCreated(
    noticeId: string,
    title: string,
    batchId: string
) {
    try {
        const batch = await prisma.batch.findUnique({
            where: { id: batchId },
            select: { name: true, coachingId: true },
        });

        if (!batch) return;

        await notifyCoaching(
            batch.coachingId,
            'NEW_NOTICE',
            `Notice: ${title}`,
            `A new notice has been posted in ${batch.name}.`,
            {
                noticeId,
                batchId,
                batchName: batch.name,
            }
        );
    } catch (err) {
        console.error('[NotificationHook] onNoticeCreated error:', err);
    }
}
