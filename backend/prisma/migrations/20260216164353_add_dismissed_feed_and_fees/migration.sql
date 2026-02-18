-- CreateTable
CREATE TABLE "Log" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "type" TEXT NOT NULL,
    "level" TEXT NOT NULL DEFAULT 'INFO',
    "userId" TEXT,
    "userEmail" TEXT,
    "userName" TEXT,
    "userRoles" TEXT[],
    "method" TEXT,
    "path" TEXT,
    "statusCode" INTEGER,
    "duration" DOUBLE PRECISION,
    "ip" TEXT,
    "userAgent" TEXT,
    "message" TEXT,
    "error" TEXT,
    "stackTrace" TEXT,
    "metadata" JSONB,

    CONSTRAINT "Log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Log_type_idx" ON "Log"("type");

-- CreateIndex
CREATE INDEX "Log_level_idx" ON "Log"("level");

-- CreateIndex
CREATE INDEX "Log_userId_idx" ON "Log"("userId");

-- CreateIndex
CREATE INDEX "Log_createdAt_idx" ON "Log"("createdAt");

-- CreateIndex
CREATE INDEX "Log_type_createdAt_idx" ON "Log"("type", "createdAt");
