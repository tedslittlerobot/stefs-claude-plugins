# Frontend Hosting (S3 + CloudFront)

Applies to every Terraform root that serves a static frontend. The pattern is the same for all of
them; what differs is only whether the distribution also fronts an API.

## The Pattern

- Frontend static files deploy **directly from the service's `frontend/` directory to an S3 bucket**
  — there is no build step. **Deployment is Terraform's own job** (`aws_s3_object` resources in
  `frontend.tf`, one per file), not a separate `aws s3 sync`. See the `frontend` skill's Deployment
  section
- **CloudFront serves the frontend via an S3 origin using Origin Access Control (OAC)** — the bucket
  is not public
- The bucket has **versioning enabled and blocks all public access**. Use
  `aws_cloudfront_origin_access_control` plus a bucket policy to restrict S3 access to CloudFront
  only

## The Domain and Certificate

The distribution is served on a domain in the service's own delegated zone (see
`reference/dns-and-ses.md`), **never its `*.cloudfront.net` domain**.

- An **ACM certificate** for that domain (`acm.tf`, via `terraform-aws-modules/acm/aws`,
  DNS-validated against the delegated zone) is required for this, and — like the WAF Web ACL —
  **must be requested in `us-east-1`** regardless of where the rest of the service runs, since
  CloudFront only accepts ACM certificates from that region
- Point the domain at the distribution with `aws_route53_record` **alias** records (A and AAAA) in
  the delegated zone, using CloudFront's fixed, well-known alias-target hosted zone ID
  **`Z2FDTNDATAQYW2`** — the same for every CloudFront distribution, regardless of account or region
- **Apex or `www.` depends on whether the service also sends email.** A service whose SES identity
  sits on its zone apex pushes its distribution onto `www.` to keep the two from colliding; a
  service that sends no email can take the apex directly — which works **only** because these are
  Route 53 *alias* records, since a plain CNAME is illegal at a zone apex

## Cache Behaviours

- **HTML and application entry points** — short or no-cache TTL so updates are picked up
  immediately. With no build step there are no content-hashed filenames, so these keys never change
  and a long-lived cache would serve stale code indefinitely
- **View template files (`/views/*`)** — short TTL; these are fetched by the router at runtime
- **Other static assets (`/assets/*`)** — a longer TTL is fine

## The SPA Fallback (read before adding one)

Because these are single-page apps served on real URLs (not hash routes), a direct visit or refresh
on any client-side route has no matching S3 object and would fail at the CloudFront/S3 layer instead
of reaching the app's own router. **How that fallback is implemented depends on whether the
distribution fronts anything but S3.**

### A distribution with an API origin must not use `custom_error_response`

Custom error responses are a property of the **distribution**, not of a cache behaviour. So a
403/404 → `/index.html` mapping **also swallows genuine 403s and 404s coming back from `/api/*`**
and returns the app shell with a `200` in their place.

This shipped as a real bug: an authenticated `GET /api/me/profile` for a user with no matching row
returned the whole frontend instead of its `{"message":"profile not found"}` 404 — and the SPA then
rendered its own "page not found" view, because `/api/me/profile` matches no client-side route. The
symptom looks like a frontend routing fault and is a CloudFront configuration fault.

### Use a CloudFront Function instead

Attach an `aws_cloudfront_function` on the **viewer-request** event of the **default cache
behaviour**, rewriting any path that is not a static file to `/index.html`. Functions are attached
per behaviour, so **`/api/*` is never touched**.

- **Match the static-file test against an explicit extension list**, not "contains a dot", so a
  route parameter that happens to contain one still reaches the router
- Leaving real file requests alone also means **a missing asset still fails as a missing asset**
  instead of silently returning the shell under a `200`
- The function source lives in `terraform/functions/` and is pulled in with `file()` — it needs no
  interpolation, so it does not belong in `terraform/templates/`
- **`publish = true` is what creates the LIVE stage** a distribution can reference
- CloudFront being global means this needs **no** `us-east-1` provider, unlike the WAF Web ACL and
  the ACM certificate

### A purely static distribution may use `custom_error_response`

A single-S3-origin distribution has nothing for the distribution-wide mapping to break, so mapping
403 and 404 to `/index.html` with a `200` remains acceptable there.

**Map both, not just 404**: with OAC and a bucket policy granting only `s3:GetObject`, a missing key
comes back as `403 AccessDenied`, not `404`.

## The API Origin

Every service with an HTTP API puts a CloudFront distribution in front of it and **never exposes the
`execute-api` endpoint directly** — that distribution is also the only place a WAF Web ACL can
attach (see `reference/waf.md`).

**CloudFront does not rewrite paths, so every API Gateway route must itself be defined under an
`/api` prefix** (`GET /api/me/profile`, matching the `api-<method>-` Lambda naming in the
`lambdas-go` skill). That is what lets one path pattern forward-match every current and future route
with no per-endpoint CloudFront configuration.

How the API sits in the distribution depends on whether the service also serves a frontend:

| Service shape | Distribution |
| --- | --- |
| Frontend **and** API | Two origins. S3 is the default cache behaviour; `/api/*` is an **ordered** behaviour pointing at the API Gateway origin |
| API only (backend service) | One origin. No S3 origin at all — the API Gateway **is** the default cache behaviour. Routes still carry the `/api` prefix, so nothing else changes if a frontend is added later and the API moves to an ordered `/api/*` behaviour |
| Frontend only, no API | One static origin, no `/api/*` behaviour. It calls other services' APIs on their own domains as an ordinary cross-origin browser client |

An API-fronting behaviour must:

- **disable caching** (AWS managed `CachingDisabled`) — the responses are authenticated and
  per-caller
- use the AWS managed **`AllViewerExceptHostHeader`** origin request policy, which forwards the
  `Authorization` header the JWT authorizer needs while replacing `Host` with the origin's own, as
  `execute-api` requires
