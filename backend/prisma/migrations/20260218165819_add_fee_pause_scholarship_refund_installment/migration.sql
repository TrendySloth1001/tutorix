-- AlterTable
ALTER TABLE "FeeAssignment" ADD COLUMN     "isPaused" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "pauseNote" TEXT,
ADD COLUMN     "pausedAt" TIMESTAMP(3),
ADD COLUMN     "scholarshipAmount" DOUBLE PRECISION,
ADD COLUMN     "scholarshipTag" TEXT;

-- AlterTable
ALTER TABLE "FeeStructure" ADD COLUMN     "installmentPlan" JSONB;

-- CreateTable
CREATE TABLE "FeeRefund" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "recordId" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "reason" TEXT,
    "mode" TEXT NOT NULL DEFAULT 'CASH',
    "refundedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeeRefund_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FeeRefund_recordId_idx" ON "FeeRefund"("recordId");

-- CreateIndex
CREATE INDEX "FeeRefund_coachingId_idx" ON "FeeRefund"("coachingId");

-- AddForeignKey
ALTER TABLE "FeeRefund" ADD CONSTRAINT "FeeRefund_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRefund" ADD CONSTRAINT "FeeRefund_recordId_fkey" FOREIGN KEY ("recordId") REFERENCES "FeeRecord"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRefund" ADD CONSTRAINT "FeeRefund_processedById_fkey" FOREIGN KEY ("processedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
