# Resources and Fields

How resources are addressed, and how their representation is shaped, named and typed.

## URLs

### Anatomy

Every path is built from the same parts, in the same order:

```
/api [/<service prefix>…] [/me] /<resources and verbs>

/api/posts/{post_id}/comments       # resources only
/api/billing/invoices               # a service prefix, then a resource
/api/billing/me/invoices            # a service prefix, the current user, then a resource
/api/auth/login                     # a non-resource scope, then a verb
```

- **`/api` comes first**, always — the `infrastructure` skill's frontend-hosting reference gives the
  reason
- **Project- or service-specific prefixes come next**, after `/api` and before any resource, `me`
  or other segment: `/api/billing/…`, `/api/reporting/…`. Which prefixes exist is a project
  decision, recorded in its `conventions/api.md`; a path does not invent a prefix that file does
  not list
- **`/me` comes next**, when the endpoint returns resources belonging to the current user — see
  "The Current User" below
- **Then the resources and verbs** the rest of this section describes
- **There is no version prefix** anywhere in that sequence — no `/api/v2/…`. Changes should be
  non-breaking wherever possible, and when a resource genuinely has to break, only that resource is
  versioned, with a suffix: `/api/users-v2`. See `versioning.md`

### What a path may name

Every route is one of these, and a path is read as a sequence of them:

| Kind | Example | Methods |
| --- | --- | --- |
| **A collection** | `/api/posts` | `GET` to list, `POST` to create |
| **A resource** | `/api/posts/{post_id}` | `GET`, `PATCH`, `PUT`, `DELETE` |
| **A singleton** | `/api/me/profile` | `GET`, `PATCH` |
| **A verb on a resource** — preferred | `/api/orders/{order_id}/cancel` | `POST` |
| **A verb on a collection** — preferred | `/api/orders/bulk-cancel`, `/api/invoices/export` | `POST` |
| **A verb in a non-resource scope** | `/api/auth/login`, `/api/auth/logout` | `POST` |
| **A top-level verb** — acceptable | `/api/search` | `POST` (or `GET` if it is safe) |

- **Create, read, update and delete are never verbs in a path.** They are what the HTTP methods
  already say: `POST /api/posts`, not `/api/posts/create`; `PATCH /api/posts/{post_id}`, not
  `/api/posts/{post_id}/update`; `DELETE`, not `/delete`; `GET /api/posts`, not `/api/get-posts` or
  `/api/posts/list`. A verb in the path that repeats the method gives a reader two things to check
  and a chance for them to disagree
- **Explicit verbs are for operations that are not plain CRUD** — a state transition, a side
  effect, a computation. Scope a verb to the resource or collection it acts on wherever there is
  one: `/api/orders/{order_id}/cancel` says what is cancelled without any documentation
- **A non-resource scope may group verbs by responsibility.** `/api/auth/login`,
  `/api/auth/logout` and `/api/auth/refresh` sit under `auth`, which is not a resource — nothing is
  listed, fetched or created at `/api/auth` — but an area of responsibility, and it tells the
  reader what the verbs are about as clearly as a resource would
- **A top-level verb is acceptable where nothing scopes it** — a search across several resource
  types, say. It is the least preferred form, because a bare verb says nothing about what it acts
  on: check first whether it belongs to a resource, a collection or a scope
- Verbs lead with the verb, in `kebab-case`: `reset-password`, `bulk-cancel`, `export`. The rules
  for what an action endpoint accepts and returns are in `methods-and-status-codes.md`

### Naming

- **Collections are plural nouns**: `/orders`, `/customers`, `/line-items`. A single resource is
  the collection plus its ID: `/orders/{order_id}`
- **Path segments are `kebab-case`**: `/line-items`, `/shipping-address`,
  `/users/{user_id}/reset-password`. Hyphens are the web's own idiom for words in a URL — they read
  cleanly in an address bar and a log line, they survive being shown as an underlined link (where an
  underscore disappears into the underline), and search engines and most tools treat them as word
  separators
- **Everything else stays `snake_case`.** Path *parameter names* in documentation (`{order_id}`),
  query parameters, and any value that names a JSON key — so it is `/orders/{order_id}/line-items`
  but `?include[]=line_items`, because `include[]` names the key the related resource will appear
  under. The rule of thumb: a path segment is part of an **address**, and is kebab-case; anything
  that names **data** is snake_case
- **Lowercase only**, no trailing slash, no file extensions (`/orders.json`)
- **Singletons are singular**: `/me/profile`, `/orders/{order_id}/shipping-address` — there is
  exactly one, so a plural would suggest a list that never comes
- **Path parameters are named for what they are** in documentation — `{order_id}`, not `{id}` —
  so a path with two IDs in it is still unambiguous to read

**Corrected:** path segments used to be `snake_case` (`/line_items`), so that a collection's URL
matched the JSON key it is embedded under. That consistency is between two things nobody confuses —
an address and a data key — and it cost the URL the conventions every other website uses.

### Nesting

A resource is nested under another in exactly two cases:

- **It is only, or primarily, accessed through that relationship.** `/api/posts/{post_id}/comments`
  — comments are read as *a post's* comments, and a comment is addressed within its post:
  `/api/posts/{post_id}/comments/{comment_id}`
- **It is scoped to the current user**: `/api/me/posts` nests the caller's posts under them, even
  though posts are otherwise a top-level collection. See "The Current User" below

Everything else is top-level. A resource that is regularly wanted on its own, or across parents —
every order regardless of customer, one order by its ID from an email link — gets its own route,
and the relationship becomes a filter: `/api/orders?filter[customer_id]=…`. Nesting it would force
every caller to know the parent just to address it.

- **Nest one level below a resource at most.**
  `/api/customers/{customer_id}/orders/{order_id}/line-items` is too deep — deep paths make a client know the whole ancestry to address a leaf, and they break
  when a relationship turns out to be many-to-many. The `/me` scope and service prefixes are not
  resources, and do not count as a level
- A nested collection behaves like any other — the same list parameters, pagination and errors

**Corrected:** nesting used to be allowed "only for genuine ownership" — a line item cannot exist
without its order. Existence was the wrong test: what decides whether a URL should be nested is how
the resource is *reached*, and a resource that is only or mainly reached through its parent is
nested whether or not it could exist without it. The `/me` case was also not stated here.

## The Current User: `/me/`

**An endpoint that returns resources belonging to the current, authenticated user starts with a
`/me/` path segment**, straight after `/api` and any service prefix — `/api/me/posts`,
`/api/billing/me/invoices`:

```
GET /api/me                  # the current user
GET /api/me/profile          # their profile — a singleton
GET /api/me/posts            # the posts they wrote
GET /api/me/posts/{post_id}  # one of them
POST /api/me/posts           # write one, as them
```

**An endpoint without `/me/` is general purpose.** `/api/posts` is *the* posts collection: it
returns what the caller is permitted to see, and it may well check permissions against the current
user, but it is never quietly narrowed to "the caller's own posts". Those are `/api/me/posts`.

- **Whose data it is, is in the URL.** A person reading `/api/me/posts` in a log, a browser tab or
  a code review knows it is the caller's posts; reading `/api/posts` they know it is not. An
  endpoint whose meaning changes with who calls it, without saying so, is read wrongly by everyone
  who did not write it
- **There is no user ID to tamper with.** Under `/me/` the user comes from the credentials and
  nowhere else — never from a path, query or body parameter. `/api/users/{user_id}/posts` called
  with the caller's own ID works right up until someone changes the ID, and whether that leaks
  another user's posts depends on an authorization check that has to be remembered on every such
  endpoint. `/api/me/posts` has no ID to change
- **Something under `/me/` that is not the caller's is `404`**: `/api/me/posts/{post_id}` for a
  post someone else wrote does not exist *for this caller* — see `auth-and-limits.md`
- **`/me/` is a scope, not a nesting level.** `/api/me/posts/{post_id}/comments` is one level of
  nesting under `posts`, the same as `/api/posts/{post_id}/comments` would be
- **A general endpoint may still be filtered by user**: `/api/posts?filter[author_id]=…` is a
  general query that happens to name an author, and it answers the same way for every caller who is
  allowed to see those posts. It is not a substitute for `/me/posts`, because it takes the user ID
  from the request
- Every `/me/` response varies by caller, so it is never shared-cacheable — see the caching rules
  in `auth-and-limits.md`

## The Envelope

Every response body is a JSON object with exactly one of two top-level keys, plus whatever
metadata the response type defines:

```json
{ "data": { "id": "ord_8f2k1", "status": "paid", "...": "..." } }
```

```json
{ "data": [ { "id": "ord_8f2k1" }, { "id": "ord_9a7x3" } ], "pagination": { "...": "..." } }
```

```json
{ "error": { "code": "not_found", "message": "No order exists with ID ord_0000." } }
```

- **`data`** holds the resource (an object) or the resources (an array)
- **`error`** holds the error — see `errors.md`. A body never has both
- **List metadata sits beside `data`**, not inside it: `pagination` — see `lists.md`
- A success response with nothing to say is `204 No Content` with **no body at all**, not
  `{ "data": null }`

The envelope is applied to single resources too, even though a bare object would be slightly
shorter. Consistency is the reason: a client — and a person reading a response — checks `data` or
`error` on every call and never has to remember which endpoints wrap and which do not. It also
leaves room for response-level metadata (a deprecation notice, a warnings list) without a breaking
change.

**Request bodies are not enveloped.** A `POST` or `PATCH` body is the resource's fields directly.
The envelope exists to carry response metadata and to separate success from failure, and a request
has neither; wrapping it only adds a level every caller has to type.

## Field Naming

- **`snake_case`**, full words, no abbreviations — see the `SKILL.md` principles
- **The same concept has the same name in every resource.** If one resource calls it `email`,
  another does not call it `email_address`
- **References to another resource are `<resource>_id`**: `customer_id`, `order_id`. A reference to
  several is `<resource>_ids`, an array
- **Booleans read as a yes/no question** and are phrased positively: `is_active`, `has_attachments`,
  `can_edit` — not `active` (a noun or a state?) and not `is_disabled` (a double negative the moment
  it is `false`)
- **Units go in the name** whenever a number has one: `timeout_seconds`, `weight_grams`,
  `file_size_bytes`. A bare `timeout: 30` is the most reliable source of off-by-a-thousand bugs
  there is
- **Counts are `<thing>_count`**: `line_item_count`, not `line_items` (which should be the items)
  or `num_items`

## Data Types

### IDs

- **Always JSON strings**, even when the underlying value is an integer. JavaScript represents
  every number as a double, so an integer above 2^53 — a 64-bit database ID, a snowflake ID —
  silently loses its last digits in a browser client: two different records then share an ID, and
  the wrong one gets updated. A string is never rounded
- **Opaque to the client.** Clients compare and pass IDs back; they never parse them, sort by them
  or construct them. That leaves the server free to change the format
- The project chooses the format (UUIDv7, prefixed IDs like `ord_8f2k1`, …) and records it in its
  `conventions/api.md`. Type-prefixed IDs are worth considering for human use: an `ord_` ID pasted
  into a `/customers/` URL is recognisably wrong at a glance

### Timestamps and dates

- **Instants are RFC 3339 strings in UTC with a `Z` suffix**: `"2026-09-26T14:03:12Z"`. Fractional
  seconds only if the precision is real and needed, and then consistently
- Not epoch integers — `1790431392` means nothing to a person reading a response, and seconds
  versus milliseconds is a guess
- Not local times or offsets — converting for display is the client's job, and a server that
  returns offsets forces every comparison to normalise first
- **Calendar dates** (a birthday, a due date — no time of day, no timezone) are `YYYY-MM-DD`
  strings. Encoding one as midnight UTC makes it the previous day for everyone west of Greenwich
- **Naming:** `<event>_at` for instants (`created_at`, `cancelled_at`), `<event>_on` for dates
  (`due_on`, `born_on`). The suffix tells the reader the type before they see a value
- Every resource has `created_at` and `updated_at`

### Money

- **An object with a decimal string amount and an ISO 4217 currency code**:
  `"total": { "amount": "12.50", "currency": "GBP" }`
- A string, because a JSON number is parsed as a floating-point double by most clients, and
  `0.1 + 0.2` is not `0.3`. A decimal string survives exactly and is still readable at a glance —
  which an integer in minor units (`1250`) is not, and minor units also vary by currency (the yen
  has none)
- Currency travels with the amount, always. An amount without a currency is a bug waiting for the
  second currency

### Enums

- **Lowercase `snake_case` strings**: `"status": "awaiting_payment"`. Never integers — `"status": 3`
  is unreadable without the documentation open beside it
- Externally standardised codes keep their standard form: ISO 4217 currencies (`GBP`), ISO 3166
  countries (`GB`), IANA timezones (`Europe/London`), BCP 47 language tags (`en-GB`)
- Clients must tolerate a value they do not recognise — see `versioning.md`

### Nulls, absence and empties

- **Every documented key is always present in a response.** A key with no value is `null`, not
  omitted. A shape that varies with the data forces every client to guard every access, and a
  person reading one response cannot learn the shape from it
- **An empty list is `[]`, never `null`.** "There are none" and "unknown" are different facts, and
  `[]` lets a client iterate without a check
- **No sentinel values**: not `-1` for "unlimited", not `""` for "not set", not
  `"1970-01-01T00:00:00Z"` for "never". Use `null`, or a separate field (`is_unlimited`) where
  `null` would be ambiguous
- **No empty strings as values**: normalise `""` in a request to `null` if the field is nullable,
  or reject it — two representations of "nothing" means every query has to check for both

### Numbers and booleans

- Booleans are JSON `true`/`false` — never `"true"`, `1` or `"Y"`
- Integers are JSON integers where they are genuinely counts or small quantities; anything that is
  an identifier, a code or money is a string (see above). A phone number, a postcode or an account
  number is a string: it has leading zeros and no arithmetic

## Related Resources

- **A relation is always referenced by ID**: `"customer_id": "cus_3k9d2"`, present whether or not
  the related resource is also returned
- **When a related resource is returned, it is a nested object** under the relation's key, inside
  the resource it belongs to — `"customer": { ... }` on the order, `"line_items": [ ... ]` as an
  array of objects. Not flattened into the parent as a handful of copied fields (`customer_name`,
  `customer_email`), and not sideloaded into a separate top-level list keyed by type, as JSON:API's
  `included` does
- Nesting is preferred because it is how a person reads the data: the customer is *on* the order.
  A sideloaded response makes every client — and every person reading one in a terminal — join it
  back together by ID; a flattened one freezes an arbitrary subset of the related resource's
  fields, and grows another `customer_<something>` field each time someone needs one more
- The cost is repetition — a page of orders from one customer repeats that customer on each. That
  is accepted: it keeps each item self-contained, and response compression (see
  `auth-and-limits.md`) removes most of the bytes
- **Which relations are returned** is the endpoint's choice, documented: one that clients nearly
  always need (an order's line items) may be nested by default; the rest are nested on request
  with `include[]`:
  `GET /orders/ord_8f2k1?include[]=customer&include[]=line_items`. Either way the related resource
  appears under its own key *alongside* the ID, which stays:

  ```json
  {
    "data": {
      "id": "ord_8f2k1",
      "customer_id": "cus_3k9d2",
      "customer": { "id": "cus_3k9d2", "name": "Ada Lovelace", "...": "..." },
      "line_items": [ { "id": "li_1", "...": "..." } ]
    }
  }
  ```

- Each resource documents which relations it nests by default and which it can include. An
  unknown `include[]` value is an error, like any unknown parameter
- When a relation is includable but was not included, its key is **absent** — the one place a
  documented key may be missing, because the client controls it explicitly. A `null` would claim
  there is no customer
- Includes nest one level (`include[]=line_items.product`) at most, and only where documented —
  unbounded expansion is a denial of service waiting for a curious client
- Embedded resources are the relation's normal representation, not a special cut-down one — a
  person should recognise a `customer` wherever it appears

## Sparse Fields

A client may restrict a response to named fields with `fields[]`:
`GET /orders?fields[]=id&fields[]=status&fields[]=total`. `id` is always returned. Offer this where
resources are large or lists are long and bandwidth matters, not by default on every endpoint — it
is an optimisation, and every optional parameter is something a reader has to understand. An
unknown field name is an error.
