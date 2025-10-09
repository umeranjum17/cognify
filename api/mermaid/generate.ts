/**
 * Mermaid Diagram Generation Endpoint
 * Proxies requests to mermaid.ink API
 * 
 * SECURITY: Requires authentication to prevent abuse
 */

import { verifyAuthForEdge, createUnauthorizedResponse } from '../shared/auth-helpers';

export const config = {
  runtime: 'edge',
};

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

interface MermaidRequest {
  code: string;
  theme?: 'default' | 'dark' | 'forest' | 'neutral';
  format?: 'png' | 'svg';
  bgColor?: string;
}

export default async function handler(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  }

  // ============================================
  // AUTHENTICATION CHECK - MUST HAPPEN FIRST
  // ============================================
  const auth = await verifyAuthForEdge(req);
  if (!auth.success) {
    console.error('Mermaid generation - Authentication failed:', auth.error);
    return createUnauthorizedResponse(auth.error || 'Unauthorized', CORS_HEADERS);
  }
  
  console.log(`Mermaid diagram generation requested by user: ${auth.uid}`);

  try {
    const body: MermaidRequest = await req.json();
    const { code, theme = 'default', format = 'png', bgColor } = body;

    if (!code) {
      return new Response(
        JSON.stringify({ error: 'Missing mermaid code' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
        }
      );
    }

    // Create the mermaid configuration
    const mermaidConfig = {
      code,
      mermaid: {
        theme,
      },
    };

    // Encode the configuration as base64
    const jsonString = JSON.stringify(mermaidConfig);
    const encodedConfig = btoa(jsonString);

    // Build URL - use /img/ for PNG and /svg/ for SVG
    const endpoint = format === 'svg' ? 'svg' : 'img';
    let url = `https://mermaid.ink/${endpoint}/${encodedConfig}`;

    // Add query parameters for PNG with background color
    if (format === 'png' && bgColor) {
      const params = new URLSearchParams();
      if (theme === 'dark') {
        params.append('theme', 'dark');
      }
      params.append('bgColor', bgColor);
      url += `?${params.toString()}`;
    }

    // Fetch the diagram from mermaid.ink
    const mermaidResponse = await fetch(url, {
      headers: {
        'User-Agent': 'Cognify-API/1.0',
        'Accept': format === 'png' ? 'image/png,*/*' : 'image/svg+xml,*/*',
      },
    });

    if (!mermaidResponse.ok) {
      // Try fallback without query parameters
      const fallbackUrl = `https://mermaid.ink/${endpoint}/${encodedConfig}`;
      const fallbackResponse = await fetch(fallbackUrl, {
        headers: {
          'User-Agent': 'Cognify-API/1.0',
          'Accept': format === 'png' ? 'image/png,*/*' : 'image/svg+xml,*/*',
        },
      });

      if (!fallbackResponse.ok) {
        return new Response(
          JSON.stringify({ error: 'Failed to generate diagram' }),
          {
            status: fallbackResponse.status,
            headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
          }
        );
      }

      const imageData = await fallbackResponse.arrayBuffer();
      return new Response(imageData, {
        status: 200,
        headers: {
          'Content-Type': format === 'png' ? 'image/png' : 'image/svg+xml',
          'Cache-Control': 'public, max-age=3600',
        },
      });
    }

    const imageData = await mermaidResponse.arrayBuffer();
    return new Response(imageData, {
      status: 200,
      headers: {
        'Content-Type': format === 'png' ? 'image/png' : 'image/svg+xml',
        'Cache-Control': 'public, max-age=3600',
      },
    });
  } catch (error) {
    console.error('Mermaid generation error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      }
    );
  }
}
