import { streamText } from 'ai';
import { createOpenRouter } from '@openrouter/ai-sdk-provider';

export const config = { runtime: 'edge' };

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

const openrouter = createOpenRouter({
  apiKey: process.env.OPENROUTER_API_KEY ?? '',
  headers: {
    'HTTP-Referer': 'https://cognify.app',
    'X-Title': 'Cognify Flutter App (Chat Mode)',
  },
});

export default async function handler(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }

  try {
    if (!process.env.OPENROUTER_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'Server misconfigured: OPENROUTER_API_KEY missing' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const { messages = [], model = 'google/gemini-2.5-flash-lite', temperature = 0.7, maxTokens } = await req
      .json()
      .catch(() => ({ messages: [] }));

    const result = streamText({
      model: openrouter.chat(model),
      messages,
      temperature,
      ...(maxTokens ? { maxTokens } : {}),
    });

    return result.toTextStreamResponse({ headers: CORS_HEADERS });
  } catch (err) {
    console.error('Chat mode (AI SDK) error:', err);
    return new Response(
      JSON.stringify({ error: 'Failed to stream chat completion' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
}
