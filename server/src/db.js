// Lightweight DB abstraction: Postgres if DATABASE_URL is set, else JSON file store
import fs from 'fs';
import path from 'path';

let pgClient = null;
async function getPg() {
  if (pgClient) return pgClient;
  try {
    const { Client } = await import('pg');
    const conn = process.env.DATABASE_URL;
    if (!conn) return null;
    const client = new Client({ connectionString: conn, ssl: process.env.PGSSL === '1' ? { rejectUnauthorized: false } : undefined });
    await client.connect();
    await client.query(`
      create table if not exists users (
        email text primary key,
        password_hash text not null,
        wallet_address text not null,
        encrypted_pk text not null
      );
    `);
    // Optional AA smart account address
    await client.query(`alter table users add column if not exists smart_account_address text`);
    pgClient = client;
    return client;
  } catch (e) {
    return null;
  }
}

const DATA_DIR = path.resolve(process.cwd(), 'server', 'data');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
function ensureStore() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(USERS_FILE)) fs.writeFileSync(USERS_FILE, JSON.stringify({}), 'utf-8');
}

export async function getUser(email) {
  const pg = await getPg();
  if (pg) {
    const { rows } = await pg.query('select email, password_hash as "passwordHash", wallet_address as "walletAddress", encrypted_pk as "encryptedPk" from users where email=$1', [email]);
    return rows[0] || null;
  }
  ensureStore();
  try {
    const raw = fs.readFileSync(USERS_FILE, 'utf-8');
    const obj = JSON.parse(raw);
    return obj[email] || null;
  } catch {
    return null;
  }
}

export async function saveUser(user) {
  const pg = await getPg();
  if (pg) {
    await pg.query(
      'insert into users(email,password_hash,wallet_address,encrypted_pk,smart_account_address) values($1,$2,$3,$4,$5) on conflict(email) do update set password_hash=excluded.password_hash, wallet_address=excluded.wallet_address, encrypted_pk=excluded.encrypted_pk, smart_account_address=coalesce(excluded.smart_account_address, users.smart_account_address)',
      [user.email, user.passwordHash, user.walletAddress, user.encryptedPk, user.smartAccountAddress || null]
    );
    return;
  }
  ensureStore();
  const raw = fs.existsSync(USERS_FILE) ? fs.readFileSync(USERS_FILE, 'utf-8') : '{}';
  const obj = JSON.parse(raw);
  obj[user.email] = { passwordHash: user.passwordHash, walletAddress: user.walletAddress, encryptedPk: user.encryptedPk, smartAccountAddress: user.smartAccountAddress || obj[user.email]?.smartAccountAddress };
  fs.writeFileSync(USERS_FILE, JSON.stringify(obj, null, 2), 'utf-8');
}

export async function setSmartAccountAddress(email, smartAccountAddress) {
  const pg = await getPg();
  if (pg) {
    await pg.query('update users set smart_account_address=$2 where email=$1', [email, smartAccountAddress]);
    return;
  }
  ensureStore();
  const raw = fs.existsSync(USERS_FILE) ? fs.readFileSync(USERS_FILE, 'utf-8') : '{}';
  const obj = JSON.parse(raw);
  obj[email] = obj[email] || {};
  obj[email].smartAccountAddress = smartAccountAddress;
  fs.writeFileSync(USERS_FILE, JSON.stringify(obj, null, 2), 'utf-8');
}

