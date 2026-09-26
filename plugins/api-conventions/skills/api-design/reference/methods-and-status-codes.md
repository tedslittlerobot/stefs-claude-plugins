# Methods and Status Codes

What each HTTP method means on a resource, how writes are shaped, and which status code a success
returns. Error status codes are in `errors.md`.

## Methods

| Method | On a collection | On a resource | Safe | Idempotent |
| --- | --- | --- | --- | --- |
| `GET` | List — see `lists.md` | Read | Yes | Yes |
| `POST` | Create | — (actions: see below) | No | No — see idempotency keys |
| `PATCH` | — | Partial update | No | Yes, as used here |
| `PUT` | — | Full replacement, rarely | No | Yes |
| `DELETE` | — | Delete | No | Yes |

- **`GET` never changes anything.** Not a counter, not a "last viewed" timestamp that anything
  depends on, not a state transition. Crawlers, link previews, prefetchers and retrying proxies all
  issue `GET`s freely, and a `GET /invites/{id}/accept` gets accepted by a chat app's link unfurler
- **`GET` requests have no body.** Many proxies and clients drop it. A query too complex for a query
  string is a sign it should be a resource of its own (a saved search) or, as a last resort, a
  `POST /orders/search` action documented as safe
- **`DELETE` is idempotent**: deleting an already-deleted resource returns `404`, which a retrying
  client treats as success. Deleting a whole collection (`DELETE /orders`) is not offered

## Request Bodies

- **The body is the resource's fields, unenveloped** — see `resources-and-fields.md`
- **Unknown fields are rejected**, with the field named in the error. A typo like
  `"shiping_address"` otherwise succeeds with the address silently not set
- **Read-only fields are rejected** when sent (`id`, `created_at`, a computed `total`), rather than
  ignored. Ignoring them lets a client believe it set a `status` it cannot set
- **Report every validation failure at once**, not the first one found. A form with four mistakes
  should not take four round trips to fix — see `errors.md`

## Create — `POST /<collection>`

- Returns **`201 Created`**, a `Location` header with the new resource's URL, and the **full
  created resource** in `data` — including server-assigned fields (`id`, timestamps, defaults), so
  the client does not need a second request to learn them
- The **server assigns the ID**. A client-chosen ID is a registered exception for the endpoint, used
  for things like offline-first clients

## Update — `PATCH /<collection>/{id}`

`PATCH` is the normal way to change a resource, with these semantics (those of JSON Merge Patch,
RFC 7396, sent as ordinary `application/json`):

- **A key that is present sets the field.** A key that is absent leaves the field unchanged
- **`null` clears a nullable field.** On a non-nullable field it is a validation error
- **Arrays are replaced whole**, not merged or appended to. To add one item to a large collection,
  use the sub-resource: `POST /orders/{order_id}/line_items`
- **Nested objects merge key by key**, following the same rules
- Returns **`200 OK` with the full updated resource**, so the client sees the result of any
  server-side derivation (a recomputed total, an updated `updated_at`)
- An empty body `{}` is a valid no-op and returns the resource unchanged

### Why `PUT` is rare

`PUT` replaces the whole resource, so a client has to send every field — including ones it does not
know about. That makes **adding a field a breaking change**: an older client that `PUT`s a resource
without the new field clears it. Use `PUT` only where a resource genuinely is a document replaced
whole (a settings blob, a file), or for a create-at-a-known-URL; everything else uses `PATCH`.

## Actions — `POST /<collection>/{id}/<verb>`

A state transition with its own rules, side effects or permissions is an **action endpoint**,
named with a `snake_case` verb:

```
POST /orders/{order_id}/cancel
POST /invoices/{invoice_id}/send
POST /users/{user_id}/reset_password
```

- Prefer this over `PATCH { "status": "cancelled" }` whenever changing the field *does* something —
  refunds a payment, sends an email, needs a different permission. An action is discoverable in
  documentation, can take its own parameters (`{ "reason": "customer_request" }`), can be permitted
  separately, and cannot be triggered by accident as part of an unrelated update
- The field it changes (`status`) is then **read-only** through `PATCH`, so there is exactly one way
  to cancel an order
- Returns **`200 OK` with the updated resource**, or `202 Accepted` if it completes asynchronously
- An action that is invalid in the resource's current state (cancelling a shipped order) is a
  `409 Conflict` with a specific code — see `errors.md`

This is a deliberate step away from strict REST, which would model every change as a
representation update. It is here because people think in actions — "cancel the order" — and an
API that makes them translate that into a field update has moved the business rules out of sight.

## Success Status Codes

| Code | When |
| --- | --- |
| `200 OK` | A read, an update or an action, with a body |
| `201 Created` | A create, with the resource and a `Location` header |
| `202 Accepted` | Work was accepted and will complete later — see long-running operations |
| `204 No Content` | Success with nothing to return, typically `DELETE`. No body at all |

Use these four and nothing more exotic. Every other success code is something a person has to look
up, and clients routinely handle only these.

## Idempotency Keys

A `POST` that creates something or has side effects accepts an **`Idempotency-Key` header** — a
client-generated unique string, typically a UUID:

```bash
curl -X POST https://api.example.com/v1/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: 9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d" \
  -H "Content-Type: application/json" \
  -d '{ "amount": { "amount": "12.50", "currency": "GBP" }, "customer_id": "cus_3k9d2" }'
```

- The server stores the key with the response for a documented period (typically 24 hours). A
  retry with the same key **returns the stored response** instead of performing the operation again
- The same key with a **different body** is an error (`409`, code `idempotency_key_reused`) — it is
  a client bug, and guessing which request was meant is worse
- A request still in flight when its retry arrives gets a `409` with a code saying so

Without this a network timeout leaves the client unable to know whether the request happened.
Retrying may charge a card twice; not retrying may lose the order. The key makes retry always safe,
which means clients can be told simply: *on a timeout or `5xx`, retry with the same key*.

## Optimistic Concurrency

Where two people editing the same resource would silently overwrite each other's work, use
entity tags:

- `GET` returns an **`ETag`** header identifying the representation's version
- `PATCH`, `PUT` and `DELETE` accept **`If-Match: <etag>`**. If the resource has changed since, the
  write is refused with **`412 Precondition Failed`** and the client re-reads before trying again
- Offer it where lost updates matter (shared documents, configuration); it need not be mandatory
  everywhere. Where it is required for an endpoint, a write without `If-Match` is a
  `428 Precondition Required`

## Long-running Operations

An operation that cannot finish within a normal request (an export, a bulk import, a report):

- Returns **`202 Accepted`** with a **job resource** in `data`, and a `Location` header
  pointing at it:

  ```json
  {
    "data": {
      "id": "job_4c8e1",
      "status": "pending",
      "created_at": "2026-09-26T14:03:12Z",
      "completed_at": null,
      "result_url": null,
      "error": null
    }
  }
  ```

- The client polls `GET /jobs/{job_id}`. `status` moves through `pending`, `running`, then
  `succeeded` or `failed`; on success `result_url` (or the result itself) is filled in, on failure
  `error` holds an error object in the same shape as `errors.md`
- The response may carry `Retry-After` to say how long to wait before polling
- Never hold a request open for minutes waiting for work to finish — gateways and proxies time out
  long before that, and the client cannot tell a timeout from a failure

## Bulk Operations

Offer bulk endpoints only where clients genuinely need them, as an action on the collection
(`POST /orders/bulk_cancel`, body `{ "order_ids": [...] }`). They are hard to get right, so:

- **Say whether it is all-or-nothing or per-item**, and prefer all-or-nothing where the store
  allows it. A partial success is the hardest result for a person to reason about
- A per-item operation returns **`200` with a result per item**, in request order, each carrying
  either the resource or an error object — and the caller must check each one
- Bound the batch size and document it, like `page_size`
