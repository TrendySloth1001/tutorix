import prisma from '../../infra/prisma.js';

export interface UpdateUserDto {
    name?: string;
    phone?: string;
    picture?: string;
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
                ownedCoachings: true,
            },
        });
    }

    async findByEmail(email: string) {
        return prisma.user.findUnique({
            where: { email },
            include: {
                ownedCoachings: true,
            },
        });
    }

    async update(id: string, data: UpdateUserDto) {
        return prisma.user.update({
            where: { id },
            data,
            include: {
                ownedCoachings: true,
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
                ownedCoachings: true,
            },
        });
    }

    async completeOnboarding(id: string) {
        return prisma.user.update({
            where: { id },
            data: { onboardingComplete: true },
            include: {
                ownedCoachings: true,
            },
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
                    ownedCoachings: true,
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
