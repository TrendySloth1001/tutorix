-- CreateTable
CREATE TABLE "Plan" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "order" INTEGER NOT NULL DEFAULT 0,
    "priceMonthly" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "priceYearly" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "maxStudents" INTEGER NOT NULL DEFAULT 10,
    "maxParents" INTEGER NOT NULL DEFAULT 10,
    "maxTeachers" INTEGER NOT NULL DEFAULT 5,
    "maxAdmins" INTEGER NOT NULL DEFAULT 1,
    "maxBatches" INTEGER NOT NULL DEFAULT 3,
    "maxAssessmentsPerMonth" INTEGER NOT NULL DEFAULT 5,
    "storageLimitBytes" BIGINT NOT NULL DEFAULT 209715200,
    "hasRazorpay" BOOLEAN NOT NULL DEFAULT false,
    "hasAutoRemind" BOOLEAN NOT NULL DEFAULT false,
    "hasFeeReports" BOOLEAN NOT NULL DEFAULT false,
    "hasFeeLedger" BOOLEAN NOT NULL DEFAULT false,
    "hasRoutePayouts" BOOLEAN NOT NULL DEFAULT false,
    "hasPushNotify" BOOLEAN NOT NULL DEFAULT false,
    "hasEmailNotify" BOOLEAN NOT NULL DEFAULT false,
    "hasSmsNotify" BOOLEAN NOT NULL DEFAULT false,
    "hasWhatsappNotify" BOOLEAN NOT NULL DEFAULT false,
    "hasCustomLogo" BOOLEAN NOT NULL DEFAULT false,
    "hasWhiteLabel" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Plan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Subscription" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "planId" TEXT NOT NULL,
    "billingCycle" TEXT NOT NULL DEFAULT 'MONTHLY',
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "currentPeriodStart" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "currentPeriodEnd" TIMESTAMP(3) NOT NULL,
    "trialEndsAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "pausedAt" TIMESTAMP(3),
    "gracePeriodEndsAt" TIMESTAMP(3),
    "pastDueAt" TIMESTAMP(3),
    "razorpaySubscriptionId" TEXT,
    "razorpayPlanId" TEXT,
    "razorpayCustomerId" TEXT,
    "scheduledPlanId" TEXT,
    "scheduledCycle" TEXT,
    "lastPaymentAt" TIMESTAMP(3),
    "lastPaymentAmount" DOUBLE PRECISION,
    "failedPaymentCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Subscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SubscriptionInvoice" (
    "id" TEXT NOT NULL,
    "subscriptionId" TEXT NOT NULL,
    "razorpayPaymentId" TEXT,
    "razorpayInvoiceId" TEXT,
    "amountPaise" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "taxPaise" INTEGER NOT NULL DEFAULT 0,
    "totalPaise" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "type" TEXT NOT NULL DEFAULT 'RENEWAL',
    "invoiceNumber" TEXT,
    "paidAt" TIMESTAMP(3),
    "failedAt" TIMESTAMP(3),
    "planSlug" TEXT,
    "billingCycle" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SubscriptionInvoice_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Plan_slug_key" ON "Plan"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_coachingId_key" ON "Subscription"("coachingId");

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_razorpaySubscriptionId_key" ON "Subscription"("razorpaySubscriptionId");

-- CreateIndex
CREATE INDEX "Subscription_status_idx" ON "Subscription"("status");

-- CreateIndex
CREATE INDEX "Subscription_currentPeriodEnd_idx" ON "Subscription"("currentPeriodEnd");

-- CreateIndex
CREATE INDEX "Subscription_razorpaySubscriptionId_idx" ON "Subscription"("razorpaySubscriptionId");

-- CreateIndex
CREATE UNIQUE INDEX "SubscriptionInvoice_razorpayPaymentId_key" ON "SubscriptionInvoice"("razorpayPaymentId");

-- CreateIndex
CREATE INDEX "SubscriptionInvoice_subscriptionId_idx" ON "SubscriptionInvoice"("subscriptionId");

-- CreateIndex
CREATE INDEX "SubscriptionInvoice_subscriptionId_status_idx" ON "SubscriptionInvoice"("subscriptionId", "status");

-- CreateIndex
CREATE INDEX "SubscriptionInvoice_razorpayPaymentId_idx" ON "SubscriptionInvoice"("razorpayPaymentId");

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_planId_fkey" FOREIGN KEY ("planId") REFERENCES "Plan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SubscriptionInvoice" ADD CONSTRAINT "SubscriptionInvoice_subscriptionId_fkey" FOREIGN KEY ("subscriptionId") REFERENCES "Subscription"("id") ON DELETE CASCADE ON UPDATE CASCADE;
