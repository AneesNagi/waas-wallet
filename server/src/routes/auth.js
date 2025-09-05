import { Router } from 'express';
import { ethers } from 'ethers';
import fs from 'fs';
import path from 'path';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { getUser, saveUser } from '../db.js';

const router = Router();

// Simple file-based user store (demo only)
const DATA_DIR = path.resolve(process.cwd(), 'server', 'data');
const USERS_FILE = path.join(DATA_DIR, 'users.json');

function ensureStore() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(USERS_FILE)) fs.writeFileSync(USERS_FILE, JSON.stringify({}), 'utf-8');
}

function loadUsers() {
  ensureStore();
  try {
    const raw = fs.readFileSync(USERS_FILE, 'utf-8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function saveUsers(usersObj) {
  ensureStore();
  fs.writeFileSync(USERS_FILE, JSON.stringify(usersObj, null, 2), 'utf-8');
}

function signToken(payload) {
  const secret = process.env.JWT_SECRET;
  return jwt.sign(payload, secret, { expiresIn: '12h' });
}

function getAesKey() {
  const secret = process.env.JWT_SECRET || '';
  return crypto.scryptSync(secret, 'waas-salt', 32); // 256-bit key
}

function encrypt(text) {
  const iv = crypto.randomBytes(12); // GCM nonce
  const key = getAesKey();
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64')}.${enc.toString('base64')}.${tag.toString('base64')}`;
}

function decrypt(payload) {
  const [ivB64, encB64, tagB64] = (payload || '').split('.');
  const iv = Buffer.from(ivB64, 'base64');
  const enc = Buffer.from(encB64, 'base64');
  const tag = Buffer.from(tagB64, 'base64');
  const key = getAesKey();
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(enc), decipher.final()]);
  return dec.toString('utf8');
}

router.post('/signup', async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'Missing email/password' });

  const existing = await getUser(email);
  if (existing) return res.status(409).json({ error: 'User already exists' });

  // For demo: generate a real Ethereum wallet locally
  const wallet = ethers.Wallet.createRandom();
  const walletAddress = wallet.address;
  const passwordHash = await bcrypt.hash(password, 10);
  const encryptedPk = encrypt(wallet.privateKey);
  await saveUser({ email, passwordHash, walletAddress, encryptedPk });
  const token = signToken({ sub: email, address: walletAddress });
  return res.status(201).json({ accessToken: token, walletAddress });
});

router.post('/signin', async (req, res) => {
  const { email, password } = req.body || {};
  const user = await getUser(email);
  if (!user) return res.status(401).json({ error: 'Invalid credentials' });
  let ok = false;
  if (user.passwordHash) {
    ok = await bcrypt.compare(password, user.passwordHash || '');
  } else if (user.password) {
    // Legacy fallback: migrate plaintext password to bcrypt
    ok = user.password === password;
    if (ok) {
      const passwordHash = await bcrypt.hash(password, 10);
      await saveUser({ email, passwordHash, walletAddress: user.walletAddress, encryptedPk: user.encryptedPk });
    }
  }
  if (!ok) return res.status(401).json({ error: 'Invalid credentials' });
  // Ensure we have a controllable key; do NOT mint a new wallet implicitly
  let pk = null;
  if (user.encryptedPk) {
    try { pk = decrypt(user.encryptedPk); } catch {}
  } else if (user.privateKey) {
    pk = user.privateKey.startsWith('0x') ? user.privateKey : `0x${user.privateKey}`;
  }
  if (!pk) {
    // Legacy record without a stored key: require migration/import
    return res.status(409).json({ error: 'account_requires_migration', walletAddress: user.walletAddress || null });
  }

  // Derive/repair walletAddress if missing
  let walletAddress = user.walletAddress;
  if (!walletAddress) {
    try {
      const w = new ethers.Wallet(pk);
      walletAddress = w.address;
      await saveUser({ email, passwordHash: user.passwordHash, walletAddress, encryptedPk: user.encryptedPk });
    } catch {}
  }

  const token = signToken({ sub: email, address: walletAddress });
  return res.json({ accessToken: token, walletAddress });
});

router.get('/me', async (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const entry = await getUser(decoded.sub);
    if (!entry) return res.status(401).json({ error: 'Unauthorized' });
    return res.json({ walletAddress: entry.walletAddress });
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
});

export default router;


