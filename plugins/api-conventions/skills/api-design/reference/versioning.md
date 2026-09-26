# Versioning and Evolution

An API changes for as long as it is used. The goal is to change it constantly **without** new
versions, by making almost every change additive, and to make the rare breaking change deliberate,
announced and survivable.

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

These need a new version, or a migration that keeps the old behaviour working until clients move:

- Removing or renaming a field, parameter, endpoint or enum value
- Changing a field's type or format — including number to string, or a string's format
- Making an optional request field required, or adding a required one
- Tightening validation — rejecting input that used to be accepted
- Changing a default: default sort, default `page_size`, a default filter
- Changing the meaning of an existing field or value, even with the same name and type
- Changing a status code or an error `code` for an existing situation
- Adding pagination to a list that previously returned everything
- Changing a scalar parameter to an array parameter, which is why equality filters start as
  arrays — see `lists.md`

When unsure, it is breaking. The test is whether any correct client written against the current
documentation could stop working.

**Renames are done by addition.** Add the new field alongside the old, document the old as
deprecated, and remove it only in the next version. Both fields carry the same value in the
meantime.

## The Version Prefix

- **The major version is the first path segment**: `https://api.example.com/v1/orders`
- Visible in every URL, every log line, every `curl` command and every piece of documentation — a
  person never has to ask which version a request was made against. A version in a header (or a
  media type) is invisible in all those places, and is the first thing forgotten when someone
  pastes a request into a bug report
- Only the major version: `v1`, `v2`. Additive changes do not move it, so `v1.3` would mean nothing
  to a client
- Start at `v1`, from the first release. Adding a prefix to an unversioned API is itself breaking
- A new major version is a large, rare event, run alongside the old one for a published period.
  If versions are frequent, the changes are not being made additively

Dated versions pinned per client (`Api-Version: 2026-09-26`), as some large public APIs use, let a
provider make small breaking changes often. They also require the server to run every historical
behaviour at once, and they hide the version from the URL. A project that needs them records the
choice in `conventions/api.md`; the default is the path prefix.

## Deprecation

- **Document it first**: the deprecated field, parameter or endpoint is marked as such in the
  OpenAPI file and the changelog, with what to use instead and the date it will stop working
- **Signal it in responses** to deprecated endpoints with the `Deprecation` header (RFC 9745) and a
  `Sunset` header (RFC 8594) giving the removal date, and a `Link` header with `rel="deprecation"`
  pointing at the migration notes. These reach the developer whose client is actually calling it,
  who may never read a changelog
- **Measure use before removal.** Log calls to deprecated features, so removal is based on who is
  still calling rather than on hope
- **Keep a changelog** of every change to the API, additive or not, dated, in the documentation
