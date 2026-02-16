import prisma from '../../infra/prisma.js';
import { onNoticeCreated } from '../notification/notification.hooks.js';

// ─── DTOs ────────────────────────────────────────────────────────────

export interface CreateBatchDto {
    name: string;
    subject?: string;
    description?: string;
    startTime?: string;
    endTime?: string;
    days?: string[];
    maxStudents?: number;
}

export interface UpdateBatchDto {
    name?: string;
    subject?: string;
    description?: string;
    startTime?: string;
    endTime?: string;
    days?: string[];
    maxStudents?: number;
    status?: string;
}

// Reusable include for batch queries — keeps all queries consistent
const BATCH_LIST_SELECT = {
    id: true,
    name: true,
    subject: true,
    description: true,
    startTime: true,
    endTime: true,
    days: true,
    maxStudents: true,
    status: true,
    createdAt: true,
    updatedAt: true,
    _count: { select: { members: true, notes: true, notices: true } },
    members: {
        where: { role: 'TEACHER' },
        take: 1,
        select: {
            id: true,
            role: true,
            member: {
                select: {
                    id: true,
                    user: { select: { id: true, name: true, picture: true } },
                },
            },
        },
    },
} as const;

const BATCH_DETAIL_SELECT = {
    id: true,
    coachingId: true,
    name: true,
    subject: true,
    description: true,
    startTime: true,
    endTime: true,
    days: true,
    maxStudents: true,
    status: true,
    createdAt: true,
    updatedAt: true,
    _count: { select: { members: true, notes: true, notices: true } },
    members: {
        select: {
            id: true,
            role: true,
            createdAt: true,
            member: {
                select: {
                    id: true,
                    role: true,
                    user: { select: { id: true, name: true, picture: true, email: true } },
                    ward: { select: { id: true, name: true, picture: true } },
                },
            },
        },
        orderBy: [{ role: 'asc' as const }, { createdAt: 'asc' as const }],
    },
};

// ─── Service ─────────────────────────────────────────────────────────

export class BatchService {

    // ── CRUD ──────────────────────────────────────────────────────────

    async create(coachingId: string, data: CreateBatchDto) {
        return prisma.batch.create({
            data: { coachingId, ...data },
            select: BATCH_LIST_SELECT,
        });
    }

    async list(coachingId: string, status?: string) {
        return prisma.batch.findMany({
            where: {
                coachingId,
                ...(status ? { status } : {}),
            },
            select: BATCH_LIST_SELECT,
            orderBy: { createdAt: 'desc' },
        });
    }

    async getById(batchId: string) {
        return prisma.batch.findUnique({
            where: { id: batchId },
            select: BATCH_DETAIL_SELECT,
        });
    }

    async update(batchId: string, data: UpdateBatchDto) {
        return prisma.batch.update({
            where: { id: batchId },
            data,
            select: BATCH_LIST_SELECT,
        });
    }

    async delete(batchId: string) {
        return prisma.batch.delete({ where: { id: batchId } });
    }

    // ── Members ───────────────────────────────────────────────────────

    async addMembers(batchId: string, memberIds: string[], role: string = 'STUDENT') {
        // Use createMany with skipDuplicates for idempotent adds
        const result = await prisma.batchMember.createMany({
            data: memberIds.map(memberId => ({
                batchId,
                memberId,
                role,
            })),
            skipDuplicates: true,
        });
        return result;
    }

    async removeMember(batchMemberId: string) {
        return prisma.batchMember.delete({ where: { id: batchMemberId } });
    }

    async getMembers(batchId: string) {
        return prisma.batchMember.findMany({
            where: { batchId },
            select: {
                id: true,
                role: true,
                createdAt: true,
                member: {
                    select: {
                        id: true,
                        role: true,
                        user: { select: { id: true, name: true, picture: true, email: true } },
                        ward: { select: { id: true, name: true, picture: true } },
                    },
                },
            },
            orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
        });
    }

    /** Get coaching members NOT already in this batch — for the "Add Members" picker */
    async getAvailableMembers(coachingId: string, batchId: string, role?: string) {
        const existingMemberIds = await prisma.batchMember.findMany({
            where: { batchId },
            select: { memberId: true },
        });
        const ids = existingMemberIds.map(m => m.memberId);

        return prisma.coachingMember.findMany({
            where: {
                coachingId,
                status: 'active',
                id: { notIn: ids },
                ...(role ? { role } : {}),
            },
            select: {
                id: true,
                role: true,
                user: { select: { id: true, name: true, picture: true } },
                ward: { select: { id: true, name: true, picture: true } },
            },
            orderBy: { createdAt: 'asc' },
        });
    }

    // ── Notes (Study Material) ────────────────────────────────────────

    async createNote(batchId: string, uploadedById: string, data: {
        title: string;
        description?: string;
        attachments?: { url: string; fileName?: string; description?: string; fileType?: string; fileSize?: number; mimeType?: string }[];
    }) {
        const { attachments, ...noteData } = data;
        return prisma.batchNote.create({
            data: {
                batchId,
                uploadedById,
                ...noteData,
                ...(attachments && attachments.length > 0 ? {
                    attachments: {
                        create: attachments.map(a => ({
                            url: a.url,
                            fileName: a.fileName ?? null,
                            description: a.description ?? null,
                            fileType: a.fileType || 'pdf',
                            fileSize: a.fileSize || 0,
                            mimeType: a.mimeType ?? null,
                        })),
                    },
                } : {}),
            },
            include: {
                uploadedBy: { select: { id: true, name: true, picture: true } },
                attachments: { orderBy: { createdAt: 'asc' } },
            },
        });
    }

    async listNotes(batchId: string) {
        return prisma.batchNote.findMany({
            where: { batchId },
            include: {
                uploadedBy: { select: { id: true, name: true, picture: true } },
                attachments: { orderBy: { createdAt: 'asc' } },
            },
            orderBy: { createdAt: 'desc' },
        });
    }

    async getRecentNotes(userId: string, coachingId: string) {
        // Get user's wards in parallel with nothing (prep step)
        const userWards = await prisma.ward.findMany({
            where: { parentId: userId },
            select: { id: true },
        });
        const wardIds = userWards.map((w) => w.id);

        // Get coaching members for both user + wards
        const whereConditions: any[] = [{ userId }];
        if (wardIds.length > 0) {
            whereConditions.push({ wardId: { in: wardIds } });
        }

        // Single query: get batch IDs through coaching members → batch members
        const memberIds = (await prisma.coachingMember.findMany({
            where: { coachingId, OR: whereConditions },
            select: { id: true },
        })).map((m) => m.id);

        if (memberIds.length === 0) return [];

        const batchIds = (await prisma.batchMember.findMany({
            where: { memberId: { in: memberIds } },
            select: { batchId: true },
        })).map((b) => b.batchId);

        if (batchIds.length === 0) return [];

        // Get notes from last 7 days
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

        return prisma.batchNote.findMany({
            where: {
                batchId: { in: batchIds },
                createdAt: { gte: sevenDaysAgo },
            },
            include: {
                uploadedBy: { select: { id: true, name: true, picture: true } },
                attachments: { orderBy: { createdAt: 'asc' } },
                batch: { select: { id: true, name: true, subject: true } },
            },
            orderBy: { createdAt: 'desc' },
            take: 20,  // Limit results for performance
        });
    }

    async deleteNote(noteId: string) {
        // Attachments cascade-delete via Prisma relation
        return prisma.batchNote.delete({ where: { id: noteId } });
    }

    // ── Storage tracking ──────────────────────────────────────────────

    /** Add bytes to coaching storage counter */
    async addStorageUsage(coachingId: string, bytes: number) {
        return prisma.coaching.update({
            where: { id: coachingId },
            data: { storageUsed: { increment: bytes } },
            select: { storageUsed: true, storageLimit: true },
        });
    }

    /** Subtract bytes from coaching storage counter */
    async subtractStorageUsage(coachingId: string, bytes: number) {
        return prisma.coaching.update({
            where: { id: coachingId },
            data: { storageUsed: { decrement: bytes } },
            select: { storageUsed: true, storageLimit: true },
        });
    }

    /** Get current storage usage for a coaching */
    async getStorageUsage(coachingId: string) {
        const coaching = await prisma.coaching.findUnique({
            where: { id: coachingId },
            select: { storageUsed: true, storageLimit: true },
        });
        return {
            used: Number(coaching?.storageUsed ?? 0),
            limit: Number(coaching?.storageLimit ?? 524288000),
        };
    }

    /** Get total bytes of attachments for a note (for deletion) */
    async getNoteAttachmentsSize(noteId: string): Promise<number> {
        const attachments = await prisma.noteAttachment.findMany({
            where: { noteId },
            select: { fileSize: true },
        });
        return attachments.reduce((sum, a) => sum + a.fileSize, 0);
    }

    // ── Notices (Announcements) ───────────────────────────────────────

    async createNotice(batchId: string, sentById: string, data: {
        title: string;
        message: string;
        priority?: string;
        type?: string;
        date?: string;
        startTime?: string;
        endTime?: string;
        day?: string;
        location?: string;
    }) {
        const createData: Record<string, any> = {
            batchId,
            sentById,
            title: data.title,
            message: data.message,
        };
        if (data.priority) createData.priority = data.priority;
        if (data.type) createData.type = data.type;
        if (data.date) createData.date = new Date(data.date);
        if (data.startTime) createData.startTime = data.startTime;
        if (data.endTime) createData.endTime = data.endTime;
        if (data.day) createData.day = data.day;
        if (data.location) createData.location = data.location;

        return prisma.batchNotice.create({
            data: createData as any,
            include: {
                sentBy: { select: { id: true, name: true, picture: true } },
            },
        }).then((result) => {
            // Fire notification for new notice
            onNoticeCreated(result.id, data.title, batchId);
            return result;
        });
    }

    async listNotices(batchId: string) {
        return prisma.batchNotice.findMany({
            where: { batchId },
            include: {
                sentBy: { select: { id: true, name: true, picture: true } },
            },
            orderBy: { createdAt: 'desc' },
        });
    }

    async deleteNotice(noticeId: string) {
        return prisma.batchNotice.delete({ where: { id: noticeId } });
    }

    // ── Helpers ───────────────────────────────────────────────────────

    /** Verify a user is an ADMIN/OWNER of the coaching that owns this batch */
    async verifyBatchAdmin(batchId: string, userId: string) {
        const batch = await prisma.batch.findUnique({
            where: { id: batchId },
            select: {
                id: true,
                coachingId: true,
                coaching: { select: { ownerId: true } },
            },
        });
        if (!batch) return null;

        if (batch.coaching.ownerId === userId) return batch;

        const adminMember = await prisma.coachingMember.findFirst({
            where: { coachingId: batch.coachingId, userId, role: 'ADMIN', status: 'active' },
        });
        return adminMember ? batch : null;
    }

    /** Verify a user is a TEACHER assigned to this batch (single query) */
    async verifyBatchTeacher(batchId: string, userId: string) {
        const batch = await prisma.batch.findUnique({
            where: { id: batchId },
            select: {
                id: true,
                coachingId: true,
                coaching: { select: { ownerId: true } },
            },
        });
        if (!batch) return null;

        // Owner has full access
        if (batch.coaching.ownerId === userId) return batch;

        // Single query: check if user is admin OR teacher in batch
        const member = await prisma.coachingMember.findFirst({
            where: {
                coachingId: batch.coachingId,
                userId,
                status: 'active',
                OR: [
                    { role: 'ADMIN' },
                    { batchMembers: { some: { batchId, role: 'TEACHER' } } },
                ],
            },
        });
        return member ? batch : null;
    }

    /** Verify a user has ANY access to this batch (admin, teacher, or student) */
    async verifyBatchAccess(batchId: string, userId: string) {
        const batch = await prisma.batch.findUnique({
            where: { id: batchId },
            select: {
                id: true,
                coachingId: true,
                coaching: { select: { ownerId: true } },
            },
        });
        if (!batch) return null;

        if (batch.coaching.ownerId === userId) return batch;

        // Check if any coaching member
        const member = await prisma.coachingMember.findFirst({
            where: { coachingId: batch.coachingId, userId, status: 'active' },
        });
        return member ? batch : null;
    }

    /** Get batches a specific user belongs to (via their coaching member) */
    async getMyBatches(coachingId: string, userId: string) {
        // First find the user's coaching member ID
        const coachingMember = await prisma.coachingMember.findFirst({
            where: { coachingId, userId, status: 'active' },
        });

        if (!coachingMember) return [];

        return prisma.batch.findMany({
            where: {
                coachingId,
                status: 'active',
                members: { some: { memberId: coachingMember.id } },
            },
            select: BATCH_LIST_SELECT,
            orderBy: { createdAt: 'desc' },
        });
    }

    /**
     * Dashboard feed — recent assessments, assignments, and notices
     * across all batches the user belongs to in a coaching.
     */
    async getDashboardFeed(userId: string, coachingId: string) {
        // Get user's wards
        const userWards = await prisma.ward.findMany({
            where: { parentId: userId },
            select: { id: true },
        });
        const wardIds = userWards.map((w) => w.id);

        const whereConditions: any[] = [{ userId }];
        if (wardIds.length > 0) {
            whereConditions.push({ wardId: { in: wardIds } });
        }

        const memberIds = (await prisma.coachingMember.findMany({
            where: { coachingId, OR: whereConditions },
            select: { id: true },
        })).map((m) => m.id);

        if (memberIds.length === 0) return { assessments: [], assignments: [], notices: [] };

        const batchIds = (await prisma.batchMember.findMany({
            where: { memberId: { in: memberIds } },
            select: { batchId: true },
        })).map((b) => b.batchId);

        if (batchIds.length === 0) return { assessments: [], assignments: [], notices: [] };

        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

        // Fetch all three in parallel
        const [assessments, assignments, notices] = await Promise.all([
            // Recent published assessments
            prisma.assessment.findMany({
                where: {
                    batchId: { in: batchIds },
                    status: 'PUBLISHED',
                    createdAt: { gte: sevenDaysAgo },
                },
                select: {
                    id: true,
                    title: true,
                    type: true,
                    totalMarks: true,
                    durationMinutes: true,
                    createdAt: true,
                    batchId: true,
                    batch: { select: { id: true, name: true } },
                    _count: { select: { questions: true } },
                },
                orderBy: { createdAt: 'desc' },
                take: 10,
            }),
            // Recent assignments
            prisma.assignment.findMany({
                where: {
                    batchId: { in: batchIds },
                    status: 'ACTIVE',
                    createdAt: { gte: sevenDaysAgo },
                },
                select: {
                    id: true,
                    title: true,
                    dueDate: true,
                    totalMarks: true,
                    createdAt: true,
                    batchId: true,
                    batch: { select: { id: true, name: true } },
                },
                orderBy: { createdAt: 'desc' },
                take: 10,
            }),
            // Recent notices
            prisma.batchNotice.findMany({
                where: {
                    batchId: { in: batchIds },
                    createdAt: { gte: sevenDaysAgo },
                },
                select: {
                    id: true,
                    title: true,
                    message: true,
                    createdAt: true,
                    batchId: true,
                    batch: { select: { id: true, name: true } },
                    sentBy: { select: { id: true, name: true } },
                },
                orderBy: { createdAt: 'desc' },
                take: 10,
            }),
        ]);

        return { assessments, assignments, notices };
    }
}
