import prisma from '../../infra/prisma.js';

interface SaveProfileData {
    schoolName?: string;
    board?: string;
    classId?: string;
    stream?: string;
    subjects?: string[];
    competitiveExams?: string[];
    targetYear?: number;
}

export class AcademicService {
    /**
     * Get user's academic profile
     */
    async getProfile(userId: string) {
        const profile = await prisma.academicProfile.findUnique({
            where: { userId },
        });
        return profile;
    }

    /**
     * Save or update user's academic profile
     */
    async saveProfile(userId: string, data: SaveProfileData) {
        const profile = await prisma.academicProfile.upsert({
            where: { userId },
            update: {
                ...data,
                status: 'COMPLETED',
                completedAt: new Date(),
            },
            create: {
                userId,
                ...data,
                status: 'COMPLETED',
                completedAt: new Date(),
            },
        });

        // Also mark user's onboarding as complete
        await prisma.user.update({
            where: { id: userId },
            data: { onboardingComplete: true },
        });

        return profile;
    }

    /**
     * Set "Remind me later" - 2 day buffer
     */
    async setRemindLater(userId: string) {
        const remindAt = new Date();
        remindAt.setDate(remindAt.getDate() + 2);

        const profile = await prisma.academicProfile.upsert({
            where: { userId },
            update: {
                status: 'REMIND_LATER',
                remindAt,
            },
            create: {
                userId,
                status: 'REMIND_LATER',
                remindAt,
            },
        });

        return { remindAt, profile };
    }

    /**
     * Get onboarding status - should we show the onboarding popup?
     */
    async getOnboardingStatus(userId: string) {
        // Check if user is a student in any coaching
        const studentMembership = await prisma.coachingMember.findFirst({
            where: {
                userId,
                role: 'STUDENT',
                status: 'active',
            },
        });

        // Not a student anywhere - no onboarding needed
        if (!studentMembership) {
            return {
                needsOnboarding: false,
                reason: 'not_a_student',
            };
        }

        // Check academic profile
        const profile = await prisma.academicProfile.findUnique({
            where: { userId },
        });

        // No profile yet - needs onboarding
        if (!profile) {
            return {
                needsOnboarding: true,
                reason: 'no_profile',
            };
        }

        // Already completed
        if (profile.status === 'COMPLETED') {
            return {
                needsOnboarding: false,
                reason: 'completed',
                profile,
            };
        }

        // Check if remind later has expired
        if (profile.status === 'REMIND_LATER' && profile.remindAt) {
            const now = new Date();
            if (now >= profile.remindAt) {
                return {
                    needsOnboarding: true,
                    reason: 'remind_expired',
                };
            } else {
                return {
                    needsOnboarding: false,
                    reason: 'remind_active',
                    remindAt: profile.remindAt,
                };
            }
        }

        // Pending - needs onboarding
        return {
            needsOnboarding: true,
            reason: 'pending',
        };
    }

    /**
     * Send reminder notification to users with expired remindAt.
     * Batched: createMany + updateMany instead of N+1 loop.
     * Called by a scheduled job.
     */
    async sendReminderNotifications() {
        const now = new Date();

        // Find users with expired remind_later
        const expiredProfiles = await prisma.academicProfile.findMany({
            where: {
                status: 'REMIND_LATER',
                remindAt: { lte: now },
            },
            select: { id: true, userId: true },
        });

        if (expiredProfiles.length === 0) return { processed: 0 };

        const profileIds = expiredProfiles.map(p => p.id);
        const userIds = expiredProfiles.map(p => p.userId);

        // Batch: create all notifications + update all profiles in a single transaction
        await prisma.$transaction([
            prisma.notification.createMany({
                data: userIds.map(userId => ({
                    userId,
                    type: 'ACADEMIC_ONBOARDING_REMINDER',
                    title: 'Complete your profile',
                    message: 'Help your teachers know you better! Complete your academic profile to get personalized learning experience.',
                    data: { action: 'open_academic_onboarding' },
                })),
            }),
            prisma.academicProfile.updateMany({
                where: { id: { in: profileIds } },
                data: { status: 'PENDING' },
            }),
        ]);

        return { processed: expiredProfiles.length };
    }
}
