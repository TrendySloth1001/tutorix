-- AlterTable
ALTER TABLE "FeePayment" ADD COLUMN     "razorpayOrderId" TEXT,
ADD COLUMN     "razorpayPaymentId" TEXT;

-- CreateTable
CREATE TABLE "RazorpayOrder" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "recordId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "razorpayOrderId" TEXT NOT NULL,
    "amountPaise" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "status" TEXT NOT NULL DEFAULT 'CREATED',
    "razorpayPaymentId" TEXT,
    "razorpaySignature" TEXT,
    "webhookReceived" BOOLEAN NOT NULL DEFAULT false,
    "webhookReceivedAt" TIMESTAMP(3),
    "receipt" TEXT,
    "notes" JSONB,
    "paymentRecorded" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RazorpayOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RazorpayWebhookLog" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT,
    "event" TEXT NOT NULL,
    "orderId" TEXT,
    "paymentId" TEXT,
    "refundId" TEXT,
    "payload" JSONB NOT NULL,
    "signature" TEXT NOT NULL,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "processed" BOOLEAN NOT NULL DEFAULT false,
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RazorpayWebhookLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RazorpayRefund" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "feeRefundId" TEXT NOT NULL,
    "razorpayRefundId" TEXT,
    "razorpayPaymentId" TEXT NOT NULL,
    "amountPaise" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'INITIATED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RazorpayRefund_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "RazorpayOrder_razorpayOrderId_key" ON "RazorpayOrder"("razorpayOrderId");

-- CreateIndex
CREATE INDEX "RazorpayOrder_coachingId_idx" ON "RazorpayOrder"("coachingId");

-- CreateIndex
CREATE INDEX "RazorpayOrder_recordId_idx" ON "RazorpayOrder"("recordId");

-- CreateIndex
CREATE INDEX "RazorpayOrder_userId_idx" ON "RazorpayOrder"("userId");

-- CreateIndex
CREATE INDEX "RazorpayOrder_status_idx" ON "RazorpayOrder"("status");

-- CreateIndex
CREATE INDEX "RazorpayOrder_razorpayOrderId_idx" ON "RazorpayOrder"("razorpayOrderId");

-- CreateIndex
CREATE INDEX "RazorpayWebhookLog_event_idx" ON "RazorpayWebhookLog"("event");

-- CreateIndex
CREATE INDEX "RazorpayWebhookLog_orderId_idx" ON "RazorpayWebhookLog"("orderId");

-- CreateIndex
CREATE INDEX "RazorpayWebhookLog_paymentId_idx" ON "RazorpayWebhookLog"("paymentId");

-- CreateIndex
CREATE INDEX "RazorpayWebhookLog_createdAt_idx" ON "RazorpayWebhookLog"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "RazorpayRefund_feeRefundId_key" ON "RazorpayRefund"("feeRefundId");

-- CreateIndex
CREATE INDEX "RazorpayRefund_coachingId_idx" ON "RazorpayRefund"("coachingId");

-- CreateIndex
CREATE INDEX "RazorpayRefund_razorpayPaymentId_idx" ON "RazorpayRefund"("razorpayPaymentId");

-- CreateIndex
CREATE INDEX "RazorpayRefund_status_idx" ON "RazorpayRefund"("status");

-- AddForeignKey
ALTER TABLE "RazorpayOrder" ADD CONSTRAINT "RazorpayOrder_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RazorpayOrder" ADD CONSTRAINT "RazorpayOrder_recordId_fkey" FOREIGN KEY ("recordId") REFERENCES "FeeRecord"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RazorpayOrder" ADD CONSTRAINT "RazorpayOrder_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RazorpayWebhookLog" ADD CONSTRAINT "RazorpayWebhookLog_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RazorpayRefund" ADD CONSTRAINT "RazorpayRefund_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RazorpayRefund" ADD CONSTRAINT "RazorpayRefund_feeRefundId_fkey" FOREIGN KEY ("feeRefundId") REFERENCES "FeeRefund"("id") ON DELETE CASCADE ON UPDATE CASCADE;
