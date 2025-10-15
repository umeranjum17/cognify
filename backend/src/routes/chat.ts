import express from 'express';
import { requireAuth, AuthRequest } from '../middleware/auth.js';
import { MODE_CONFIGS } from '../config/config-data.js';
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

function needsClarification(userMessage: string, conversationHistory: any[]): boolean {
  if (!userMessage || userMessage.length < 3) return true;
  
  // Check for vague references that need context
  const vaguePatterns = [
    /\b(this|that|it|them|those|these)\b/i,
    /\b(what|how|why|when|where)\s+(about|with|is|are|was|were)\s+(it|this|that)\b/i,
    /\b(explain|tell me about|what about)\s+(it|this|that)\b/i,
    /\b(more|additional|further)\s+(info|information|details)\b/i,
    /\b(continue|go on|keep going)\b/i,
    /\b(same|similar|like that)\b/i
  ];
  
  const hasVagueReference = vaguePatterns.some(pattern => pattern.test(userMessage));
  
  // If there's a vague reference and no recent context, clarification is needed
  if (hasVagueReference && conversationHistory.length === 0) {
    return true;
  }
  
  // Check if the message is too short and vague
  if (userMessage.length < 10 && /\b(what|how|why|when|where|explain|tell me)\b/i.test(userMessage)) {
    return true;
  }
  
  return false;
}

function extractContextTopics(conversationHistory: any[]): string[] {
  const topics: string[] = [];
  const recentMessages = conversationHistory.slice(-3); // Last 3 messages for topic extraction
  
  for (const msg of recentMessages) {
    if (msg.role === 'user' || msg.role === 'assistant') {
      let content = '';
      if (typeof msg.content === 'string') {
        content = msg.content;
      } else if (Array.isArray(msg.content)) {
        content = msg.content
          .filter((part: any) => part.type === 'text')
          .map((part: any) => part.text)
          .join(' ');
      }
      
      // Extract potential topics (simple keyword extraction)
      const words = content.toLowerCase().split(/\s+/);
      const topicWords = words.filter(word => 
        word.length > 4 && 
        !['this', 'that', 'with', 'from', 'they', 'them', 'their', 'there', 'where', 'when', 'what', 'how', 'why'].includes(word)
      );
      topics.push(...topicWords.slice(0, 3)); // Take first 3 potential topic words
    }
  }
  
  return [...new Set(topics)]; // Remove duplicates
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

function buildWriterPromptFromAgents(params: {
  originalQuery: string;
  mode: string;
  sources: any[];
  images: any[];
  conversationHistory?: any[];
}): string {
  const { originalQuery, mode, sources, images, conversationHistory = [] } = params;
  
  // Build conversation context section
  const conversationSection = conversationHistory.length > 0 ? `\n**CONVERSATION CONTEXT:**\n\n${conversationHistory
    .map((msg: any, i: number) => {
      const role = msg.role === 'user' ? 'User' : 'Assistant';
      let content = '';
      if (typeof msg.content === 'string') {
        content = msg.content;
      } else if (Array.isArray(msg.content)) {
        content = msg.content
          .filter((part: any) => part.type === 'text')
          .map((part: any) => part.text)
          .join(' ');
      }
      return `${role}: ${content}`;
    })
    .join('\n\n')}\n` : '';
  
  const sourcesSection = sources.length > 0 ? `\n**SOURCES WITH CONTENT:**\n\n${sources
    .map((s: any, i: number) => `Source ${i + 1}: ${s.title || 'Untitled'}\nURL: ${s.url || ''}\nCONTENT: ${(s.content || s.description || '').slice(0, 1000)}`)
    .join('\n\n')}` : '';
  const imagesSection = images.length > 0 ? `\n**AVAILABLE IMAGES FOR MARKDOWN INCLUSION:**\n\n${images
    .map((img: any, i: number) => `${i + 1}. **${img.title || 'Image'}**\n   MARKDOWN: ![${img.title || 'Image'}](${img.url})\n   DESCRIPTION: ${img.description || ''}\n   CONTEXT: ${img.source || ''}`)
    .join('\n\n')}` : '';
  const modeGuidance = mode === 'aipedia'
    ? '\nProduce a structured overview: Summary, Key Facts (bullets), Main Sections (with headings).'
    : '';
  const responseGuidelines = `**RESPONSE EXCELLENCE GUIDELINES:** 
- Use the conversation context to understand what the user is asking about
- If the current query seems vague or unclear, ask for clarification
- Maintain continuity with previous topics discussed
- Use bold, lists, code blocks; be comprehensive but concise
- Do not include a Sources section in the text (UI shows sources)`;
  
  return `You are a helpful, professional AI assistant with strong context awareness.

**CURRENT USER QUERY:** "${originalQuery}"
**MODE:** ${mode}${modeGuidance}${conversationSection}${sourcesSection}${imagesSection}

${responseGuidelines}

Write your response now:`;
}

// Check if a model is known to have compatibility issues
function isProblematicModel(model: string): boolean {
  const problematicModels = [
    'deepseek/deepseek-v3.2-exp',
    'deepseek/deepseek-v3',
    'deepseek/deepseek-coder-v2',
    'deepseek/deepseek-coder-v1.5',
  ];
  return problematicModels.some(problematic => model.includes(problematic));
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
  
  // For problematic models, use fullStream directly to avoid validation issues
  if (isProblematicModel(options.model)) {
    console.log(`[stream] Using fullStream for problematic model: ${options.model}`);
    try {
      for await (const part of result.fullStream) {
        if ((part as any).type === 'text-delta') {
          options.onTextDelta((part as any).text as string);
        }
        if ((part as any).type === 'finish') {
          console.log('[stream] Stream completed successfully');
          break;
        }
      }
      return;
    } catch (error) {
      console.error('[stream] fullStream error for problematic model:', error);
      throw error;
    }
  }
  
  // For other models, try textStream first
  try {
    for await (const chunk of result.textStream) {
      options.onTextDelta(chunk);
    }
    console.log('[stream] Stream completed successfully');
  } catch (error: any) {
    console.error('[stream] Stream error:', error);
    
    // Check if it's a type validation error from OpenRouter
    if (error?.message?.includes('Type validation failed') || 
        error?.message?.includes('invalid_union') ||
        error?.message?.includes('logprobs')) {
      console.warn('[stream] OpenRouter type validation error, attempting fallback with fullStream');
      
      try {
        // Fallback to fullStream with manual text extraction
        for await (const part of result.fullStream) {
          if ((part as any).type === 'text-delta') {
            options.onTextDelta((part as any).text as string);
          }
          if ((part as any).type === 'finish') {
            console.log('[stream] Fallback stream completed');
            break;
          }
        }
        return; // Success with fallback
      } catch (fallbackError) {
        console.error('[stream] Fallback also failed:', fallbackError);
        throw error; // Throw original error if fallback fails
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
    const model = (typeof rawModel === 'string' ? rawModel : null) || (modeConfig?.model as string) || 'google/gemini-2.5-flash-lite';
    
    // Debug logging for model selection
    console.log(`[chat] Mode: ${mode}, RawModel: ${rawModel}, SelectedModel: ${model}, ModeConfigModel: ${modeConfig?.model}`);
    
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
    });

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
      
      // Build conversation context with last 4 messages for better continuity
      const conversationMessages = [];
      
      // Check if clarification is needed
      const recentHistory = messages.slice(-4, -1); // Last 3 messages before current
      const needsClarificationCheck = needsClarification(userQuery, recentHistory);
      const contextTopics = extractContextTopics(recentHistory);
      
      // Add enhanced system message with context awareness
      let systemMessage = `You are a helpful, professional AI assistant with strong context awareness. 

IMPORTANT CONTEXT GUIDELINES:
- Always maintain awareness of the conversation history and current topic
- If a user's message seems vague or unclear, ask for clarification before responding
- When the user refers to "this", "that", "it", or other pronouns, use the conversation context to understand what they mean
- If you're unsure about what the user is asking about, politely ask: "I want to make sure I understand correctly - are you asking about [specific topic from context] or something else?"
- Keep track of the main topics being discussed and maintain continuity
- If the conversation topic seems to have changed abruptly, acknowledge it and ask for confirmation

Be conversational, helpful, and always strive to understand the user's intent based on the conversation context.`;

      // Add context-specific guidance if clarification might be needed
      if (needsClarificationCheck && contextTopics.length > 0) {
        systemMessage += `\n\nCURRENT CONTEXT TOPICS: ${contextTopics.join(', ')}\nIf the user's message seems to reference these topics but is unclear, ask for clarification.`;
      }
      
      conversationMessages.push({ role: 'system', content: systemMessage });
      
      // Add conversation history (last 4 messages for better context)
      const recentMessages = messages.slice(-4); // Last 4 messages for context as requested
      for (const msg of recentMessages) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          // Extract text content from message
          let content = '';
          if (typeof msg.content === 'string') {
            content = msg.content;
          } else if (Array.isArray(msg.content)) {
            // Extract text from content array
            const textParts = msg.content
              .filter((part: any) => part.type === 'text')
              .map((part: any) => part.text)
              .join(' ');
            content = textParts;
          }
          
          if (content.trim()) {
            conversationMessages.push({
              role: msg.role,
              content: content.trim()
            });
          }
        }
      }
      
      // For two-phase modes (search/aipedia), enhance the writer prompt with conversation context
      // For simple chat mode, use the conversation history directly
      if (isTwoPhase) {
        const writerPrompt = buildWriterPromptFromAgents({ 
          originalQuery: userQuery, 
          mode, 
          sources: collectedSources, 
          images: collectedImages,
          conversationHistory: recentMessages.slice(0, -1) // Exclude the current message as it's already in the query
        });
        conversationMessages.push({ role: 'user', content: writerPrompt });
      }
      // For simple chat mode, the conversation history already includes the current user message
      
      console.log(`[chat] Using ${conversationMessages.length} messages for context (including system${isTwoPhase ? ' and writer prompt' : ''})`);
      
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

