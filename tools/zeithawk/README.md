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
explicit permission to test. If you don't have written sign-off for a
target yet, the "Request Security authorization" link in the banner opens
a prefilled email to Security (same escalation pattern as the AI Tool
Finder artifact) — update `SECURITY_APPROVAL_EMAIL` in `index.html` if
that alias ever changes.

## Optional backend: a durable log of authorization requests

Clicking "Request Security authorization" always opens the mailto above,
with zero setup. It also *tries* to log the same request to Firestore via
a small Apps Script web app, so there's a searchable record beyond one
inbox — see `../apps-script-backend/README.md` for what that is and how
to deploy it (shared with the AI Tool Finder artifact, which logs its own
"Request Security Approval" / "Request IT review" clicks the same way).

Until you deploy it and paste the resulting URL into `APPS_SCRIPT_URL` in
`index.html`, this is a silent no-op — the mailto flow is unaffected
either way, and the "View recent authorization requests" panel in the
banner just says it isn't configured yet.
