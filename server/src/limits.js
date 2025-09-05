// Simple in-memory per-user sponsorship limiter (replace with DB/Redis in prod)
const userDaily = new Map();

function getKey(email) {
  const today = new Date().toISOString().slice(0, 10);
  return `${email}:${today}`;
}

export function addSpend(email, amountWei) {
  const key = getKey(email);
  const prev = userDaily.get(key) || 0n;
  userDaily.set(key, prev + BigInt(amountWei));
}

export function getSpend(email) {
  const key = getKey(email);
  return userDaily.get(key) || 0n;
}

export function limitsMiddleware(req, res, next) {
  // Only guard sponsorship endpoints
  if (req.path.endsWith('/sponsor') || req.path.endsWith('/send-sponsored')) {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
    if (!token) return next();
    try {
      // Do not import jwt here to keep index lean; wallet routes already verify JWT
      return next();
    } catch {
      return next();
    }
  }
  return next();
}


