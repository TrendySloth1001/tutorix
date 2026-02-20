/*
  Warnings:

  - A unique constraint covering the columns `[coachingId,memberId]` on the table `FeeAssignment` will be added. If there are existing duplicate values, this will fail.

*/
-- DropIndex
DROP INDEX "FeeAssignment_coachingId_idx";

-- DropIndex
DROP INDEX "FeeAssignment_feeStructureId_memberId_key";

-- CreateIndex
CREATE UNIQUE INDEX "FeeAssignment_coachingId_memberId_key" ON "FeeAssignment"("coachingId", "memberId");
