# Auth, Request IDs and Limits

The cross-cutting concerns every endpoint shares: how a caller proves who it is, what happens when
it is not allowed, how a request is traced, and how the API protects itself.

## Authentication

- **Credentials go in the `Authorization` header**: `Authorization: Bearer <token>`. Never in the
  query string — URLs are written to access logs, proxy logs, browser history and `Referer`
  headers, so a token in one has been disclosed to all of them
- **HTTPS only.** A plain-HTTP request is refused, not redirected: by the time a redirect is sent,
  the token has already crossed the network in clear text, and a redirect teaches clients that the
  HTTP URL works
- An API key and a user token use the same header and scheme where possible, so a caller has one
  thing to learn
- Endpoints are private unless explicitly public, and the documentation says which each is — see
  the `documentation` skill's API-docs reference for how that is recorded in the OpenAPI file

## `401`, `403` or `404`

These three are easy to get wrong, and the wrong one is either a security leak or a confusing
message:

| Situation | Status |
| --- | --- |
| No credentials, or invalid or expired ones | `401 Unauthorized`, with `WWW-Authenticate` |
| Valid credentials, and the caller can see the resource, but may not do this to it (a viewer trying to delete) | `403 Forbidden` |
| Valid credentials, and the caller may not know the resource exists (another tenant's order) | `404 Not Found` — the same response a genuinely missing resource gets |

The last row matters most. Returning `403` for another tenant's resource confirms that it exists,
and with sequential or guessable IDs that turns every endpoint into a way to enumerate other
customers' data. The `404` must be **indistinguishable** from a real one: the same body, and no
measurably different response time.

Authentication (who are you?) and authorization (may you do this?) are separate checks, and the
documentation for each endpoint answers both.

## Request IDs

- Every response carries a **`Request-Id`** header, and every error body carries the same value as
  `request_id`
- If the client sends a `Request-Id`, the server uses it (after validating its length and
  characters) and passes it on to anything it calls, so one ID follows a request across services
- It is logged with every server-side log line for the request. That is what lets an error body
  contain nothing internal: the `request_id` is the pointer from a user's bug report to the full
  detail
- Custom headers are named without an `X-` prefix (RFC 6648): `Request-Id`, not `X-Request-Id`.
  Where a gateway or platform already emits `X-Request-Id` and cannot be changed, echo the same ID
  in both rather than inventing a second one

## Rate Limiting

- An exceeded limit is **`429 Too Many Requests`** with a **`Retry-After`** header, in seconds, and
  the standard error body with code `rate_limited`
- Every response reports the caller's current position against its limit, so a client can slow
  down *before* it is refused — using the IETF `RateLimit` / `RateLimit-Policy` header fields, or,
  where the platform already emits them, the widely used `RateLimit-Limit`, `RateLimit-Remaining`
  and `RateLimit-Reset`. The project records which in `conventions/api.md`; mixing both in one API
  is the one wrong answer
- Limits are documented — per what (token, user, IP), over what window, and for which endpoints —
  so a person can plan a bulk job without discovering the limit by hitting it
- Expensive endpoints (search, exports, anything that sends a message) may have tighter limits of
  their own

## Other Limits

- **Request body size** has a documented maximum; beyond it is `413` — see `errors.md`
- **`per_page`** and bulk batch sizes have documented maximums — see `lists.md` and
  `methods-and-status-codes.md`
- **String fields** have documented maximum lengths, validated on input, so the limit is a clear
  `422` rather than a database truncation or a `500`

## CORS

An API called directly from browsers sends CORS headers for an **explicit allow-list of origins**
held in configuration — never `Access-Control-Allow-Origin: *` on an authenticated API, and never
by reflecting whatever `Origin` the request sent, which is `*` with extra steps. An API not called
from browsers sends no CORS headers at all.

## Caching

- Responses to authenticated requests default to `Cache-Control: no-store` unless an endpoint
  documents otherwise — a shared cache that stores one user's `GET /me` serves it to the next
- Public, cacheable resources send an explicit `Cache-Control` with a `max-age`, and an `ETag` so
  a client can revalidate with `If-None-Match` and get a `304 Not Modified`
