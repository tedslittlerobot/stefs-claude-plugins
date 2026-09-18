# API Documentation

Two documents describe every service's HTTP surface, and they are not alternatives: the OAS file is
the contract, the `api.md` overview is the map.

## OpenAPI Specification

- All API endpoints **must** be documented using **OpenAPI Specification (OAS) in YAML format**
- Use **OAS 3.1.x**
- The OAS file is **co-located with the service it describes** (`<service>/openapi.yaml`), not
  collected in a central docs directory — it belongs to the service and is versioned with it
- Document all request/response schemas, path parameters, query parameters, headers and status codes
- **Distinguish public from private endpoints using the `security` field.** Private endpoints
  reference the JWT security scheme; public endpoints carry an explicit empty `security: []`
  override. An omitted `security` field inherits the document default, which makes "public" and
  "forgot to say" indistinguishable — always be explicit
- **The OAS file is the source of truth for the API contract.** Update it in the same change as any
  Lambda or API Gateway change. An endpoint whose behaviour has moved on from its spec is worse
  than an undocumented one

## API Overview Documents

Alongside the OAS file, every service has an API overview at `architecture/<service>/api.md`. This
is a high-level map of the service's HTTP surface — enough to understand what the API offers and how
it is protected without opening the spec.

It deliberately does **not** replace the OAS file: no exhaustive schemas, no per-status-code
enumeration, no worked examples. **If the two disagree, the OAS file wins and `api.md` is the thing
to correct.**

### Structure

1. **Intro** — one or two paragraphs: where the API is served from (CDN, gateway, base URL/path
   prefix), what protects it (WAF, authorizers), which clients consume it, and anything notable that
   is *not* part of this API (e.g. calls the client makes straight to the identity provider). That
   last point matters more than it looks: a reader who cannot see what is absent will assume the
   document is incomplete.
2. **Endpoints** — a "table of contents" style linked list, one line per endpoint, giving the method
   and path and linking to that endpoint's section, with a public/private marker and a few words of
   summary. **Order by path, then by method within a path.**
3. **One section per endpoint**, `### <METHOD> <path>`, as subsections beneath that list.

### Per-endpoint sections

Each endpoint section contains exactly these four, in order:

- **Auth** — public or private; which authorizer and token type; any authorization rule beyond
  authentication (e.g. the caller can only ever read their own record). Authentication and
  authorization are different questions and readers need both answered
- **Description** — one to three sentences on what the endpoint does, linking to the Lambda
  directory that serves it
- **Request** — the request body shape and any path/query parameters, as a short TypeScript
  `interface` block (the same syntax as a Lambda's `schema.md`) or a short bullet list. Key fields
  only
- **Response** — the success body shape, plus a one-line note on the notable failure modes. Not
  every status code — the OAS file has those

### Linking convention

Use the GitHub heading-anchor slug of the endpoint's section: lowercased, with `/` and other
punctuation removed and spaces turned into hyphens. So `### GET /api/me/profile` is linked as
`[GET /api/me/profile](#get-apimeprofile)`.

### Services with no HTTP API

**A service with no HTTP API still gets an `api.md`.** It states that plainly and describes the
interfaces it *does* expose — queues, hosted identity flows, manually invoked Lambdas — so readers
are not left wondering whether the document is simply missing.

So does a service that will **never** have one. Say so explicitly: "not built yet" and "not part of
this service's design" are different facts, and a reader cannot tell them apart from an empty
endpoint list.
