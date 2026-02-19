-- AlterTable
ALTER TABLE "Coaching" ADD COLUMN     "bankAccountName" TEXT,
ADD COLUMN     "bankAccountNumber" TEXT,
ADD COLUMN     "bankIfscCode" TEXT,
ADD COLUMN     "bankName" TEXT,
ADD COLUMN     "gstNumber" TEXT,
ADD COLUMN     "panNumber" TEXT,
ADD COLUMN     "platformFeePercent" DOUBLE PRECISION NOT NULL DEFAULT 1.0,
ADD COLUMN     "razorpayAccountId" TEXT,
ADD COLUMN     "razorpayActivated" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "FeePayment" ADD COLUMN     "razorpayTransferId" TEXT;

-- AlterTable
ALTER TABLE "FeeRecord" ADD COLUMN     "cessAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "cgstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "gstRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "hsnCode" TEXT,
ADD COLUMN     "igstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "lineItems" JSONB,
ADD COLUMN     "sacCode" TEXT,
ADD COLUMN     "sgstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "taxType" TEXT NOT NULL DEFAULT 'NONE';

-- AlterTable
ALTER TABLE "FeeStructure" ADD COLUMN     "cessRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "gstRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "gstSupplyType" TEXT NOT NULL DEFAULT 'INTRA_STATE',
ADD COLUMN     "hsnCode" TEXT,
ADD COLUMN     "lineItems" JSONB,
ADD COLUMN     "sacCode" TEXT,
ADD COLUMN     "taxType" TEXT NOT NULL DEFAULT 'NONE';

-- AlterTable
ALTER TABLE "RazorpayOrder" ADD COLUMN     "platformFeePaise" INTEGER,
ADD COLUMN     "transferId" TEXT,
ADD COLUMN     "transferStatus" TEXT;

-- CreateTable
CREATE TABLE "ReceiptSequence" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "financialYear" TEXT NOT NULL,
    "lastNumber" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReceiptSequence_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ReceiptSequence_coachingId_financialYear_key" ON "ReceiptSequence"("coachingId", "financialYear");

-- AddForeignKey
ALTER TABLE "ReceiptSequence" ADD CONSTRAINT "ReceiptSequence_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;
