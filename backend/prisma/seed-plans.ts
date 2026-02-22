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
}

const plans: PlanSeed[] = [
    {
        slug: 'free',
        name: 'Free',
        order: 0,
        priceMonthly: 0,
        priceYearly: 0,
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
    },
    {
        slug: 'basic',
        name: 'Basic',
        order: 1,
        priceMonthly: 599,
        priceYearly: 5999,
        maxStudents: 75,
        maxParents: 75,
        maxTeachers: 15,
        maxAdmins: 2,
        maxBatches: 15,
        maxAssessmentsPerMonth: 50,
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
    },
    {
        slug: 'standard',
        name: 'Standard',
        order: 2,
        priceMonthly: 1499,
        priceYearly: 14999,
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
    },
    {
        slug: 'premium',
        name: 'Premium',
        order: 3,
        priceMonthly: 2999,
        priceYearly: 29999,
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

    console.log('Done — 4 plans seeded.');
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(() => prisma.$disconnect());
