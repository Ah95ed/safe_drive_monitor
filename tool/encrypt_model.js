#!/usr/bin/env node
/**
 * Safe Drive Monitor - Model Encryption Tool (AES-256-GCM)
 * Encrypts TFLite neural network weights for secure storage in release APK.
 */

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const salt = Buffer.from('SafeDriveModelSec2026_AESGCM', 'utf8');
const packageName = Buffer.from('com.eyewatchdriver.eye.safe_drive_monitor', 'utf8');
const key = crypto.createHash('sha256').update(salt).update(packageName).digest();

const inputPath = process.argv[2] || 'assets/models/eye_detector_5n_320_float16.tflite';
const outputPath = process.argv[3] || (inputPath.endsWith('.enc') ? inputPath : inputPath + '.enc');

if (!fs.existsSync(inputPath)) {
  console.error(`Error: Input model file not found at ${inputPath}`);
  process.exit(1);
}

const rawData = fs.readFileSync(inputPath);
const iv = crypto.randomBytes(12);
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

const encrypted = Buffer.concat([cipher.update(rawData), cipher.final()]);
const tag = cipher.getAuthTag();

// Format: MAGIC(7: "SDM_ENC") + VERSION(1: 0x01) + IV(12) + CIPHERTEXT + TAG(16)
const magic = Buffer.from('SDM_ENC\x01', 'binary');
const finalPayload = Buffer.concat([magic, iv, encrypted, tag]);

fs.writeFileSync(outputPath, finalPayload);
console.log(`[ModelSecurity] Successfully encrypted ${rawData.length} bytes -> ${finalPayload.length} bytes.`);
console.log(`[ModelSecurity] Output: ${outputPath}`);

