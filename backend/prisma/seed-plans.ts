/**
 * Seed the Plan table with the 4 fixed tiers.
 * Run: npx tsx prisma/seed-plans.ts
 *
 * Idempotent — uses upsert so re-running is safe.
 */
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const GB = 1_073_741_824;
const MB = 1_048_576;

interface PlanSeed {
    slug: string;
    name: string;
    order: number;
    priceMonthly: number;
    priceYearly: number;
    mrpMonthly: number;
    mrpYearly: number;
    maxStudents: number;
    maxParents: number;
    maxTeachers: number;
    maxAdmins: number;
    maxBatches: number;
    maxAssessmentsPerMonth: number;
    storageLimitBytes: bigint;
    hasRazorpay: boolean;
    hasAutoRemind: boolean;
    hasFeeReports: boolean;
    hasFeeLedger: boolean;
    hasRoutePayouts: boolean;
    hasPushNotify: boolean;
    hasEmailNotify: boolean;
    hasSmsNotify: boolean;
    hasWhatsappNotify: boolean;
    hasCustomLogo: boolean;
    hasWhiteLabel: boolean;
    hasWebManagement: boolean;
}

const plans: PlanSeed[] = [
    {
        slug: 'free',
        name: 'Free',
        order: 0,
        priceMonthly: 0,
        priceYearly: 0,
        mrpMonthly: 0,
        mrpYearly: 0,
        maxStudents: 10,
        maxParents: 10,
        maxTeachers: 5,
        maxAdmins: 1,
        maxBatches: 3,
        maxAssessmentsPerMonth: 5,
        storageLimitBytes: BigInt(200 * MB),
        hasRazorpay: false,
        hasAutoRemind: false,
        hasFeeReports: false,
        hasFeeLedger: false,
        hasRoutePayouts: false,
        hasPushNotify: false,
        hasEmailNotify: false,
        hasSmsNotify: false,
        hasWhatsappNotify: false,
        hasCustomLogo: false,
        hasWhiteLabel: false,
        hasWebManagement: false,
    },
    {
        slug: 'web-portal',
        name: 'Web Portal',
        order: 1,
        priceMonthly: 499,
        priceYearly: 4999,
        mrpMonthly: 0,
        mrpYearly: 0,
        maxStudents: 100,
        maxParents: 100,
        maxTeachers: 10,
        maxAdmins: 3,
        maxBatches: -1,
        maxAssessmentsPerMonth: 20,
        storageLimitBytes: BigInt(2 * GB),
        hasRazorpay: true,
        hasAutoRemind: false,
        hasFeeReports: false,
        hasFeeLedger: false,
        hasRoutePayouts: false,
        hasPushNotify: true,
        hasEmailNotify: false,
        hasSmsNotify: false,
        hasWhatsappNotify: false,
        hasCustomLogo: false,
        hasWhiteLabel: false,
        hasWebManagement: true,
    },
    {
        slug: 'basic',
        name: 'Basic',
        order: 2,
        priceMonthly: 599,
        priceYearly: 5999,
        mrpMonthly: 0,
        mrpYearly: 0,
        maxStudents: 1,
        maxParents: 1,
        maxTeachers: 1,
        maxAdmins: 2,
        maxBatches: 1,
        maxAssessmentsPerMonth: 50,
        storageLimitBytes: BigInt(5 * MB),
        hasRazorpay: true,
        hasAutoRemind: false,
        hasFeeReports: false,
        hasFeeLedger: false,
        hasRoutePayouts: false,
        hasPushNotify: true,
        hasEmailNotify: false,
        hasSmsNotify: false,
        hasWhatsappNotify: false,
        hasCustomLogo: false,
        hasWhiteLabel: false,
        hasWebManagement: false,
    },
    {
        slug: 'standard',
        name: 'Standard',
        order: 3,
        priceMonthly: 1499,
        priceYearly: 14999,
        mrpMonthly: 0,
        mrpYearly: 0,
        maxStudents: 300,
        maxParents: 300,
        maxTeachers: 40,
        maxAdmins: 5,
        maxBatches: -1, // -1 = unlimited
        maxAssessmentsPerMonth: -1,
        storageLimitBytes: BigInt(10 * GB),
        hasRazorpay: true,
        hasAutoRemind: true,
        hasFeeReports: false,
        hasFeeLedger: false,
        hasRoutePayouts: false,
        hasPushNotify: true,
        hasEmailNotify: true,
        hasSmsNotify: false,
        hasWhatsappNotify: false,
        hasCustomLogo: true,
        hasWhiteLabel: false,
        hasWebManagement: false,
    },
    {
        slug: 'premium',
        name: 'Premium',
        order: 4,
        priceMonthly: 3299,
        priceYearly: 32999,
        mrpMonthly: 3499,
        mrpYearly: 34999,
        maxStudents: 1000,
        maxParents: 1000,
        maxTeachers: 100,
        maxAdmins: 10,
        maxBatches: -1,
        maxAssessmentsPerMonth: -1,
        storageLimitBytes: BigInt(50 * GB),
        hasRazorpay: true,
        hasAutoRemind: true,
        hasFeeReports: true,
        hasFeeLedger: true,
        hasRoutePayouts: true,
        hasPushNotify: true,
        hasEmailNotify: true,
        hasSmsNotify: true,
        hasWhatsappNotify: false,
        hasCustomLogo: true,
        hasWhiteLabel: true,
        hasWebManagement: true,
    },
];

async function main() {
    console.log('Seeding plans...');

    for (const plan of plans) {
        await prisma.plan.upsert({
            where: { slug: plan.slug },
            update: { ...plan },
            create: { ...plan },
        });
        console.log(`  ✓ ${plan.name} (₹${plan.priceMonthly}/mo)`);
    }

    console.log('Done — 5 plans seeded.');
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(() => prisma.$disconnect());
