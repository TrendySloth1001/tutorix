import prisma from '../../infra/prisma.js';

export interface CreateWardDto {
    name: string;
    picture?: string;
    parentId: string;
}

export interface UpdateWardDto {
    name?: string;
    picture?: string;
}

export class WardService {
    async create(data: CreateWardDto) {
        return prisma.ward.create({
            data,
        });
    }

    async findByParentId(parentId: string) {
        return prisma.ward.findMany({
            where: { parentId },
            include: {
                enrollments: {
                    include: {
                        coaching: true
                    }
                }
            },
            orderBy: { name: 'asc' }
        });
    }

    async findById(id: string) {
        return prisma.ward.findUnique({
            where: { id },
            include: {
                parent: true,
                enrollments: {
                    include: {
                        coaching: true
                    }
                }
            }
        });
    }

    async update(id: string, data: UpdateWardDto) {
        return prisma.ward.update({
            where: { id },
            data,
        });
    }

    async delete(id: string) {
        return prisma.ward.delete({
            where: { id },
        });
    }

    async enrollInCoaching(wardId: string, coachingId: string) {
        return prisma.coachingMember.create({
            data: {
                wardId,
                coachingId,
                role: 'STUDENT',
                status: 'active'
            }
        });
    }
}
