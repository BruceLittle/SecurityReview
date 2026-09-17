/**
 * A minimal CORS-bypassing reverse proxy for ZeitHawk, deployed as a
 * Cloudflare Worker. Unlike a Google Apps Script web app (which can't set
 * response headers at all, so a plain fetch() can never read its body
 * cross-origin), a Worker can freely set Access-Control-Allow-Origin and
 * Access-Control-Expose-Headers — which is the whole point here.
 *
 * Usage: GET <this-worker-url>/?url=<url-encoded target>
 * Forwards method, headers, and body to the target, then returns the
 * target's real status/headers/body with permissive CORS headers added.
 *
 * This has no allowlist or auth by design — it's meant to be pointed at
 * whatever target you're authorized to test, the same as ZeitHawk itself.
 * Anyone with the deployed URL can use it as an open proxy, so don't put
 * anything sensitive in front of it you wouldn't want relayed.
 */

const HOP_BY_HOP_REQUEST_HEADERS = [
  'host', 'connection', 'keep-alive', 'transfer-encoding', 'upgrade',
  'te', 'trailer', 'proxy-authorization', 'proxy-connection',
];

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const reqUrl = new URL(request.url);
    const target = reqUrl.searchParams.get('url');
    if (!target) {
      return jsonError('Missing ?url= query parameter', 400);
    }

    let targetUrl;
    try {
      targetUrl = new URL(target);
    } catch (e) {
      return jsonError('Invalid target URL: ' + target, 400);
    }
    if (targetUrl.protocol !== 'http:' && targetUrl.protocol !== 'https:') {
      return jsonError('Only http/https targets are supported', 400);
    }

    const forwardHeaders = new Headers();
    for (const [key, value] of request.headers) {
      const k = key.toLowerCase();
      if (HOP_BY_HOP_REQUEST_HEADERS.includes(k)) continue;
      if (k.startsWith('cf-') || k === 'x-forwarded-for' || k === 'x-real-ip') continue;
      forwardHeaders.set(key, value);
    }

    const init = {
      method: request.method,
      headers: forwardHeaders,
      redirect: 'follow',
    };
    if (!['GET', 'HEAD'].includes(request.method)) {
      init.body = await request.arrayBuffer();
    }

    let targetRes;
    try {
      targetRes = await fetch(targetUrl.toString(), init);
    } catch (e) {
      return jsonError('Upstream request failed: ' + ((e && e.message) || String(e)), 502);
    }

    const respHeaders = new Headers(targetRes.headers);
    const exposeList = Array.from(respHeaders.keys()).join(', ');
    respHeaders.set('Access-Control-Allow-Origin', '*');
    respHeaders.set('Access-Control-Expose-Headers', exposeList || '*');
    // Hop-by-hop, and content-encoding since fetch() already decoded the body.
    respHeaders.delete('content-encoding');
    respHeaders.delete('content-length');
    respHeaders.delete('transfer-encoding');
    respHeaders.delete('connection');

    return new Response(targetRes.body, {
      status: targetRes.status,
      statusText: targetRes.statusText,
      headers: respHeaders,
    });
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Max-Age': '86400',
  };
}

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: Object.assign({ 'content-type': 'application/json' }, corsHeaders()),
  });
}
