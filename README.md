# SecurityReview

A Rails 8 reference application for an inspection/asset-management platform:
organizations submit missions, missions contain inspections, inspections
contain assets, and assets carry file attachments (photos, video, reports)
stored in S3. It exists as a deliberately security-conscious target for
authorization/token/S3 review exercises — built clean rather than seeded
with intentional vulnerabilities, so a review's findings are either real
gaps or hardening suggestions, not planted bugs.

## Architecture

**Two authentication surfaces, never overlapping:**

- **Customer-facing JSON API** (`/api/v1/*`) — authenticated via a static
  `X-Api-Token` header (see `ApiToken`, `ApiTokenAuthenticatable`). Every
  token belongs to exactly one `Organization`; every query in this
  controller tree is built from `policy_scope`, so a token can never see
  another organization's rows. Only `X-Api-Token` is accepted — no
  session cookie, no query param.
- **Internal admin console** (`/admin/*`) — session-authenticated via
  Devise. Reachable by `platform_admin` users (full cross-org access) and
  `org_admin` users (same console, but every query is scoped to their own
  `organization_id` — see `ApplicationPolicy::Scope`). Never reachable via
  `X-Api-Token`.

**Domain model:** `Organization` → `Mission` → `Inspection` → `Asset` →
`Attachment`. `organization_id` is denormalized onto every descendant
table (set server-side from the parent association, never from params) so
every lookup is a single-column scope, not a join chain.

**Authorization:** Pundit policies for every resource. API policies
(`TokenScopedPolicy` and subclasses) take the `ApiToken` as `pundit_user`;
admin policies (`ApplicationPolicy` and subclasses) take the signed-in
`User`. Controllers resolve records through `policy_scope(...).find(...)`
— a cross-organization ID simply isn't in the query, so it 404s rather
than leaking existence via a 403 — then call `authorize` again as
defense-in-depth.

**File uploads/downloads:** `Attachment#s3_key` is always a
server-generated UUID under `attachments/<organization_id>/...`, never
client-influenced. `S3PresignedUrlService` is the only code that talks to
S3: it requires an already-authorized, already-`downloadable?` record,
issues short-lived presigned URLs (5 min GET / 15 min PUT), and logs the
access (object id, org, actor) without ever logging the URL itself. A
vendor webhook (`Api::V1::WebhooksController#scan_results`, HMAC-verified)
flips an attachment from `pending` to `processed`/`quarantined` after an
async malware scan; quarantined files can never be downloaded again.

**Outbound webhooks:** organizations can register a `WebhookEndpoint` to
receive events. `WebhookUrlGuard` blocks anything that isn't a public
HTTPS host — checked at registration time *and* again immediately before
every delivery in `WebhookDeliveryJob`, since DNS can change between the
two (SSRF-via-rebinding).

**Secrets:** `ApiToken` and Devise passwords are stored as one-way
digests/bcrypt hashes only. `WebhookEndpoint#signing_secret` is the one
value that must be *recovered* later (to sign outgoing deliveries), so
it's encrypted at rest via `ActiveRecord::Encryption` rather than hashed.
Nothing is logged in plaintext — see `config/initializers/filter_parameter_logging.rb`.

**Defense in depth:** `Rack::Attack` throttles logins, API auth attempts,
and presigned-URL issuance independently; `Rack::Cors` only allows the
JSON API from an explicit origin allowlist; `secure_headers` sets a strict
CSP/HSTS/frame baseline; every sensitive action writes an `AuditLog` row
(actor, org, object, IP — never a secret) via the shared `Auditable`
concern.

## Local development

```
bin/setup            # installs gems, copies .env.example -> .env, preps the DB
bin/rails server
bin/sidekiq          # background jobs (attachment scanning, webhook delivery)
bin/rails db:seed    # creates a platform admin + a demo org (dev only)
```

Or via Docker (copy the env file first — `docker compose` doesn't run `bin/setup` for you):
```
cp .env.example .env
docker compose up
```

## Tests / static analysis

```
bundle exec rspec       # request/model/policy specs, including the auth/token regression matrix
bundle exec rubocop     # style + a few Rails/security-relevant cops
bundle exec brakeman    # static security analysis (see config/brakeman.ignore for the one reviewed/accepted finding)
bundle exec bundler-audit check --update   # known CVEs in the dependency tree
```

## Deployment

- `Dockerfile` / `docker-compose.yml` — containerized app + Sidekiq worker.
- `terraform/` — the S3 attachment bucket (encrypted, versioned, no public
  access, TLS-only bucket policy) and a least-privilege IAM role scoped to
  that bucket only.
- `k8s/` — namespace, deployments, service, ingress, a default-deny
  `NetworkPolicy`, and a `secret.yaml.example` template (real secrets are
  never committed — see the file's header comment).
- `.github/workflows/ci.yml` — tests, rubocop, Brakeman, bundler-audit,
  and `terraform validate` on every push.
