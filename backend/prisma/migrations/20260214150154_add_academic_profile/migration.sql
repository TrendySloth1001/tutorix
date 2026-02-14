-- CreateTable
CREATE TABLE "AcademicProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "schoolName" TEXT,
    "board" TEXT,
    "classId" TEXT,
    "stream" TEXT,
    "subjects" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "competitiveExams" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "targetYear" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "remindAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AcademicProfile_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AcademicProfile_userId_key" ON "AcademicProfile"("userId");

-- CreateIndex
CREATE INDEX "AcademicProfile_userId_idx" ON "AcademicProfile"("userId");

-- AddForeignKey
ALTER TABLE "AcademicProfile" ADD CONSTRAINT "AcademicProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
