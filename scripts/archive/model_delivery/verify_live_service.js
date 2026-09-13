const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

console.log('=== Step 4: Verify Live Cloudflare Service End-to-End ===');

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

const workerBaseUrl = 'https://drivealert-model-service.amhmeed31.workers.dev';
const downloadSecret = env.DOWNLOAD_TOKEN_SECRET;
const aesKeyBase64 = env.MODEL_AES_KEY_BASE64;
const expectedOriginalSha256 = env.MODEL_SHA256;
const expectedEncSha256 = env.ENCRYPTED_MODEL_SHA256;

function httpGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const req = https.request(parsed, { method: 'GET', headers }, (res) => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: buffer
        });
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function verify() {
  try {
    // 1. Health Check
    console.log(`1. Testing /health on ${workerBaseUrl}...`);
    const health = await httpGet(`${workerBaseUrl}/health`);
    console.log('Health Status Code:', health.statusCode);
    console.log('Health Body:', health.body.toString('utf8'));
    if (health.statusCode !== 200) throw new Error('Health check failed');

    // 2. Manifest Endpoint
    console.log('\n2. Testing /v1/model/manifest...');
    const manifestRes = await httpGet(`${workerBaseUrl}/v1/model/manifest`);
    console.log('Manifest Status Code:', manifestRes.statusCode);
    const manifest = JSON.parse(manifestRes.body.toString('utf8'));
    console.log('Manifest data:', manifest);
    if (manifest.encrypted_sha256 !== expectedEncSha256) {
      throw new Error('Manifest encrypted_sha256 mismatch');
    }
    console.log(' Manifest verified successfully!');

    // 3. Unauthorized Download Check
    console.log('\n3. Testing /v1/model/download without token (should be 401)...');
    const unauth = await httpGet(`${workerBaseUrl}/v1/model/download`);
    console.log('Unauthenticated Status Code:', unauth.statusCode);
    if (unauth.statusCode !== 401) throw new Error('Expected 401 for unauthenticated request');
    console.log(' Security Guard Verified: Access denied without token.');

    // 4. Authenticated Download Check
    console.log('\n4. Testing /v1/model/download with Authorization Bearer...');
    const authDownload = await httpGet(`${workerBaseUrl}/v1/model/download`, {
      'Authorization': `Bearer ${downloadSecret}`
    });
    console.log('Download Status Code:', authDownload.statusCode);
    console.log('Downloaded bytes:', authDownload.body.length);
    if (authDownload.statusCode !== 200) throw new Error('Download failed with status ' + authDownload.statusCode);

    const downloadedSha256 = crypto.createHash('sha256').update(authDownload.body).digest('hex');
    console.log('Downloaded Encrypted Model SHA-256:', downloadedSha256);
    if (downloadedSha256 !== expectedEncSha256) {
      throw new Error('Downloaded file checksum does not match expected encrypted SHA-256');
    }
    console.log(' Encrypted model download integrity verified!');

    // 5. In-Memory Decryption and Original Byte Verification
    console.log('\n5. Decrypting in-memory with AES-256-GCM key...');
    const container = authDownload.body;
    const magic = container.subarray(0, 4).toString('utf8');
    if (magic !== 'DAM1') throw new Error('Invalid magic header');
    const iv = container.subarray(4, 16);
    const tag = container.subarray(16, 32);
    const ciphertext = container.subarray(32);

    const aesKey = Buffer.from(aesKeyBase64, 'base64');
    const decipher = crypto.createDecipheriv('aes-256-gcm', aesKey, iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

    const decryptedSha256 = crypto.createHash('sha256').update(decrypted).digest('hex');
    console.log('Decrypted Model SHA-256:', decryptedSha256);
    console.log('Expected Original SHA-256:', expectedOriginalSha256);

    if (decryptedSha256 === expectedOriginalSha256) {
      console.log('\n FULL END-TO-END PIPELINE VERIFIED SUCCESSFULLY!');
      console.log('Cloudflare Worker -> R2 Storage -> Authorized Download -> Secure Decryption -> Identical TFLite Model!');
    } else {
      throw new Error('Decrypted model hash does not match original TFLite model!');
    }

  } catch (err) {
    console.error('Verification failed:', err.message);
    process.exit(1);
  }
}

verify();
