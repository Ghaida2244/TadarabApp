import { createRemoteJWKSet, jwtVerify } from 'jose';

// Google's published JWK set for Firebase ID tokens. jose caches this
// remotely and refreshes it as keys rotate, so we build it once per isolate.
const FIREBASE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
);

const CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages';
const CLAUDE_MODEL = 'claude-sonnet-5';

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/// Verifies the caller's Firebase ID token. Returns the decoded payload
/// (which includes the student's uid in `sub`) or throws on any failure.
async function verifyFirebaseToken(request, projectId) {
  const authHeader = request.headers.get('Authorization') ?? '';
  const match = authHeader.match(/^Bearer (.+)$/);
  if (!match) {
    throw new Error('Missing Authorization: Bearer <idToken> header');
  }
  const idToken = match[1];

  const { payload } = await jwtVerify(idToken, FIREBASE_JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });

  if (!payload.sub) {
    throw new Error('Token missing subject (uid)');
  }
  return payload;
}

/// Handles POST /generate — the only route this Worker exposes. The Flutter
/// app sends { materials, difficulty, mode, count, customPrompt } and gets
/// back Claude's raw response for the app to parse into Questions/Flashcards.
async function handleGenerate(request, env) {
  let payload;
  try {
    payload = await verifyFirebaseToken(request, env.FIREBASE_PROJECT_ID);
  } catch (err) {
    return jsonResponse({ error: 'Unauthorized', message: err.message }, 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Bad Request', message: 'Body must be valid JSON' }, 400);
  }

  if (!body.prompt || typeof body.prompt !== 'string') {
    return jsonResponse({ error: 'Bad Request', message: 'Missing "prompt" string field' }, 400);
  }

  let claudeRes;
  try {
    claudeRes = await fetch(CLAUDE_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: body.maxTokens ?? 4096,
        messages: [{ role: 'user', content: body.prompt }],
      }),
    });
  } catch (err) {
    return jsonResponse({ error: 'Upstream request failed', message: err.message }, 502);
  }

  const claudeData = await claudeRes.json().catch(() => null);
  if (!claudeRes.ok || !claudeData) {
    return jsonResponse(
      { error: 'Claude API error', status: claudeRes.status, details: claudeData },
      502,
    );
  }

  return jsonResponse({ uid: payload.sub, result: claudeData });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/generate') {
      return handleGenerate(request, env);
    }

    return jsonResponse({ error: 'Not Found' }, 404);
  },
};
