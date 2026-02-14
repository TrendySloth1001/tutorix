import prisma from '../../infra/prisma.js';

export interface CreateCoachingDto {
    name: string;
    slug: string;
    description?: string;
    logo?: string;
}

export interface UpdateCoachingDto {
    name?: string;
    description?: string;
    logo?: string;
    status?: string;
}

export class CoachingService {
    async create(ownerId: string, data: CreateCoachingDto) {
        // Create coaching and set user as admin
        const [coaching] = await prisma.$transaction([
            prisma.coaching.create({
                data: {
                    ...data,
                    ownerId,
                },
                include: {
                    owner: true,
                },
            }),
            // Set the user as admin when they create a coaching
            prisma.user.update({
                where: { id: ownerId },
                data: { isAdmin: true, onboardingComplete: true },
            }),
        ]);

        return coaching;
    }

    async findById(id: string) {
        return prisma.coaching.findUnique({
            where: { id },
            include: {
                owner: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        picture: true,
                    },
                },
            },
        });
    }

    async findBySlug(slug: string) {
        return prisma.coaching.findUnique({
            where: { slug },
            include: {
                owner: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        picture: true,
                    },
                },
            },
        });
    }

    async findByOwner(ownerId: string) {
        return prisma.coaching.findMany({
            where: { ownerId },
            orderBy: { createdAt: 'desc' },
        });
    }

    async update(id: string, ownerId: string, data: UpdateCoachingDto) {
        // First verify ownership
        const coaching = await prisma.coaching.findFirst({
            where: { id, ownerId },
        });

        if (!coaching) {
            throw new Error('Coaching not found or you do not have permission');
        }

        return prisma.coaching.update({
            where: { id },
            data,
            include: {
                owner: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        picture: true,
                    },
                },
            },
        });
    }

    async delete(id: string, ownerId: string) {
        // First verify ownership
        const coaching = await prisma.coaching.findFirst({
            where: { id, ownerId },
        });

        if (!coaching) {
            throw new Error('Coaching not found or you do not have permission');
        }

        return prisma.coaching.delete({
            where: { id },
        });
    }

    async findAll(page: number = 1, limit: number = 10) {
        const skip = (page - 1) * limit;
        const [coachings, total] = await Promise.all([
            prisma.coaching.findMany({
                skip,
                take: limit,
                where: { status: 'active' },
                orderBy: { createdAt: 'desc' },
                include: {
                    owner: {
                        select: {
                            id: true,
                            name: true,
                            email: true,
                            picture: true,
                        },
                    },
                },
            }),
            prisma.coaching.count({ where: { status: 'active' } }),
        ]);

        return {
            coachings,
            pagination: {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit),
            },
        };
    }

    async getMembers(coachingId: string) {
        const members = await prisma.coachingMember.findMany({
            where: { coachingId },
            include: {
                user: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        picture: true,
                        isParent: true,
                        wards: {
                            select: {
                                id: true,
                                name: true,
                                picture: true,
                            },
                        },
                    },
                },
                ward: {
                    select: {
                        id: true,
                        name: true,
                        picture: true,
                        parentId: true,
                        parent: {
                            select: {
                                id: true,
                                name: true,
                                email: true,
                                picture: true,
                            },
                        },
                    },
                },
            },
            orderBy: { createdAt: 'asc' },
        });
        return members;
    }

    async addWardMember(coachingId: string, parentUserId: string, wardName: string) {
        // Create the ward under the parent and enrol as STUDENT in one transaction
        const [ward] = await prisma.$transaction(async (tx) => {
            // Ensure parent exists
            const parent = await tx.user.findUnique({ where: { id: parentUserId } });
            if (!parent) throw new Error('Parent user not found');

            // Create ward
            const newWard = await tx.ward.create({
                data: { name: wardName, parentId: parentUserId },
            });

            // Set parent flag if not already
            if (!parent.isParent) {
                await tx.user.update({
                    where: { id: parentUserId },
                    data: { isParent: true },
                });
            }

            // Enrol ward as STUDENT member
            await tx.coachingMember.create({
                data: {
                    coachingId,
                    wardId: newWard.id,
                    role: 'STUDENT',
                    status: 'active',
                },
            });

            return [newWard];
        });

        return ward;
    }

    async isSlugAvailable(slug: string): Promise<boolean> {
        const existing = await prisma.coaching.findUnique({
            where: { slug },
        });
        return !existing;
    }

    generateSlug(name: string): string {
        return name
            .toLowerCase()
            .trim()
            .replace(/[^a-z0-9\s-]/g, '')
            .replace(/\s+/g, '-')
            .replace(/-+/g, '-');
    }
}
