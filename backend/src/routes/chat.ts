import express from 'express';
import { requireAuth, AuthRequest } from '../middleware/auth.js';
import { MODE_CONFIGS } from '../config/config-data.js';
import { streamText, generateText, tool } from 'ai';
import { createOpenRouter } from '@openrouter/ai-sdk-provider';
import { z } from 'zod';

export const chatRouter = express.Router();
// Resolve an internal base URL for server-to-server calls within the same process
function getInternalBaseUrl(req: express.Request): string {
  const envBase = process.env.INTERNAL_BASE_URL;
  if (envBase && typeof envBase === 'string' && envBase.trim().length > 0) return envBase.trim();
  const host = req.get('host') || '';
  const port = host.includes(':') ? host.split(':')[1] : (process.env.PORT || '3000');
  const proto = process.env.INTERNAL_PROTOCOL || 'http';
  return `${proto}://127.0.0.1:${port}`;
}

// Create the OpenRouter provider lazily so env vars are read after dotenv is loaded
function getOpenRouterProvider() {
  const apiKey = process.env.OPENROUTER_API_KEY ?? '';
  return createOpenRouter({
    apiKey,
    headers: {
      'HTTP-Referer': 'https://cognify.app',
      'X-Title': 'Cognify Backend',
    },
  });
}

// Helpers
function getLastUserMessageText(messages: any[]): string {
  const reversed = [...messages].reverse();
  for (const m of reversed) {
    if (m && typeof m === 'object' && m.role === 'user') {
      const content = m.content;
      if (typeof content === 'string') return content;
      if (Array.isArray(content)) {
        const textPart = content.find((p: any) => p?.type === 'text' && typeof p.text === 'string');
        if (textPart) return textPart.text;
      }
    }
  }
  return '';
}

async function braveWebSearch(query: string, count = 5): Promise<{ sources: any[] }> {
  const apiKey = process.env.BRAVE_API_KEY || '';
  if (!apiKey) return { sources: [] };
  const url = new URL('https://api.search.brave.com/res/v1/web/search');
  url.searchParams.set('q', query);
  url.searchParams.set('count', String(count));
  url.searchParams.set('safesearch', 'strict');
  const r = await fetch(url, { headers: { Accept: 'application/json', 'X-Subscription-Token': apiKey } });
  if (!r.ok) return { sources: [] };
  const json: any = await r.json().catch(() => ({}));
  const results: any[] = (json?.web?.results ?? []).map((it: any) => ({
    title: it?.title ?? it?.url ?? 'Untitled',
    url: it?.url ?? '',
    description: it?.description ?? it?.snippet ?? '',
  }));
  // Best-effort content enrichment
  const max = Math.min(results.length, count);
  const enriched = await Promise.all(results.slice(0, max).map(async (r) => ({
    ...r,
    content: await fetchPageTextSafe(r.url),
  })));
  return { sources: enriched };
}

async function braveImageSearch(query: string, count = 4): Promise<{ images: any[] }> {
  const apiKey = process.env.BRAVE_API_KEY || '';
  if (!apiKey) return { images: [] };
  const url = new URL('https://api.search.brave.com/res/v1/images/search');
  url.searchParams.set('q', query);
  url.searchParams.set('count', String(count));
  url.searchParams.set('safesearch', 'strict');
  const r = await fetch(url, { headers: { Accept: 'application/json', 'X-Subscription-Token': apiKey } });
  if (!r.ok) return { images: [] };
  const json: any = await r.json().catch(() => ({}));
  const imgs = (json?.results ?? json?.images ?? json?.items ?? []) as any[];
  const images = imgs.map((it) => ({
    title: it?.title ?? it?.source ?? 'Image',
    url: it?.properties?.url ?? it?.thumbnail?.src ?? it?.url ?? '',
    source: it?.source ?? it?.host_page_display_url ?? '',
  }));
  return { images };
}

async function fetchPageTextSafe(urlStr: string): Promise<string> {
  try {
    if (!urlStr) return '';
    const res = await fetch(urlStr, { headers: { Accept: 'text/html,application/xhtml+xml' } });
    if (!res.ok) return '';
    const html = await res.text();
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
    let mainHtml = pickSection(html)
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
      .replace(/<svg[\s\S]*?<\/svg>/gi, ' ')
      .replace(/<nav[\s\S]*?<\/nav>/gi, ' ')
      .replace(/<aside[\s\S]*?<\/aside>/gi, ' ')
      .replace(/<footer[\s\S]*?<\/footer>/gi, ' ')
      .replace(/<header[\s\S]*?<\/header>/gi, ' ')
      .replace(/<div[^>]*(id|class)=["'][^"']*(sidebar|menu|nav|footer|header|advert|ad-|ads|promo|cookie|banner)[^"']*["'][\s\S]*?<\/div>/gi, ' ')
      .replace(/<\s*br\s*\/??\s*>/gi, '\n')
      .replace(/<\/(p|h[1-6]|li|section|article|main)>/gi, '\n');
    let text = mainHtml.replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'");
    text = text.replace(/\s+/g, ' ').trim();
    const MAX_CHARS = 1800;
    return text.length > MAX_CHARS ? text.slice(0, MAX_CHARS) : text;
  } catch {
    return '';
  }
}

function createPlanningPromptFromAgents(query: string, mode: string, enabledTools: string[]): string {
  // Planning is only used for 'search' and 'aipedia'. Build a concise tool plan aligned with server behavior.
  const toolDescriptions = enabledTools.map((t) => `- ${t}: enabled`).join('\n');
  const searchLimits = mode === 'aipedia' ? { maxResults: 6 } : { maxResults: 5 };
  const critical = [
    'CRITICAL INSTRUCTIONS:',
    '- You MUST perform a web search before writing any answer.',
    '- Do NOT answer from prior knowledge; always base on search results.',
    "- Prefer scraped page 'content' when available; titles/snippets are secondary.",
  ].join('\n');
  const goal = mode === 'aipedia'
    ? 'Create 2–3 focused searches to comprehensively cover the topic and include an image search if helpful.'
    : 'Create 1–2 focused searches to quickly answer the question.';

  return [
    `You are a planning agent creating a tool execution plan.`,
    `Mode: ${mode}`,
    `User Query: ${query}`,
    '',
    'Available Tools:',
    toolDescriptions,
    '',
    critical,
    '',
    goal,
    '',
    'Return JSON with EXACT schema:',
    '{',
    '  "analysis": "Brief analysis of user need",',
    '  "tools": [',
    '    { "name": "brave_search" | "brave_search_enhanced",',
    `      "input": { "query": "search terms", "count": ${searchLimits.maxResults} },`,
    '      "order": 1,',
    '      "reasoning": "why this search"',
    '    },',
    '    { "name": "image_search" (optional),',
    '      "input": { "query": "image search terms", "count": 4 },',
    '      "order": 2,',
    '      "reasoning": "why images help"',
    '    }',
    '  ],',
    '  "estimatedSteps": 2,',
    '  "complexity": "low|medium"',
    '}',
  ].join('\n');
}

function buildWriterPromptFromAgents(params: {
  originalQuery: string;
  mode: string;
  sources: any[];
  images: any[];
}): string {
  const { originalQuery, mode, sources, images } = params;
  const sourcesSection = sources.length > 0 ? `\n**SOURCES WITH CONTENT:**\n\n${sources
    .map((s: any, i: number) => `Source ${i + 1}: ${s.title || 'Untitled'}\nURL: ${s.url || ''}\nCONTENT: ${(s.content || s.description || '').slice(0, 1000)}`)
    .join('\n\n')}` : '';
  const imagesSection = images.length > 0 ? `\n**AVAILABLE IMAGES FOR MARKDOWN INCLUSION:**\n\n${images
    .map((img: any, i: number) => `${i + 1}. **${img.title || 'Image'}**\n   MARKDOWN: ![${img.title || 'Image'}](${img.url})\n   DESCRIPTION: ${img.description || ''}\n   CONTEXT: ${img.source || ''}`)
    .join('\n\n')}` : '';
  const modeGuidance = mode === 'aipedia'
    ? '\nProduce a structured overview: Summary, Key Facts (bullets), Main Sections (with headings).'
    : '';
  const responseGuidelines = `**RESPONSE EXCELLENCE GUIDELINES:** Use bold, lists, code blocks; be comprehensive but concise; do not include a Sources section in the text (UI shows sources).`;
  return `You are a helpful, professional AI assistant.\n\n**USER QUERY:** "${originalQuery}"\n**MODE:** ${mode}${modeGuidance}${sourcesSection}${imagesSection}\n\n${responseGuidelines}\n\nWrite your response now:`;
}

async function streamWithAiSDK(options: {
  model: string;
  messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string | any[] }>;
  temperature?: number;
  maxTokens?: number;
  onTextDelta: (text: string) => void;
}): Promise<void> {
  const result = streamText({
    model: getOpenRouterProvider()(options.model),
    messages: options.messages as any,
    temperature: options.temperature ?? 0.7,
    ...(options.maxTokens ? { maxOutputTokens: options.maxTokens } : {}),
  });
  for await (const part of result.fullStream) {
    if ((part as any).type === 'text-delta') {
      options.onTextDelta((part as any).text as string);
    }
  }
}

async function completeJSONWithAiSDK(options: { model: string; prompt: string; temperature?: number; maxTokens?: number; }): Promise<any> {
  const result = await generateText({
    model: getOpenRouterProvider()(options.model),
    temperature: options.temperature ?? 0.3,
    ...(options.maxTokens ? { maxOutputTokens: options.maxTokens } : {}),
    prompt: options.prompt,
  });
  let cleaned = (result.text || '').trim();
  if (cleaned.startsWith('```json')) cleaned = cleaned.slice(7);
  if (cleaned.startsWith('```')) cleaned = cleaned.slice(3);
  if (cleaned.endsWith('```')) cleaned = cleaned.slice(0, -3);
  cleaned = cleaned.trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const m = cleaned.match(/\{[\s\S]*\}/);
    if (m) {
      try { return JSON.parse(m[0]); } catch {}
    }
    return {};
  }
}

// POST /api/chat - Unified chat endpoint with SSE streaming
chatRouter.post('/', requireAuth, async (req: AuthRequest, res) => {
  const reqStartMs = Date.now();
  const timings: any = { requestStartMs: reqStartMs };
  const authTiming = (req as any)._timing?.authVerifyMs;
  if (typeof authTiming === 'number') timings.authVerifyMs = authTiming;
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as const;

  try {
    const { messages, mode: rawMode, model: rawModel, temperature, maxTokens } = req.body || {};
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'Missing or invalid messages array' });
      return;
    }

    const mode = typeof rawMode === 'string' ? rawMode : 'chat';
    const modeConfig: any = (MODE_CONFIGS as any)[mode] || (MODE_CONFIGS as any).chat;
    const model = (modeConfig?.model as string) || (typeof rawModel === 'string' ? rawModel : 'google/gemini-2.5-flash-lite');
    const userQuery = getLastUserMessageText(messages);
    const effectiveMaxTokens = typeof maxTokens === 'number' ? maxTokens : mode === 'aipedia' ? 900 : 700;

    // Pre-deduct credits using server-side calculation
    const requestId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    let didConsume = false;
    try {
      const t0 = Date.now();
      const internalBase = getInternalBaseUrl(req);
      const consumeRes = await fetch(`${internalBase}/api/credits/consume`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: String(req.headers.authorization || '') },
        body: JSON.stringify({ modelId: model, mode, requestId }),
      });
      timings.creditsConsumeMs = Date.now() - t0;
      if (consumeRes.status === 409) {
        res.status(409).json({ error: 'INSUFFICIENT_CREDITS' });
        return;
      }
      if (!consumeRes.ok) throw new Error(`Credit consume failed: ${consumeRes.status}`);
      didConsume = true;
    } catch (e) {
      console.error('Credit consumption error:', e);
      res.status(500).json({ error: 'Credit check failed' });
      return;
    }

    // SSE setup
    res.writeHead(200, {
      ...corsHeaders,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
      // Enable Server-Timing trailer at end of stream for DevTools visibility
      Trailer: 'Server-Timing',
    });

    const sendEvent = (obj: any) => {
      res.write(`data: ${JSON.stringify(obj)}\n\n`);
    };

    const finish = () => {
      try {
        timings.totalMs = Date.now() - reqStartMs;
        sendEvent({ type: 'timing', timing: timings });
        // Structured log line for profiling aggregation
        console.log('[chat-timing]', JSON.stringify({ requestId: timings.requestId, mode: timings.mode, model: timings.model, ...timings }));
        // Emit Server-Timing as trailer so browsers can show timings
        const serverTimingParts: string[] = [];
        if (typeof timings.authVerifyMs === 'number') serverTimingParts.push(`auth;dur=${timings.authVerifyMs}`);
        if (typeof timings.creditsConsumeMs === 'number') serverTimingParts.push(`credits;dur=${timings.creditsConsumeMs}`);
        if (typeof timings.planningMs === 'number') serverTimingParts.push(`planning;dur=${timings.planningMs}`);
        if (Array.isArray(timings.searches)) {
          const totalSearchMs = timings.searches.reduce((acc: number, s: any) => acc + (s.ms || 0), 0);
          serverTimingParts.push(`search;dur=${totalSearchMs}`);
        }
        if (Array.isArray(timings.imagesSearch) && timings.imagesSearch.length > 0) {
          const totalImgMs = timings.imagesSearch.reduce((acc: number, s: any) => acc + (s.ms || 0), 0);
          serverTimingParts.push(`imgsearch;dur=${totalImgMs}`);
        }
        if (typeof timings.writerTtfbMs === 'number') serverTimingParts.push(`writer_ttfb;dur=${timings.writerTtfbMs}`);
        if (typeof timings.writerTotalMs === 'number') serverTimingParts.push(`writer;dur=${timings.writerTotalMs}`);
        if (typeof timings.totalMs === 'number') serverTimingParts.push(`total;dur=${timings.totalMs}`);
        const trailerValue = serverTimingParts.join(', ');
        if (trailerValue) {
          (res as any).addTrailers?.({ 'Server-Timing': trailerValue });
        }
      } catch {}
      res.write('data: [DONE]\n\n');
      res.end();
    };

    try {
      const isTwoPhase = mode === 'search' || mode === 'aipedia';
      timings.requestId = requestId;
      timings.mode = mode;
      timings.model = model;
      timings.searches = [] as any[];
      timings.imagesSearch = [] as any[];
      let firstChunkSent = false;
      let collectedSources: any[] = [];
      let collectedImages: any[] = [];

      if (isTwoPhase) {
        // Phase 1 (planning): use agent planning prompt to create tool plan
        const enabledTools = ['brave_search_enhanced', 'brave_search'];
        if (mode === 'aipedia') enabledTools.push('image_search');
        const planningPrompt = createPlanningPromptFromAgents(userQuery || '', mode, enabledTools);
        let plan: any = {};
        try {
          const t0 = Date.now();
          plan = await completeJSONWithAiSDK({ model, prompt: planningPrompt, temperature: 0.3, maxTokens: 1200 });
          timings.planningMs = Date.now() - t0;
        } catch (e) {
          console.warn('Planning phase failed, falling back to direct search:', (e as Error).message);
        }
        const tools: any[] = Array.isArray(plan?.tools) ? plan.tools : [];
        const searchCount = mode === 'aipedia' ? 6 : 5;

        // Execute planned tools (search/image)
        for (const t of tools) {
          const name = String(t?.name || '').toLowerCase();
          const input = t?.input || {};
          if ((name === 'brave_search' || name === 'brave_search_enhanced') && (input?.query || userQuery)) {
            const q = String(input.query || userQuery);
            const t0 = Date.now();
            const { sources } = await braveWebSearch(q, Number(input.count ?? searchCount));
            const ms = Date.now() - t0;
            const mapped = (sources || []).map((s: any, idx: number) => ({
              id: `search-${Date.now()}-${idx}`,
              title: s.title || 'Untitled',
              url: s.url || '',
              description: s.description || '',
              content: s.content || '',
              type: 'web',
            }));
            if (mapped.length > 0) {
              collectedSources.push(...mapped);
              sendEvent({ type: 'sourcesReady', sources: mapped });
            }
            timings.searches.push({ query: q, results: mapped.length, ms });
          } else if (name === 'image_search' && (input?.query || userQuery)) {
            const q = String(input.query || userQuery);
            const t0 = Date.now();
            const { images } = await braveImageSearch(q, Number(input.count ?? 4));
            const ms = Date.now() - t0;
            const mapped = (images || []).map((img: any, idx: number) => ({
              id: `image-${Date.now()}-${idx}`,
              title: img.title || 'Image',
              url: img.url || '',
              source: img.source || '',
              type: 'image',
            }));
            if (mapped.length > 0) {
              collectedImages.push(...mapped);
              sendEvent({ type: 'imagesReady', images: mapped });
            }
            timings.imagesSearch.push({ query: q, results: mapped.length, ms });
          }
        }

        // Fallback if plan produced nothing
        if (collectedSources.length === 0) {
          const t0 = Date.now();
          const { sources } = await braveWebSearch(userQuery || 'latest news', searchCount);
          const ms = Date.now() - t0;
          const mapped = (sources || []).map((s: any, idx: number) => ({
            id: `search-${Date.now()}-${idx}`,
            title: s.title || 'Untitled',
            url: s.url || '',
            description: s.description || '',
            content: s.content || '',
            type: 'web',
          }));
          if (mapped.length > 0) {
            collectedSources.push(...mapped);
            sendEvent({ type: 'sourcesReady', sources: mapped });
          }
          timings.searches.push({ query: userQuery || 'latest news', results: mapped.length, ms, fallback: true });
        }
        if ((mode === 'aipedia') && collectedImages.length === 0) {
          const t0 = Date.now();
          const { images } = await braveImageSearch(userQuery || 'topic', 4);
          const ms = Date.now() - t0;
          const mapped = (images || []).map((img: any, idx: number) => ({
            id: `image-${Date.now()}-${idx}`,
            title: img.title || 'Image',
            url: img.url || '',
            source: img.source || '',
            type: 'image',
          }));
          if (mapped.length > 0) {
            collectedImages.push(...mapped);
            sendEvent({ type: 'imagesReady', images: mapped });
          }
          timings.imagesSearch.push({ query: userQuery || 'topic', results: mapped.length, ms, fallback: true });
        }
      }

      // Phase 2 or single-phase: writer pass using agents prompt
      const writerPrompt = buildWriterPromptFromAgents({ originalQuery: userQuery, mode, sources: collectedSources, images: collectedImages });
      const writerStart = Date.now();
      await streamWithAiSDK({
        model,
        temperature: typeof temperature === 'number' ? temperature : (modeConfig?.temperature ?? 0.7),
        maxTokens: effectiveMaxTokens,
        messages: [
          { role: 'system', content: 'You are a helpful, professional AI assistant.' },
          { role: 'user', content: writerPrompt },
        ],
        onTextDelta: (text) => {
          if (!firstChunkSent) {
            firstChunkSent = true;
            timings.writerTtfbMs = Date.now() - writerStart;
            timings.ttfbTotalMs = Date.now() - reqStartMs;
          }
          sendEvent({ type: 'content', content: text });
        },
      });
      timings.writerTotalMs = Date.now() - writerStart;

      finish();
    } catch (err) {
      console.error('Chat streaming error:', err);
      // Attempt refund if we consumed credits
      if (didConsume) {
        const internalBase = getInternalBaseUrl(req);
        fetch(`${internalBase}/api/credits/refund`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: String(req.headers.authorization || '') },
          body: JSON.stringify({ requestId }),
        }).catch(() => {});
      }
      // Send error and end stream
      sendEvent({ type: 'error', error: 'Chat request failed' });
      finish();
    }
  } catch (error: any) {
    console.error('Chat error:', error);
    res.status(500).json({ error: 'Chat request failed', message: error.message });
  }
});

