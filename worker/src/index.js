import { createRemoteJWKSet, jwtVerify } from 'jose';
import {
  VALID_TYPES,
  parseDifficulty,
  validateCustomPrompt,
  computeMaxTokens,
  buildPrompt,
  buildToolSchema,
  shuffleQuizOptions,
} from './generation.js';

// Google's published JWK set for Firebase ID tokens. jose caches this
// remotely and refreshes it as keys rotate, so we build it once per isolate.
const FIREBASE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
);

const CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages';
// Per quiz_flashcard_generation_spec.md — pinned, not the latest/default model.
const CLAUDE_MODEL = 'claude-haiku-4-5-20251001';

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

/// Validates and normalizes the request body into the shape [buildPrompt]
/// and friends expect. Throws a plain Error (client-safe message) on
/// anything invalid — the caller maps that to a 400.
function parseGenerateRequest(body) {
  if (!body || typeof body !== 'object') {
    throw new Error('Body must be a JSON object');
  }
  if (!VALID_TYPES.includes(body.type)) {
    throw new Error(`"type" must be one of ${VALID_TYPES.join(', ')}`);
  }
  if (!Number.isInteger(body.count) || body.count < 1) {
    throw new Error('"count" must be a positive integer');
  }
  if (!Array.isArray(body.materials) || body.materials.length === 0) {
    throw new Error('"materials" must be a non-empty array of { title, sourceText }');
  }
  for (const material of body.materials) {
    if (!material || typeof material.title !== 'string' || typeof material.sourceText !== 'string' || material.sourceText.trim() === '') {
      throw new Error('Each material needs a "title" and non-empty "sourceText"');
    }
  }

  const difficulties = parseDifficulty(body.difficulty);
  validateCustomPrompt(body.customPrompt);

  return {
    type: body.type,
    count: body.count,
    materials: body.materials,
    difficulties,
    customPrompt: typeof body.customPrompt === 'string' ? body.customPrompt : null,
  };
}

/// Handles POST /generate — the only route this Worker exposes. Verifies
/// the caller, builds the exact prompt from
/// quiz_flashcard_generation_spec.md, forces structured (Tool Use) output
/// from Claude, shuffles quiz option order server-side, and returns
/// { items, note } ready for the app to turn into Question/Flashcard docs.
async function handleGenerate(request, env) {
  let payload;
  try {
    payload = await verifyFirebaseToken(request, env.FIREBASE_PROJECT_ID);
  } catch (err) {
    return jsonResponse({ error: 'Unauthorized', message: err.message }, 401);
  }

  let rawBody;
  try {
    rawBody = await request.json();
  } catch {
    return jsonResponse({ error: 'Bad Request', message: 'Body must be valid JSON' }, 400);
  }

  let req;
  try {
    req = parseGenerateRequest(rawBody);
  } catch (err) {
    return jsonResponse({ error: 'Bad Request', message: err.message }, 400);
  }

  const prompt = buildPrompt(req);
  const tool = buildToolSchema(req.type);
  const maxTokens = computeMaxTokens(req.type, req.count);

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
        max_tokens: maxTokens,
        messages: [{ role: 'user', content: prompt }],
        tools: [tool],
        tool_choice: { type: 'tool', name: tool.name },
      }),
    });
  } catch (err) {
    return jsonResponse({ error: 'Upstream request failed', message: err.message }, 502);
  }

  const claudeData = await claudeRes.json().catch(() => null);
  if (!claudeRes.ok || !claudeData) {
    return jsonResponse({ error: 'Claude API error', status: claudeRes.status, details: claudeData }, 502);
  }

  const toolUse = (claudeData.content ?? []).find((block) => block.type === 'tool_use' && block.name === tool.name);
  if (!toolUse || !Array.isArray(toolUse.input?.items)) {
    return jsonResponse(
      { error: 'Claude API error', message: 'Response did not include the expected structured output', details: claudeData },
      502,
    );
  }

  const items = req.type === 'quiz' ? shuffleQuizOptions(toolUse.input.items) : toolUse.input.items;

  return jsonResponse({
    uid: payload.sub,
    type: req.type,
    items,
    note: toolUse.input.note ?? null,
  });
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
