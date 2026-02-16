import express from 'express';
import * as corsNamespace from 'cors';
const cors = (corsNamespace as any).default || corsNamespace;
import dotenv from 'dotenv';
dotenv.config();

// BigInt JSON serialization — Prisma returns BigInt for large numeric fields.
// Without this, JSON.stringify throws "Do not know how to serialize a BigInt".
(BigInt.prototype as any).toJSON = function () {
  const n = Number(this);
  if (!Number.isSafeInteger(n)) return this.toString();
  return n;
};
import authRoutes from './modules/auth/auth.route.js';
import userRoutes from './modules/user/user.route.js';
import coachingRoutes from './modules/coaching/coaching.route.js';
import uploadRoutes from './modules/upload/upload.route.js';
import notificationRoutes from './modules/notification/notification.route.js';
import academicRoutes from './modules/academic/academic.route.js';


const app = express();
const port = process.env.PORT || 3010;

// Only trust first proxy hop (not all)
app.set('trust proxy', 1);

// CORS: restrict to known origins
const allowedOrigins = (process.env.CORS_ORIGINS || '').split(',').filter(Boolean);
app.use(cors(allowedOrigins.length > 0 ? {
  origin: allowedOrigins,
  credentials: true,
} : undefined));
app.use(express.json({ limit: '100kb' }));

// Lightweight request logger — never log sensitive body fields
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

app.use('/auth', authRoutes);
app.use('/user', userRoutes);
app.use('/coaching', coachingRoutes);
app.use('/upload', uploadRoutes);
app.use('/notifications', notificationRoutes);
app.use('/academic', academicRoutes);

app.get('/hello', (req, res) => {
  res.json({ message: 'Hello from Express TypeScript!' });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
