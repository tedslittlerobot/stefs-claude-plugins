# Versioning and Evolution

An API changes for as long as it is used. The goal is to change it constantly **without** new
versions, by making almost every change additive, and to make the rare breaking change deliberate,
announced, limited to the one resource that needs it, and survivable.

## What Clients Must Tolerate

These are part of the contract, stated in the API's documentation, because they are what makes
additive change safe:

- **Unknown fields in a response are ignored**, not treated as errors. A client that validates
  responses against a closed schema breaks on the first new field
- **Unknown enum values are handled**, typically by falling back to a generic case. A `status` gains
  a value sooner or later; a client with an exhaustive `switch` and no default will crash on it
- **Unknown error `code`s are handled by status class** — an unrecognised `409` code is still a
  conflict
- **Order of keys in an object is not significant**, and neither is the order of a list whose
  documentation does not define one

The server, in turn, stays **strict in what it accepts** — see `SKILL.md`. That asymmetry is
deliberate: a strict server means a client's mistakes surface immediately, and a tolerant client
means the server's additions do not break anyone.

## Non-breaking Changes

These ship without a new version:

- Adding an endpoint, a resource or an action
- Adding a field to a response
- Adding an **optional** request field or query parameter, whose default preserves existing
  behaviour
- Adding an enum value to a response field (clients tolerate it — above)
- Adding an error `code` within an existing status
- Adding an `include[]` relation or a filterable or sortable field
- Relaxing validation — accepting a longer string, a wider range

## Breaking Changes

These need a new version of the resource, or a migration that keeps the old behaviour working
until clients move:

- Removing or renaming a field, parameter, endpoint or enum value
- Changing a field's type or format — including number to string, or a string's format
- Making an optional request field required, or adding a required one
- Tightening validation — rejecting input that used to be accepted
- Changing a default: default sort, default `per_page`, a default filter
- Changing the meaning of an existing field or value, even with the same name and type
- Changing a status code or an error `code` for an existing situation
- Adding pagination to a list that previously returned everything
- Changing a scalar parameter to an array parameter. Where several values are wanted, add a
  separate array form alongside instead — which is why filters take multiple values through an
  additive `[in][]` operator rather than by turning `filter[status]` into an array — see
  `lists.md`

When unsure, it is breaking. The test is whether any correct client written against the current
documentation could stop working.

**Renames are done by addition.** Add the new field alongside the old, document the old as
deprecated, and remove it only once nothing calls it. Both fields carry the same value in the
meantime. Most breaking changes can be avoided this way, without a new version of the resource.

## Versioning a Resource

**Avoid needing a version at all.** Almost every change can be made additively, and a new version
is a cost paid by every client that has to move, and by the server that has to run both. A
breaking change is a design failure to learn from, not a routine release step.

When a resource genuinely must break, **the new version is a new resource, named with a `-v<n>`
suffix**:

```
/api/users            # the original — never suffixed, never renamed
/api/users-v2         # the replacement, alongside it
/api/users-v2/{user_id}
```

- **Only the resource that changed is versioned.** Everything else keeps its URL. A version prefix
  on the whole API (`/v2/...`) forces every client to move every call to pick up a change to one
  resource, and forces the server to serve an entire second copy of the API for it
- **The original has no suffix.** Nothing is `-v1`; a resource only gains a suffix when a second
  version of it exists, so a new API carries no version noise at all
- **The suffix is part of the collection name**, in kebab-case like the rest of the path, and it
  is visible in every URL, log line, `curl` command and bug report — a person never has to ask which
  version a request was made against. A version in a header or a media type is invisible in all of
  those places
- **Sub-resources move with their parent**: `/api/orders-v2/{order_id}/line-items`. A
  sub-resource that breaks on its own is suffixed on its own:
  `/api/orders/{order_id}/line-items-v2`
- The old and new resources run side by side, the old one deprecated (below), until its callers
  have moved. The new one is a fresh design, not a copy with one field changed: if breaking is
  unavoidable, take the chance to fix everything else that was wrong with it
- IDs are shared between versions where the underlying record is the same, so a client can migrate
  one call at a time

**Corrected:** this section used to put the major version in a path prefix
(`https://api.example.com/v1/orders`) from the first release, on the grounds that it is visible in
every URL. The suffix keeps that visibility without its costs: a prefix versions the whole API when
only one resource changed, puts a `v1` in every URL of an API that may never need a `v2`, and
makes a new version a big-bang migration rather than a per-resource one.

## Deprecation

- **Document it first**: the deprecated field, parameter or endpoint is marked as such in the
  OpenAPI file and the changelog, with what to use instead and the date it will stop working
- **Signal it in responses** from deprecated endpoints — including an old resource that a
  `-v<n>` version has replaced — with the `Deprecation` header (RFC 9745), a `Sunset` header
  (RFC 8594) giving the removal date, and a `Link` header with `rel="deprecation"` pointing at the
  migration notes. These reach the developer whose client is actually calling it, who may never
  read a changelog
- **Measure use before removal.** Log calls to deprecated features, so removal is based on who is
  still calling rather than on hope
- **Keep a changelog** of every change to the API, additive or not, dated, in the documentation
