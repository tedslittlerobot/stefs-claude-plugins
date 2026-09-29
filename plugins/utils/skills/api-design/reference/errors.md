# Errors

An error response has two readers: a program deciding what to do next, and a person working out
what went wrong. It serves both with one shape, everywhere, for every failure the API can produce —
including the ones produced by a gateway or framework in front of the handler.

## The Error Body

A `422`, for example — the same shape serves every error status:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "2 answers need correcting.",
    "details": [
      {
        "source": "body",
        "path": ["email"],
        "code": "invalid_format",
        "message": "Must be a valid email address, like name@example.com."
      },
      {
        "source": "body",
        "path": ["line_items", 2, "quantity"],
        "code": "too_small",
        "message": "Must be at least 1."
      }
    ],
    "request_id": "req_7h2m9x4k",
    "documentation_url": "https://example.com/docs/errors#validation_failed"
  }
}
```

| Key | Always present | Holds |
| --- | --- | --- |
| `code` | Yes | A stable, `snake_case`, machine-readable identifier for the kind of error |
| `message` | Yes | A sentence for a person: what went wrong and, where possible, how to fix it |
| `details` | Yes — `[]` when there is nothing to add | One entry per specific problem, each with its own `source`, `path`, `code` and `message` |
| `request_id` | Yes | The ID of this request, matching the `Request-Id` response header — see `auth-and-limits.md` |
| `documentation_url` | Optional | A link to the documentation for this `code` |

- **`code` is the contract; `message` is not.** Programs switch on `code`. Messages are free to be
  reworded, improved and translated, and a client that string-matches a message will break the
  first time someone fixes a typo in it. A `code`, once published, never changes meaning
- **The status code and the error code agree.** The HTTP status gives the class of failure; `code`
  narrows it. Neither contradicts the other
- The body is served as `application/json`, the same as every other response

### Writing the message

- **A full sentence, in plain language, that a person can act on**: "Must be at least 1.",
  "No order exists with ID ord_0000.", "per_page must be between 1 and 150; got 500."
- **Write for the person who can fix it.** A `422` is fixed by the person using the client, so its
  messages are written to be **shown to them as they are** — a UI puts each detail's message beside
  its field without rewriting it, so it does not lean on parameter names or API jargon. A `400` is
  fixed by the developer of the client, so its messages name parameters and forms exactly — see
  "400 or 422" below
- **Say how to fix it** when the fix is known: "Use filter[status][in][] to pass several
  statuses, for example ?filter[status][in][]=paid&filter[status][in][]=refunded." An error that
  names the correct form is the cheapest documentation an API has, because it is read at exactly
  the moment it is needed
- **Include the offending value** where it is safe to echo, and the allowed values where they are
  a short list
- Do not start with "Error:" or end with a stack of codes; it is already an error, and the codes
  have their own keys

### Why not RFC 9457 (Problem Details)?

RFC 9457 standardises an error body (`type`, `title`, `status`, `detail`, `instance`, served as
`application/problem+json`). It is a reasonable format, and a project may adopt it as a registered
choice in `conventions/api.md`. The shape here is preferred by default because it fits the
envelope — every response is `data` or `error`, so a client checks one key to know which it has —
because a short `code` is easier to read, type and switch on than a `type` URI, and because RFC
9457 leaves the structure of per-field validation errors undefined, which is the part clients most
need to be consistent.

## 400 or 422

Invalid input gets one of two statuses, and the line between them is **who can fix it**:

| Status | `code` | Means | Fixed by |
| --- | --- | --- | --- |
| `422 Unprocessable Content` | `validation_failed` | The request is well formed, but one or more values fail an input constraint or validation rule | **The person using the client**, by changing an answer |
| `400 Bad Request` | `invalid_request` | The request itself is malformed, or uses the API in a way it does not support | **The developer of the client**, by changing the code |

The test: **could the person filling in the form fix this by changing what they entered?** If yes,
it is a `422`; if no answer they could give would help, it is a `400`.

| `422` — a value fails a constraint | `400` — the request is malformed |
| --- | --- |
| A required field is missing or empty | The body is not parseable JSON |
| An email, date or postcode is in the wrong format | A value has the wrong JSON type — a string where a number belongs |
| A number is too small or too large; a string too long or too short | An unknown field in the body, or an unknown query parameter |
| A value is not one of the allowed values (`filter[status]=payed`) | A read-only field was sent |
| `per_page` above 150, `page` below 1, or more `[in][]` values than the documented cap | An array parameter without its `[]` (`filter[status][in]=paid`) |
| A range whose lower bound is above its upper bound | An unknown `filter`, filter operator, `sort[]`, `include[]` or `fields[]` name |
| A value that must be unique is already taken (an email address) | |

- **A `422` lists every invalid parameter**, one `details` entry each, with its own `code` and a
  message presentable to the user as it is. Its top-level `message` summarises them, and is
  presentable too
- **A `400` lists every problem it found** in the same `details` shape — the developer should not
  fix one per round trip either — but its messages are written for a developer
- **A request with both kinds of problem is a `400`**, reporting only the malformation. Validating
  the values of a request that is structurally wrong produces errors about the wrong thing
- The split is worth having because the two are handled differently: a client shows a `422`'s
  details to its user and lets them try again, and treats a `400` as a bug to log and fix. A client
  that got both from one status would have to inspect every detail code to know which it had

**Corrected:** this used to say that all invalid input is `400` and `422` is not used, on the
grounds that both mean "change your request" and no client acts on the difference. Clients do act on
it: a user-recoverable validation failure is shown to the user, and a malformed request is a bug.
Collapsing them made every client inspect detail codes to tell a user's mistake from its own.

## Details and Field Paths

- **Every problem is reported in one response**, one `details` entry each. A client fixing one
  field per round trip is the most common complaint about an API's errors
- **`source`** says where the problem is: `body`, `query`, `path` or `header`
- **`path`** locates it as an **array of keys and indices**, not a string to parse:
  `["line_items", 2, "quantity"]` is the `quantity` of the third line item. A client maps that
  straight onto a form field or a nested object without splitting on dots — and a string form such
  as `line_items[2].quantity` is ambiguous as soon as a key contains a dot or a bracket
- For a query parameter, `path` is the parameter's name split at its brackets, followed by an
  index if the problem is with one element of an array:
  `?filter[status][in][]=paid&filter[status][in][]=payed` gives
  `"source": "query", "path": ["filter", "status", "in", 1]`. A range operator is a key:
  `["filter", "created_at", "gte"]`
- A problem with the request as a whole rather than one field (two mutually exclusive fields both
  sent) has `"path": []` and names the fields in its `message`
- Each detail's `code` is from a small shared vocabulary, so a client can handle a kind of problem
  once for every endpoint. An endpoint adds a specific code only for a rule no shared one describes

  | Status | Detail codes |
  | --- | --- |
  | `422` | `required`, `invalid_format`, `too_small`, `too_large`, `too_short`, `too_long`, `not_allowed` (a value outside the allowed set), `invalid_range`, `taken` (a value that must be unique already exists) |
  | `400` | `malformed_json`, `invalid_type`, `unknown_field`, `unknown_parameter`, `read_only`, `not_an_array` |

## Status Codes

| Status | `code` (typical) | When |
| --- | --- | --- |
| `400 Bad Request` | `invalid_request` | The request is malformed or uses the API wrongly — see "400 or 422". Fixed by the client's developer |
| `401 Unauthorized` | `unauthenticated` | No credentials, or credentials that are invalid or expired. Sent with a `WWW-Authenticate` header |
| `403 Forbidden` | `forbidden` | Authenticated, and allowed to know the resource exists, but not allowed to do this to it |
| `404 Not Found` | `not_found` | The resource does not exist — **or the caller is not allowed to know it exists**. See `auth-and-limits.md` |
| `405 Method Not Allowed` | `method_not_allowed` | The path exists but not with this method. Sent with an `Allow` header |
| `409 Conflict` | a specific code | The request is valid but conflicts with the resource's current state: an action invalid in this state (`order_already_shipped`), a reused idempotency key, a request still in flight |
| `412 Precondition Failed` | `precondition_failed` | An `If-Match` did not match — the resource has changed since it was read |
| `413 Content Too Large` | `payload_too_large` | The body is over the documented size limit |
| `415 Unsupported Media Type` | `unsupported_media_type` | The body is not `application/json` |
| `422 Unprocessable Content` | `validation_failed` | One or more values fail an input constraint — see "400 or 422". Fixed by the user changing an answer |
| `428 Precondition Required` | `precondition_required` | An endpoint that requires `If-Match` did not get one |
| `429 Too Many Requests` | `rate_limited` | Rate limit exceeded. Sent with `Retry-After` |
| `500 Internal Server Error` | `internal_error` | A bug. The client did nothing wrong and should not change its request |
| `502`, `503`, `504` | `service_unavailable` | Upstream failure, maintenance or overload — temporary. `503` carries `Retry-After` where the wait is known |

- **`409` always carries a specific `code`**, because the whole point of it is that the client may
  be able to resolve the conflict, and it can only do that if it knows which conflict it has
- **A uniqueness violation is a `422`, not a `409`** — "that email address is already registered"
  is fixed by the user entering a different one, so it is reported beside the field like any other
  validation failure, with detail code `taken`. `409` is for conflicts with the resource's *state*
  that no different answer in the same request would resolve
- **Retryable versus not** follows from the status: `429`, `503` and (with an idempotency key)
  `500`/`502`/`504` may be retried with backoff; every `4xx` other than `429` will fail the same
  way again until the request changes
- Never `200` with an error in the body, and never a `4xx` or `5xx` with a success body. Monitoring,
  caches, retry logic and every HTTP client's error handling key off the status

## What an Error Must Never Contain

- **Stack traces, exception class names, SQL, file paths or internal hostnames.** They help an
  attacker map the system and help no legitimate client. The `request_id` links the response to
  the full detail in the server's logs, which is where a developer debugging it should look
- **Secrets or credentials**, including echoing back a submitted password or token as the
  "offending value"
- **Whether something exists that the caller may not see** — see the `404` rule above. "No account
  with that email" on a password-reset endpoint is an account enumeration oracle
- A different shape. Framework-generated errors (a routing `404`, a body-parser failure, an
  authorizer's `401` from a gateway) are caught and re-rendered in this format, or configured to
  produce it. A client that has to handle two error shapes handles neither well

## A `500` Done Properly

```json
{
  "error": {
    "code": "internal_error",
    "message": "Something went wrong on our side, and the request may not have completed. It is safe to retry with the same Idempotency-Key.",
    "details": [],
    "request_id": "req_7h2m9x4k"
  }
}
```

It says whose fault it is, what state things may be in, what the caller can do, and how to
reference it when reporting it — and nothing about the internals. It does not claim the operation
did not happen: a `500` can come after the write committed, and a message that says otherwise
invites a retry without the key.
