---
name: frontend
description: SPA frontend development — AlpineJS + Tailwind CSS v4 + Pinecone Router loaded from CDN at pinned versions with no build step, the index.html/app.js/views layout, adding a route, Terraform-rendered runtime config, S3 deployment, design-idiom rules and the settled accessibility patterns. Use when writing or editing any frontend HTML/CSS/JS, adding a page or route, working with Alpine components or Tailwind utilities, or reviewing frontend markup.
---

# Frontend Conventions

Every frontend is built the same way, from the same libraries, in the same directory shape. This is
binding on any **new** frontend too — a new frontend does not get to pick a different framework.
Separate frontends share **no code**; what they share is a stack and a set of rules. Only the visual
design is expected to differ.

A project's own `conventions/frontend.md` names which frontends exist and what each one's design
idiom is.

## No Build Step

- **No build process, ever** — plain static files, deployed exactly as they are authored
- No `package.json`, no `node_modules`, no bundler, no `dist/` directory
- Every library is loaded from a CDN at a **pinned exact version** (`alpinejs@3.16.2`, not
  `alpinejs@3`) so a CDN-side release cannot silently change what ships
- This is a hard constraint, not a default: the Terraform deployment uploads the contents of
  `frontend/` verbatim. **A framework that cannot run without a compile step is not a candidate**

## The Stack

Three libraries, all via CDN:

- **[AlpineJS](https://alpinejs.dev/)** (v3) — lightweight JS framework for interactivity
- **[Tailwind CSS](https://tailwindcss.com/) v4** — utility-first CSS, via the **browser build**.
  **v4 specifically, never v3**: use `@tailwindcss/browser@4.x`, not `cdn.tailwindcss.com`, which
  only ever serves v3 and is unmaintained. Read `reference/tailwind-v4.md` before writing any
  markup or CSS against it — several v3 class names still compile under v4 but mean something else
- **[Pinecone Router](https://github.com/rehhouari/pinecone-router)** (v7) — client-side router for
  AlpineJS, using the external-templates pattern

**Load order in `index.html` is load-bearing and the same everywhere:** Pinecone Router (not
deferred), then `config.js` if the app has one, then any library `app.js` itself depends on
(deferred), then `app.js` (deferred), then AlpineJS (deferred). Alpine calls `Alpine.start()` as
soon as its own script executes, so anything registering `Alpine.data()` must run first; deferred
scripts run in source order, which is what guarantees it.

**Do not add a further library without a reason that survives the no-build-step rule.** The bar is
that the alternative is the wrong kind of original work — hand-writing cryptography, say, whose bugs
surface as intermittent failures rather than as a test going red.

Any CDN script handling credentials must additionally carry a
[Subresource Integrity](https://developer.mozilla.org/docs/Web/Security/Subresource_Integrity) hash
and `crossorigin="anonymous"` alongside its pinned version, so a swapped or compromised artefact
fails closed instead of executing. Get the hash with:

```bash
curl -sL <cdn-url> | openssl dgst -sha384 -binary | openssl base64 -A
```

## Structure

```
frontend/
  index.html     # single entry point
  app.js         # Alpine component definitions + global router config
  config.js      # rendered by Terraform, not hand-authored (only if the app needs one)
  views/*.html   # per-route templates, fetched at runtime by Pinecone Router
  assets/        # images, GIFs, icons (only if the app has any)
```

- `index.html` declares all routes with Pinecone Router's `x-route` + `x-template` directives, and
  holds any application chrome that surrounds *every* route rather than belonging to one of them
- `views/*.html` are plain fragments — no `<html>`/`<head>` of their own — fetched at runtime
- `app.js` holds Alpine component definitions (`Alpine.data(...)` inside an `alpine:init` listener)
  and global router configuration (`targetID`, global handlers)
- **Keep view templates declarative**: state and behaviour belong in an `Alpine.data()` component in
  `app.js`, referenced from the view by name via `x-data`

### Adding a page

Add a `<template x-route>` in `index.html` pointing at a new `views/<name>.html`, and put any
component or global router logic in `app.js`. The CloudFront distribution already rewrites 403/404
to `/index.html`, **so a new route never needs an infrastructure change.**

See `reference/routing.md` for route parameters, guards, the `notfound` route, and the trap where a
parameter change does not re-run `init()`.

## Runtime Configuration

Values that only exist after `terraform apply` (client IDs, API base URLs), or that differ per
deployment of the same checked-in code (which environment this is), are **never hand-authored into a
static file**. Terraform renders `config.js` from a template straight into an S3 object, and that
key is **subtracted from the generic per-file sweep** of `frontend/` so the two resources can never
both manage it. Load it before `app.js`.

**Every app must still render when `config.js` is absent** — it is never checked in, so serving
`frontend/` locally always 404s on it. Give every value read from it a fallback rather than assuming
the file loaded.

## Deployment

Deployment is **entirely Terraform's job**, not a separate sync step. `terraform/frontend.tf`
declares an `aws_s3_object` per file in `frontend/` (via `fileset(..., "**")`), each with
`etag = filemd5(...)` — so editing a file's content is all it takes for the next apply to re-upload
it. **There is no `aws s3 sync` step to remember.**

Content types are set explicitly per file extension (`.html` → `text/html`, …) since S3 does not
infer them and would otherwise serve everything as `application/octet-stream`, which makes browsers
download `index.html` instead of rendering it.

The bucket is **private** — Block Public Access on, no static website hosting endpoint — with
CloudFront the only reader via Origin Access Control. See the `infrastructure` skill's
frontend-hosting reference.

## Design

- Designs are **colourful, fun, and playful** — bold, saturated colours for buttons, highlights and
  interactive elements rather than defaulting to neutral greys
- **Commit to one specific idiom and follow it all the way through**, rather than a generic wash of
  a style. A half-committed aesthetic reads as a mistake; a fully committed one reads as a choice
- **Each frontend must be visually distinct from the others.** They are separate products a user may
  see in the same session and must not be mistakable for one another. This is the one place
  frontends are expected to diverge — the shared stack is not a shared skin. The project's
  `conventions/frontend.md` records which idiom each frontend uses
- Subtle hover and interaction animations enhance interactivity
- **Accessibility is never traded away for the look.** Text meets **WCAG AA** contrast, controls are
  real focusable elements with visible focus, decorative chrome is hidden from assistive technology
  with `aria-hidden`, and animation respects `prefers-reduced-motion`. See
  `reference/accessibility.md` for the settled patterns
- The tone should feel welcoming and energetic — the UI should look like something people enjoy
  using, not just something that works

## Local Development

No build step, so any static file server works:

```bash
# From inside the frontend directory being worked on:
python3 -m http.server 8080   # no install needed
npx serve .                   # one-off, no project dependency
```

Neither replicates CloudFront's 403/404 → `/index.html` rewrite, so **a direct visit to a
client-side route other than `/` will 404 at the server instead of reaching the router.** Navigate
from `/` when testing routing locally, or use a dev server that falls back to `index.html`.

## References

- **`reference/tailwind-v4.md`** — read before writing markup or CSS: CSS-based configuration, how
  the browser build discovers classes, the v3 names that changed meaning, and where hand-written
  CSS must go
- **`reference/routing.md`** — Pinecone Router patterns: external templates, guards, route
  parameters, `notfound`
- **`reference/accessibility.md`** — the settled patterns every screen follows

## Related

- `infrastructure` skill — the S3/CloudFront/ACM/WAF hosting the frontend is deployed onto, and the
  SPA fallback rewrite
- `documentation` skill — documenting a frontend in `architecture/<service>/`
