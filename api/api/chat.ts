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
    const model = (body?.model as string) || 'openai/gpt-4o-mini';
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

    // Debug logging
    console.log('=== DEBUG INFO ===');
    console.log('Mode:', mode);
    console.log('Model:', model);
    console.log('Mode config:', JSON.stringify(modeConfig, null, 2));
    console.log('Tools available:', tools ? Object.keys(tools) : 'none');
    if (tools) {
      console.log('Tool details:', JSON.stringify(tools, null, 2));
    }
    console.log('Messages:', JSON.stringify(messages, null, 2));
    console.log('==================');

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
          let allSources: any[] = [];
          let allImages: any[] = [];
          
          for await (const part of result.fullStream) {
            if (part.type === 'text-delta') {
              // Send text content chunks
              const sseMessage = `data: ${JSON.stringify({ content: part.text })}\n\n`;
              controller.enqueue(encoder.encode(sseMessage));
            } else if (part.type === 'tool-result') {
              // Capture tool results for sources
              const toolOutput = part.output;
              
              if (part.toolName === 'braveWebSearch' && toolOutput && typeof toolOutput === 'object' && 'results' in toolOutput) {
                // Add web search sources
                const results = (toolOutput as any).results;
                if (Array.isArray(results)) {
                  const sources = results.map((result: any, index: number) => ({
                    id: `search-${Date.now()}-${index}`,
                    title: result.title || 'Untitled',
                    url: result.url || '',
                    description: result.description || '',
                    type: 'web',
                    query: (toolOutput as any).query || '',
                  }));
                  allSources.push(...sources);
                }
              } else if (part.toolName === 'braveImageSearch' && toolOutput && typeof toolOutput === 'object' && 'images' in toolOutput) {
                // Add image search results
                const images = (toolOutput as any).images;
                if (Array.isArray(images)) {
                  const imageResults = images.map((image: any, index: number) => ({
                    id: `image-${Date.now()}-${index}`,
                    title: image.title || 'Image',
                    url: image.url || '',
                    source: image.source || '',
                    type: 'image',
                    query: (toolOutput as any).query || '',
                  }));
                  allImages.push(...imageResults);
                }
              }
            }
          }
          
          // Send sources if any were found
          if (allSources.length > 0) {
            const sourcesMessage = `data: ${JSON.stringify({ 
              type: 'sourcesReady', 
              sources: allSources 
            })}\n\n`;
            controller.enqueue(encoder.encode(sourcesMessage));
          }
          
          // Send images if any were found
          if (allImages.length > 0) {
            const imagesMessage = `data: ${JSON.stringify({ 
              type: 'imagesReady', 
              images: allImages 
            })}\n\n`;
            controller.enqueue(encoder.encode(imagesMessage));
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

    const resultCount = mode === 'aipedia' ? 6 : 5;

    toolSet.braveWebSearch = tool({
      description: 'Search the web using Brave and return top results',
      parameters: z.object({
        query: z.string().describe('The search query'),
      }),
      execute: async ({ query }) => {
        const url = new URL('https://api.search.brave.com/res/v1/web/search');
        url.searchParams.set('q', query);
        url.searchParams.set('count', String(resultCount));
        url.searchParams.set('safesearch', 'strict');

        const res = await fetch(url.toString(), {
          headers: {
            Accept: 'application/json',
            'X-Subscription-Token': process.env.BRAVE_API_KEY as string,
          },
        });
        if (!res.ok) throw new Error(`Brave web search failed: ${res.status}`);
        const json: any = await res.json();
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
      }),
      execute: async ({ query }) => {
        const imageCount = 4;
        const url = new URL('https://api.search.brave.com/res/v1/images/search');
        url.searchParams.set('q', query);
        url.searchParams.set('count', String(imageCount));
        url.searchParams.set('safesearch', 'strict');
        const res = await fetch(url.toString(), {
          headers: {
            Accept: 'application/json',
            'X-Subscription-Token': process.env.BRAVE_API_KEY as string,
          },
        });
        if (!res.ok) throw new Error(`Brave image search failed: ${res.status}`);
        const json: any = await res.json();
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
