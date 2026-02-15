-- AlterTable
ALTER TABLE "Coaching" ADD COLUMN     "aboutUs" TEXT,
ADD COLUMN     "category" TEXT,
ADD COLUMN     "contactEmail" TEXT,
ADD COLUMN     "contactPhone" TEXT,
ADD COLUMN     "coverImage" TEXT,
ADD COLUMN     "facebookUrl" TEXT,
ADD COLUMN     "foundedYear" INTEGER,
ADD COLUMN     "instagramUrl" TEXT,
ADD COLUMN     "isVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "linkedinUrl" TEXT,
ADD COLUMN     "onboardingComplete" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "subjects" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "tagline" TEXT,
ADD COLUMN     "verificationDocs" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "websiteUrl" TEXT,
ADD COLUMN     "whatsappPhone" TEXT,
ADD COLUMN     "youtubeUrl" TEXT;

-- CreateTable
CREATE TABLE "CoachingAddress" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "addressLine1" TEXT NOT NULL,
    "addressLine2" TEXT,
    "landmark" TEXT,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "pincode" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "openingTime" TEXT,
    "closingTime" TEXT,
    "workingDays" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CoachingAddress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CoachingBranch" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "addressLine1" TEXT NOT NULL,
    "addressLine2" TEXT,
    "landmark" TEXT,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "pincode" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "contactPhone" TEXT,
    "contactEmail" TEXT,
    "openingTime" TEXT,
    "closingTime" TEXT,
    "workingDays" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CoachingBranch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Batch" (
    "id" TEXT NOT NULL,
    "coachingId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "subject" TEXT,
    "description" TEXT,
    "startTime" TEXT,
    "endTime" TEXT,
    "days" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "maxStudents" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Batch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BatchMember" (
    "id" TEXT NOT NULL,
    "batchId" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'STUDENT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BatchMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BatchNote" (
    "id" TEXT NOT NULL,
    "batchId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "fileUrl" TEXT NOT NULL,
    "fileType" TEXT NOT NULL DEFAULT 'pdf',
    "fileName" TEXT,
    "uploadedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BatchNote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BatchNotice" (
    "id" TEXT NOT NULL,
    "batchId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "priority" TEXT NOT NULL DEFAULT 'normal',
    "sentById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BatchNotice_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CoachingAddress_coachingId_key" ON "CoachingAddress"("coachingId");

-- CreateIndex
CREATE INDEX "CoachingBranch_coachingId_idx" ON "CoachingBranch"("coachingId");

-- CreateIndex
CREATE INDEX "Batch_coachingId_idx" ON "Batch"("coachingId");

-- CreateIndex
CREATE INDEX "BatchMember_batchId_idx" ON "BatchMember"("batchId");

-- CreateIndex
CREATE INDEX "BatchMember_memberId_idx" ON "BatchMember"("memberId");

-- CreateIndex
CREATE UNIQUE INDEX "BatchMember_batchId_memberId_key" ON "BatchMember"("batchId", "memberId");

-- CreateIndex
CREATE INDEX "BatchNote_batchId_idx" ON "BatchNote"("batchId");

-- CreateIndex
CREATE INDEX "BatchNote_uploadedById_idx" ON "BatchNote"("uploadedById");

-- CreateIndex
CREATE INDEX "BatchNotice_batchId_idx" ON "BatchNotice"("batchId");

-- CreateIndex
CREATE INDEX "BatchNotice_sentById_idx" ON "BatchNotice"("sentById");

-- AddForeignKey
ALTER TABLE "CoachingAddress" ADD CONSTRAINT "CoachingAddress_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CoachingBranch" ADD CONSTRAINT "CoachingBranch_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Batch" ADD CONSTRAINT "Batch_coachingId_fkey" FOREIGN KEY ("coachingId") REFERENCES "Coaching"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BatchMember" ADD CONSTRAINT "BatchMember_batchId_fkey" FOREIGN KEY ("batchId") REFERENCES "Batch"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BatchMember" ADD CONSTRAINT "BatchMember_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CoachingMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BatchNote" ADD CONSTRAINT "BatchNote_batchId_fkey" FOREIGN KEY ("batchId") REFERENCES "Batch"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BatchNote" ADD CONSTRAINT "BatchNote_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BatchNotice" ADD CONSTRAINT "BatchNotice_batchId_fkey" FOREIGN KEY ("batchId") REFERENCES "Batch"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BatchNotice" ADD CONSTRAINT "BatchNotice_sentById_fkey" FOREIGN KEY ("sentById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
