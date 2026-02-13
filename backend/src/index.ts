import express from 'express';
import cors from 'cors';

const app = express();
const port = 3010;

app.use(cors());
app.use(express.json());

app.get('/hello', (req, res) => {
  res.json({ message: 'Hello from Express TypeScript!' });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
