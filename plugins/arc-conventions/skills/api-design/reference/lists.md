# List Endpoints

List (index) endpoints are `GET` on a collection: `GET /orders`. They are the endpoints people
call most, explore most and script against most, so they carry most of the conventions.

A complete example, which the rest of this file explains:

```bash
curl -G https://example.com/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "filter[status][]=paid" \
  --data-urlencode "filter[status][]=refunded" \
  --data-urlencode "filter[created_at][gte]=2026-09-01T00:00:00Z" \
  --data-urlencode "filter[created_at][lt]=2026-10-01T00:00:00Z" \
  --data-urlencode "q=blue widget" \
  --data-urlencode "sort[]=-created_at" \
  --data-urlencode "page=2" \
  --data-urlencode "per_page=50"
```

```json
{
  "data": [
    { "id": "ord_9a7x3", "status": "paid", "created_at": "2026-09-25T10:12:44Z", "...": "..." },
    { "id": "ord_8f2k1", "status": "refunded", "created_at": "2026-09-24T08:01:09Z", "...": "..." }
  ],
  "pagination": {
    "current_page": 2,
    "per_page": 50,
    "total_pages": 6,
    "total_items": 287
  }
}
```

## The List Response

- **`data` is always an array**, and `[]` when nothing matches
- **An empty result is `200` with `"data": []`, never `404`.** A filter that matches nothing is a
  successful answer; `404` means the collection itself does not exist, and a client that treats the
  two alike cannot tell a typo in the URL from an empty day
- **`pagination` sits beside `data`** on every list response, including a list short enough to fit
  in one page — a client should not need to know in advance which lists paginate
- List items use the **same representation** as the single-resource endpoint. A cut-down list
  representation is sometimes worth it for very large resources, but then it is documented as such
  and `fields[]` or `include[]` is usually the better answer — two representations of one resource
  means two things to learn

## Top-level Parameters

The top level of a list's query string is kept **tidy and small**: a fixed set of control
parameters, with every filter nested under `filter`. A reader can then tell at a glance which parts
of a URL narrow the results and which shape the response, and no field name can ever collide with
a control parameter.

| Parameter | Purpose |
| --- | --- |
| `filter[...]` | Every filter — see Filtering |
| `q` | Free-text search — see Search |
| `sort[]` | Sort order — see Sorting |
| `page` | The page to return — see Pagination |
| `per_page` | Items per page — see Pagination |
| `cursor` | Position, on the endpoints that use cursor pagination instead |
| `include[]` | Embed related resources — see `resources-and-fields.md` |
| `fields[]` | Sparse fields — see `resources-and-fields.md` |

Anything else at the top level is an unknown parameter, and an error.

## Array Query Parameters

A query parameter that takes several values is written **once per value, with a `[]` suffix**:

```
?filter[status][]=paid&filter[status][]=refunded
```

- **The `[]` is part of the name and is required.** `filter[status][]=paid` is an array of one.
  `filter[status]=paid` on an array parameter is rejected with an error naming
  `filter[status][]` — not quietly accepted, because then half a team's scripts use one form and
  half the other, and neither is sure which is canonical
- **Never a comma-separated string.** `filter[status][]=paid,refunded` is one value,
  `paid,refunded`, which matches no status and is rejected as such; it is never split. Splitting
  on commas breaks the first time a value legitimately contains one —
  `filter[tag][]=red, white and blue`, a name, an address — and there is no escaping scheme a person would guess. It also makes every client
  hand-roll a join and every server a split, where a repeated parameter is something every HTTP
  library already produces and parses
- The brackets make the array-ness visible in the URL itself: a person reading
  `?filter[status][]=paid` knows they could add a second value, which `?filter[status]=paid` does
  not tell them
- It works with plain repeated-key parsers too — to Go's `net/url` or Python's `parse_qs` the key is
  simply the literal string `filter[status][]` with several values — and with bracket-aware ones
  (Rack, PHP, Node's `qs`), which nest it as `filter.status`. No custom parsing is needed on either
  side
- Clients will often percent-encode the brackets (`filter%5Bstatus%5D%5B%5D=paid`); the server
  decodes before matching. Documentation and examples show the brackets unencoded, because that is
  what a person reads and types
- **Order is preserved** and meaningful where the parameter says so (`sort[]`), and irrelevant
  where it does not (`filter[status][]`)
- Duplicate values are harmless and treated as one

## Filtering

Filters are nested under **`filter`**, keyed by the field they filter on: `filter[<field>]`.

- **Equality filters are arrays, and mean "any of"**:
  `?filter[status][]=paid&filter[status][]=refunded` returns orders that are paid *or* refunded.
  Use the array form even for fields that usually take one value —
  `filter[customer_id][]=cus_3k9d2` — because "any of these" is almost always wanted
  eventually, and turning a scalar parameter into an array later is a breaking change
- **Different filters combine with AND**: `?filter[status][]=paid&filter[customer_id][]=cus_3k9d2`
  is paid orders *belonging to* that customer
- **Boolean filters are scalar** `true` or `false` — `?filter[is_archived]=false` — nothing else
  (`1`, `yes`) is accepted
- **Ranges use a bracketed operator after the field**, which says explicitly whether a bound is
  inclusive:

  | Operator | Means | Example |
  | --- | --- | --- |
  | `[gt]` | greater than | `filter[total][gt]=100.00` |
  | `[gte]` | greater than or equal | `filter[created_at][gte]=2026-09-01T00:00:00Z` |
  | `[lt]` | less than | `filter[created_at][lt]=2026-10-01T00:00:00Z` |
  | `[lte]` | less than or equal | `filter[quantity][lte]=10` |

  A time window is written **half-open** — `[gte]` the start, `[lt]` the end — so consecutive
  windows (September, then October) neither overlap nor leave a gap at midnight. Named bounds like
  `created_after` / `created_before` read slightly better but leave inclusivity to the
  documentation, and "is the 1st included?" is the question every reader asks
- **`null` matching**, where needed, is its own documented filter (`filter[has_shipped]=false`,
  `filter[cancelled_at][exists]=false`) rather than a magic string like `filter[status][]=null`
- **Only documented fields are filterable, and an unknown filter is an error.** This is the rule
  from `SKILL.md` that matters most here: an ignored filter returns an unfiltered list, and an
  unfiltered list fed to a bulk operation is how an entire table gets updated
- **Invalid values are errors too**: `filter[status][]=payed` is a `422` naming the allowed values,
  not an empty result — an empty result reads as "none match", which is a wrong answer rather than
  a failed request. See `errors.md` for which failures are `400` and which `422`

**Corrected:** filters used to be flat top-level parameters (`?status[]=paid`), with the control
parameters (`search`, `sort[]`, `page_size`, `cursor`, …) reserved by name, on the grounds that the
flat form is shorter to read and type. That traded a few characters for a top level where filters
and controls are mixed together and a reader has to know the reserved list to tell them apart, and
where a resource with a field named `sort` or `page` needs a renamed filter and an exception. The
`filter[...]` namespace removes both problems for the cost of one word.

## Search

- **Free-text search is one top-level `q` parameter** holding a string: `?q=blue widget`. It is not
  an array and not split — spaces are part of the query, and how words combine is the search
  engine's job
- `q` is the name people already know from search engines and search URLs everywhere; it stays out
  of the `filter` namespace because it is not a filter on a field
- It is **different from filtering**: filters are exact and structured; `q` is fuzzy and matches
  across documented fields (a name, a description, a reference number). Each endpoint that offers
  it documents which fields it searches
- `q` combines with filters by AND — search within the filtered set
- **With `q` present and no `sort[]`, results are ordered by relevance**; an explicit `sort[]`
  overrides it. Relevance order is documented as not stable across index updates
- An endpoint that does not support search rejects the parameter, like any unknown parameter

**Corrected:** this used to be a `search` parameter, "not `q`", on the grounds that `search` says
what it is to someone who has never seen the API. `q` is the more widely recognised name, and it
keeps the top level short.

## Sorting

- **`sort[]` is an array of field names, in priority order; a leading `-` means descending**:
  `?sort[]=-created_at&sort[]=name` is newest first, then by name. Ascending is the default
- It is an array — not a comma-joined `sort=-created_at,name` — for the same reasons as every other
  multi-value parameter, and so that priority order is unambiguous
- The `-` prefix is a small piece of syntax to learn, and it is used because every alternative is
  worse for a reader: `sort[created_at]=desc` looks friendlier, but sort priority then depends on
  the order of object keys in a query string, which many parsers (Go's `url.Values` among them)
  throw away. A single string per sort key keeps one element per key and its position as its
  priority
- **Every list has a documented default sort**, usually `-created_at`. An unspecified order is
  whatever the database felt like, and it changes when an index does
- **The server always appends `id` as a final tiebreaker**, silently. Without a unique final key,
  two rows with the same `created_at` can swap between requests, and pagination then skips one and
  repeats the other
- **Only documented fields are sortable**, and an unknown one is an error listing the sortable
  fields. Sorting on an unindexed column is a slow query waiting for a large tenant

## Pagination

Every list endpoint paginates, from day one, even if the collection is small today. Adding
pagination to a list that returned everything is a breaking change — every existing client
silently starts seeing only the first page.

**Pagination is page-based by default.** Cursor pagination is used only where there is a specific
reason for it — see below.

### Page-based pagination — the default

- **`page`** is the page to return, **1-based** — page 1 is the first page, as a person would say
  it. Omitted, it is `1`
- **`per_page`** is the number of items per page. It **defaults to 25**, and a client may override
  it up to a **maximum of 150**
- A `per_page` above 150 (or below 1), or a `page` below 1, is **rejected with a `422` stating the
  allowed range** — never silently clamped. A client that asks for 500 and quietly gets 150
  believes it has everything; the failure then surfaces much later, as missing data, somewhere far
  from its cause. Error loudly and early instead
- **A `page` beyond the last is `200` with `"data": []`**, not an error — the collection may simply
  have shrunk since the previous page was read
- **Every page-based list response carries a `pagination` object with exactly these four keys**:

  ```json
  "pagination": {
    "current_page": 2,
    "per_page": 50,
    "total_pages": 6,
    "total_items": 287
  }
  ```

  | Key | Holds |
  | --- | --- |
  | `current_page` | The page this response is — the `page` requested, or `1` |
  | `per_page` | The page size actually used — the `per_page` requested, or the default |
  | `total_pages` | The number of pages at this `per_page`; `0` when there are no items |
  | `total_items` | The number of items matching the filters and search, across all pages |

- Whether there is a next page is `current_page < total_pages`; the next page's URL is the same
  URL with `page` incremented. Both are simple enough that the response does not repeat them

Page-based is the default because it is what a person expects and can reason about: "page 3 of 12,
287 results" can be shown in a UI, jumped around in, and requested by hand with nothing but the
page number. It also makes a request reproducible from its URL alone, which a cursor does not.

### Cursor pagination — when there is a reason

Use cursor pagination instead only when the endpoint has a specific reason, recorded in its
documentation:

- **The data set is very large or of indeterminate size** — counting it for `total_items` would
  cost as much as the query, and deep `page` numbers would make the database read and discard every
  skipped row
- **The data is volatile** — rows are inserted or deleted often while clients page through it (an
  event log, a feed, an activity stream)

The second reason is about correctness, not speed. Page-based pagination counts rows (`LIMIT 50
OFFSET 100`): when a row is inserted before the current position while a client is paging, every
later row shifts down one and an item is shown twice; when one is deleted, an item is skipped
entirely. A script exporting every record that way loses some without any error. A cursor says
"after this item", which does not move.

A cursor-paginated endpoint takes `cursor` and `per_page` (same default and maximum), and returns:

```json
"pagination": {
  "per_page": 50,
  "has_more": true,
  "next_cursor": "eyJjIjoiMjAyNi0wOS0yNFQwODowMTowOVoiLCJpIjoib3JkXzhmMmsxIn0",
  "next_url": "https://example.com/api/events?filter[type][]=login&sort[]=-created_at&per_page=50&cursor=eyJjIjoi..."
}
```

- The client passes `cursor=<next_cursor>` to get the next page, with **the same filters, sort and
  `per_page`**
- **`next_url` is the complete URL of the next page**, every original parameter included, so a
  script can paginate by following `next_url` until it is `null`, without rebuilding a query string
- **The last page has `has_more: false`, `next_cursor: null` and `next_url: null`** — the keys are
  present, as always
- There is no `current_page`, `total_pages` or `total_items`: a cursor has no page number, and
  counting is usually the very cost cursor pagination was chosen to avoid. Where a count is needed
  and cheap, `total_items` may be added and documented
- **Cursors are opaque.** They encode the position (the sort-key values and `id` of the last item),
  typically as URL-safe base64, but clients never decode, construct or store them long term
- **A cursor is bound to its query.** Reusing one with different filters or sort is an error, not
  a guess at what was meant. A cursor may expire; an expired one is an error with a code that says
  so, and the client starts again from the first page
- `previous_cursor`/`previous_url` are offered only where a client genuinely pages backwards

**Corrected:** pagination used to default to cursors, with page numbers allowed only for small,
slowly changing collections, a `page_size` parameter (default 25, maximum 100), and no total count
by default. That optimised every list for the worst case — huge, volatile data — at the cost of the
common one, where a person wants to see how many results there are and jump to a page. Cursor
pagination's correctness argument is real, which is why volatility is one of the two reasons to
use it; it is not a reason to use it everywhere. The parameter is now `per_page`, the name most
people already know, and the maximum is 150.
