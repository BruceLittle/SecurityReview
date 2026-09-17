# ZeitHawk

A standalone, browser-only HTTP security testing toolkit built in the spirit
of Burp Suite's core tools — Repeater, Intruder, Decoder, and Comparer. It's
a single self-contained HTML file (`index.html`) with no build step, no
server, and no dependencies beyond a Google Fonts stylesheet; open it
directly in a browser or host it as a static file.

It is not part of the SecurityReview Rails application and has no runtime
dependency on it — it lives here as a companion tool for people doing manual
review/testing work against systems they're authorized to test.

## Tools

- **Repeater** — build one HTTP request (method/URL/headers/body), send it,
  inspect the status/headers/body, tweak, resend.
- **Intruder** — mark an injection point with `§inject§` anywhere in the
  URL, a header, or the body; runs a payload list (built-in presets or a
  custom list) against it sequentially and reports status/length/timing per
  payload.
- **Decoder** — Base64/URL/HTML-entity/Hex/Unicode transforms, JWT decode
  (unverified), and SHA-1/256/384/512 hashing, chainable output → input.
- **Comparer** — line-level diff between two blocks of text.
- **History** — every request sent from Repeater or Intruder, stored in
  `localStorage`, click a row to reload it into Repeater.

## Constraints (by design — it runs entirely client-side)

Because it's a plain web page with no proxy or backend, every request is
subject to the same rules any page's `fetch()` is subject to:

- **CORS** — the target must allow cross-origin requests, or the response
  can't be read (status/headers/body all come back opaque/blocked).
- **Forbidden headers** — a browser will never let a page set `Host`,
  `Cookie`, `Origin`, `Referer`, `Content-Length`, and a handful of others;
  ZeitHawk flags and skips these when building a request.

These aren't bugs to fix later — they're the tradeoff of a zero-install,
zero-backend tool. For anything that needs true request interception or
raw socket control, use a real intercepting proxy (Burp Suite, OWASP ZAP,
mitmproxy).

**Authorized testing only.** Only point this at systems you own or have
explicit permission to test.
