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

    type ChatRequestBody = {
      messages?: any[];
      mode?: string;
      model?: string;
      temperature?: number;
      maxTokens?: number;
      query?: string;
    };
    const body = (await req.json().catch(() => ({}))) as ChatRequestBody;

    // Extract parameters - backend determines defaults
    const mode = (body?.mode as string) || 'chat';
    // Prefer model defined by mode config; fall back to request body or default
    const model = (getModeConfig(mode)?.model as string) || (body?.model as string) || 'google/gemini-2.5-flash-lite';
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

    // Pre-deduct credits based on model/mode and refund on failure
    const requestId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    let didConsume = false;
    try {
      // Attempt to consume credits; if insufficient, return 409
      const baseUrl = req.url.split('/api/')[0];
      const consumeRes = await fetch(`${baseUrl}/api/credits/consume`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...(req.headers.get('authorization') ? { Authorization: String(req.headers.get('authorization')) } : {}) },
        body: JSON.stringify({
          modelId: model,
          mode,
          requestId,
        }),
      });
      if (consumeRes.status === 409) {
        return new Response(JSON.stringify({ error: 'INSUFFICIENT_CREDITS' }), { status: 409, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } });
      }
      if (!consumeRes.ok) {
        const text = await consumeRes.text().catch(() => '');
        throw new Error(`Credit consume failed: ${consumeRes.status} ${text}`);
      }
      didConsume = true;
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'Credit check failed', details: e instanceof Error ? e.message : String(e) }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } },
      );
    }

    // Two-phase for search-like modes; single-phase otherwise
    const effectiveMaxTokens = maxTokens ?? (modeConfig as any).maxTokens;
    const isTwoPhase = mode === 'search' || mode === 'aipedia';
    const singlePhaseResult = !isTwoPhase
      ? streamText({
          model: openrouter(model),
          messages: [...systemMessages, ...messages],
          temperature: modeConfig.temperature ?? temperature,
          ...(effectiveMaxTokens ? { maxOutputTokens: effectiveMaxTokens } : {}),
          ...(tools ? { tools, toolChoice: modeConfig.toolChoice || 'auto' } : {}),
        })
      : undefined;
    
    // Convert to SSE format that Flutter expects
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        try {
        let allSources: any[] = [];
        let allImages: any[] = [];
        let emittedText = false;
        let sourcesSent = false;
        let imagesSent = false;

        if (!isTwoPhase) {
          emittedText = await streamSinglePhase(singlePhaseResult as any, controller, encoder, (toolName, toolOutput) => {
            if (toolName === 'braveWebSearch' && toolOutput && typeof toolOutput === 'object') {
              const results = (toolOutput as any).sources ?? (toolOutput as any).results;
              if (Array.isArray(results)) {
                const sources = results.map((result: any, index: number) => ({
                  id: `search-${Date.now()}-${index}`,
                  title: result.title || 'Untitled',
                  url: result.url || '',
                  description: result.description || '',
                  type: 'web',
                }));
                allSources.push(...sources);
              }
            } else if (toolName === 'braveImageSearch' && toolOutput && typeof toolOutput === 'object' && 'images' in toolOutput) {
              const images = (toolOutput as any).images;
              if (Array.isArray(images)) {
                const imageResults = images.map((image: any, index: number) => ({
                  id: `image-${Date.now()}-${index}`,
                  title: image.title || 'Image',
                  url: image.url || '',
                  source: image.source || '',
                  type: 'image',
                }));
                allImages.push(...imageResults);
                const imagesMessage = `data: ${JSON.stringify({ type: 'imagesReady', images: imageResults })}\n\n`;
                controller.enqueue(encoder.encode(imagesMessage));
              }
            }
          });
        } else {
          const { rawSources, uiSources, uiImages } = await toolPhaseCollectSources({
            model,
            systemMessages,
            messages,
            temperature: modeConfig.temperature ?? temperature,
            tools,
          });
          allSources = uiSources;
          allImages = uiImages;
          // Stream sources/images immediately so the UI can render while we summarize
          if (allSources.length > 0) {
            const sourcesMessage = `data: ${JSON.stringify({ type: 'sourcesReady', sources: allSources })}\n\n`;
            controller.enqueue(encoder.encode(sourcesMessage));
            sourcesSent = true;
          }
          if (allImages.length > 0) {
            const imagesMessage = `data: ${JSON.stringify({ type: 'imagesReady', images: allImages })}\n\n`;
            controller.enqueue(encoder.encode(imagesMessage));
            imagesSent = true;
          }
          // Minimal fallback: for aipedia, ensure we have images
          if (mode === 'aipedia' && !imagesSent && tools && (tools as any).braveImageSearch) {
            const extraImages = await toolPhaseCollectImages({
              model,
              systemMessages,
              messages,
              temperature: modeConfig.temperature ?? temperature,
              tools,
            });
            if (extraImages.length > 0) {
              allImages = extraImages;
              const imagesMessage = `data: ${JSON.stringify({ type: 'imagesReady', images: allImages })}\n\n`;
              controller.enqueue(encoder.encode(imagesMessage));
              imagesSent = true;
            }
          }
          await summarizePhaseStream({
            model,
            systemMessages,
            userQuery: messages[messages.length - 1]?.content || fallbackQuery,
            rawSources,
            uiImages: allImages,
            mode,
            temperature: modeConfig.temperature ?? temperature,
            maxTokens: effectiveMaxTokens,
            controller,
            encoder,
          });
          emittedText = true;
        }
          
          // No second pass fallback here to avoid extra cost/latency.

          // Send sources now (after any text that may have streamed)
          if (!sourcesSent && allSources.length > 0) {
            const sourcesMessage = `data: ${JSON.stringify({ 
              type: 'sourcesReady', 
              sources: allSources 
            })}\n\n`;
            controller.enqueue(encoder.encode(sourcesMessage));
          }
          
          // Send images if any were found
          if (!imagesSent && allImages.length > 0) {
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
          // On error, attempt to refund credits
          if (didConsume) {
            const baseUrl = req.url.split('/api/')[0];
            fetch(`${baseUrl}/api/credits/refund`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', ...(req.headers.get('authorization') ? { Authorization: String(req.headers.get('authorization')) } : {}) },
              body: JSON.stringify({ requestId }),
            }).catch(() => {});
          }
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
    // Best-effort: cannot refund here because requestId lives in inner scope
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
      model: 'google/gemini-2.5-flash-lite',
      systemPrompt: 'You are a helpful AI assistant.',
      temperature: 0.7,
      maxTokens: 700,
      capabilities: ['text'],
      tools: [],
    },
    search: {
      model: 'google/gemini-2.5-flash-lite',
      systemPrompt: [
        'You are a web search assistant.',
        'CRITICAL INSTRUCTIONS (follow exactly):',
        '- You MUST call the tool braveWebSearch BEFORE writing any answer.',
        '- Do NOT answer from prior knowledge. Never produce an answer without at least one braveWebSearch call.',
        "- The tool returns results with optional 'content' (fetched page text). Prefer that 'content' over titles/snippets when forming the answer.",
        '- After tool results arrive, you MUST write and STREAM a concise answer. Do not end the response after a tool call.',
        '- Keep answers concise, neutral, and factual. Do NOT add inline [n] citation markers inside sentences. Instead, add a short "References" section at the end with numbered items (title – URL).',
        '- If the tool returns no useful sources, explicitly say you lack sufficient information and stop.',
        '- Never fabricate or guess URLs, titles, or facts.',
        '- Begin streaming the answer as soon as you can; do not wait to see all tool results if the first ones suffice.',
        '- Target length: 120–180 words. Avoid long digressions.',
      ].join('\n'),
      temperature: 0.6,
      maxTokens: 600,
      capabilities: ['text', 'web-search'],
      tools: ['braveWebSearch'],
      // Allow the model to proceed after tool calls; some models stall on 'required'
      toolChoice: 'auto',
    },
    aipedia: {
      model: 'google/gemini-2.5-flash-lite',
      systemPrompt: [
        'You are an encyclopedic topic writer (AIpedia). Produce a structured overview.',
        'Format:',
        '- Summary (2–4 sentences)',
        '- Key Facts (bullets)',
        '- Main Sections (clear headings)',
        '- References (titles + URLs)',
        '',
        'Use Brave tools to gather reputable sources and relevant images.',
        'When images are available, weave them naturally into the prose (mention what key image(s) depict without dumping links or markdown).',
        "When available, rely on the 'content' included with each source to write the summary and facts.",
        'After tool results arrive, you MUST stream the structured article text. Do not stop after tool calls.',
        'Do NOT add inline [n] citation markers inside sentences. Instead, include a short "References" section at the end with numbered items (title – URL). Keep a neutral tone.',
        'Target length: ~350–500 words.',
      ].join('\n'),
      temperature: 0.5,
      maxTokens: 900,
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

    toolSet.braveWebSearch = tool<any>({
      description: 'Search the web using Brave and return top results',
      inputSchema: (z.object({
        query: z.string().describe('The search query'),
      }) as any),
      execute: async (args: any) => {
        const query = String(args?.query ?? '');
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
        const results: any[] = (json?.web?.results ?? []).map((r: any) => ({
          title: r?.title ?? r?.url ?? 'Untitled',
          url: r?.url ?? '',
          description: r?.description ?? r?.snippet ?? '',
        }));

        // Crawl pages to extract summary content for the model and UI
        const maxPages = Math.min(results.length, resultCount);
        const sources = await Promise.all(
          results.slice(0, maxPages).map(async (r: any) => {
            const content = await fetchPageTextSafe(r.url);
            return {
              title: r.title,
              url: r.url,
              description: r.description,
              content,
            };
          })
        );

        return { query, sources, totalResults: results.length };
      },
    });
  }

  if (config.tools?.includes('braveImageSearch')) {
    if (!process.env.BRAVE_API_KEY) {
      throw new Error('BRAVE_API_KEY required for aipedia mode');
    }

    toolSet.braveImageSearch = tool<any>({
      description: 'Find relevant images using Brave image search',
      inputSchema: (z.object({
        query: z.string().describe('Image search query'),
      }) as any),
      execute: async (args: any) => {
        const query = String(args?.query ?? '');
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

// Best-effort page text fetcher for enriching sources
async function fetchPageTextSafe(url: string): Promise<string> {
  try {
    if (!url) return '';
    const res = await fetch(url, { headers: { Accept: 'text/html,application/xhtml+xml' } });
    if (!res.ok) return '';
    const html = await res.text();
    // Heuristic extraction: prefer <article> or <main>, else full HTML
    const pickSection = (source: string): string => {
      const articleMatch = source.match(/<article[\s\S]*?<\/article>/i);
      if (articleMatch) return articleMatch[0];
      const mainMatch = source.match(/<main[\s\S]*?<\/main>/i);
      if (mainMatch) return mainMatch[0];
      const roleMainMatch = source.match(/<[^>]*role=["']main["'][^>]*>[\s\S]*?<\/[^^>]+>/i);
      if (roleMainMatch) return roleMainMatch[0];
      const bodyMatch = source.match(/<body[\s\S]*?<\/body>/i);
      return bodyMatch ? bodyMatch[0] : source;
    };

    let mainHtml = pickSection(html);

    // Remove noisy blocks by tag and common boilerplate ids/classes
    mainHtml = mainHtml
      // scripts/styles/media
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
      .replace(/<svg[\s\S]*?<\/svg>/gi, ' ')
      // nav/aside/footer/header sections
      .replace(/<nav[\s\S]*?<\/nav>/gi, ' ')
      .replace(/<aside[\s\S]*?<\/aside>/gi, ' ')
      .replace(/<footer[\s\S]*?<\/footer>/gi, ' ')
      .replace(/<header[\s\S]*?<\/header>/gi, ' ')
      // common boilerplate containers by class/id (best-effort)
      .replace(/<div[^>]*(id|class)=["'][^"']*(sidebar|menu|nav|footer|header|advert|ad-|ads|promo|cookie|banner)[^"']*["'][\s\S]*?<\/div>/gi, ' ');

    // Convert <br> and block tags to line breaks to keep some structure
    mainHtml = mainHtml
      .replace(/<\s*br\s*\/?\s*>/gi, '\n')
      .replace(/<\/(p|h[1-6]|li|section|article|main)>/gi, '\n');

    // Strip remaining tags
    let text = mainHtml.replace(/<[^>]+>/g, ' ');

    // Decode a few common HTML entities
    text = text
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'");

    // Collapse whitespace and trim
    text = text.replace(/\s+/g, ' ').trim();

    // Truncate to keep payload small for streaming/UI
    const MAX_CHARS = 1800;
    return text.length > MAX_CHARS ? text.slice(0, MAX_CHARS) : text;
  } catch {
    return '';
  }
}

// Helpers: single-phase streaming with tool capture
async function streamSinglePhase(result: any, controller: ReadableStreamDefaultController, encoder: { encode: (s: string) => Uint8Array }, onTool: (toolName: string, output: any) => void): Promise<boolean> {
  let emitted = false;
  for await (const part of result.fullStream) {
    if (part.type === 'text-delta') {
      const sseMessage = `data: ${JSON.stringify({ type: 'content', content: part.text })}\n\n`;
      controller.enqueue(encoder.encode(sseMessage));
      emitted = true;
    } else if (part.type === 'tool-result') {
      onTool(part.toolName, part.output);
    }
  }
  return emitted;
}

// Helpers: Phase 1 – collect sources/images via tools only
async function toolPhaseCollectSources({ model, systemMessages, messages, temperature, tools }: { model: string; systemMessages: any[]; messages: any[]; temperature: number; tools: any; }) {
  const phase1 = streamText({
    model: openrouter(model),
    messages: [...systemMessages, ...messages],
    temperature,
    maxOutputTokens: 64,
    ...(tools ? { tools, toolChoice: 'required' } : {}),
  });
  const rawSources: any[] = [];
  const uiSources: any[] = [];
  const uiImages: any[] = [];
  for await (const part of phase1.fullStream) {
    if (part.type === 'tool-result') {
      const toolOutput = part.output;
      if (part.toolName === 'braveWebSearch' && toolOutput && typeof toolOutput === 'object') {
        const results = (toolOutput as any).sources ?? (toolOutput as any).results;
        if (Array.isArray(results)) {
          rawSources.push(...results);
          const sources = (results as any[]).map((result: any, index: number) => ({
            id: `search-${Date.now()}-${index}`,
            title: result.title || 'Untitled',
            url: result.url || '',
            description: result.description || '',
            type: 'web',
            query: (toolOutput as any)?.query || '',
          }));
          uiSources.push(...sources);
        }
      } else if (part.toolName === 'braveImageSearch' && toolOutput && typeof toolOutput === 'object' && 'images' in toolOutput) {
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
          uiImages.push(...imageResults);
        }
      }
    }
  }
  return { rawSources, uiSources, uiImages };
}

// Helpers: Phase 2 – summarization-only streaming
async function summarizePhaseStream({ model, systemMessages, userQuery, rawSources, uiImages, mode, temperature, maxTokens, controller, encoder }: { model: string; systemMessages: any[]; userQuery: string; rawSources: any[]; uiImages?: any[]; mode?: string; temperature: number; maxTokens?: number; controller: ReadableStreamDefaultController; encoder: { encode: (s: string) => Uint8Array }; }) {
  const sourcesList = rawSources
    .slice(0, 6)
    .map((s: any, i: number) => `Source [${i + 1}] ${s.title}\nURL: ${s.url}\n${(typeof s.content === 'string' ? s.content : (s.description || '')).slice(0, 800)}`)
    .join('\n\n');
  const imagesList = (uiImages ?? [])
    .slice(0, 6)
    .map((img: any, i: number) => `Image [${i + 1}] ${img.title || 'Image'}\nURL: ${img.url}${img.source ? `\nSource: ${img.source}` : ''}`)
    .join('\n\n');
  const phase2 = streamText({
    model: openrouter(model),
    messages: [
      ...systemMessages,
      { role: 'user', content: `Question: ${userQuery}\n\nUse ONLY the following sources to answer. Prioritize the scraped page text under each source when available; treat titles/snippets as secondary. Do NOT include inline [n] citation markers inside sentences. Instead, add a short References section at the end with numbered items (title – URL). ${mode === 'aipedia' ? 'If helpful, seamlessly integrate the images into the narrative (e.g., "see image of X") but do not output raw HTML or markdown image tags.' : ''} Keep the answer concise.\n\n${sourcesList}${imagesList && mode === 'aipedia' ? `\n\nRelevant images (for context, not for listing verbatim):\n\n${imagesList}` : ''}` },
    ],
    temperature,
    ...(maxTokens ? { maxOutputTokens: maxTokens } : {}),
  });
  for await (const part of phase2.fullStream) {
    if (part.type === 'text-delta') {
      const sseMessage = `data: ${JSON.stringify({ type: 'content', content: part.text })}\n\n`;
      controller.enqueue(encoder.encode(sseMessage));
    }
  }
}

// (no extra phases)
async function toolPhaseCollectImages({ model, systemMessages, messages, temperature, tools }: { model: string; systemMessages: any[]; messages: any[]; temperature: number; tools: any; }) {
  const phase = streamText({
    model: openrouter(model),
    messages: [...systemMessages, ...messages],
    temperature,
    maxOutputTokens: 64,
    tools: { braveImageSearch: (tools as any).braveImageSearch },
    toolChoice: 'required',
  } as any);
  const uiImages: any[] = [];
  for await (const part of (phase as any).fullStream) {
    if (part.type === 'tool-result' && part.toolName === 'braveImageSearch') {
      const images = (part.output as any)?.images;
      if (Array.isArray(images)) {
        const mapped = images.map((image: any, index: number) => ({
          id: `image-${Date.now()}-${index}`,
          title: image.title || 'Image',
          url: image.url || '',
          source: image.source || '',
          type: 'image',
        }));
        uiImages.push(...mapped);
      }
    }
  }
  return uiImages;
}



