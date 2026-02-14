-- AlterTable
ALTER TABLE "User" ADD COLUMN     "showEmailInSearch" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "showPhoneInSearch" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "showWardsInSearch" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "Ward" ADD COLUMN     "class" TEXT,
ADD COLUMN     "dob" TIMESTAMP(3),
ADD COLUMN     "school" TEXT;

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT,
    "userId" TEXT,
    "type" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "read" BOOLEAN NOT NULL DEFAULT false,
    "data" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Notification_coachingId_idx" ON "Notification"("coachingId");

-- CreateIndex
CREATE INDEX "Notification_userId_idx" ON "Notification"("userId");

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
