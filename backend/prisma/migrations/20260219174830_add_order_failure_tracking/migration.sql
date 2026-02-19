-- AlterTable
ALTER TABLE "RazorpayOrder" ADD COLUMN     "failedAt" TIMESTAMP(3),
ADD COLUMN     "failureReason" TEXT;
