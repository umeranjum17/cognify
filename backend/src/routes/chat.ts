import express from 'express';
import { requireAuth, AuthRequest } from '../middleware/auth.js';
import { MODE_CONFIGS, MODEL_DEFAULTS, CACHE_CONFIG, QUOTA_CONFIG } from '../config/config-data.js';
import { streamText, generateText, generateObject, tool } from 'ai';
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

// Lightweight model capabilities cache (supportsImages) based on OpenRouter metadata
let _modelCapsCache: { fetchedAt: number; supportsImages: Record<string, boolean> } | null = null;
async function supportsImages(modelId: string): Promise<boolean> {
  const ttlMs = (CACHE_CONFIG.modelsCacheDuration || 3600) * 1000;
  const now = Date.now();
  // Refresh cache if missing or expired
  if (!_modelCapsCache || now - _modelCapsCache.fetchedAt > ttlMs) {
    try {
      const r = await fetch('https://openrouter.ai/api/v1/models', {
        headers: { 'Content-Type': 'application/json' },
      });
      if (r.ok) {
        const json: any = await r.json();
        const map: Record<string, boolean> = {};
        const arr: any[] = Array.isArray(json?.data) ? json.data : [];
        for (const m of arr) {
          const id = m?.id;
          if (!id) continue;
          // Check input_modalities array for image support
          const inputModalities: string[] = m?.architecture?.input_modalities || [];
          map[id] = Array.isArray(inputModalities) && inputModalities.includes('image');
        }
        _modelCapsCache = { fetchedAt: now, supportsImages: map };
      }
    } catch (_) {
      // On failure, keep old cache if any; default to false
    }
  }
  return Boolean(_modelCapsCache?.supportsImages?.[modelId]);
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

// Extract media type from data URL
function extractMediaType(dataUrl: string): string | undefined {
  try {
    if (dataUrl.startsWith('data:')) {
      const match = dataUrl.match(/^data:([^;,]+)/);
      return match?.[1];
    }
  } catch (e) {
    console.warn('[chat] Failed to extract media type from data URL');
  }
  return undefined;
}

// Validate base64 data URL
function validateDataUrl(dataUrl: string): { valid: boolean; error?: string } {
  try {
    if (!dataUrl.startsWith('data:')) {
      return { valid: false, error: 'Not a data URL' };
    }

    const [header, data] = dataUrl.split(',');
    if (!header || !data) {
      return { valid: false, error: 'Invalid data URL format' };
    }

    // Check if it's an image
    if (!header.toLowerCase().includes('image/')) {
      return { valid: false, error: 'Not an image data URL' };
    }

    // Validate base64 encoding
    if (header.includes('base64')) {
      // Basic base64 validation
      if (!/^[A-Za-z0-9+/]*={0,2}$/.test(data)) {
        return { valid: false, error: 'Invalid base64 encoding' };
      }
    }

    // Check size (approximate, 1 base64 char ≈ 0.75 bytes)
    const sizeBytes = data.length * 0.75;
    const MAX_SIZE = 20 * 1024 * 1024; // 20MB
    if (sizeBytes > MAX_SIZE) {
      return { valid: false, error: 'Image too large (>20MB)' };
    }

    return { valid: true };
  } catch (e) {
    return { valid: false, error: 'Validation error' };
  }
}

// Validate and select appropriate model based on content
async function validateAndSelectModel(
  requestedModel: string,
  messages: any[]
): Promise<string> {
  // Check if any message contains images
  const hasImages = messages.some((msg: any) => {
    if (Array.isArray(msg.content)) {
      return msg.content.some((part: any) =>
        part.type === 'image_url' || part.type === 'image'
      );
    }
    return false;
  });

  if (!hasImages) {
    return requestedModel; // No images, use requested model
  }

  // Check if requested model supports images
  try {
    const canUseImages = await supportsImages(requestedModel);
    if (canUseImages) {
      console.log(`[chat] Model ${requestedModel} supports images`);
      return requestedModel;
    } else {
      console.log(`[chat] Model ${requestedModel} lacks image support; switching to ${MODEL_DEFAULTS.CLOUD_FALLBACK}`);
      return MODEL_DEFAULTS.CLOUD_FALLBACK;
    }
  } catch (e) {
    console.warn('[chat] supportsImages check failed; using fallback model for safety');
    return MODEL_DEFAULTS.CLOUD_FALLBACK;
  }
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
    'CRITICAL: Keep reasoning field under 50 words. Be concise and avoid repetition.',
    'IMPORTANT: You must respond with ONLY valid JSON. No additional text, explanations, or markdown formatting.',
    'Return JSON with this EXACT structure:',
    '{',
    '  "analysis": "Brief analysis of user need",',
    '  "tools": [',
    '    { "name": "brave_search_enhanced",',
    `      "input": { "query": "search terms", "count": ${searchLimits.maxResults} },`,
    '      "order": 1,',
    '      "reasoning": "Short reason for this search"',
    '    }',
    '  ],',
    '  "estimatedSteps": 2,',
    '  "complexity": "low"',
    '}',
    '',
    'JSON Response:'
  ].join('\n');
}

function buildSourcesContext(params: { sources: any[]; images: any[]; }): string {
  const { sources, images } = params;
  
  let context = 'Use the following sources to inform your response:\n\n';
  
  if (sources.length > 0) {
    context += sources
      .map((s: any, i: number) => `[${i + 1}] ${s.title}\n${s.url}\n${s.content || s.description}`)
      .join('\n\n');
  }
  
  if (images.length > 0) {
    context += '\n\nAvailable images:\n' + images
      .map((img: any, i: number) => `![${img.title}](${img.url})`)
      .join('\n');
  }
  
  return context;
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
    frequencyPenalty: 0.3,  // Discourage repeating tokens
    presencePenalty: 0.1,   // Encourage topic diversity
    ...(options.maxTokens !== undefined ? { maxOutputTokens: options.maxTokens } : {}),
  });
  
  try {
    // Use textStream with proper error handling
    for await (const chunk of result.textStream) {
      options.onTextDelta(chunk);
    }
    console.log('[stream] Stream completed successfully');
  } catch (error: any) {
    console.error('[stream] Stream error:', error);
    
    // If it's a validation error, try with fullStream as fallback
    if (error?.message?.includes('Type validation failed') || 
        error?.message?.includes('invalid_union') ||
        error?.message?.includes('logprobs')) {
      console.warn('[stream] Validation error, trying fullStream fallback');
      
      try {
        for await (const part of result.fullStream) {
          if ((part as any).type === 'text-delta') {
            options.onTextDelta((part as any).text as string);
          } else if ((part as any).type === 'finish') {
            console.log('[stream] Fallback stream completed');
            break;
          }
        }
        return;
      } catch (fallbackError) {
        console.error('[stream] Fallback also failed:', fallbackError);
        throw error;
      }
    }
    
    throw error;
  }
}

async function completeJSONWithAiSDK(options: { model: string; prompt: string; temperature?: number; maxTokens?: number; }): Promise<any> {
  const planSchema = z.object({
    analysis: z.string().min(1).max(200).optional().default(''),
    tools: z.array(z.object({
      name: z.enum(['brave_search', 'brave_search_enhanced', 'image_search']).optional().default('brave_search'),
      input: z.object({
        query: z.string().min(1).max(100).optional(),
        count: z.number().int().positive().max(10).optional(),
      }).optional().default({}),
      order: z.number().int().min(1).max(10).optional().default(1),
      reasoning: z.string().max(100).optional().default(''),
    })).max(3).default([]),
    estimatedSteps: z.number().int().min(1).max(10).optional().default(2),
    complexity: z.enum(['low', 'medium']).optional().default('low'),
  });

  try {
    const result = await generateObject({
      model: getOpenRouterProvider()(options.model),
      temperature: options.temperature ?? 0.3,
      ...(options.maxTokens ? { maxOutputTokens: options.maxTokens } : {}),
      prompt: options.prompt,
      schema: planSchema as any,
    });
    
    // Validate the result before returning
    if (!result || !result.object) {
      console.warn('[planning] generateObject returned empty result');
      return {};
    }
    
    // Log successful planning for debugging
    console.log('[planning] Successfully generated plan:', JSON.stringify(result.object, null, 2));
    return result.object;
  } catch (error: any) {
    console.error('[planning] generateObject failed:', {
      error: error.message,
      model: options.model,
      promptLength: options.prompt.length,
      stack: error.stack
    });
    
    // Try to extract any partial response for debugging
    if (error.cause) {
      console.error('[planning] Error cause:', error.cause);
    }
    
    throw new Error(`No object generated: could not parse the response. ${error.message}`);
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
    // Prioritize user-selected model over mode default
    let model = (typeof rawModel === 'string' ? rawModel : null) || (modeConfig?.model as string) || MODEL_DEFAULTS.CHAT_MODE;
    
    // Debug logging for model selection
    console.log(`[chat] Mode: ${mode}, RawModel: ${rawModel}, SelectedModel: ${model}, ModeConfigModel: ${modeConfig?.model}`);
    
    const userQuery = getLastUserMessageText(messages);
    
    // CRITICAL: Apply hard global maximum token limit
    const globalMaxTokens = QUOTA_CONFIG.globalMaxTokens;
    
    // Apply safety limit from mode config
    const modeMaxTokens = modeConfig?.maxTokens as number | undefined;
    let effectiveMaxTokens: number | undefined;
    
    if (typeof maxTokens === 'number') {
      // User explicitly provided maxTokens - apply mode limit AND global limit as caps
      effectiveMaxTokens = Math.min(
        modeMaxTokens || Infinity,
        maxTokens,
        globalMaxTokens
      );
    } else if (modeMaxTokens) {
      // Apply mode's default safety limit, capped by global max
      effectiveMaxTokens = Math.min(modeMaxTokens, globalMaxTokens);
    } else {
      // No mode limit, but still enforce global max
      effectiveMaxTokens = globalMaxTokens;
    }
    
    // EXTRA PROTECTION: Reasoning models (like deepseek-r1) can generate massive outputs
    // Apply an additional safety cap specifically for reasoning models
    const isReasoningModel = model.includes('r1') || model.includes('reasoning') || model.includes('deepseek-r1');
    if (isReasoningModel && effectiveMaxTokens && effectiveMaxTokens > 15000) {
      console.warn(`⚠️ [SAFETY] Reasoning model detected (${model}), applying extra tight limit (15k tokens, 10x cost)`);
      effectiveMaxTokens = 15000; // Very strict limit for reasoning models
    }
    
    // Log token limits for debugging (and alert if limit was reduced)
    if (maxTokens && maxTokens > effectiveMaxTokens) {
      console.warn(`⚠️ [SAFETY] User requested ${maxTokens} tokens but limited to ${effectiveMaxTokens} by safety guardrails`);
    }
    console.log(`[chat] Token limit enforced: ${effectiveMaxTokens} (global: ${globalMaxTokens}, mode max: ${modeMaxTokens}, requested: ${maxTokens}, isReasoningModel: ${isReasoningModel})`);

    // Pre-deduct credits using server-side calculation
    const requestId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    const internalBase = getInternalBaseUrl(req);
    let didConsume = false;
    try {
      const t0 = Date.now();
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
      // Disable proxy buffering where applicable (e.g., Nginx)
      'X-Accel-Buffering': 'no',
    });
    // Ensure headers are flushed so the client can start receiving events immediately
    try { (res as any).flushHeaders?.(); } catch {}

    const sendEvent = (obj: any) => {
      res.write(`data: ${JSON.stringify(obj)}\n\n`);
    };

    const finish = () => {
      try {
        timings.totalMs = Date.now() - reqStartMs;
        const totalSearchMs = Array.isArray(timings.searches) ? timings.searches.reduce((acc: number, s: any) => acc + (s.ms || 0), 0) : 0;
        const totalImgMs = Array.isArray(timings.imagesSearch) ? timings.imagesSearch.reduce((acc: number, s: any) => acc + (s.ms || 0), 0) : 0;
        console.log(`[chat] id=${timings.requestId} mode=${timings.mode} model=${timings.model} auth=${timings.authVerifyMs ?? 0}ms credits=${timings.creditsConsumeMs ?? 0}ms plan=${timings.planningMs ?? 0}ms search=${totalSearchMs}ms img=${totalImgMs}ms writer_ttfb=${timings.writerTtfbMs ?? 0}ms writer=${timings.writerTotalMs ?? 0}ms total=${timings.totalMs ?? 0}ms`);
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
      let fullText = '';
      let collectedSources: any[] = [];
      let collectedImages: any[] = [];

      if (isTwoPhase) {
        // Phase 1 (planning): use agent planning prompt to create tool plan
        const enabledTools = ['brave_search_enhanced', 'brave_search'];
        if (mode === 'aipedia') enabledTools.push('image_search');
        const searchCount = mode === 'aipedia' ? 6 : 5;
        const planningPrompt = createPlanningPromptFromAgents(userQuery || '', mode, enabledTools);
        let plan: any = {};
        try {
          const t0 = Date.now();
          plan = await completeJSONWithAiSDK({ model, prompt: planningPrompt, temperature: 0.1, maxTokens: 500 });
          timings.planningMs = Date.now() - t0;
          console.log(`[planning] Planning completed in ${timings.planningMs}ms`);
        } catch (e) {
          console.warn('Planning phase failed, falling back to direct search:', (e as Error).message);
          // Set a default plan structure for fallback
          plan = {
            analysis: 'Planning failed, using direct search approach',
            tools: [{
              name: 'brave_search_enhanced',
              input: { query: userQuery, count: searchCount },
              order: 1,
              reasoning: 'Fallback search due to planning failure'
            }],
            estimatedSteps: 1,
            complexity: 'low'
          };
        }
        const tools: any[] = Array.isArray(plan?.tools) ? plan.tools : [];

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
      const writerStart = Date.now();

      // Validate model early (check if it supports images if needed)
      const recentMessages = messages.slice(-15);  // Industry standard: 10-15 turns
      model = await validateAndSelectModel(model, recentMessages);
      timings.model = model; // Update timing with final model

      // Build conversation messages
      const conversationMessages = [];

      // Add system message
      const systemMessage = mode === 'chat'
        ? 'You are a helpful AI assistant. Be conversational, natural, and concise. Build naturally on the conversation without repeating what you just said.'
        : 'You are a helpful AI assistant. When sources are provided, use them to give fresh, specific information. Be conversational and concise, building naturally on previous responses without repetition.';
      conversationMessages.push({ role: 'system', content: systemMessage });

      // Inject sources for search/aipedia modes
      if (isTwoPhase && (collectedSources.length > 0 || collectedImages.length > 0)) {
        const sourcesContext = buildSourcesContext({ sources: collectedSources, images: collectedImages });
        conversationMessages.push({ role: 'system', content: sourcesContext });
      }

      // Add conversation history with simplified multimodal transformation
      for (const msg of recentMessages) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          if (typeof msg.content === 'string') {
            // Simple text content
            if (msg.content.trim()) {
              conversationMessages.push({ role: msg.role, content: msg.content.trim() });
            }
          } else if (Array.isArray(msg.content)) {
            // Multimodal content - transform to AI SDK format
            const multimodalContent = msg.content
              .map((part: any) => {
                // Handle text parts
                if (part.type === 'text' && part.text) {
                  return { type: 'text', text: part.text };
                }

                // Handle image_url parts (OpenAI format from frontend)
                if (part.type === 'image_url') {
                  const imageUrl = part.image_url?.url || part.image_url;
                  if (imageUrl && typeof imageUrl === 'string') {
                    // Optional validation for data URLs
                    if (imageUrl.startsWith('data:')) {
                      const validation = validateDataUrl(imageUrl);
                      if (!validation.valid) {
                        console.warn(`[chat] Invalid image data URL: ${validation.error}`);
                        return null; // Skip this image
                      }
                    }

                    // AI SDK expects simple format: type 'image' with image property
                    return {
                      type: 'image',
                      image: imageUrl,
                      // Optional: extract mediaType from data URL
                      ...(imageUrl.startsWith('data:') && {
                        mediaType: extractMediaType(imageUrl)
                      })
                    };
                  }
                }

                // Handle image parts (already in AI SDK format)
                if (part.type === 'image' && part.image) {
                  return { type: 'image', image: part.image };
                }

                // Drop invalid parts
                return null;
              })
              .filter((part: any) => part !== null);

            if (multimodalContent.length > 0) {
              conversationMessages.push({ role: msg.role, content: multimodalContent });
            }
          }
        }
      }
      
      console.log(`[chat] Using ${conversationMessages.length} messages for context (including system${isTwoPhase ? ' and sources' : ''})`);
      
      // Log multimodal content for debugging
      const multimodalMessages = conversationMessages.filter(msg => Array.isArray(msg.content));
      if (multimodalMessages.length > 0) {
        console.log(`[chat] Found ${multimodalMessages.length} multimodal messages`);
        multimodalMessages.forEach((msg, idx) => {
          const imageCount = msg.content.filter((part: any) => part.type === 'image').length;
          const textCount = msg.content.filter((part: any) => part.type === 'text').length;
          console.log(`[chat] Message ${idx}: ${textCount} text parts, ${imageCount} image parts`);
        });
      }
      
      await streamWithAiSDK({
        model,
        temperature: typeof temperature === 'number' ? temperature : (modeConfig?.temperature ?? 0.7),
        maxTokens: effectiveMaxTokens,
        messages: conversationMessages,
        onTextDelta: (text) => {
          if (!firstChunkSent) {
            firstChunkSent = true;
            timings.writerTtfbMs = Date.now() - writerStart;
            timings.ttfbTotalMs = Date.now() - reqStartMs;
          }
          fullText += text;
          sendEvent({ type: 'content', content: text });
        },
      });
      timings.writerTotalMs = Date.now() - writerStart;

      // Emit a final completion event so frontend can finalize the message cleanly
      sendEvent({
        type: 'complete',
        message: fullText,
        sources: collectedSources,
        images: collectedImages,
        model,
        llmUsed: model,
        done: true,
      });

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
