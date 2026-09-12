const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const modelPath = 'assets/models/eye_detector_5n_320_float16.tflite';
const encModelPath = 'assets/models/eye_detector_5n_320_float16.enc';
const envPath = 'secrets/drivealert_secrets.local.env';
const publicDir = 'security/public';

console.log('=== Step 1: Cryptographic Key Generation & Model Encryption ===');

if (!fs.existsSync(modelPath)) {
  console.error('Original model not found at:', modelPath);
  process.exit(1);
}

const rawModel = fs.readFileSync(modelPath);
const originalSha256 = crypto.createHash('sha256').update(rawModel).digest('hex');
console.log('Original Model Size:', rawModel.length, 'bytes');
console.log('Original Model SHA-256:', originalSha256);

// 1. Generate AES-256 Key (32 bytes)
const aesKey = crypto.randomBytes(32);
const aesKeyBase64 = aesKey.toString('base64');
console.log('Generated AES-256-GCM Key (256 bits): [SAVED TO SECRETS]');

// 2. Generate Ed25519 Signing Keypair
const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
const privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' }).trim();
const publicKeyPem = publicKey.export({ type: 'spki', format: 'pem' }).trim();
const publicKeyBase64 = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');

// 3. Generate Download Token Secret (32 bytes)
const downloadTokenSecret = crypto.randomBytes(32).toString('hex');

// 4. Encrypt Model with AES-256-GCM
// Container Format:
// [0..3]: Magic 'DAM1' (4 bytes)
// [4..15]: IV / Nonce (12 bytes)
// [16..31]: Auth Tag (16 bytes)
// [32..]: Ciphertext
const iv = crypto.randomBytes(12);
const cipher = crypto.createCipheriv('aes-256-gcm', aesKey, iv);
const ciphertext = Buffer.concat([cipher.update(rawModel), cipher.final()]);
const authTag = cipher.getAuthTag();

const magic = Buffer.from('DAM1', 'utf8');
const encryptedContainer = Buffer.concat([magic, iv, authTag, ciphertext]);
fs.writeFileSync(encModelPath, encryptedContainer);

const encSha256 = crypto.createHash('sha256').update(encryptedContainer).digest('hex');
console.log('Encrypted Model Written to:', encModelPath);
console.log('Encrypted Model Size:', encryptedContainer.length, 'bytes');
console.log('Encrypted Model SHA-256:', encSha256);

// 5. In-memory Decryption Verification
console.log('\nVerifying Decryption Integrity...');
const readContainer = fs.readFileSync(encModelPath);
const readMagic = readContainer.subarray(0, 4).toString('utf8');
if (readMagic !== 'DAM1') throw new Error('Invalid magic header');
const readIv = readContainer.subarray(4, 16);
const readTag = readContainer.subarray(16, 32);
const readCipher = readContainer.subarray(32);

const decipher = crypto.createDecipheriv('aes-256-gcm', aesKey, readIv);
decipher.setAuthTag(readTag);
const decrypted = Buffer.concat([decipher.update(readCipher), decipher.final()]);
const decryptedSha256 = crypto.createHash('sha256').update(decrypted).digest('hex');

if (decryptedSha256 !== originalSha256) {
  throw new Error('Decryption SHA-256 mismatch!');
}
console.log(' Decryption Verification PASSED! Byte-for-byte identical to original model.');

// 6. Sign Model Manifest
const manifest = {
  model_id: 'drivealert-model-v1',
  version: '1.0.0',
  algorithm: 'AES-256-GCM',
  sha256: originalSha256,
  encrypted_sha256: encSha256,
  file_size: encryptedContainer.length,
  timestamp: new Date().toISOString()
};
const manifestString = JSON.stringify(manifest);
const signature = crypto.sign(null, Buffer.from(manifestString), privateKey).toString('base64');
manifest.signature = signature;

// 7. Save Public Material for Mobile App Verification
if (!fs.existsSync(publicDir)) {
  fs.mkdirSync(publicDir, { recursive: true });
}
fs.writeFileSync(path.join(publicDir, 'model_signing_public.pem'), publicKeyPem);
fs.writeFileSync(path.join(publicDir, 'model_signing_public.base64'), publicKeyBase64);
fs.writeFileSync(path.join(publicDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log('Public signing key and manifest saved to:', publicDir);

// 8. Update secrets/drivealert_secrets.local.env
let envContent = fs.readFileSync(envPath, 'utf8');

function updateEnvVar(content, name, value) {
  const regex = new RegExp(`^${name}=.*$`, 'm');
  if (regex.test(content)) {
    return content.replace(regex, `${name}="${value}"`);
  } else {
    return content + `\n${name}="${value}"`;
  }
}

// Format PEM on single line or clean base64 for env
const privateKeyBase64 = privateKey.export({ type: 'pkcs8', format: 'der' }).toString('base64');

envContent = updateEnvVar(envContent, 'MODEL_AES_KEY_BASE64', aesKeyBase64);
envContent = updateEnvVar(envContent, 'MODEL_SIGNING_PRIVATE_KEY', privateKeyBase64);
envContent = updateEnvVar(envContent, 'MODEL_SIGNING_PUBLIC_KEY', publicKeyBase64);
envContent = updateEnvVar(envContent, 'DOWNLOAD_TOKEN_SECRET', downloadTokenSecret);
envContent = updateEnvVar(envContent, 'MODEL_SHA256', originalSha256);
envContent = updateEnvVar(envContent, 'ENCRYPTED_MODEL_SHA256', encSha256);

fs.writeFileSync(envPath, envContent);
console.log('Updated', envPath, 'with generated cryptographic keys and checksums.');

console.log('\n=== Step 1 Completed Successfully ===\n');
