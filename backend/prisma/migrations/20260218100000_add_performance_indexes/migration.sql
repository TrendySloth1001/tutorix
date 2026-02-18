-- CreateIndex
CREATE INDEX "Assessment_batchId_status_createdAt_idx" ON "Assessment"("batchId", "status", "createdAt");

-- CreateIndex
CREATE INDEX "Assignment_batchId_status_createdAt_idx" ON "Assignment"("batchId", "status", "createdAt");

-- CreateIndex
CREATE INDEX "CoachingAddress_latitude_longitude_idx" ON "CoachingAddress"("latitude", "longitude");

-- CreateIndex
CREATE INDEX "Invitation_status_idx" ON "Invitation"("status");

-- CreateIndex
CREATE INDEX "Invitation_status_inviteEmail_idx" ON "Invitation"("status", "inviteEmail");

-- CreateIndex
CREATE INDEX "Invitation_status_invitePhone_idx" ON "Invitation"("status", "invitePhone");

-- CreateIndex
CREATE INDEX "Log_level_createdAt_idx" ON "Log"("level", "createdAt");
