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
    coverImage?: string;
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
                address: true,
                branches: {
                    where: { isActive: true },
                    orderBy: { createdAt: 'asc' },
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
                address: true,
                branches: {
                    where: { isActive: true },
                    orderBy: { createdAt: 'asc' },
                },
            },
        });
    }

    async findByOwner(ownerId: string) {
        const coachings = await prisma.coaching.findMany({
            where: { ownerId },
            orderBy: { createdAt: 'desc' },
            include: {
                _count: {
                    select: { members: true },
                },
                members: {
                    select: { role: true },
                },
                address: true,
                branches: {
                    where: { isActive: true },
                    orderBy: { createdAt: 'asc' },
                },
            },
        });

        // Transform to include stats
        return coachings.map((coaching) => {
            const roleCounts = coaching.members.reduce(
                (acc, m) => {
                    acc[m.role] = (acc[m.role] || 0) + 1;
                    return acc;
                },
                {} as Record<string, number>
            );

            return {
                ...coaching,
                memberCount: coaching._count.members,
                teacherCount: roleCounts['TEACHER'] || 0,
                studentCount: roleCounts['STUDENT'] || 0,
                members: undefined,
                _count: undefined,
            };
        });
    }

    /**
     * Find coachings where user is a member (but not owner).
     */
    async findByMember(userId: string) {
        const memberships = await prisma.coachingMember.findMany({
            where: { userId },
            include: {
                coaching: {
                    include: {
                        owner: {
                            select: { id: true, name: true, picture: true },
                        },
                        _count: {
                            select: { members: true },
                        },
                        members: {
                            select: { role: true },
                        },
                        address: true,
                        branches: {
                            where: { isActive: true },
                            orderBy: { createdAt: 'asc' },
                        },
                    },
                },
            },
            orderBy: { createdAt: 'desc' },
        });

        // Filter out coachings where user is owner, transform to include stats and role
        return memberships
            .filter((m) => m.coaching.ownerId !== userId)
            .map((m) => {
                const coaching = m.coaching;
                const roleCounts = coaching.members.reduce(
                    (acc, mem) => {
                        acc[mem.role] = (acc[mem.role] || 0) + 1;
                        return acc;
                    },
                    {} as Record<string, number>
                );

                return {
                    id: coaching.id,
                    name: coaching.name,
                    slug: coaching.slug,
                    description: coaching.description,
                    logo: coaching.logo,
                    status: coaching.status,
                    ownerId: coaching.ownerId,
                    owner: coaching.owner,
                    createdAt: coaching.createdAt,
                    updatedAt: coaching.updatedAt,
                    memberCount: coaching._count.members,
                    teacherCount: roleCounts['TEACHER'] || 0,
                    studentCount: roleCounts['STUDENT'] || 0,
                    myRole: m.role,
                    address: coaching.address,
                    branches: coaching.branches,
                };
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

    /**
     * Remove a member from a coaching.
     * Sends notification to removed user and deletes member record.
     */
    async removeMember(coachingId: string, memberId: string) {
        const member = await prisma.coachingMember.findFirst({
            where: { id: memberId, coachingId },
            include: {
                user: { select: { id: true, name: true } },
                ward: { select: { id: true, name: true, parentId: true } },
                coaching: { select: { name: true } },
            },
        });

        if (!member) {
            throw new Error('Member not found in this coaching');
        }

        console.log('Removing member:', {
            memberId,
            coachingId,
            userId: member.userId,
            wardId: member.wardId,
            role: member.role,
        });

        // Delete member and create notification in transaction
        await prisma.$transaction(async (tx) => {
            // Delete ALL member records for this user/ward in this coaching
            // (should be only one, but this ensures complete cleanup)
            let deletedCount = 0;
            if (member.userId) {
                const result = await tx.coachingMember.deleteMany({
                    where: {
                        coachingId,
                        userId: member.userId,
                    },
                });
                deletedCount = result.count;
                console.log(`Deleted ${deletedCount} member record(s) for userId: ${member.userId}`);
            } else if (member.wardId) {
                const result = await tx.coachingMember.deleteMany({
                    where: {
                        coachingId,
                        wardId: member.wardId,
                    },
                });
                deletedCount = result.count;
                console.log(`Deleted ${deletedCount} member record(s) for wardId: ${member.wardId}`);
            }

            // Cancel any pending invitations for this user/ward to allow re-invitation
            if (member.userId) {
                await tx.invitation.updateMany({
                    where: {
                        coachingId,
                        userId: member.userId,
                        status: 'PENDING',
                    },
                    data: {
                        status: 'EXPIRED',
                        respondedAt: new Date(),
                    },
                });
            } else if (member.wardId) {
                await tx.invitation.updateMany({
                    where: {
                        coachingId,
                        wardId: member.wardId,
                        status: 'PENDING',
                    },
                    data: {
                        status: 'EXPIRED',
                        respondedAt: new Date(),
                    },
                });
            }

            // Send notification to removed user
            // For direct user members (teachers/admins)
            if (member.userId) {
                await tx.notification.create({
                    data: {
                        userId: member.userId,
                        type: 'REMOVED_FROM_COACHING',
                        title: 'Enrollment Change Notice',
                        message: `There has been a change to your enrollment in ${member.coaching.name}. For more details, please contact the coaching administration.`,
                        data: {
                            coachingId,
                            coachingName: member.coaching.name,
                            removedAt: new Date().toISOString(),
                        },
                    },
                });
            }
            // For ward members (students) - notify parent
            else if (member.wardId && member.ward) {
                await tx.notification.create({
                    data: {
                        userId: member.ward.parentId,
                        type: 'WARD_REMOVED_FROM_COACHING',
                        title: 'Ward Enrollment Change Notice',
                        message: `${member.ward.name} is no longer enrolled at ${member.coaching.name}.If you have any questions, please contact the coaching administration.`,
                        data: {
                            coachingId,
                            coachingName: member.coaching.name,
                            wardId: member.wardId,
                            wardName: member.ward.name,
                            removedAt: new Date().toISOString(),
                        },
                    },
                });
            }
        });

        return { success: true };
    }

    /**
     * Update a member's role in a coaching.
     */
    async updateMemberRole(coachingId: string, memberId: string, role: string) {
        const member = await prisma.coachingMember.findFirst({
            where: { id: memberId, coachingId },
        });

        if (!member) {
            throw new Error('Member not found in this coaching');
        }

        return prisma.coachingMember.update({
            where: { id: memberId },
            data: { role },
            include: {
                user: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        picture: true,
                    },
                },
                ward: {
                    select: {
                        id: true,
                        name: true,
                        picture: true,
                    },
                },
            },
        });
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

    // ── Onboarding Methods ────────────────────────────────────────────────

    async updateProfile(coachingId: string, data: {
        tagline?: string;
        aboutUs?: string;
        foundedYear?: number;
        websiteUrl?: string;
        contactEmail?: string;
        contactPhone?: string;
        whatsappPhone?: string;
        category?: string;
        subjects?: string[];
        facebookUrl?: string;
        instagramUrl?: string;
        youtubeUrl?: string;
        linkedinUrl?: string;
    }) {
        return prisma.coaching.update({
            where: { id: coachingId },
            data,
        });
    }

    async setAddress(coachingId: string, data: {
        addressLine1: string;
        addressLine2?: string;
        landmark?: string;
        city: string;
        state: string;
        pincode: string;
        country?: string;
        latitude?: number;
        longitude?: number;
        openingTime?: string;
        closingTime?: string;
        workingDays?: string[];
    }) {
        return prisma.coachingAddress.upsert({
            where: { coachingId },
            update: data,
            create: {
                coachingId,
                ...data,
            },
        });
    }

    async addBranch(coachingId: string, data: {
        name: string;
        addressLine1: string;
        addressLine2?: string;
        landmark?: string;
        city: string;
        state: string;
        pincode: string;
        country?: string;
        contactPhone?: string;
        contactEmail?: string;
        openingTime?: string;
        closingTime?: string;
        workingDays?: string[];
    }) {
        return prisma.coachingBranch.create({
            data: {
                coachingId,
                ...data,
            },
        });
    }

    async getBranches(coachingId: string) {
        return prisma.coachingBranch.findMany({
            where: { coachingId, isActive: true },
            orderBy: { createdAt: 'asc' },
        });
    }

    async deleteBranch(branchId: string) {
        return prisma.coachingBranch.delete({
            where: { id: branchId },
        });
    }

    async completeOnboarding(coachingId: string) {
        return prisma.coaching.update({
            where: { id: coachingId },
            data: { onboardingComplete: true },
        });
    }

    async getFullDetails(coachingId: string) {
        return prisma.coaching.findUnique({
            where: { id: coachingId },
            include: {
                owner: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        picture: true,
                    },
                },
                address: true,
                branches: {
                    where: { isActive: true },
                    orderBy: { createdAt: 'asc' },
                },
                _count: {
                    select: { members: true },
                },
            },
        });
    }
}
