-- AlterTable
ALTER TABLE "BatchNotice" ADD COLUMN     "date" TIMESTAMP(3),
ADD COLUMN     "day" TEXT,
ADD COLUMN     "endTime" TEXT,
ADD COLUMN     "location" TEXT,
ADD COLUMN     "startTime" TEXT,
ADD COLUMN     "type" TEXT NOT NULL DEFAULT 'general';
