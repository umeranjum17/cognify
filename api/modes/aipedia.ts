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
    'X-Title': 'Cognify Flutter App (AIpedia Mode)',
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
    const temperature = typeof body?.temperature === 'number' ? body.temperature : 0.5;
    const maxTokens = typeof body?.maxTokens === 'number' ? body.maxTokens : undefined;
    const providedMessages = Array.isArray(body?.messages) ? body.messages : [];
    const fallbackQuery = typeof body?.query === 'string' ? body.query.trim() : '';

    const braveWebSearch = tool({
      description: 'Search the web using Brave and return top results',
      parameters: z.object({
        query: z.string().describe('The topic or query to search for'),
        count: z.number().int().min(1).max(10).default(6),
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

    const braveImageSearch = tool({
      description: 'Find relevant images using Brave image search',
      parameters: z.object({
        query: z.string().describe('Image search query'),
        count: z.number().int().min(1).max(10).default(4),
      }),
      execute: async ({ query, count }) => {
        const url = new URL('https://api.search.brave.com/res/v1/images/search');
        url.searchParams.set('q', query);
        url.searchParams.set('count', String(count));
        url.searchParams.set('safesearch', 'strict');
        const res = await fetch(url.toString(), {
          headers: {
            Accept: 'application/json',
            'X-Subscription-Token': process.env.BRAVE_API_KEY as string,
          },
        });
        if (!res.ok) throw new Error(`Brave image search failed: ${res.status}`);
        const json = await res.json();
        const imgs = (json?.results ?? json?.images ?? json?.items ?? []) as any[];
        const images = imgs.map((it) => ({
          title: it?.title ?? it?.source ?? 'Image',
          url: it?.properties?.url ?? it?.thumbnail?.src ?? it?.url ?? '',
          source: it?.source ?? it?.host_page_display_url ?? '',
        }));
        return { query, images, totalImages: images.length };
      },
    });

    const system = [
      'You are an encyclopedic topic writer (AIpedia). Produce a structured overview.',
      'Format:',
      '- Summary (2–4 sentences)',
      '- Key Facts (bullets)',
      '- Main Sections (clear headings)',
      '- References (titles + URLs)',
      '',
      'Use Brave tools to gather reputable sources and relevant images.',
      'Cite with inline markers like [1], [2]. Keep a neutral tone.',
    ].join('\n');

    const messages = providedMessages.length
      ? providedMessages
      : [{ role: 'user', content: fallbackQuery }];

    const result = streamText({
      model: openrouter.chat(model),
      messages: [{ role: 'system', content: system }, ...messages],
      temperature,
      ...(maxTokens ? { maxTokens } : {}),
      tools: { braveWebSearch, braveImageSearch },
      toolChoice: 'auto',
    });

    return result.toTextStreamResponse({ headers: CORS_HEADERS });
  } catch (err) {
    console.error('AIpedia mode (AI SDK) error:', err);
    return new Response(
      JSON.stringify({ error: 'AIpedia mode failed' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
}
