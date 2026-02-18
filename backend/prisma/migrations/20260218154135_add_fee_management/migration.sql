-- CreateTable
CREATE TABLE "FeeStructure" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "amount" DOUBLE PRECISION NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "cycle" TEXT NOT NULL DEFAULT 'MONTHLY',
    "lateFinePerDay" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discounts" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeeStructure_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeeAssignment" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "feeStructureId" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "customAmount" DOUBLE PRECISION,
    "discountAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountReason" TEXT,
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeeAssignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeeRecord" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "assignmentId" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "baseAmount" DOUBLE PRECISION NOT NULL,
    "discountAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "fineAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "finalAmount" DOUBLE PRECISION NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "paidAt" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "paymentMode" TEXT,
    "transactionRef" TEXT,
    "receiptNo" TEXT,
    "paidAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "notes" TEXT,
    "reminderSentAt" TIMESTAMP(3),
    "reminderCount" INTEGER NOT NULL DEFAULT 0,
    "markedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeeRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeePayment" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "recordId" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "mode" TEXT NOT NULL,
    "transactionRef" TEXT,
    "receiptNo" TEXT,
    "notes" TEXT,
    "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "recordedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeePayment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FeeStructure_coachingId_idx" ON "FeeStructure"("coachingId");

-- CreateIndex
CREATE INDEX "FeeStructure_coachingId_isActive_idx" ON "FeeStructure"("coachingId", "isActive");

-- CreateIndex
CREATE INDEX "FeeAssignment_coachingId_idx" ON "FeeAssignment"("coachingId");

-- CreateIndex
CREATE INDEX "FeeAssignment_memberId_idx" ON "FeeAssignment"("memberId");

-- CreateIndex
CREATE INDEX "FeeAssignment_feeStructureId_idx" ON "FeeAssignment"("feeStructureId");

-- CreateIndex
CREATE UNIQUE INDEX "FeeAssignment_feeStructureId_memberId_key" ON "FeeAssignment"("feeStructureId", "memberId");

-- CreateIndex
CREATE INDEX "FeeRecord_coachingId_idx" ON "FeeRecord"("coachingId");

-- CreateIndex
CREATE INDEX "FeeRecord_memberId_idx" ON "FeeRecord"("memberId");

-- CreateIndex
CREATE INDEX "FeeRecord_assignmentId_idx" ON "FeeRecord"("assignmentId");

-- CreateIndex
CREATE INDEX "FeeRecord_coachingId_status_idx" ON "FeeRecord"("coachingId", "status");

-- CreateIndex
CREATE INDEX "FeeRecord_coachingId_dueDate_idx" ON "FeeRecord"("coachingId", "dueDate");

-- CreateIndex
CREATE INDEX "FeeRecord_memberId_status_idx" ON "FeeRecord"("memberId", "status");

-- CreateIndex
CREATE INDEX "FeeRecord_memberId_dueDate_idx" ON "FeeRecord"("memberId", "dueDate");

-- CreateIndex
CREATE INDEX "FeePayment_recordId_idx" ON "FeePayment"("recordId");

-- CreateIndex
CREATE INDEX "FeePayment_coachingId_idx" ON "FeePayment"("coachingId");

-- CreateIndex
CREATE INDEX "FeePayment_coachingId_paidAt_idx" ON "FeePayment"("coachingId", "paidAt");

-- AddForeignKey
ALTER TABLE "FeeStructure" ADD CONSTRAINT "FeeStructure_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeAssignment" ADD CONSTRAINT "FeeAssignment_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeAssignment" ADD CONSTRAINT "FeeAssignment_feeStructureId_fkey" FOREIGN KEY ("feeStructureId") REFERENCES "FeeStructure"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeAssignment" ADD CONSTRAINT "FeeAssignment_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CoachingMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRecord" ADD CONSTRAINT "FeeRecord_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRecord" ADD CONSTRAINT "FeeRecord_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "FeeAssignment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRecord" ADD CONSTRAINT "FeeRecord_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CoachingMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeRecord" ADD CONSTRAINT "FeeRecord_markedById_fkey" FOREIGN KEY ("markedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeePayment" ADD CONSTRAINT "FeePayment_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeePayment" ADD CONSTRAINT "FeePayment_recordId_fkey" FOREIGN KEY ("recordId") REFERENCES "FeeRecord"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeePayment" ADD CONSTRAINT "FeePayment_recordedById_fkey" FOREIGN KEY ("recordedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
