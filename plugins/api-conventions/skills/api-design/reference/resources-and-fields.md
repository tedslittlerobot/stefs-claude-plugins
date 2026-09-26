# Resources and Fields

How resources are addressed, and how their representation is shaped, named and typed.

## URLs

- **Collections are plural nouns**: `/orders`, `/customers`, `/line_items`. A single resource is
  the collection plus its ID: `/orders/{order_id}`
- **Path segments are `snake_case`**, the same casing as keys. The collection a resource lives at
  then matches the key it appears under when embedded — `/line_items` and `"line_items": [...]` —
  so there is one name to learn rather than a URL spelling and a JSON spelling
- **Lowercase only**, no trailing slash, no file extensions (`/orders.json`)
- **Nest at most one level**, and only for genuine ownership: `/orders/{order_id}/line_items`
  exists because a line item cannot exist without its order.
  `/customers/{id}/orders/{id}/line_items` does not — deep paths force a client to know the whole ancestry just to address a leaf, and they
  break when a relationship turns out to be many-to-many. Anything reachable by ID alone gets a
  top-level route, and a cross-cutting view is a filter: `/orders?customer_id[]=...`
- **Singletons are singular**: `/me`, `/orders/{order_id}/shipping_address` — there is exactly one,
  so a plural would suggest a list that never comes
- **Path parameters are named for what they are** in documentation — `{order_id}`, not `{id}` —
  so a path with two IDs in it is still unambiguous to read
- Verbs appear in a path only as **action endpoints** — see `methods-and-status-codes.md`

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

- **By default a resource references others by ID**: `"customer_id": "cus_3k9d2"`. Responses stay
  small, predictable and cacheable
- **A client may ask for related resources to be embedded** with `include[]`:
  `GET /orders/ord_8f2k1?include[]=customer&include[]=line_items`. The related resource then
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

- Each resource documents which relations it can include. An unknown `include[]` value is an
  error, like any unknown parameter
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
