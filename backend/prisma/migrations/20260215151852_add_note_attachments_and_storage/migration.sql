/*
  Warnings:

  - You are about to drop the column `fileName` on the `BatchNote` table. All the data in the column will be lost.
  - You are about to drop the column `fileType` on the `BatchNote` table. All the data in the column will be lost.
  - You are about to drop the column `fileUrl` on the `BatchNote` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "BatchNote" DROP COLUMN "fileName",
DROP COLUMN "fileType",
DROP COLUMN "fileUrl";

-- AlterTable
ALTER TABLE "Coaching" ADD COLUMN     "storageLimit" BIGINT NOT NULL DEFAULT 524288000,
ADD COLUMN     "storageUsed" BIGINT NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "NoteAttachment" (
    "id" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "fileName" TEXT,
    "fileType" TEXT NOT NULL DEFAULT 'pdf',
    "fileSize" INTEGER NOT NULL DEFAULT 0,
    "mimeType" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NoteAttachment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "NoteAttachment_noteId_idx" ON "NoteAttachment"("noteId");

-- AddForeignKey
ALTER TABLE "NoteAttachment" ADD CONSTRAINT "NoteAttachment_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "BatchNote"("id") ON DELETE CASCADE ON UPDATE CASCADE;
