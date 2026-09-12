const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('=== Step 3: Deploy Cloudflare Worker ===');

const envPath = 'secrets/drivealert_secrets.local.env';
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
const downloadSecret = env.DOWNLOAD_TOKEN_SECRET;

console.log('Account ID:', accountId);
console.log('Deploying drivealert-model-service to Cloudflare...');

try {
  process.env.CLOUDFLARE_API_TOKEN = token;
  process.env.CLOUDFLARE_ACCOUNT_ID = accountId;

  const deployOutput = execSync('npx wrangler deploy', {
    cwd: path.resolve('cloudflare_worker'),
    stdio: 'inherit'
  });

  console.log('\nWorker deployed successfully!');

  // Now set DOWNLOAD_TOKEN_SECRET on the worker via wrangler secret
  if (downloadSecret) {
    console.log('Setting DOWNLOAD_TOKEN_SECRET on deployed worker...');
    try {
      execSync(`echo ${downloadSecret} | npx wrangler secret put DOWNLOAD_TOKEN_SECRET`, {
        cwd: path.resolve('cloudflare_worker'),
        stdio: 'inherit'
      });
      console.log('DOWNLOAD_TOKEN_SECRET set successfully on Cloudflare Worker!');
    } catch (secErr) {
      console.warn('Could not set secret via pipe:', secErr.message);
    }
  }

  const modelAesKey = env.MODEL_AES_KEY_BASE64;
  if (modelAesKey) {
    console.log('Setting MODEL_AES_KEY_BASE64 on deployed worker...');
    try {
      execSync(`echo ${modelAesKey} | npx wrangler secret put MODEL_AES_KEY_BASE64`, {
        cwd: path.resolve('cloudflare_worker'),
        stdio: 'inherit'
      });
      console.log('MODEL_AES_KEY_BASE64 set successfully on Cloudflare Worker!');
    } catch (secErr) {
      console.warn('Could not set secret via pipe:', secErr.message);
    }
  }

} catch (err) {
  console.error('Worker deployment error:', err.message);
}
