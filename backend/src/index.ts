import express from 'express';
import * as corsNamespace from 'cors';
const cors = (corsNamespace as any).default || corsNamespace;
import dotenv from 'dotenv';
import authRoutes from './modules/auth/auth.route.js';
import userRoutes from './modules/user/user.route.js';
import coachingRoutes from './modules/coaching/coaching.route.js';
import uploadRoutes from './modules/upload/upload.route.js';
import notificationRoutes from './modules/notification/notification.route.js';
import academicRoutes from './modules/academic/academic.route.js';


const app = express();
const port = process.env.PORT || 3010;

app.set('trust proxy', true);

app.use(cors());
app.use(express.json());

// Request logger - log ALL incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`, {
    body: req.body,
    query: req.query,
    params: req.params,
  });
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
