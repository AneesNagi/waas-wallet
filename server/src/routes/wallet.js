import { Router } from 'express';
import { ethers } from 'ethers';
import fs from 'fs';
import path from 'path';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { getUser, setSmartAccountAddress } from '../db.js';
import { addSpend, getSpend } from '../limits.js';
import { createSmartAccountClient } from '@biconomy/account';
import { createBundler } from '@biconomy/bundler';
import { BiconomyPaymaster } from '@biconomy/paymaster';
import { ENTRYPOINT_ADDRESS_V06 } from '@biconomy/common';

const router = Router();

// Load users from the same store as auth
const DATA_DIR = path.resolve(process.cwd(), 'server', 'data');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
function loadUsers() { return {}; }

async function getUserFromAuthHeader(req) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return null;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return await getUser(decoded.sub);
  } catch {
    return null;
  }
}

function getAesKey() {
  const secret = process.env.JWT_SECRET || '';
  return crypto.scryptSync(secret, 'waas-salt', 32);
}

function decryptPk(encrypted) {
  const [ivB64, encB64, tagB64] = (encrypted || '').split('.');
  if (!ivB64 || !encB64 || !tagB64) {
    throw new Error('Invalid encrypted key format');
  }
  const iv = Buffer.from(ivB64, 'base64');
  const enc = Buffer.from(encB64, 'base64');
  const tag = Buffer.from(tagB64, 'base64');
  const key = getAesKey();
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(enc), decipher.final()]);
  return dec.toString('utf8');
}

function getUserPrivateKey(user) {
  // Backward compatibility for users created before encryption change
  if (user?.encryptedPk) {
    return decryptPk(user.encryptedPk);
  }
  if (user?.privateKey) {
    return user.privateKey.startsWith('0x') ? user.privateKey : `0x${user.privateKey}`;
  }
  throw new Error('User private key not found');
}

router.get('/address', async (req, res) => {
  const user = await getUserFromAuthHeader(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });
  return res.json({ address: user.walletAddress });
});

// Return AA smart account address (placeholder until Biconomy is configured)
router.get('/aa-address', async (req, res) => {
  try {
    const user = await getUserFromAuthHeader(req);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });

    // If already set, return it
    if (user.smartAccountAddress) {
      return res.json({ smartAccountAddress: user.smartAccountAddress });
    }

    const bundlerUrl = process.env.BICONOMY_BUNDLER_URL;
    const paymasterUrl = process.env.BICONOMY_PAYMASTER_URL;
    if (!bundlerUrl || !paymasterUrl) {
      return res.status(501).json({ error: 'AA not configured. Set BICONOMY_BUNDLER_URL and BICONOMY_PAYMASTER_URL.' });
    }

    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const chainId = Number(process.env.CHAIN_ID || 84532);
    const entryPoint = process.env.ENTRY_POINT_ADDRESS || ENTRYPOINT_ADDRESS_V06;

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const ownerPk = getUserPrivateKey(user);
    const owner = new ethers.Wallet(ownerPk, provider);

    const bundler = createBundler({
      bundlerUrl,
      chainId,
      entryPointAddress: entryPoint,
    });
    const paymaster = new BiconomyPaymaster({ paymasterUrl });
    const smartAccount = await createSmartAccountClient({
      signer: owner,
      chainId,
      bundler,
      paymaster,
      entryPointAddress: entryPoint,
      rpcUrl,
    });

    const smartAccountAddress = await smartAccount.getAccountAddress();
    await setSmartAccountAddress(user.email, smartAccountAddress);
    return res.json({ smartAccountAddress });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
});

router.get('/balance', async (req, res) => {
  try {
    const user = await getUserFromAuthHeader(req);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });
    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const usdc = process.env.USDC_CONTRACT_ADDRESS;
    const erc20Abi = [
      'function balanceOf(address) view returns (uint256)'
    ];
    const contract = new ethers.Contract(usdc, erc20Abi, provider);
    const [ethBal, usdcBal] = await Promise.all([
      provider.getBalance(user.walletAddress),
      contract.balanceOf(user.walletAddress)
    ]);
    return res.json({
      address: user.walletAddress,
      ethWei: ethBal.toString(),
      usdcWei: usdcBal.toString()
    });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
});

router.get('/transactions', async (req, res) => {
  try {
    const user = await getUserFromAuthHeader(req);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });
    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const usdc = process.env.USDC_CONTRACT_ADDRESS;
    const erc20Iface = new ethers.Interface([
      'event Transfer(address indexed from, address indexed to, uint256 value)'
    ]);
    const currentBlock = await provider.getBlockNumber();
    const fromBlock = currentBlock - 9500 > 0 ? currentBlock - 9500 : 0;
    const topicTransfer = ethers.id('Transfer(address,address,uint256)');
    const userTopic = ethers.zeroPadValue(user.walletAddress, 32);
    const [logsFrom, logsTo] = await Promise.all([
      provider.getLogs({ address: usdc, fromBlock, toBlock: currentBlock, topics: [topicTransfer, userTopic, null] }),
      provider.getLogs({ address: usdc, fromBlock, toBlock: currentBlock, topics: [topicTransfer, null, userTopic] })
    ]);
    const logs = [...logsFrom, ...logsTo];
    const txs = logs.map(l => {
      const parsed = erc20Iface.decodeEventLog('Transfer', l.data, l.topics);
      const from = ethers.getAddress(parsed[0]);
      const to = ethers.getAddress(parsed[1]);
      const amount = parsed[2].toString();
      const type = to.toLowerCase() === user.walletAddress.toLowerCase() ? 'receive' : 'send';
      return {
        hash: l.transactionHash,
        type,
        amount,
        to,
        from,
        timestamp: Date.now(),
        status: 'confirmed',
        token: 'USDC'
      };
    });
    return res.json({ transactions: txs });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
});

router.post('/send', async (req, res) => {
  try {
    const user = await getUserFromAuthHeader(req);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });

    const { to, amount, token, network } = req.body || {};
    if (!to || !amount) return res.status(400).json({ error: 'Missing to/amount' });

    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    // decrypt using AES-256-GCM with JWT_SECRET-derived key
    const pk = getUserPrivateKey(user);
    const signer = new ethers.Wallet(pk, provider);

    let tx;
    if ((token || 'USDC').toUpperCase() === 'USDC') {
      const usdcAddress = process.env.USDC_CONTRACT_ADDRESS;
      if (!usdcAddress) {
        return res.status(500).json({ error: 'Server missing USDC_CONTRACT_ADDRESS' });
      }
      const erc20Abi = [
        'function transfer(address to, uint256 value) returns (bool)',
        'function decimals() view returns (uint8)'
      ];
      const contract = new ethers.Contract(usdcAddress, erc20Abi, signer);
      // amount is expected to be a string of integer base units (e.g., 6 decimals for USDC)
      tx = await contract.transfer(to, ethers.toBigInt(amount));
    } else {
      // Native send (ETH)
      tx = await signer.sendTransaction({ to, value: ethers.toBigInt(amount) });
    }

    const receipt = await provider.waitForTransaction(tx.hash, 1, 60_000);
    if (!receipt) return res.status(504).json({ error: 'Transaction not confirmed in time' });
    return res.status(201).json({ txHash: tx.hash });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
});

// Sponsor user's gas by topping up ETH to their custodial address
// Deprecated: remove in-house sponsorship; return 410 Gone
router.post('/sponsor', async (_req, res) => {
  return res.status(410).json({ error: 'Deprecated: sponsorship removed. Use AA endpoint /v1/wallet/send-aa.' });
});

// Gas-sponsored USDC send: top-up then submit user's transfer
// Deprecated: remove in-house sponsorship; return 410 Gone
router.post('/send-sponsored', async (_req, res) => {
  return res.status(410).json({ error: 'Deprecated: sponsorship removed. Use AA endpoint /v1/wallet/send-aa.' });
});

// AA send via Coinbase Paymaster (scaffold) - replace with real SDK calls
router.post('/send-aa', async (req, res) => {
  try {
    const user = await getUserFromAuthHeader(req);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });

    const { to, amount } = req.body || {};
    if (!to || !amount) return res.status(400).json({ error: 'Missing to/amount' });

    const bundlerUrl = process.env.BICONOMY_BUNDLER_URL;
    const paymasterUrl = process.env.BICONOMY_PAYMASTER_URL;
    if (!bundlerUrl || !paymasterUrl) {
      return res.status(501).json({ error: 'AA not configured. Set BICONOMY_BUNDLER_URL and BICONOMY_PAYMASTER_URL.' });
    }

    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const chainId = Number(process.env.CHAIN_ID || 84532);
    const entryPoint = process.env.ENTRY_POINT_ADDRESS || ENTRYPOINT_ADDRESS_V06;
    const usdcAddress = process.env.USDC_CONTRACT_ADDRESS;
    if (!usdcAddress) return res.status(500).json({ error: 'Server missing USDC_CONTRACT_ADDRESS' });

    // EOA owner for smart account
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const ownerPk = getUserPrivateKey(user);
    const owner = new ethers.Wallet(ownerPk, provider);

    // Biconomy client setup
    const bundler = createBundler({ bundlerUrl, chainId, entryPointAddress: entryPoint });
    const paymaster = new BiconomyPaymaster({ paymasterUrl });
    const smartAccount = await createSmartAccountClient({
      signer: owner,
      chainId,
      bundler,
      paymaster,
      entryPointAddress: entryPoint,
      rpcUrl,
    });

    // Encode USDC transfer
    const erc20 = new ethers.Interface([
      'function transfer(address to, uint256 value) returns (bool)'
    ]);
    const data = erc20.encodeFunctionData('transfer', [to, ethers.toBigInt(amount)]);

    // Send AA transaction with paymaster-sponsored gas
    const txResponse = await smartAccount.sendTransaction({ to: usdcAddress, data });
    // Biconomy SDK v3 returns helpers to wait
    let txHash;
    if (typeof txResponse?.waitForTxHash === 'function') {
      const { transactionHash } = await txResponse.waitForTxHash();
      txHash = transactionHash;
      await txResponse.wait();
    } else if (typeof smartAccount.waitForUserOperationTransaction === 'function' && txResponse) {
      txHash = await smartAccount.waitForUserOperationTransaction(txResponse);
    }

    if (!txHash) {
      return res.status(500).json({ error: 'Failed to obtain transaction hash from AA send' });
    }

    // Cache smart account address if not set
    try {
      const saAddr = await smartAccount.getAccountAddress();
      if (saAddr && !user.smartAccountAddress) {
        await setSmartAccountAddress(user.email, saAddr);
      }
    } catch {}

    return res.status(201).json({ txHash });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
});

export default router;


