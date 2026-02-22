import prisma from '../../infra/prisma.js';
import redis from '../../infra/redis.js';
import { assessmentService } from '../assessment/assessment.service.js';
import { CreditService } from '../subscription/credit.service.js';
import Razorpay from 'razorpay';

const creditService = new CreditService();

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID;
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
const razorpay = RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET
    ? new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET })
    : null;

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
                    select: {
                        members: true,
                    },
                },
                address: true,
                branches: {
                    where: { isActive: true },
                    orderBy: { createdAt: 'asc' },
                },
            },
        });

        if (coachings.length === 0) return [];

        // Single groupBy query replaces N+1 count queries
        const roleCounts = await prisma.coachingMember.groupBy({
            by: ['coachingId', 'role'],
            where: { coachingId: { in: coachings.map(c => c.id) } },
            _count: true,
        });

        // Build lookup map: coachingId → { TEACHER: n, STUDENT: n }
        const statsMap = new Map<string, { teacherCount: number; studentCount: number }>();
        for (const row of roleCounts) {
            const entry = statsMap.get(row.coachingId) ?? { teacherCount: 0, studentCount: 0 };
            if (row.role === 'TEACHER') entry.teacherCount = row._count;
            else if (row.role === 'STUDENT') entry.studentCount = row._count;
            statsMap.set(row.coachingId, entry);
        }

        return coachings.map((coaching) => ({
            ...coaching,
            storageUsed: Number(coaching.storageUsed),
            storageLimit: Number(coaching.storageLimit),
            memberCount: coaching._count.members,
            teacherCount: statsMap.get(coaching.id)?.teacherCount ?? 0,
            studentCount: statsMap.get(coaching.id)?.studentCount ?? 0,
            _count: undefined,
        }));
    }

    /**
     * Find coachings where user is a member (but not owner).
     */
    async findByMember(userId: string) {
        const memberships = await prisma.coachingMember.findMany({
            where: { userId, status: { not: 'removed' } },
            include: {
                coaching: {
                    include: {
                        owner: {
                            select: { id: true, name: true, picture: true },
                        },
                        _count: {
                            select: { members: true },
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

        // Filter out coachings where user is owner
        const filtered = memberships.filter((m) => m.coaching.ownerId !== userId);

        if (filtered.length === 0) return [];

        // Single groupBy query replaces N+1 count queries
        const coachingIds = filtered.map(m => m.coaching.id);
        const roleCounts = await prisma.coachingMember.groupBy({
            by: ['coachingId', 'role'],
            where: { coachingId: { in: coachingIds } },
            _count: true,
        });

        const statsMap = new Map<string, { teacherCount: number; studentCount: number }>();
        for (const row of roleCounts) {
            const entry = statsMap.get(row.coachingId) ?? { teacherCount: 0, studentCount: 0 };
            if (row.role === 'TEACHER') entry.teacherCount = row._count;
            else if (row.role === 'STUDENT') entry.studentCount = row._count;
            statsMap.set(row.coachingId, entry);
        }

        return filtered.map((m) => {
            const coaching = m.coaching;
            const stats = statsMap.get(coaching.id) ?? { teacherCount: 0, studentCount: 0 };
            return {
                id: coaching.id,
                name: coaching.name,
                slug: coaching.slug,
                description: coaching.description,
                logo: coaching.logo,
                coverImage: coaching.coverImage,
                status: coaching.status,
                ownerId: coaching.ownerId,
                owner: coaching.owner,
                createdAt: coaching.createdAt,
                updatedAt: coaching.updatedAt,
                memberCount: coaching._count.members,
                teacherCount: stats.teacherCount,
                studentCount: stats.studentCount,
                myRole: m.role,
                address: coaching.address,
                branches: coaching.branches,
            };
        });
    }

    async update(id: string, ownerId: string, data: UpdateCoachingDto) {
        // Single query: update only if owner matches (returns count=0 if not found/unauthorized)
        const result = await prisma.coaching.updateMany({
            where: { id, ownerId },
            data,
        });

        if (result.count === 0) {
            throw new Error('Coaching not found or you do not have permission');
        }

        // Return the updated coaching
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

    async delete(id: string, ownerId: string) {
        // 1. Verify ownership
        const coaching = await prisma.coaching.findFirst({
            where: { id, ownerId },
            select: { id: true, name: true, ownerId: true },
        });
        if (!coaching) {
            throw new Error('Coaching not found or you do not have permission');
        }

        // 2. Issue credit for remaining subscription value (50%)
        let creditResult = { creditIssuedPaise: 0, message: 'No credit issued.' };
        try {
            creditResult = await creditService.issueDeleteCredit(ownerId, id, coaching.name);
        } catch (e: any) {
            console.error('[CoachingService] Credit issue error:', e.message);
        }

        // 3. Cancel Razorpay subscription if active
        const sub = await prisma.subscription.findUnique({
            where: { coachingId: id },
            select: { razorpaySubscriptionId: true },
        });
        if (sub?.razorpaySubscriptionId && razorpay) {
            try {
                await razorpay.subscriptions.cancel(sub.razorpaySubscriptionId, true); // cancel immediately
            } catch (e: any) {
                console.error('[CoachingService] Razorpay cancel error:', e.message);
            }
        }

        // 4. Notify all members before deletion
        const members = await prisma.coachingMember.findMany({
            where: { coachingId: id, status: 'active' },
            select: { userId: true },
        });
        const memberUserIds = members
            .map(m => m.userId)
            .filter((uid): uid is string => uid != null && uid !== ownerId);

        if (memberUserIds.length > 0) {
            await prisma.notification.createMany({
                data: memberUserIds.map(uid => ({
                    userId: uid,
                    type: 'COACHING_DELETED',
                    title: 'Coaching Deleted',
                    message: `"${coaching.name}" has been deleted by the owner. You have been removed.`,
                    // NOTE: coachingId left null — coaching is about to be cascade-deleted
                })),
            });
        }

        // 5. Invalidate Redis cache
        try {
            await redis.del(`coaching:${id}`);
            await redis.del('coaching:searchable');
        } catch (_) { /* ignore redis errors */ }

        // 6. Delete coaching (cascades to members, batches, fees, assessments, etc.)
        await prisma.coaching.delete({ where: { id } });

        return {
            deleted: true,
            creditIssuedPaise: creditResult.creditIssuedPaise,
            creditMessage: creditResult.message,
        };
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

    /**
     * Find coachings near a location using the Haversine formula.
     * Uses a bounding-box pre-filter on the DB query to avoid loading
     * rows that are obviously outside the radius, then refines with
     * Haversine in JS for accurate distance.
     */
    async findNearby(lat: number, lng: number, radiusKm: number = 20, page: number = 1, limit: number = 20) {
        // Clamp radius to a sane maximum (500 km)
        const safeRadius = Math.min(radiusKm, 500);

        // Bounding box: ~1 degree ≈ 111 km
        const degDelta = safeRadius / 111;
        const minLat = lat - degDelta;
        const maxLat = lat + degDelta;
        const minLng = lng - degDelta;
        const maxLng = lng + degDelta;

        const coachings = await prisma.coaching.findMany({
            where: {
                status: 'active',
                onboardingComplete: true,
                address: {
                    latitude: { gte: minLat, lte: maxLat },
                    longitude: { gte: minLng, lte: maxLng },
                },
            },
            // Cap DB results to prevent unbounded memory for huge bounding boxes
            take: 500,
            select: {
                id: true,
                name: true,
                slug: true,
                description: true,
                logo: true,
                coverImage: true,
                status: true,
                ownerId: true,
                category: true,
                subjects: true,
                isVerified: true,
                tagline: true,
                createdAt: true,
                updatedAt: true,
                owner: {
                    select: { id: true, name: true, picture: true },
                },
                address: true,
                _count: { select: { members: true } },
            },
        });

        // Haversine distance in km
        const toRad = (deg: number) => (deg * Math.PI) / 180;
        const haversine = (lat1: number, lon1: number, lat2: number, lon2: number) => {
            const R = 6371; // Earth radius in km
            const dLat = toRad(lat2 - lat1);
            const dLon = toRad(lon2 - lon1);
            const a =
                Math.sin(dLat / 2) ** 2 +
                Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
            return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        };

        // Filter with exact Haversine + compute distance
        const withDistance = coachings
            .map((c) => {
                const addr = c.address;
                // Skip coachings with null/invalid addresses
                if (!addr || addr.latitude == null || addr.longitude == null) {
                    console.warn(`⚠️ Coaching ${c.id} has invalid address, skipping`);
                    return null;
                }
                const dist = haversine(lat, lng, addr.latitude, addr.longitude);
                return { coaching: c, distance: Math.round(dist * 10) / 10 };
            })
            .filter((c): c is { coaching: any; distance: number } => c !== null && c.distance <= safeRadius)
            .sort((a, b) => a.distance - b.distance);

        const total = withDistance.length;
        const skip = (page - 1) * limit;
        const paged = withDistance.slice(skip, skip + limit);

        return {
            coachings: paged.map(({ coaching, distance }) => ({
                id: coaching.id,
                name: coaching.name,
                slug: coaching.slug,
                description: coaching.description,
                logo: coaching.logo,
                coverImage: coaching.coverImage,
                status: coaching.status,
                ownerId: coaching.ownerId,
                owner: coaching.owner,
                createdAt: coaching.createdAt,
                updatedAt: coaching.updatedAt,
                memberCount: coaching._count.members,
                category: coaching.category,
                subjects: coaching.subjects,
                isVerified: coaching.isVerified,
                tagline: coaching.tagline,
                address: coaching.address,
                distance,
            })),
            pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
        };
    }

    /**
     * Search active coachings by name (prefix / contains).
     * Uses Redis cache to avoid DB hits on every keystroke.
     * All searchable coachings are cached in Redis for 5 min,
     * then filtered in-memory per query.
     */
    async search(query: string, limit: number = 15) {
        const safeLimit = Math.min(Math.max(limit, 1), 50);
        const CACHE_KEY = 'coaching:searchable';
        const CACHE_TTL = 300; // 5 minutes

        let all: any[] | null = null;

        // 1. Try Redis cache first
        try {
            const cached = await redis.get(CACHE_KEY);
            if (cached) {
                all = JSON.parse(cached);
            }
        } catch { /* Redis miss or error — fall through to DB */ }

        // 2. Cache miss — load all searchable coachings from DB
        if (!all) {
            const coachings = await prisma.coaching.findMany({
                where: {
                    status: 'active',
                    onboardingComplete: true,
                },
                select: {
                    id: true,
                    name: true,
                    slug: true,
                    logo: true,
                    category: true,
                    isVerified: true,
                    address: { select: { city: true, state: true, latitude: true, longitude: true } },
                    _count: { select: { members: true } },
                },
                orderBy: { name: 'asc' },
            });

            all = coachings.map((c) => ({
                id: c.id,
                name: c.name,
                slug: c.slug,
                logo: c.logo,
                category: c.category,
                isVerified: c.isVerified,
                city: c.address?.city ?? null,
                state: c.address?.state ?? null,
                latitude: c.address?.latitude ?? null,
                longitude: c.address?.longitude ?? null,
                memberCount: c._count.members,
            }));

            // Persist to Redis (best-effort)
            try { await redis.set(CACHE_KEY, JSON.stringify(all), 'EX', CACHE_TTL); } catch { }
        }

        // 3. Filter in-memory and return
        const lowerQ = query.toLowerCase();
        return all
            .filter((c: any) => c.name.toLowerCase().includes(lowerQ))
            .slice(0, safeLimit);
    }

    async getMembers(coachingId: string) {
        const members = await prisma.coachingMember.findMany({
            where: { coachingId, status: { not: 'removed' } },
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

        // Soft-delete member and create notification in transaction.
        // We NEVER hard-delete a CoachingMember once fee records exist —
        // financial history must remain tied to the coaching & member row.
        await prisma.$transaction(async (tx) => {
            const removedAt = new Date();

            // Soft-delete: mark removed, never physically delete
            if (member.userId) {
                await tx.coachingMember.updateMany({
                    where: { coachingId, userId: member.userId, status: { not: 'removed' } },
                    data: { status: 'removed', removedAt },
                });
            } else if (member.wardId) {
                await tx.coachingMember.updateMany({
                    where: { coachingId, wardId: member.wardId, status: { not: 'removed' } },
                    data: { status: 'removed', removedAt },
                });
            }

            // Deactivate any ongoing fee assignments for this member
            // so no new fee records are generated after removal.
            await tx.feeAssignment.updateMany({
                where: { coachingId, memberId: member.id, isActive: true },
                data: { isActive: false, endDate: removedAt },
            });

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
        const count = await prisma.coaching.count({ where: { slug } });
        return count === 0;
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

    async deleteBranch(branchId: string, coachingId: string) {
        return prisma.coachingBranch.delete({
            where: { id: branchId, coachingId },
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

    // ── Saved / Bookmarked Coachings ──────────────────────────────────

    async saveCoaching(userId: string, coachingId: string) {
        return prisma.savedCoaching.upsert({
            where: { userId_coachingId: { userId, coachingId } },
            create: { userId, coachingId },
            update: {},
        });
    }

    async unsaveCoaching(userId: string, coachingId: string) {
        return prisma.savedCoaching.deleteMany({
            where: { userId, coachingId },
        });
    }

    async getSavedCoachings(userId: string) {
        const saved = await prisma.savedCoaching.findMany({
            where: { userId },
            include: {
                coaching: {
                    select: {
                        id: true,
                        name: true,
                        slug: true,
                        logo: true,
                        category: true,
                        isVerified: true,
                        address: { select: { city: true, state: true, latitude: true, longitude: true } },
                        _count: { select: { members: true } },
                    },
                },
            },
            orderBy: { createdAt: 'desc' },
        });

        return saved.map((s) => ({
            id: s.coaching.id,
            name: s.coaching.name,
            slug: s.coaching.slug,
            logo: s.coaching.logo,
            category: s.coaching.category,
            isVerified: s.coaching.isVerified,
            city: s.coaching.address?.city ?? null,
            state: s.coaching.address?.state ?? null,
            latitude: s.coaching.address?.latitude ?? null,
            longitude: s.coaching.address?.longitude ?? null,
            memberCount: s.coaching._count.members,
            savedAt: s.createdAt,
        }));
    }

    async isCoachingSaved(userId: string, coachingId: string): Promise<boolean> {
        const saved = await prisma.savedCoaching.findUnique({
            where: { userId_coachingId: { userId, coachingId } },
        });
        return !!saved;
    }

    async getMemberAcademicHistory(coachingId: string, memberId: string) {
        const member = await prisma.coachingMember.findFirst({
            where: { id: memberId, coachingId },
            select: { userId: true },
        });

        if (!member) throw new Error('Member not found');
        if (!member.userId) return []; // Member has no associated user account to take tests

        return assessmentService.getStudentResults(member.userId);
    }
}
