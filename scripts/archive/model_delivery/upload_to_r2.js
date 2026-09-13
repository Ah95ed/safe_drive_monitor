const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

console.log('=== Step 2: Upload Encrypted Model to Cloudflare R2 ===');

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
const bucketName = env.CLOUDFLARE_R2_BUCKET_NAME;

const encFilePath = 'assets/models/eye_detector_5n_320_float16.enc';
const manifestPath = 'security/public/manifest.json';

if (!fs.existsSync(encFilePath)) {
  console.error('Encrypted model file not found:', encFilePath);
  process.exit(1);
}

// Function to upload via Cloudflare R2 REST API
function uploadR2Object(objectKey, filePath, contentType = 'application/octet-stream') {
  return new Promise((resolve, reject) => {
    const fileData = fs.readFileSync(filePath);
    const urlStr = `https://api.cloudflare.com/client/v4/accounts/${accountId}/r2/buckets/${bucketName}/objects/${encodeURIComponent(objectKey)}`;
    const parsed = new URL(urlStr);

    const options = {
      hostname: parsed.hostname,
      path: parsed.pathname,
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': contentType,
        'Content-Length': fileData.length,
        'User-Agent': 'DriveAlert-Uploader/1.0'
      }
    };

    console.log(`Uploading ${filePath} (${fileData.length} bytes) to R2 [${bucketName}/${objectKey}]...`);
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Upload response: HTTP ${res.statusCode}`);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(true);
        } else {
          console.error('Upload error response:', data);
          resolve(false);
        }
      });
    });

    req.on('error', (err) => {
      console.error('Network error during upload:', err);
      reject(err);
    });

    req.write(fileData);
    req.end();
  });
}

async function run() {
  try {
    // 1. Upload manifest
    console.log('1. Uploading manifest.json...');
    const okManifest = await uploadR2Object('models/v1/manifest.json', manifestPath, 'application/json');
    
    // 2. Upload encrypted model
    console.log('2. Uploading eye_detector_5n_320_float16.enc...');
    const okModel = await uploadR2Object('models/v1/eye_detector_5n_320_float16.enc', encFilePath, 'application/octet-stream');

    if (okManifest && okModel) {
      console.log('\n All objects successfully uploaded to Cloudflare R2 bucket: ' + bucketName);
    } else {
      console.log('\nDirect HTTP upload had status, attempting fallback via wrangler r2 object put...');
      try {
        process.env.CLOUDFLARE_API_TOKEN = token;
        process.env.CLOUDFLARE_ACCOUNT_ID = accountId;
        console.log('Uploading manifest.json to remote R2...');
        execSync(`npx wrangler r2 object put "${bucketName}/models/v1/manifest.json" --file "${manifestPath}" --remote`, { stdio: 'inherit' });
        console.log('Uploading eye_detector_5n_320_float16.enc to remote R2...');
        execSync(`npx wrangler r2 object put "${bucketName}/models/v1/eye_detector_5n_320_float16.enc" --file "${encFilePath}" --remote`, { stdio: 'inherit' });
        console.log('\n Remote objects uploaded successfully to Cloudflare R2!');
      } catch (wErr) {
        console.error('Wrangler upload error:', wErr.message);
      }
    }
  } catch (err) {
    console.error('Error during R2 upload:', err);
  }
}

run();
