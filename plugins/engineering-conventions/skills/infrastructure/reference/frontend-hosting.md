# Frontend Hosting (S3 + CloudFront)

Applies to every Terraform root that serves a static frontend. The pattern is the same for all of
them; what differs is only whether the distribution also fronts an API.

## The Pattern

- **Terraform builds the hosting; it never puts content in it.** The bucket, its policy, the Origin
  Access Control, the distribution, its certificate and its DNS records are infrastructure. The
  files the bucket serves are a release, and **CI** uploads them — see "Deploying the Content"
- **CloudFront serves the frontend via an S3 origin using Origin Access Control (OAC)** — the bucket
  is not public
- The bucket has **versioning enabled and blocks all public access**. Use
  `aws_cloudfront_origin_access_control` plus a bucket policy to restrict S3 access to CloudFront
  only

**Diverged from `prototype-conventions`:** there, the frontend has no build step and Terraform
deploys it, one `aws_s3_object` per file. For a prototype that is one command for everything. In
production it ties every copy change to an infrastructure run, puts the release's files in Terraform
state, and leaves nowhere natural for a build step, content hashing or a cache invalidation. Content
and infrastructure change at different rates, for different reasons, and are reviewed by different
people.

## Deploying the Content

CI deploys the frontend after building it, in this order:

1. **Fetch the bucket name and distribution ID on demand** — `terraform output -raw` against the
   environment's workspace (see `variables-and-environments.md`). Never copy them into CI
   configuration, where they go stale the first time the bucket is replaced
2. **Upload the content-hashed assets first**, with
   `Cache-Control: public, max-age=31536000, immutable` — a file whose name changes when its content
   does can be cached forever
3. **Upload the entry points last** — `index.html` and anything else whose name does not change —
   with `Cache-Control: no-cache`, so every request revalidates
4. **Invalidate the entry points**: `aws cloudfront create-invalidation --distribution-id <id>
   --paths "/index.html"` (plus any other unhashed path). The hashed assets need no invalidation —
   they are new names

The order is what makes a release atomic for a user: until step 3, every `index.html` in circulation
refers only to assets that exist.

- **Do not delete the previous release's hashed assets in the same deploy.** A browser that loaded
  the old `index.html` a minute ago still asks for them, and a deleted one comes back as a 403.
  Prune them in a later deploy, or leave them — they are small
- **CI's role gets exactly** `s3:PutObject`, `s3:DeleteObject` and `s3:ListBucket` on this bucket
  and `cloudfront:CreateInvalidation` on this distribution — granted in Terraform, beside the bucket
- The CloudFront cache behaviour for the S3 origin uses a cache policy that **honours the origin's
  `Cache-Control`**, so the headers set at upload are what decide caching

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

## Transport, Headers and Logs

- **`minimum_protocol_version = "TLSv1.2_2021"`** in the distribution's `viewer_certificate`, with
  `ssl_support_method = "sni-only"`, and `viewer_protocol_policy = "redirect-to-https"` on every
  behaviour
- **Every behaviour that serves the frontend has a response headers policy** setting HSTS (a year,
  including subdomains), `X-Content-Type-Options`, `X-Frame-Options` or a `frame-ancestors`
  directive, `Referrer-Policy`, and a **Content-Security-Policy written for this app**. AWS's
  managed security-headers policy covers everything but the CSP, which only the app's authors can
  write — so a frontend needs an `aws_cloudfront_response_headers_policy` of its own
- **Every distribution has access logging**, to CloudWatch Logs or S3, with a retention period set
  explicitly — a WAF log shows what was blocked, and only the access log shows what was served

## Cache Behaviours

- **Entry points** (`index.html` and other unhashed files) — `no-cache`, set at upload
- **Content-hashed assets** — cached for a year as `immutable`, set at upload
- Anything the build cannot hash (a `robots.txt`, a favicon at a fixed path) — a short max-age

**Diverged from `prototype-conventions`:** there, nothing is hashed, so the rule is short TTLs on
entry points and on `/views/*`, a longer one on `/assets/*`, and no file can ever be cached for
long. A build step that hashes filenames removes the trade-off.

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

Every service with an HTTP API puts a CloudFront distribution in front of it and **never advertises
the `execute-api` endpoint** — that distribution is also the only place a WAF Web ACL can attach
(see `reference/waf.md`).

**Every API Gateway route is defined under an `/api` prefix** (`GET /api/me/profile`, matching the
`api-<method>-` Lambda naming in the `lambdas-go` skill) — **always, whichever hostname serves the
API**, its own included. CloudFront does not rewrite paths, so the prefix is what lets one path
pattern forward-match every current and future route with no per-endpoint CloudFront configuration.
Keeping it on an API with a hostname of its own means a route has the same path in every shape
below: an API can move onto or off a frontend's distribution without a client, a route, a WAF
scope-down statement or a log query changing.

How the API sits in the distribution depends on the service's shape:

| Service shape | Distribution |
| --- | --- |
| Frontend **and** API on one hostname | Two origins. S3 is the default cache behaviour; `/api/*` is an **ordered** behaviour pointing at the API Gateway origin |
| API on its own hostname (`api.<domain>`), or an API-only backend service | One origin. No S3 origin — the API Gateway **is** the default cache behaviour. Routes still carry the `/api` prefix |
| Frontend only, no API | One static origin, no `/api/*` behaviour. It calls other services' APIs on their own domains as an ordinary cross-origin browser client |

An API-fronting behaviour must:

- **disable caching** (AWS managed `CachingDisabled`) — the responses are authenticated and
  per-caller
- use the AWS managed **`AllViewerExceptHostHeader`** origin request policy, which forwards the
  `Authorization` header the JWT authorizer needs while replacing `Host` with the origin's own, as
  `execute-api` requires

**The `execute-api` endpoint is still reachable by anyone who learns its URL**, and a request sent
there skips the distribution and its Web ACL. An HTTP API has no resource policy to restrict that,
and disabling the default endpoint only moves the problem: CloudFront then needs an API Gateway
custom domain as its origin, and that is just as reachable. So **the authorizer, not WAF, is
what protects an authenticated route**, and an unauthenticated route must be safe to call without
WAF in front of it. The distribution is still the only entry point the service publishes.
