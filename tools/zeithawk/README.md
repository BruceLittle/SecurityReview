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
- **Recon** — DNS records (A/AAAA/MX/TXT/NS/CNAME/SOA) via DNS-over-HTTPS,
  WHOIS/RDAP, and an HTTP-reachability check on common web ports for a
  domain or IP — plus ready-to-copy `ping`/`traceroute`/`whois`/`nmap`
  commands for the things a browser can't do (see below).

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

## Recon's limits (also by design)

A browser has no API for raw sockets, so three of the things "recon a
target" usually means are flatly impossible from client-side JS, not just
inconvenient:

- **ICMP ping** — needs a raw socket; there's no ping API in a browser.
- **Traceroute** — needs to send packets with increasing TTL and read back
  ICMP responses; same problem, no workaround.
- **A real port scan** — needs raw TCP SYN/connect control across arbitrary
  ports; a browser's `fetch()` can only ever make an HTTP request, and only
  on ports the browser itself doesn't block outright.

Recon's "HTTP reachability" table is a limited, honest substitute: it tries
a plain HTTPS/HTTP request on a handful of common web ports and reports
reachable/timeout/closed — useful signal, not a substitute for `nmap`.
For the real thing, Recon prints ready-to-copy `ping`, `traceroute`,
`whois`, and `nmap` commands to run in your own terminal, against targets
you're authorized to test.

DNS-over-HTTPS (`dns.google`) and RDAP (`rdap.org`, which bootstraps to the
authoritative registry) are both public APIs with no key required. RDAP
lookups can still fail if the target registry's own RDAP server doesn't
send CORS headers for browser access — when that happens, Recon says so
and points at the `whois` command instead.
