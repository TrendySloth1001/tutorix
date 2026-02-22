-- DropForeignKey
ALTER TABLE "FeeAssignment" DROP CONSTRAINT "FeeAssignment_memberId_fkey";

-- DropForeignKey
ALTER TABLE "FeeRecord" DROP CONSTRAINT "FeeRecord_memberId_fkey";

-- AlterTable
ALTER TABLE "CoachingMember" ADD COLUMN     "removedAt" TIMESTAMP(3);

-- AddForeignKey
ALTER TABLE "FeeAssignment" ADD CONSTRAINT "FeeAssignment_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CoachingMember"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRecord" ADD CONSTRAINT "FeeRecord_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CoachingMember"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
