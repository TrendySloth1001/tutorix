/*
  Warnings:

  - A unique constraint covering the columns `[recordId,razorpayPaymentId]` on the table `FeePayment` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[razorpayRefundId]` on the table `RazorpayRefund` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "RazorpayOrder" ADD COLUMN     "platformFeePercent" DOUBLE PRECISION;

-- CreateIndex
CREATE UNIQUE INDEX "FeePayment_recordId_razorpayPaymentId_key" ON "FeePayment"("recordId", "razorpayPaymentId");

-- CreateIndex
CREATE INDEX "RazorpayOrder_transferId_idx" ON "RazorpayOrder"("transferId");

-- CreateIndex
CREATE UNIQUE INDEX "RazorpayRefund_razorpayRefundId_key" ON "RazorpayRefund"("razorpayRefundId");
