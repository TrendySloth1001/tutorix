-- AlterTable
ALTER TABLE "FeeStructure" ADD COLUMN     "allowInstallments" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "installmentAmounts" JSONB,
ADD COLUMN     "installmentCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "isCurrent" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "replacedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "FeeAuditLog" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "feeStructureId" TEXT,
    "event" TEXT NOT NULL,
    "actorType" TEXT NOT NULL DEFAULT 'ADMIN',
    "actorId" TEXT,
    "before" JSONB,
    "after" JSONB,
    "meta" JSONB,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeeAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FeeAuditLog_coachingId_idx" ON "FeeAuditLog"("coachingId");

-- CreateIndex
CREATE INDEX "FeeAuditLog_coachingId_entityType_idx" ON "FeeAuditLog"("coachingId", "entityType");

-- CreateIndex
CREATE INDEX "FeeAuditLog_coachingId_createdAt_idx" ON "FeeAuditLog"("coachingId", "createdAt");

-- CreateIndex
CREATE INDEX "FeeAuditLog_entityId_idx" ON "FeeAuditLog"("entityId");

-- AddForeignKey
ALTER TABLE "FeeAuditLog" ADD CONSTRAINT "FeeAuditLog_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeAuditLog" ADD CONSTRAINT "FeeAuditLog_feeStructureId_fkey" FOREIGN KEY ("feeStructureId") REFERENCES "FeeStructure"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeeAuditLog" ADD CONSTRAINT "FeeAuditLog_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
