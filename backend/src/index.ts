import express from 'express';
import * as corsNamespace from 'cors';
const cors = (corsNamespace as any).default || corsNamespace;
import dotenv from 'dotenv';
import authRoutes from './modules/auth/auth.route.js';

dotenv.config();

const app = express();
const port = process.env.PORT || 3010;

app.use(cors());
app.use(express.json());

app.use('/auth', authRoutes);

app.get('/hello', (req, res) => {
  res.json({ message: 'Hello from Express TypeScript!' });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
