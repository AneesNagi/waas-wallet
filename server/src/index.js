import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import authRouter from './routes/auth.js';
import walletRouter from './routes/wallet.js';
import { limitsMiddleware } from './limits.js';

dotenv.config();

const app = express();
app.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization','x-api-key'] }));
app.use(helmet());
app.set('trust proxy', 1);
app.use(rateLimit({ windowMs: 60 * 1000, max: 120 }));
app.use(express.json());
app.use(limitsMiddleware);

app.get('/health', (_req, res) => res.json({ ok: true }));

app.use('/v1/auth', authRouter);
app.use('/v1/wallet', walletRouter);

const port = process.env.PORT || 4000;
const host = process.env.HOST || '0.0.0.0';

function requireEnv(name, fallback) {
  const v = process.env[name] || fallback;
  if (!v) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
  return v;
}

requireEnv('JWT_SECRET');
requireEnv('RPC_URL', 'https://sepolia.base.org');
requireEnv('USDC_CONTRACT_ADDRESS');
console.log('ENV CONFIG:', {
  RPC_URL: process.env.RPC_URL || '(default) https://sepolia.base.org',
  USDC_CONTRACT_ADDRESS: process.env.USDC_CONTRACT_ADDRESS || '(missing)'
});
app.listen(port, host, () => {
  console.log(`Server listening on http://${host}:${port}`);
});


