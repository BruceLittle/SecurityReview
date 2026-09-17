# Apps Script + Firestore backend

A tiny Google Apps Script web app that gives ZeitHawk and the AI Tool
Finder artifact a durable, searchable log of the requests they already
send by `mailto:` — "Request Security authorization" (ZeitHawk),
"Request Security Approval", and "Request IT review of this app" (AI Tool
Finder). The email still sends; this just also writes a copy to
Firestore so the requests aren't only sitting in one inbox.

It does **not** replace the mailto flow — both artifacts fire this
in addition to opening the email, best-effort, and silently no-op if it
isn't deployed yet.

## Why Apps Script, not a "real" server

Both callers are static HTML artifacts with nowhere to run server code
and no credentials of their own. Apps Script is a way to get a callable,
authenticated-to-Firestore endpoint without standing up any
infrastructure — deploy it once under a Google account and both artifacts
just point at the resulting URL.

## Deploy it

1. Go to [script.google.com](https://script.google.com) → **New project**.
2. Replace the default `Code.gs` with this folder's `Code.gs`. Add
   `appsscript.json` too — in the editor, click the gear icon → **Show
   "appsscript.json" manifest file in editor**, then paste its contents.
3. **Project Settings → Google Cloud Platform (GCP) Project** → switch
   from the default project to a standard GCP project you control (create
   one at [console.cloud.google.com](https://console.cloud.google.com) if
   you don't have one to reuse).
4. In that GCP project's console: **Firestore** → create a database in
   **Native mode** (any region). Also confirm the **Cloud Firestore API**
   is enabled (it is by default once you create the database).
5. Back in Apps Script, edit `Code.gs` and set `PROJECT_ID` to that GCP
   project's ID (not its display name — the ID, e.g. `my-project-123`).
6. **Deploy → New deployment → Web app**:
   - Execute as: **Me**
   - Who has access: **Anyone**
   (Anyone access is what lets the artifacts call this without a login —
   see the security note below.)
7. Authorize the requested scopes when prompted (this is where
   `oauthScopes` in the manifest — `script.external_request` and
   `datastore` — get consented to).
8. Copy the deployment's **Web app URL** (ends in `/exec`).
9. Paste that URL into `APPS_SCRIPT_URL` in:
   - `tools/zeithawk/index.html`
   - the AI Tool Finder artifact (`Project Settings → Google Cloud
     Platform (GCP) Project` note above applies the same way if you
     redeploy it there)

Re-deploy (**Deploy → Manage deployments → Edit → New version**) any time
you change `Code.gs` — editing the file alone doesn't update a live `/exec`
URL.

## What it stores

Two collections, one document per request:

- `security_authorization_requests` — ZeitHawk's "Request Security
  authorization" and AI Tool Finder's "Request Security Approval"
- `app_review_requests` — AI Tool Finder's "Request IT review of this app"

Each document: `tool`, `target`, `requester`, `note`, `createdAt` (ISO
string). `requester` is left blank by both artifacts today — neither
collects an identity — so treat this log as "what was requested," not
"who requested it," unless you wire up a requester field yourself.

## Reading it back

`doGet` supports a small JSONP API for the artifacts' "recent requests"
panel:

```
GET {WEB_APP_URL}?collection=security_authorization_requests&limit=10&callback=myFn
```

Without `callback`, it returns plain JSON — handy for `curl` while
testing, but a browser `fetch()` from a different origin can't read it
(see the CORS note below).

## Known limitations (read before relying on this)

- **No auth on the endpoint.** "Anyone" access means anyone who has the
  URL — including anyone who reads the artifacts' source, since
  `APPS_SCRIPT_URL` is right there in plain HTML — can write arbitrary
  documents to these two collections, or read them back. Don't put
  secrets in the fields, and don't point this at anything more sensitive
  than "a request was made." Apps Script web apps don't support
  fine-grained auth for anonymous callers without a lot more machinery
  than fits a static artifact.
- **No CORS headers on the response.** A cross-origin `fetch()` POST is
  sent with `mode: 'no-cors'` (fire-and-forget — the artifacts never read
  the response, just log and move on) and reads happen over the JSONP
  `callback=` path instead, which sidesteps CORS entirely by using a
  `<script src=...>` tag rather than `fetch`.
- **Rate limiting: none.** This is a request log for a small internal
  audience, not a public-facing form. If it ever gets abused, the fastest
  mitigation is disabling the deployment (**Deploy → Manage deployments →
  Archive**) — the mailto flow in both artifacts keeps working either way.
