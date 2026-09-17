# ZeitHawk

A standalone, browser-only HTTP security testing toolkit built in the spirit
of Burp Suite's core tools — Repeater, Intruder, Decoder, and Comparer. It's
a single self-contained HTML file (`index.html`) with no build step, no
server, and no dependencies beyond a Google Fonts stylesheet; open it
directly in a browser or host it as a static file.

It is not part of the SecurityReview Rails application and has no runtime
dependency on it — it lives here as a companion tool for people doing manual
review/testing work against systems they're authorized to test.

## Running it

Host `index.html` as a static file (e.g. via [GitHub
Pages](https://github.com/BruceLittle/SecurityReview/settings/pages) —
Source: "Deploy from a branch", branch `main`, folder `/(root)` — it'll be
served at `https://<owner>.github.io/<repo>/tools/zeithawk/`) or open the
file directly in a browser.

**Don't rely on a Claude Artifact preview of this file for real use.**
Claude's artifact sandbox blocks outbound `fetch()` to arbitrary
third-party domains via its own CSP — every request in this app
(Repeater, Intruder, Recon, Vuln Scan, and any CORS proxy) will fail with
a generic `Failed to fetch` there regardless of target, proxy
configuration, or anything else in this code. That's a property of the
artifact wrapper, not a bug here — confirmed by the exact same requests
working correctly once run from a real hosted page instead.

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
- **Vuln Scan** — a lightweight header/config checker in the spirit of
  securityheaders.com or Mozilla Observatory: checks for common security
  headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options,
  Referrer-Policy, Permissions-Policy), flags a permissive-plus-credentialed
  CORS policy, and probes a fixed list of commonly-exposed sensitive paths
  (`.env`, `.git/HEAD`, `wp-config.php.bak`, `id_rsa`, etc). Not a
  signature-based scanner like Nessus/OpenVAS/Nikto — see below for what it
  can and can't actually prove.

## Constraints (by design — it runs entirely client-side)

Because it's a plain web page with no backend of its own, every request is
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

### CORS proxy toggle (on by default, configurable endpoint)

A switch in the header routes Repeater, Intruder, Recon's DNS/RDAP
lookups, and Vuln Scan through a proxy, which fetches the target
server-side and returns the response with permissive CORS headers —
letting ZeitHawk reach targets that don't set their own. It's **on by
default** since that's the point of the toggle, but it comes with real
tradeoffs:

- **Whatever endpoint is set is a third party you don't fully control**
  (unless you deployed it yourself — see below). The target URL, and
  anything you send it (headers, body, Intruder payloads), passes through
  it. Turn the toggle off for anything sensitive, internal, or already
  CORS-permissive.
- **It doesn't change Vuln Scan's honesty guarantee.** Header checks still
  only ever report "Present" when actually read, never a false "Missing" —
  because whether the configured proxy itself exposes the target's
  original headers via `Access-Control-Expose-Headers` isn't something
  ZeitHawk can verify, on or off.
- **Method/header/body forwarding depends on the proxy's own behavior**,
  not ZeitHawk's — if a request behaves differently proxied vs. direct,
  toggle it off and compare.
- Recon's port-reachability check is deliberately **not** proxied: it uses
  `mode:'no-cors'`, which already isn't blocked by CORS, so routing it
  through a proxy would only change the network vantage point, not fix
  anything.

**Default endpoint** is the public [corsproxy.io](https://corsproxy.io).
A **Proxy endpoint** field beneath the toggle lets you point it at a
private proxy instead — see `tools/zeithawk/cors-proxy-worker/` for a
ready-to-deploy Cloudflare Worker that does the same job under your own
account rather than a public third party. (A Google Apps Script web app
*can't* fill this role: it has no way to set
`Access-Control-Allow-Origin` on its own response at all, so a plain
`fetch()` could never read what it returned — see
`tools/apps-script-backend/Code.gs` for where that limitation is
documented, from when that backend was built for a different purpose.)

Both the on/off state and the endpoint persist per-browser via
`localStorage`; nothing about the toggle itself is sent anywhere.

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

## Vuln Scan's limits (also by design)

The security-header checks can only ever prove a header is **present** —
they can never prove one is **missing**. Browsers only expose a small
CORS-safelisted set of response headers to cross-origin JavaScript
(`Cache-Control`, `Content-Language`, `Content-Length`, `Content-Type`,
`Expires`, `Last-Modified`, `Pragma`); none of the security headers this
tool checks are in that list. A server can only make a header readable by
naming it in its own `Access-Control-Expose-Headers` response header. So
when a check reports "Not readable cross-origin", that means exactly what
it says — unproven either way — not "confirmed missing." This applies to
`Access-Control-Allow-Origin` itself too: if it isn't exposed via
`Access-Control-Expose-Headers`, Vuln Scan can't even read whether CORS is
open, and says so rather than guessing. Every row that reports a real
finding (a header actually read, a CORS policy actually inspected, a path
that actually returned a status code) is something ZeitHawk directly
observed — never inferred from silence. For ground truth on anything
marked "Not readable cross-origin," the read-out includes a ready-to-copy
`curl -sD - -o /dev/null <url>` command, which sees every header a server
sends, no CORS restriction involved.

The exposed-path checks need the target to allow cross-origin reads at
all (same CORS requirement as Repeater) to see status codes back; a
target with a locked-down CORS policy will show every path check as
blocked, which is not the same as those paths not existing.
