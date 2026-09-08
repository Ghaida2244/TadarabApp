# Tadarab AI Worker

Cloudflare Worker that sits between the Flutter app and the Claude API. The
app never holds the Anthropic key — it calls this Worker with a Firebase ID
token, the Worker verifies that token against Google's public keys, then
calls Claude with the key stored as a Worker secret.

## One-time setup (once the Anthropic API key is available)

```
cd worker
npm install
npx wrangler login
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler deploy
```

`wrangler login` opens a browser for Cloudflare auth — a human has to do
that step. `wrangler secret put` prompts for the key value and stores it
server-side; it is never written to a file in this repo.

## Local dev

```
cd worker
npm install
npx wrangler dev
```

For local dev, put the key in `worker/.dev.vars` (already gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
```

## Endpoint

`POST /generate` — body `{ "prompt": "...", "maxTokens": 4096 }`,
`Authorization: Bearer <firebase-id-token>` header required.
