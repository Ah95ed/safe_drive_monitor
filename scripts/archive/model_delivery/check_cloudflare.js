const fs = require('fs');
const https = require('https');

// 1. Read secrets/drivealert_secrets.local.env
const envPath = 'secrets/drivealert_secrets.local.env';
if (!fs.existsSync(envPath)) {
  console.error('File not found:', envPath);
  process.exit(1);
}

const lines = fs.readFileSync(envPath, 'utf8').split('\n');
const env = {};
for (const line of lines) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const eqIdx = trimmed.indexOf('=');
  if (eqIdx !== -1) {
    const key = trimmed.slice(0, eqIdx).trim();
    let val = trimmed.slice(eqIdx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    env[key] = val;
  }
}

const token = env.CLOUDFLARE_API_TOKEN;
const accountId = env.CLOUDFLARE_ACCOUNT_ID;
const bucketName = env.CLOUDFLARE_R2_BUCKET_NAME;

console.log('--- Checking Cloudflare Credentials ---');
console.log('Account ID:', accountId);
console.log('Target R2 Bucket:', bucketName);
console.log('Token starts with:', token ? token.substring(0, 10) + '...' : 'NONE');

function makeRequest(url, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'User-Agent': 'DriveAlert-Setup/1.0'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, json: JSON.parse(data) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  try {
    // 1. Verify token
    console.log('\n1. Verifying API Token with Cloudflare...');
    const verifyRes = await makeRequest('https://api.cloudflare.com/client/v4/user/tokens/verify');
    console.log('Token verify response code:', verifyRes.statusCode);
    if (verifyRes.json && verifyRes.json.success) {
      console.log(' Token is VALID! Status:', verifyRes.json.result.status);
    } else {
      console.error(' Token verification failed:', verifyRes.json || verifyRes.raw);
    }

    // 2. Check R2 Buckets for Account
    console.log(`\n2. Checking R2 Buckets for Account (${accountId})...`);
    const r2Res = await makeRequest(`https://api.cloudflare.com/client/v4/accounts/${accountId}/r2/buckets`);
    console.log('R2 list response code:', r2Res.statusCode);
    if (r2Res.json && r2Res.json.success) {
      const buckets = r2Res.json.result.buckets || [];
      console.log(`Found ${buckets.length} bucket(s):`, buckets.map(b => b.name));
      const targetExists = buckets.some(b => b.name === bucketName);
      if (targetExists) {
        console.log(` Bucket "${bucketName}" exists!`);
      }
    } else {
      console.error(' R2 Query Error:', r2Res.json || r2Res.raw);
    }

    // 3. Check Workers scripts for Account
    console.log(`\n3. Checking Workers Scripts for Account (${accountId})...`);
    const workerRes = await makeRequest(`https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts`);
    console.log('Workers list response code:', workerRes.statusCode);
    if (workerRes.json && workerRes.json.success) {
      const scripts = workerRes.json.result || [];
      console.log(`Found ${scripts.length} worker script(s):`, scripts.map(s => s.id));
    } else {
      console.error(' Workers Query Error:', workerRes.json || workerRes.raw);
    }
  } catch (err) {
    console.error('Unexpected error:', err.message);
  }
}

run();
