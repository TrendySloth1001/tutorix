-- CreateTable
CREATE TABLE "SavedCoaching" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SavedCoaching_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "SavedCoaching_userId_idx" ON "SavedCoaching"("userId");

-- CreateIndex
CREATE INDEX "SavedCoaching_coachingId_idx" ON "SavedCoaching"("coachingId");

-- CreateIndex
CREATE UNIQUE INDEX "SavedCoaching_userId_coachingId_key" ON "SavedCoaching"("userId", "coachingId");

-- AddForeignKey
ALTER TABLE "SavedCoaching" ADD CONSTRAINT "SavedCoaching_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SavedCoaching" ADD CONSTRAINT "SavedCoaching_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;
