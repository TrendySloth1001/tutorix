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
    replacePending?: boolean; // If true, cancel existing pending invitation
}

export class InvitationService {
    /**
     * Lookup a user by phone or email, scoped to a specific coaching.
     * Respects user privacy settings — bypasses them if user is already in this coaching.
     */
    async lookupByContact(contact: string, coachingId: string) {
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
                showEmailInSearch: true,
                showPhoneInSearch: true,
                showWardsInSearch: true,
                wards: {
                    select: {
                        id: true,
                        name: true,
                        picture: true,
                    },
                },
            },
        });

        if (!user) return null;

        // Parallelize: membership check + ward enrollment check
        const wardIds = user.wards.map(w => w.id);
        const [memberships, wardMemberships] = await Promise.all([
            prisma.coachingMember.findMany({
                where: { coachingId, userId: user.id },
                select: { role: true, status: true },
            }),
            wardIds.length > 0
                ? prisma.coachingMember.findMany({
                    where: { coachingId, wardId: { in: wardIds } },
                    select: { wardId: true, role: true, status: true },
                })
                : Promise.resolve([]),
        ]);
        const isMember = memberships.length > 0;

        // If already a member of this coaching → full access, bypass privacy
        const bypassPrivacy = isMember;
        const wardMap = new Map(
            wardMemberships.map(wm => [wm.wardId, { role: wm.role, status: wm.status }])
        );

        // Apply privacy: name & picture always shown
        const showEmail = bypassPrivacy || user.showEmailInSearch;
        const showPhone = bypassPrivacy || user.showPhoneInSearch;
        const showWards = bypassPrivacy || user.showWardsInSearch;

        return {
            id: user.id,
            name: user.name,
            email: showEmail ? user.email : null,
            phone: showPhone ? user.phone : null,
            picture: user.picture,
            existingRoles: memberships.map(m => m.role),
            isMember,
            wards: showWards
                ? user.wards.map(w => ({
                    ...w,
                    isEnrolled: wardMap.has(w.id),
                    enrolledRole: wardMap.get(w.id)?.role ?? null,
                }))
                : [],
            // Tell the frontend what's hidden so it can show hints
            privacy: {
                emailHidden: !showEmail,
                phoneHidden: !showPhone,
                wardsHidden: !showWards,
            },
        };
    }

    /**
     * Create an invitation.
     * If userId/wardId is provided, it's a resolved invitation.
     * If only phone/email is provided, it's an unresolved (pending signup) invitation.
     */
    async createInvitation(data: CreateInvitationDto) {

        // Check for ANY existing invitation (not just PENDING) due to unique constraint
        if (data.userId) {
            const existing = await prisma.invitation.findFirst({
                where: {
                    coachingId: data.coachingId,
                    userId: data.userId,
                    role: data.role,
                },
                select: { id: true, role: true, status: true },
            });

            if (existing) {
                console.log('Found existing invitation:', existing);

                // If it's PENDING and replacePending is false, block
                if (existing.status === 'PENDING' && !data.replacePending) {
                    throw new Error('An invitation for this user already exists. Please cancel the existing invitation first.');
                }

                // Reuse the existing invitation - update it back to PENDING
                console.log('Reusing existing invitation, updating to PENDING');
                const updated = await prisma.invitation.update({
                    where: { id: existing.id },
                    data: {
                        status: 'PENDING',
                        respondedAt: null,
                        message: data.message ?? null,
                        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
                    },
                    include: {
                        coaching: { select: { id: true, name: true, logo: true } },
                        user: { select: { id: true, name: true, picture: true } },
                        ward: { select: { id: true, name: true, picture: true } },
                        invitedBy: { select: { id: true, name: true, picture: true } },
                    },
                });
                console.log('Invitation updated successfully:', updated.id);
                return updated;
            }
        }

        if (data.wardId) {
            const existing = await prisma.invitation.findFirst({
                where: {
                    coachingId: data.coachingId,
                    wardId: data.wardId,
                },
                select: { id: true, status: true },
            });

            if (existing) {
                console.log('Found existing ward invitation:', existing);

                // If it's PENDING and replacePending is false, block
                if (existing.status === 'PENDING' && !data.replacePending) {
                    throw new Error('An invitation for this ward already exists. Please cancel the existing invitation first.');
                }

                // Reuse the existing invitation - update it back to PENDING
                console.log('Reusing existing ward invitation, updating to PENDING');
                const updated = await prisma.invitation.update({
                    where: { id: existing.id },
                    data: {
                        status: 'PENDING',
                        role: data.role,
                        respondedAt: null,
                        message: data.message ?? null,
                        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
                    },
                    include: {
                        coaching: { select: { id: true, name: true, logo: true } },
                        user: { select: { id: true, name: true, picture: true } },
                        ward: { select: { id: true, name: true, picture: true } },
                        invitedBy: { select: { id: true, name: true, picture: true } },
                    },
                });
                console.log('Ward invitation updated successfully:', updated.id);
                return updated;
            }
        }

        // Parallelize member existence checks (both user and ward at once)
        const memberChecks = await Promise.all([
            data.userId
                ? prisma.coachingMember.findFirst({
                    where: { coachingId: data.coachingId, userId: data.userId },
                    select: { id: true, role: true, status: true },
                })
                : null,
            data.wardId
                ? prisma.coachingMember.findFirst({
                    where: { coachingId: data.coachingId, wardId: data.wardId },
                    select: { id: true, role: true, status: true },
                })
                : null,
        ]);

        const [userMember, wardMember] = memberChecks;
        if (userMember) {
            throw new Error(`This user is already a member of this coaching (role: ${userMember.role}, status: ${userMember.status})`);
        }
        if (wardMember) {
            throw new Error(`This ward is already enrolled in this coaching (role: ${wardMember.role}, status: ${wardMember.status})`);
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
     * Also includes user's existing coaching memberships for confirmation UX.
     */
    async getMyInvitations(userId: string) {
        // Get user's ward IDs
        const wards = await prisma.ward.findMany({
            where: { parentId: userId },
            select: { id: true },
        });
        const wardIds = wards.map(w => w.id);

        // Fetch pending invitations
        const invitations = await prisma.invitation.findMany({
            where: {
                status: 'PENDING',
                OR: [
                    { userId },
                    ...(wardIds.length > 0 ? [{ wardId: { in: wardIds } }] : []),
                ],
            },
            include: {
                coaching: { select: { id: true, name: true, logo: true, coverImage: true, slug: true } },
                ward: { select: { id: true, name: true, picture: true } },
                invitedBy: { select: { id: true, name: true, picture: true } },
            },
            orderBy: { createdAt: 'desc' },
        });

        // Fetch user's existing active coaching memberships
        const existingMemberships = await prisma.coachingMember.findMany({
            where: { userId, status: 'active' },
            select: {
                role: true,
                coaching: { select: { id: true, name: true } },
            },
        });

        // Attach existingMemberships to each invitation
        return invitations.map(inv => ({
            ...inv,
            existingMemberships: existingMemberships.map(m => ({
                coachingId: m.coaching.id,
                coachingName: m.coaching.name,
                role: m.role,
            })),
        }));
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
                if (invitation.userId) {
                    // Fetch existing active memberships to notify them
                    const existingMemberships = await tx.coachingMember.findMany({
                        where: {
                            userId: invitation.userId,
                            status: 'active',
                            coachingId: { not: invitation.coachingId }, // Don't notify the one passing invitation
                        },
                        include: { coaching: { select: { name: true } } },
                    });

                    // Create or reactivate membership (member may have been removed before)
                    await tx.coachingMember.upsert({
                        where: { coachingId_userId: { coachingId: invitation.coachingId, userId: invitation.userId } },
                        create: {
                            coachingId: invitation.coachingId,
                            role: invitation.role,
                            userId: invitation.userId,
                            wardId: invitation.wardId,
                            status: 'active',
                        },
                        update: {
                            role: invitation.role,
                            status: 'active',
                            removedAt: null,
                        },
                    });

                    // Update role flags on user if needed
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

                    // Create notifications for existing coachings (batch)
                    if (existingMemberships.length > 0) {
                        const userName = (await tx.user.findUnique({
                            where: { id: invitation.userId },
                            select: { name: true },
                        }))?.name || 'A member';

                        await tx.notification.createMany({
                            data: existingMemberships.map((membership) => ({
                                coachingId: membership.coachingId,
                                type: 'MEMBER_JOINED_ANOTHER_COACHING',
                                title: 'Member joined another coaching',
                                message: `${userName} has joined another coaching`,
                                data: {
                                    userId: invitation.userId,
                                    memberId: membership.id,
                                },
                            })),
                        });
                    }
                } else {
                    // Ward invitation: create or reactivate membership
                    await tx.coachingMember.upsert({
                        where: { coachingId_wardId: { coachingId: invitation.coachingId, wardId: invitation.wardId! } },
                        create: {
                            coachingId: invitation.coachingId,
                            role: invitation.role,
                            wardId: invitation.wardId,
                            status: 'active',
                        },
                        update: {
                            role: invitation.role,
                            status: 'active',
                            removedAt: null,
                        },
                    });
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

        // Single updateMany instead of fetch + loop
        const result = await prisma.invitation.updateMany({
            where: {
                status: 'PENDING',
                userId: null,
                wardId: null,
                OR: conditions,
            },
            data: { userId },
        });

        return result.count;
    }

    /**
     * Cancel/revoke an invitation (admin action).
     */
    async cancelInvitation(invitationId: string, coachingId: string) {
        // Single query: updateMany with compound WHERE replaces findFirst + update
        const result = await prisma.invitation.updateMany({
            where: { id: invitationId, coachingId, status: 'PENDING' },
            data: { status: 'EXPIRED' },
        });

        if (result.count === 0) {
            throw new Error('Invitation not found or already processed');
        }

        return { id: invitationId, status: 'EXPIRED' };
    }
}
