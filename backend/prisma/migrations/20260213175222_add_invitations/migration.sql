-- CreateTable
CREATE TABLE "Invitation" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "userId" TEXT,
    "wardId" TEXT,
    "invitePhone" TEXT,
    "inviteEmail" TEXT,
    "inviteName" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "invitedById" TEXT NOT NULL,
    "message" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3),
    "respondedAt" TIMESTAMP(3),

    CONSTRAINT "Invitation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Invitation_coachingId_idx" ON "Invitation"("coachingId");

-- CreateIndex
CREATE INDEX "Invitation_userId_idx" ON "Invitation"("userId");

-- CreateIndex
CREATE INDEX "Invitation_invitePhone_idx" ON "Invitation"("invitePhone");

-- CreateIndex
CREATE INDEX "Invitation_inviteEmail_idx" ON "Invitation"("inviteEmail");

-- CreateIndex
CREATE UNIQUE INDEX "Invitation_coachingId_userId_role_key" ON "Invitation"("coachingId", "userId", "role");

-- CreateIndex
CREATE UNIQUE INDEX "Invitation_coachingId_wardId_key" ON "Invitation"("coachingId", "wardId");

-- AddForeignKey
ALTER TABLE "Invitation" ADD CONSTRAINT "Invitation_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invitation" ADD CONSTRAINT "Invitation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invitation" ADD CONSTRAINT "Invitation_wardId_fkey" FOREIGN KEY ("wardId") REFERENCES "Ward"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invitation" ADD CONSTRAINT "Invitation_invitedById_fkey" FOREIGN KEY ("invitedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
