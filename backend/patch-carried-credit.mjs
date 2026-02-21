import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

async function main() {
  // Find all active records whose discountAmount doesn't account for the carried credit.
  // A carried credit record has a WAIVED sibling on the same assignment with paidAmount > 0
  // and notes containing 'auto-waived'.
  const waived = await prisma.feeRecord.findMany({
    where: {
      status: 'WAIVED',
      notes: { contains: 'auto-waived' },
      paidAmount: { gt: 0 },
    },
    select: { id: true, assignmentId: true, paidAmount: true, finalAmount: true, memberId: true },
  });

  if (waived.length === 0) {
    console.log('No carried-credit waived records found.');
    return;
  }

  console.log(`Found ${waived.length} waived record(s) to check.`);

  for (const w of waived) {
    // Find the active sibling on the same assignment that was created AFTER this waived record
    const activeRecord = await prisma.feeRecord.findFirst({
      where: {
        assignmentId: w.assignmentId,
        status: { notIn: ['PAID', 'WAIVED'] },
        paidAmount: 0,
      },
      orderBy: { createdAt: 'asc' },
    });

    if (!activeRecord) {
      console.log(`  [${w.id}] No unpaid active sibling found — skipping.`);
      continue;
    }

    const credit = w.paidAmount;
    // The active record's baseAmount is the structure amount (raw, pre-discount)
    const expectedFinalAmount = Math.max(0, activeRecord.baseAmount - activeRecord.discountAmount - credit);

    if (Math.abs(activeRecord.finalAmount - expectedFinalAmount) < 0.01) {
      console.log(`  [${activeRecord.id}] Already correct (finalAmount=${activeRecord.finalAmount}).`);
      continue;
    }

    console.log(`  [${activeRecord.id}] baseAmount=${activeRecord.baseAmount} discountAmount=${activeRecord.discountAmount}`);
    console.log(`  Applying credit ₹${credit}: ${activeRecord.finalAmount} → ${expectedFinalAmount}`);

    await prisma.feeRecord.update({
      where: { id: activeRecord.id },
      data: {
        discountAmount: activeRecord.discountAmount + credit,
        finalAmount: expectedFinalAmount,
        amount: expectedFinalAmount,
      },
    });

    console.log(`  ✓ Updated record ${activeRecord.id}`);
  }

  console.log('\nDone.');
}

main().catch(console.error).finally(() => prisma.$disconnect());
