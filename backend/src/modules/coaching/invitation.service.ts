import prisma from '../../infra/prisma.js';

export interface CreateInvitationDto {
    coachingId: string;
    role: string; // TEACHER, PARENT, STUDENT
    userId?: string;
    wardId?: string;
    invitePhone?: string;
    inviteEmail?: string;
    inviteName?: string;
    message?: string;
    invitedById: string;
}

export class InvitationService {
    /**
     * Lookup a user by phone or email.
     * Returns the user profile with their wards if found.
     */
    async lookupByContact(contact: string) {
        // Try email first, then phone
        const user = await prisma.user.findFirst({
            where: {
                OR: [
                    { email: contact },
                    { phone: contact },
                ],
            },
            select: {
                id: true,
                name: true,
                email: true,
                phone: true,
                picture: true,
                isAdmin: true,
                isTeacher: true,
                isParent: true,
                isWard: true,
                wards: {
                    select: {
                        id: true,
                        name: true,
                        picture: true,
                    },
                },
            },
        });

        return user;
    }

    /**
     * Create an invitation.
     * If userId/wardId is provided, it's a resolved invitation.
     * If only phone/email is provided, it's an unresolved (pending signup) invitation.
     */
    async createInvitation(data: CreateInvitationDto) {
        // Check for existing invitation
        if (data.userId) {
            const existing = await prisma.invitation.findFirst({
                where: {
                    coachingId: data.coachingId,
                    userId: data.userId,
                    role: data.role,
                    status: 'PENDING',
                },
            });
            if (existing) {
                throw new Error('An invitation for this user with this role already exists');
            }
        }

        if (data.wardId) {
            const existing = await prisma.invitation.findFirst({
                where: {
                    coachingId: data.coachingId,
                    wardId: data.wardId,
                    status: 'PENDING',
                },
            });
            if (existing) {
                throw new Error('An invitation for this ward already exists');
            }
        }

        // Check if already a member
        if (data.userId) {
            const existingMember = await prisma.coachingMember.findFirst({
                where: {
                    coachingId: data.coachingId,
                    userId: data.userId,
                },
            });
            if (existingMember) {
                throw new Error('This user is already a member of this coaching');
            }
        }

        if (data.wardId) {
            const existingMember = await prisma.coachingMember.findFirst({
                where: {
                    coachingId: data.coachingId,
                    wardId: data.wardId,
                },
            });
            if (existingMember) {
                throw new Error('This ward is already enrolled in this coaching');
            }
        }

        return prisma.invitation.create({
            data: {
                coachingId: data.coachingId,
                role: data.role,
                userId: data.userId ?? null,
                wardId: data.wardId ?? null,
                invitePhone: data.invitePhone ?? null,
                inviteEmail: data.inviteEmail ?? null,
                inviteName: data.inviteName ?? null,
                message: data.message ?? null,
                invitedById: data.invitedById,
                expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
            },
            include: {
                coaching: { select: { id: true, name: true, logo: true } },
                user: { select: { id: true, name: true, picture: true } },
                ward: { select: { id: true, name: true, picture: true } },
                invitedBy: { select: { id: true, name: true, picture: true } },
            },
        });
    }

    /**
     * Get all invitations for a coaching (admin view).
     */
    async getInvitationsForCoaching(coachingId: string) {
        return prisma.invitation.findMany({
            where: { coachingId },
            include: {
                user: { select: { id: true, name: true, email: true, picture: true } },
                ward: { select: { id: true, name: true, picture: true } },
                invitedBy: { select: { id: true, name: true } },
            },
            orderBy: { createdAt: 'desc' },
        });
    }

    /**
     * Get pending invitations for a user (and their wards).
     */
    async getMyInvitations(userId: string) {
        // Get user's ward IDs
        const wards = await prisma.ward.findMany({
            where: { parentId: userId },
            select: { id: true },
        });
        const wardIds = wards.map(w => w.id);

        return prisma.invitation.findMany({
            where: {
                status: 'PENDING',
                OR: [
                    { userId },
                    ...(wardIds.length > 0 ? [{ wardId: { in: wardIds } }] : []),
                ],
            },
            include: {
                coaching: { select: { id: true, name: true, logo: true, slug: true } },
                ward: { select: { id: true, name: true, picture: true } },
                invitedBy: { select: { id: true, name: true, picture: true } },
            },
            orderBy: { createdAt: 'desc' },
        });
    }

    /**
     * Respond to an invitation (accept or decline).
     */
    async respondToInvitation(invitationId: string, userId: string, accept: boolean) {
        const invitation = await prisma.invitation.findUnique({
            where: { id: invitationId },
            include: { ward: true },
        });

        if (!invitation) {
            throw new Error('Invitation not found');
        }

        // Verify authorization: user must be the target, or parent of target ward
        if (invitation.userId && invitation.userId !== userId) {
            throw new Error('Not authorized to respond to this invitation');
        }
        if (invitation.wardId && invitation.ward) {
            if (invitation.ward.parentId !== userId) {
                throw new Error('Not authorized to respond to this invitation');
            }
        }

        if (invitation.status !== 'PENDING') {
            throw new Error(`Invitation is already ${invitation.status.toLowerCase()}`);
        }

        if (accept) {
            // Accept: create CoachingMember and update invitation
            return prisma.$transaction(async (tx) => {
                // Create membership
                await tx.coachingMember.create({
                    data: {
                        coachingId: invitation.coachingId,
                        role: invitation.role,
                        userId: invitation.userId,
                        wardId: invitation.wardId,
                        status: 'active',
                    },
                });

                // Update role flags on user if needed
                if (invitation.userId) {
                    const roleUpdate: Record<string, boolean> = {};
                    if (invitation.role === 'TEACHER') roleUpdate.isTeacher = true;
                    if (invitation.role === 'ADMIN') roleUpdate.isAdmin = true;
                    if (invitation.role === 'PARENT') roleUpdate.isParent = true;

                    if (Object.keys(roleUpdate).length > 0) {
                        await tx.user.update({
                            where: { id: invitation.userId },
                            data: roleUpdate,
                        });
                    }
                }

                // Mark invitation as accepted
                return tx.invitation.update({
                    where: { id: invitationId },
                    data: {
                        status: 'ACCEPTED',
                        respondedAt: new Date(),
                    },
                    include: {
                        coaching: { select: { id: true, name: true } },
                    },
                });
            });
        } else {
            // Decline
            return prisma.invitation.update({
                where: { id: invitationId },
                data: {
                    status: 'DECLINED',
                    respondedAt: new Date(),
                },
            });
        }
    }

    /**
     * Auto-claim pending invitations when a user signs up.
     * Matches by email or phone.
     */
    async claimPendingInvitations(userId: string, email: string, phone?: string) {
        const conditions: Array<{ inviteEmail: string } | { invitePhone: string }> = [
            { inviteEmail: email },
        ];
        if (phone) {
            conditions.push({ invitePhone: phone });
        }

        const pendingInvitations = await prisma.invitation.findMany({
            where: {
                status: 'PENDING',
                userId: null,   // Only unresolved invitations
                wardId: null,
                OR: conditions,
            },
        });

        // Link each pending invitation to the user
        for (const inv of pendingInvitations) {
            await prisma.invitation.update({
                where: { id: inv.id },
                data: { userId },
            });
        }

        return pendingInvitations.length;
    }

    /**
     * Cancel/revoke an invitation (admin action).
     */
    async cancelInvitation(invitationId: string, coachingId: string) {
        const invitation = await prisma.invitation.findFirst({
            where: { id: invitationId, coachingId, status: 'PENDING' },
        });

        if (!invitation) {
            throw new Error('Invitation not found or already processed');
        }

        return prisma.invitation.update({
            where: { id: invitationId },
            data: { status: 'EXPIRED' },
        });
    }
}
