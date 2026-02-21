-- AlterTable
ALTER TABLE "Coaching" ADD COLUMN     "bankVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "bankVerifiedAt" TIMESTAMP(3);
