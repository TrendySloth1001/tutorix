import prisma from '../../infra/prisma.js';

export interface UpdateUserDto {
    name?: string;
    phone?: string;
    picture?: string | null;
    isAdmin?: boolean;
    isTeacher?: boolean;
    isParent?: boolean;
    isWard?: boolean;
    onboardingComplete?: boolean;
}

export class UserService {
    async findById(id: string) {
        return prisma.user.findUnique({
            where: { id },
            include: {
                ownedCoachings: {
                    select: { id: true, name: true, slug: true, logo: true, status: true },
                },
                wards: {
                    select: { id: true, name: true, picture: true },
                },
            },
        });
    }

    async findByEmail(email: string) {
        return prisma.user.findUnique({
            where: { email },
            include: {
                ownedCoachings: {
                    select: { id: true, name: true, slug: true, logo: true, status: true },
                },
                wards: {
                    select: { id: true, name: true, picture: true },
                },
            },
        });
    }

    async update(id: string, data: UpdateUserDto) {
        return prisma.user.update({
            where: { id },
            data,
            include: {
                ownedCoachings: {
                    select: { id: true, name: true, slug: true, logo: true, status: true },
                },
                wards: {
                    select: { id: true, name: true, picture: true },
                },
            },
        });
    }

    async updateRoles(id: string, roles: {
        isAdmin?: boolean;
        isTeacher?: boolean;
        isParent?: boolean;
        isWard?: boolean;
    }) {
        return prisma.user.update({
            where: { id },
            data: roles,
            include: {
                ownedCoachings: {
                    select: { id: true, name: true, slug: true, logo: true, status: true },
                },
            },
        });
    }

    async completeOnboarding(id: string) {
        return prisma.user.update({
            where: { id },
            data: { onboardingComplete: true },
            include: {
                ownedCoachings: {
                    select: { id: true, name: true, slug: true, logo: true, status: true },
                },
            },
        });
    }

    async getSessions(userId: string) {
        return prisma.loginSession.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
            take: 20, // Limit to last 20 sessions for performance
        });
    }

    async findAll(page: number = 1, limit: number = 10) {
        const skip = (page - 1) * limit;
        const [users, total] = await Promise.all([
            prisma.user.findMany({
                skip,
                take: limit,
                orderBy: { createdAt: 'desc' },
                include: {
                    ownedCoachings: {
                        select: { id: true, name: true, slug: true, logo: true, status: true },
                    },
                },
            }),
            prisma.user.count(),
        ]);

        return {
            users,
            pagination: {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit),
            },
        };
    }

    async delete(id: string) {
        return prisma.user.delete({
            where: { id },
        });
    }
}
