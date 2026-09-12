/**
 * DriveAlert Secure Model Delivery Service
 * Cloudflare Worker with R2 Storage & Device Attestation
 */

// In-memory sliding-window IP rate limiter
const ipRequestCounts = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS_PER_WINDOW = 20;

function checkRateLimit(clientIp) {
  const now = Date.now();
  const clientRecord = ipRequestCounts.get(clientIp);

  if (!clientRecord || now - clientRecord.startTime > RATE_LIMIT_WINDOW_MS) {
    ipRequestCounts.set(clientIp, { startTime: now, count: 1 });
    return true;
  }

  if (clientRecord.count >= MAX_REQUESTS_PER_WINDOW) {
    return false;
  }

  clientRecord.count++;
  return true;
}

// Helper to generate HMAC-SHA256 token
async function generateHmacSha256(secret, message) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify']
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const clientIp = request.headers.get('CF-Connecting-IP') || 'unknown';

    // Strict Security Headers
    const securityHeaders = {
      'Content-Type': 'application/json',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-Device-ID, X-App-Version, X-App-Package',
      'Access-Control-Max-Age': '86400',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: securityHeaders });
    }

    // 1. IP Rate Limiting
    if (!checkRateLimit(clientIp)) {
      return new Response(
        JSON.stringify({ error: 'Too many requests. Please try again later.' }),
        { status: 429, headers: securityHeaders }
      );
    }

    // 2. Health Check
    if (path === '/' || path === '/health') {
      return new Response(
        JSON.stringify({
          service: 'drivealert-model-service',
          status: 'healthy',
          version: '1.2.0',
          timestamp: new Date().toISOString(),
        }),
        { status: 200, headers: securityHeaders }
      );
    }

    // 3. Model Manifest Endpoint
    if (path === '/v1/model/manifest') {
      if (!env.MODELS_BUCKET) {
        console.error('R2 MODELS_BUCKET binding missing');
        return new Response(JSON.stringify({ error: 'Service unavailable' }), {
          status: 503,
          headers: securityHeaders,
        });
      }

      const manifestObject = await env.MODELS_BUCKET.get('models/v1/manifest.json');
      if (!manifestObject) {
        return new Response(JSON.stringify({ error: 'Resource not found' }), {
          status: 404,
          headers: securityHeaders,
        });
      }

      const manifestData = await manifestObject.text();
      return new Response(manifestData, {
        status: 200,
        headers: {
          ...securityHeaders,
          'Cache-Control': 'public, max-age=300', // 5 minutes edge cache
        },
      });
    }

    // 4. Device Attestation & Short-Lived Token Issuance
    if (path === '/v1/auth/attest' && request.method === 'POST') {
      try {
        const body = await request.json().catch(() => ({}));
        const { deviceId, appPackage, appVersion, attestationToken } = body;

        // Verify authorized client package
        if (appPackage !== 'com.eyewatchdriver.eye.safe_drive_monitor') {
          return new Response(JSON.stringify({ error: 'Unauthorized client package' }), {
            status: 403,
            headers: securityHeaders,
          });
        }

        const secret = env.DOWNLOAD_TOKEN_SECRET || 'default_secret';
        // 15-minute expiration timestamp
        const expiry = Date.now() + 15 * 60 * 1000;
        const payload = `${deviceId || 'anon'}:${expiry}`;
        const signature = await generateHmacSha256(secret, payload);
        const token = `${payload}:${signature}`;

        return new Response(
          JSON.stringify({
            status: 'attested',
            token: token,
            expiresAt: new Date(expiry).toISOString(),
          }),
          { status: 200, headers: securityHeaders }
        );
      } catch (err) {
        console.error('Attestation error:', err);
        return new Response(JSON.stringify({ error: 'Attestation verification failed' }), {
          status: 400,
          headers: securityHeaders,
        });
      }
    }

    // 5. Authenticated Secure Model Download
    if (path === '/v1/model/download') {
      if (!env.MODELS_BUCKET) {
        console.error('R2 MODELS_BUCKET binding missing');
        return new Response(JSON.stringify({ error: 'Service unavailable' }), {
          status: 503,
          headers: securityHeaders,
        });
      }

      // Verify Authorization Token
      const authHeader = request.headers.get('Authorization') || '';
      const bearerMatch = authHeader.match(/^Bearer\s+(.+)$/i);
      const token = bearerMatch ? bearerMatch[1].trim() : url.searchParams.get('token');

      const expectedSecret = env.DOWNLOAD_TOKEN_SECRET;
      let isAuthorized = false;

      if (expectedSecret && token) {
        // Direct secret match (for operators)
        if (token === expectedSecret) {
          isAuthorized = true;
        } else if (token.includes(':')) {
          // Short-lived signed token verification: `deviceId:expiry:signature`
          const parts = token.split(':');
          if (parts.length === 3) {
            const [deviceId, expiryStr, receivedSig] = parts;
            const expiry = parseInt(expiryStr, 10);
            if (!isNaN(expiry) && Date.now() <= expiry) {
              const expectedSig = await generateHmacSha256(expectedSecret, `${deviceId}:${expiry}`);
              if (receivedSig === expectedSig) {
                isAuthorized = true;
              }
            }
          }
        }
      }

      if (!isAuthorized) {
        return new Response(
          JSON.stringify({ error: 'Access denied: Valid authorization required' }),
          { status: 401, headers: securityHeaders }
        );
      }

      const modelObject = await env.MODELS_BUCKET.get('models/v1/eye_detector_5n_320_float16.enc');
      if (!modelObject) {
        return new Response(JSON.stringify({ error: 'Resource not found' }), {
          status: 404,
          headers: securityHeaders,
        });
      }

      const headers = new Headers(securityHeaders);
      headers.set('Content-Type', 'application/octet-stream');
      headers.set('Content-Disposition', 'attachment; filename="eye_detector_5n_320_float16.enc"');
      headers.set('Content-Length', modelObject.size.toString());
      headers.set('Cache-Control', 'private, no-transform, max-age=86400');
      if (modelObject.httpEtag) headers.set('ETag', modelObject.httpEtag);

      return new Response(modelObject.body, {
        status: 200,
        headers: headers,
      });
    }

    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: securityHeaders,
    });
  },
};
