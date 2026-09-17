# ZeitHawk CORS proxy (Cloudflare Worker)

A private alternative to routing ZeitHawk's requests through the public
`corsproxy.io`. Same idea (fetch the target server-side, hand back the
response with permissive CORS headers), but it's your own deployment
instead of a third party you don't control — and unlike a Google Apps
Script web app, a Cloudflare Worker can actually set
`Access-Control-Allow-Origin` on its response, which Apps Script cannot
do at all (see `tools/apps-script-backend/Code.gs` for why that backend
uses JSONP instead of a proxy).

## Deploy it (no CLI needed, ~2 minutes)

1. Sign up for a free Cloudflare account at
   [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) if
   you don't have one — the free tier (100,000 requests/day) is plenty
   for this.
2. In the dashboard, go to **Workers & Pages** → **Create** → **Create
   Worker**.
3. Give it a name (e.g. `zeithawk-proxy`) → **Deploy** (this creates a
   placeholder — you'll replace its code next).
4. Click **Edit code** (or "Quick edit") to open the online editor.
5. Delete the placeholder code and paste in the contents of
   [`worker.js`](./worker.js) from this folder.
6. **Save and deploy.**
7. Copy the Worker's URL — it looks like
   `https://zeithawk-proxy.<your-subdomain>.workers.dev`.

## Point ZeitHawk at it

In ZeitHawk's header, the CORS proxy section has a **Proxy endpoint**
field (below the on/off toggle), pre-filled with
`https://corsproxy.io/?url=`. Replace it with your Worker's URL plus
`/?url=`, e.g.:

```
https://zeithawk-proxy.<your-subdomain>.workers.dev/?url=
```

That's stored in your browser's `localStorage`, so it persists across
visits until you change it again.

## Caveats

- **No allowlist, no auth.** Anyone who has this Worker's URL can use it
  as an open relay to fetch anything from anywhere. That's the point (you
  need it to reach arbitrary authorized-test targets), but don't reuse
  this Worker for anything you wouldn't want acting as an open proxy.
- **It forwards headers and body as-is** — including anything you type
  into Repeater/Intruder. Nothing about what you send through it is
  logged by this code, but Cloudflare's own platform-level request logs
  (if you have logging enabled on your account) would still see it, same
  as any Worker you deploy.
- **Still bound by what the target itself allows.** If a target blocks
  Cloudflare's IP ranges, rate-limits aggressively, or requires a
  specific `User-Agent`, this proxy won't get around that — it's not a
  general-purpose anti-blocking tool, just a CORS workaround.
