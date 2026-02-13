-- CreateTable
CREATE TABLE "Ward" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "picture" TEXT,
    "parentId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Ward_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoginSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "ip" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LoginSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CoachingMember" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'STUDENT',
    "userId" TEXT,
    "wardId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CoachingMember_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Ward_parentId_idx" ON "Ward"("parentId");

-- CreateIndex
CREATE INDEX "LoginSession_userId_idx" ON "LoginSession"("userId");

-- CreateIndex
CREATE INDEX "CoachingMember_coachingId_idx" ON "CoachingMember"("coachingId");

-- CreateIndex
CREATE INDEX "CoachingMember_userId_idx" ON "CoachingMember"("userId");

-- CreateIndex
CREATE INDEX "CoachingMember_wardId_idx" ON "CoachingMember"("wardId");

-- CreateIndex
CREATE UNIQUE INDEX "CoachingMember_coachingId_userId_key" ON "CoachingMember"("coachingId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "CoachingMember_coachingId_wardId_key" ON "CoachingMember"("coachingId", "wardId");

-- AddForeignKey
ALTER TABLE "Ward" ADD CONSTRAINT "Ward_parentId_fkey" FOREIGN KEY ("parentId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoginSession" ADD CONSTRAINT "LoginSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachingMember" ADD CONSTRAINT "CoachingMember_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachingMember" ADD CONSTRAINT "CoachingMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachingMember" ADD CONSTRAINT "CoachingMember_wardId_fkey" FOREIGN KEY ("wardId") REFERENCES "Ward"("id") ON DELETE CASCADE ON UPDATE CASCADE;
