-- CreateIndex
CREATE INDEX "AcademicProfile_status_remindAt_idx" ON "AcademicProfile"("status", "remindAt");

-- CreateIndex
CREATE INDEX "Batch_coachingId_status_idx" ON "Batch"("coachingId", "status");

-- CreateIndex
CREATE INDEX "BatchNote_batchId_createdAt_idx" ON "BatchNote"("batchId", "createdAt");

-- CreateIndex
CREATE INDEX "BatchNotice_batchId_createdAt_idx" ON "BatchNotice"("batchId", "createdAt");

-- CreateIndex
CREATE INDEX "CoachingMember_coachingId_status_idx" ON "CoachingMember"("coachingId", "status");

-- CreateIndex
CREATE INDEX "CoachingMember_coachingId_role_idx" ON "CoachingMember"("coachingId", "role");

-- CreateIndex
CREATE INDEX "Notification_coachingId_archived_idx" ON "Notification"("coachingId", "archived");

-- CreateIndex
CREATE INDEX "Notification_userId_read_idx" ON "Notification"("userId", "read");
