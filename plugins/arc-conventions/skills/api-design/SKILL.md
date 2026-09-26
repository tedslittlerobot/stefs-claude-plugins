---
name: api-design
description: HTTP/JSON API design conventions — request and response formats, snake_case keys and query parameters, kebab-case URL paths, arrays in query strings as repeated name[] parameters (never comma-separated strings), the data/error response envelope, resource URLs, HTTP methods and status codes, list and index endpoints (q text search, filter[...] parameters, sort[], page and per_page pagination, the pagination object, cursor pagination), the error response format, 400 versus 422 and validation errors, IDs, timestamps, money, enums and nulls, PATCH semantics, idempotency keys, versioning by resource suffix (users-v2) and breaking changes, auth headers and rate limiting. Use when designing, building, reviewing or documenting a REST or HTTP API, an endpoint, controller or route handler, an OpenAPI schema, a JSON request or response payload, or an API client, or when asked how an endpoint should paginate, filter, sort, search or report an error.
---

# API Design Conventions

These are the rules for every HTTP/JSON API a project builds. They are a record of current good
practice, **not** an implementation of any one specification — they borrow from JSON:API, RFC 9457,
and the public APIs people find easiest to use, and depart from each wherever the departure is
easier for a person to read, guess and debug. A project records its own chosen values and
registered exceptions in `conventions/api.md`; where that file and this skill disagree, **the
project file wins** (see the `conventions` skill for the two-layer model).

## Principles

The first reader of an API is a person — reading its documentation, typing a `curl` command,
squinting at a response in a terminal, or reading a client's code a year later. Every rule below
follows from designing for that person first and for the machine second, because a machine will
cope with whatever it is given and a person will not.

- **Guessable beats clever.** Someone who has used one endpoint should be able to guess the shape
  of the next. The same concept has the same name, type and format everywhere it appears — a
  `customer_id` is never a `client_id` in another resource, and a timestamp is never an epoch
  integer in one place and a string in another
- **Explicit beats implicit.** Every documented key is always present, with `null` for "no value";
  array parameters look like arrays; ranges say whether they are inclusive. A reader should never
  have to know an unwritten rule to read a request or a response correctly
- **Strict in what it accepts.** Unknown query parameters, unknown body fields, malformed values
  and read-only fields are *rejected* with an error that names them, never silently ignored. This
  deliberately inverts Postel's law: a lenient API turns typos into silent wrong answers —
  `?filter[stauts]=paid` ignored as unknown returns *every* order, and a script built on that
  result refunds, deletes or emails the lot. Leniency also becomes contract: once a client relies
  on a quirk being accepted, it cannot be removed
- **Errors are written to be acted on.** An error says what was wrong, where, and how to fix it,
  in a sentence a person can read, alongside a stable code a program can switch on. See
  `reference/errors.md`
- **Full words, no abbreviations.** `description`, `quantity`, `organisation_id` — not `desc`,
  `qty`, `org_id`. An abbreviation saves the writer a keystroke and costs every reader a guess, and
  two people abbreviate the same word differently
- **Don't leak the storage model.** The API models resources as a client thinks of them, not as
  tables. Join tables, internal status flags, column names chosen for the database and
  auto-increment IDs are implementation details; exposing them makes every schema change an API
  change
- **Safe, documented defaults.** A request that omits an optional parameter gets the behaviour
  that is least surprising and least dangerous, and the documentation says what that is
- **Usable from a terminal.** Every endpoint can be exercised with `curl` and a bearer token: JSON
  in, JSON out, no bespoke encodings, no required client library. If an example in the
  documentation cannot be pasted into a shell and run, the design is the problem

## Core Rules

These hold everywhere; the reference files give the detail and the reasoning.

- **JSON in, JSON out**, `Content-Type: application/json`, UTF-8. No form-encoded or XML bodies
- **All keys and parameter names are `snake_case`** — JSON body keys, query parameters, path
  parameter names in documentation, error codes and enum values. One casing for everything that
  names data means no one has to remember which part of the payload uses which
- **URL path segments are `kebab-case`** — `/line-items`, `/orders/{order_id}/bulk-cancel`. A path
  is an address, and hyphens are the web's idiom for words in one. HTTP header names keep HTTP's
  own `Hyphenated-Case`
- **Arrays are always arrays — never comma-separated strings.** In a JSON body that is a JSON
  array. In a query string it is the parameter repeated with a `[]` suffix:
  `?filter[status][in][]=paid&filter[status][in][]=refunded`. A single value is still
  `filter[status][in][]=paid`, an array of one. A comma-joined value is never split. A
  comma-joined string breaks the first time a value contains a comma (a tag, a name, an address),
  pushes a bespoke parsing step into every client and server, and makes an array
  indistinguishable from a scalar that happens to contain a comma. See `reference/lists.md`
- **Every response body is an object with a top-level `data` or `error` key** — `data` for success
  (an object for one resource, an array for a list), `error` for failure. Never a bare array, never
  a bare resource. A bare array cannot grow a `pagination` key later without breaking every client
- **Resources live at plural, `kebab-case` collection URLs** — `/orders`, `/orders/{order_id}`,
  `/orders/{order_id}/line-items` — nested at most one level deep
- **Lists keep a tidy top level**: filters nest under `filter[...]` — plain equality, `[in][]` for
  any of several values, and `[gt]`/`[gte]`/`[lt]`/`[lte]` for ranges — text search is `q`, and
  pagination is **page-based by default** with `page` and `per_page` (default 25, maximum 150) and
  a `pagination` object of `current_page`, `per_page`, `total_pages` and `total_items`. Cursor
  pagination is for data that is very large, of unknown size, or volatile. See `reference/lists.md`
- **IDs are strings in JSON, always** — even when they are numbers underneath
- **Timestamps are RFC 3339 strings in UTC with a `Z`**, named `<event>_at`
  (`"created_at": "2026-09-26T14:03:12Z"`); calendar dates are `YYYY-MM-DD`, named `<event>_on`
- **Status codes mean what HTTP says they mean.** A `200` never carries an error; a failure is
  never reported with a success code. See `reference/methods-and-status-codes.md`
- **A validation failure is a `422`; a malformed request is a `400`.** A `422` — a value fails an
  input constraint, and the user can fix it by changing an answer — lists every invalid parameter
  with a code and a message fit to show the user. A `400` is a bug in the client. See
  `reference/errors.md`
- **Out-of-range input errors loudly, now** — a `per_page` of 500 is a `422` stating the maximum,
  never silently clamped to 150. A silent correction surfaces later, far from its cause, as data
  that seems to be missing
- **Adding is safe, changing is breaking — and avoid versioning.** A new optional field or
  endpoint is not a new version; renaming, removing or retyping anything is. When a resource
  genuinely must break, the replacement is a new resource with a suffix — `/api/users-v2` beside
  `/api/users` — never a version prefix on the whole API. See `reference/versioning.md`

## Before Designing an Endpoint

1. Read the project's `conventions/api.md` if it exists — it carries the project's chosen values
   (ID format, which endpoints use cursor pagination and why) and any registered exceptions
2. Find the nearest existing endpoint for a similar resource and match its names and shapes; a new
   endpoint that is consistent with a slightly imperfect neighbour beats a perfect one that is not
3. Write the example request and response **first**, as a `curl` command and its JSON output, and
   read it as a newcomer would. If it needs explaining, change the design rather than the
   documentation

## References

- **`reference/resources-and-fields.md`** — kebab-case URLs and nesting, the response envelope,
  field naming, data types (IDs, timestamps, money, enums, booleans, nulls), related resources and
  `include[]`, sparse `fields[]`
- **`reference/methods-and-status-codes.md`** — what each method means, request bodies, `PATCH`
  semantics, action endpoints, success status codes, idempotency keys, optimistic concurrency,
  long-running and bulk operations
- **`reference/lists.md`** — list and index endpoints: the list response, the top-level
  parameters, array query parameters, `filter[...]` and range operators, `q` search, sorting,
  page-based pagination and when to use cursors instead
- **`reference/errors.md`** — the error body, error codes, `400` versus `422`, detail codes and
  field paths, the status code table, and what an error must never contain
- **`reference/versioning.md`** — what is and is not a breaking change, what clients must
  tolerate, versioning a single resource with a `-v<n>` suffix, and deprecation
- **`reference/auth-and-limits.md`** — authentication headers, `401` versus `403` versus `404`,
  request IDs, rate limiting, CORS, and caching headers

## Related

- `documentation` skill — its API-docs reference covers the OpenAPI file that is the contract for
  an API designed here, and the `api.md` overview beside it
- `lambdas-go` / `lambdas-node` skills — an API route is served by an `api-<method>-<purpose>`
  Lambda, one per route; this skill decides what that Lambda accepts and returns
- `infrastructure` skill — its frontend-hosting reference explains why every route sits under an
  `/api` path prefix
- `mysql` skill — shares the `snake_case` naming, which lets a field keep one name from column to
  JSON key; the rule above against leaking the storage model still decides *whether* a column is
  exposed
- `conventions` skill — how the project's own `conventions/api.md` sits on top of this skill, and
  precedence when they disagree
