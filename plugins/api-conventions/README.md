# api-conventions

The portable layer of **HTTP/JSON API** conventions, as one model-invoked skill: how requests and
responses are shaped, named and typed, how list endpoints search, filter, sort and paginate, and
how errors are reported.

It is a record of current good practice rather than an implementation of any one specification.
It borrows from JSON:API, RFC 9457 and the public APIs people find easiest to use, and departs from
each wherever that makes an API easier for a person to read, guess and debug — the person calling
the API is the reader it is designed for first.

A few choices run through all of it:

- **`snake_case`** for every key, parameter, error code and enum value; **`kebab-case`** for URL
  path segments
- **Arrays are always arrays.** In a query string that is the parameter repeated with a `[]`
  suffix — `?filter[status][]=paid&filter[status][]=refunded` — and never a comma-separated string
- **A tidy list query string**: filters under `filter[...]`, search as `q`, and page-based
  pagination with `page` and `per_page` by default
- **`422` for a validation failure the user can fix, `400` for a malformed request**
- **Versioning is avoided**, and when a resource must break, the replacement is a suffixed resource
  (`/api/users-v2`), not a version prefix on the whole API
- **Strict in what it accepts.** Unknown parameters and fields are errors, not silently ignored
- **Every response is `{ "data": ... }` or `{ "error": ... }`**

Like `arc-conventions`, it sits under a project layer: a consuming repository records its chosen
values and registered exceptions in `conventions/api.md`, and that file wins where the two differ.
See the [repository README](../../README.md) for the two-layer model and installation.

## Skills

| Skill | Load it when |
| --- | --- |
| `api-design` | Designing, building, reviewing or documenting an HTTP API endpoint, a JSON payload, an OpenAPI schema, a list endpoint's filters, sort or pagination, or an error response |

`api-design` keeps its principles and core rules in `SKILL.md`, and the detail in six reference
files it names: resources and fields, methods and status codes, lists, errors, versioning, and
auth and limits.

## Hooks

None. Installing this plugin changes nothing about a session until the skill's description matches
the work.
