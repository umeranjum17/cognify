import { streamText, tool } from 'ai';
import { z } from 'zod';
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
    'X-Title': 'Cognify Flutter App (Search Mode)',
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
    if (!process.env.BRAVE_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'Server misconfigured: BRAVE_API_KEY missing' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    const body = await req.json().catch(() => ({}));
    const model = (body?.model as string) || 'google/gemini-2.5-flash-lite';
    const temperature = typeof body?.temperature === 'number' ? body.temperature : 0.7;
    const maxTokens = typeof body?.maxTokens === 'number' ? body.maxTokens : undefined;
    const providedMessages = Array.isArray(body?.messages) ? body.messages : [];
    const fallbackQuery = typeof body?.query === 'string' ? body.query.trim() : '';

    const braveWebSearch = tool({
      description: 'Search the web using Brave and return top results',
      parameters: z.object({
        query: z.string().describe('The search query'),
        count: z.number().int().min(1).max(10).default(5).describe('Number of results'),
      }),
      execute: async ({ query, count }) => {
        const url = new URL('https://api.search.brave.com/res/v1/web/search');
        url.searchParams.set('q', query);
        url.searchParams.set('count', String(count));
        url.searchParams.set('safesearch', 'strict');

        const res = await fetch(url.toString(), {
          headers: {
            Accept: 'application/json',
            'X-Subscription-Token': process.env.BRAVE_API_KEY as string,
          },
        });
        if (!res.ok) throw new Error(`Brave web search failed: ${res.status}`);
        const json = await res.json();
        const results = (json?.web?.results ?? []).map((r: any) => ({
          title: r?.title ?? r?.url ?? 'Untitled',
          url: r?.url ?? '',
          description: r?.description ?? r?.snippet ?? '',
        }));
        return { query, results, totalResults: results.length };
      },
    });

    const system = [
      'You are a web search assistant.',
      'Behavior:',
      '- Use braveWebSearch first to fetch relevant results.',
      '- Answer concisely, then list key sources with [1], [2] markers.',
      '- Only use provided sources; if insufficient, say so.',
    ].join('\n');

    // If caller didn’t include a user message, seed one with the query.
    const messages = providedMessages.length
      ? providedMessages
      : [{ role: 'user', content: fallbackQuery }];

    const result = streamText({
      model: openrouter.chat(model),
      messages: [{ role: 'system', content: system }, ...messages],
      temperature,
      ...(maxTokens ? { maxTokens } : {}),
      tools: { braveWebSearch },
      toolChoice: 'auto',
    });

    return result.toTextStreamResponse({ headers: CORS_HEADERS });
  } catch (err) {
    console.error('Search mode (AI SDK) error:', err);
    return new Response(
      JSON.stringify({ error: 'Search mode failed' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
}
