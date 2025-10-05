import { streamText, tool } from 'ai';
import { createOpenRouter } from '@openrouter/ai-sdk-provider';
import { z } from 'zod';
// Manual SSE streaming to OpenRouter to guarantee streaming regardless of SDK helpers

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
    'X-Title': 'Cognify Flutter App',
  },
});

/**
 * Unified Chat Endpoint
 * POST /api/chat
 *
 * Handles ALL chat modes in one endpoint. Backend determines behavior based on 'mode' parameter.
 *
 * Request:
 * {
 *   "messages": [...],
 *   "mode": "chat" | "search" | "aipedia",  // Backend uses this to determine behavior
 *   "model": "google/gemini-2.5-flash-lite",  // optional, backend has defaults
 *   "temperature": 0.7,  // optional
 *   "maxTokens": 4000    // optional
 * }
 */
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

    const body = await req.json().catch(() => ({}));

    // Extract parameters - backend determines defaults
    const mode = (body?.mode as string) || 'chat';
    const model = (body?.model as string) || 'google/gemini-2.5-flash-lite';
    const temperature = typeof body?.temperature === 'number' ? body.temperature : 0.7;
    const maxTokens = typeof body?.maxTokens === 'number' ? body.maxTokens : undefined;
    const providedMessages = Array.isArray(body?.messages) ? body.messages : [];
    const fallbackQuery = typeof body?.query === 'string' ? body.query.trim() : '';

    // Mode configuration - backend knows what each mode needs
    const modeConfig = getModeConfig(mode);

    // Build messages
    const messages = providedMessages.length
      ? providedMessages
      : fallbackQuery
      ? [{ role: 'user', content: fallbackQuery }]
      : [];

    if (messages.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No messages provided' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // Build system prompt based on mode
    const systemMessages = modeConfig.systemPrompt
      ? [{ role: 'system', content: modeConfig.systemPrompt }]
      : [];

    // Build tools based on mode capabilities
    const tools = await buildToolsForMode(mode, modeConfig);

    // Use AI SDK streaming helpers
    const result = streamText({
      model: openrouter(model),
      messages: [...systemMessages, ...messages],
      temperature: modeConfig.temperature ?? temperature,
      ...(maxTokens ? { maxTokens } : {}),
      ...(tools ? { tools, toolChoice: modeConfig.toolChoice || 'auto' } : {}),
    });
    
    // Convert to SSE format that Flutter expects
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        try {
          for await (const textPart of result.textStream) {
            // Send each chunk in SSE format with data: prefix
            const sseMessage = `data: ${JSON.stringify({ content: textPart })}\n\n`;
            controller.enqueue(encoder.encode(sseMessage));
          }
          // Send completion marker
          controller.enqueue(encoder.encode('data: [DONE]\n\n'));
          controller.close();
        } catch (error) {
          controller.error(error);
        }
      },
    });

    return new Response(stream, {
      headers: {
        ...CORS_HEADERS,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    });
  } catch (err) {
    console.error('Unified chat endpoint error:', err);
    return new Response(
      JSON.stringify({ error: 'Chat request failed', details: err instanceof Error ? err.message : 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
    );
  }
}

/**
 * Mode configurations - Backend defines all mode behavior
 */
function getModeConfig(mode: string) {
  const configs: Record<string, any> = {
    chat: {
      systemPrompt: 'You are a helpful AI assistant.',
      temperature: 0.7,
      capabilities: ['text'],
      tools: [],
    },
    search: {
      systemPrompt: [
        'You are a web search assistant.',
        'Behavior:',
        '- Use braveWebSearch first to fetch relevant results.',
        '- Answer concisely, then list key sources with [1], [2] markers.',
        '- Only use provided sources; if insufficient, say so.',
      ].join('\n'),
      temperature: 0.7,
      capabilities: ['text', 'web-search'],
      tools: ['braveWebSearch'],
      toolChoice: 'auto',
    },
    aipedia: {
      systemPrompt: [
        'You are an encyclopedic topic writer (AIpedia). Produce a structured overview.',
        'Format:',
        '- Summary (2–4 sentences)',
        '- Key Facts (bullets)',
        '- Main Sections (clear headings)',
        '- References (titles + URLs)',
        '',
        'Use Brave tools to gather reputable sources and relevant images.',
        'Cite with inline markers like [1], [2]. Keep a neutral tone.',
      ].join('\n'),
      temperature: 0.5,
      capabilities: ['text', 'web-search', 'image-search'],
      tools: ['braveWebSearch', 'braveImageSearch'],
      toolChoice: 'auto',
    },
  };

  return configs[mode] || configs.chat;
}

/**
 * Build tools based on mode requirements
 */
async function buildToolsForMode(mode: string, config: any) {
  const toolSet: Record<string, any> = {};

  if (config.tools?.includes('braveWebSearch')) {
    if (!process.env.BRAVE_API_KEY) {
      throw new Error('BRAVE_API_KEY required for search mode');
    }

    toolSet.braveWebSearch = tool({
      description: 'Search the web using Brave and return top results',
      parameters: z.object({
        query: z.string().describe('The search query'),
        count: z.number().int().min(1).max(10).default(mode === 'aipedia' ? 6 : 5),
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
  }

  if (config.tools?.includes('braveImageSearch')) {
    if (!process.env.BRAVE_API_KEY) {
      throw new Error('BRAVE_API_KEY required for aipedia mode');
    }

    toolSet.braveImageSearch = tool({
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
  }

  return Object.keys(toolSet).length > 0 ? toolSet : undefined;
}

// removed manual SSE fallback per request
