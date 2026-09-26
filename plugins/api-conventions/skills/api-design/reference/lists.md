# List Endpoints

List (index) endpoints are `GET` on a collection: `GET /orders`. They are the endpoints people
call most, explore most and script against most, so they carry most of the conventions.

A complete example, which the rest of this file explains:

```bash
curl -G https://api.example.com/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "status[]=paid" \
  --data-urlencode "status[]=refunded" \
  --data-urlencode "created_at[gte]=2026-09-01T00:00:00Z" \
  --data-urlencode "created_at[lt]=2026-10-01T00:00:00Z" \
  --data-urlencode "search=blue widget" \
  --data-urlencode "sort[]=-created_at" \
  --data-urlencode "page_size=50"
```

```json
{
  "data": [
    { "id": "ord_9a7x3", "status": "paid", "created_at": "2026-09-25T10:12:44Z", "...": "..." },
    { "id": "ord_8f2k1", "status": "refunded", "created_at": "2026-09-24T08:01:09Z", "...": "..." }
  ],
  "pagination": {
    "page_size": 50,
    "has_more": true,
    "next_cursor": "eyJjIjoiMjAyNi0wOS0yNFQwODowMTowOVoiLCJpIjoib3JkXzhmMmsxIn0",
    "next_url": "https://api.example.com/v1/orders?status[]=paid&status[]=refunded&...&cursor=eyJj..."
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

## Array Query Parameters

A query parameter that takes several values is written **once per value, with a `[]` suffix**:

```
?status[]=paid&status[]=refunded
```

- **The `[]` is part of the name and is required.** `status[]=paid` is an array of one.
  `status=paid` on an array parameter is rejected with an error naming `status[]` — not quietly
  accepted, because then half a team's scripts use one form and half the other, and neither is
  sure which is canonical
- **Never a comma-separated string.** `status=paid,refunded` is rejected, not split. Splitting on
  commas breaks the first time a value legitimately contains one — `tag[]=red, white and blue`,
  a name, an address — and there is no escaping scheme a person would guess. It also makes every
  client hand-roll a join and every server a split, where a repeated parameter is something every
  HTTP library already produces and parses
- The brackets make the array-ness visible in the URL itself: a person reading `?status[]=paid`
  knows they could add a second value, which `?status=paid` does not tell them
- It works with plain repeated-key parsers too — to Go's `net/url` or Python's `parse_qs` the key is
  simply the literal string `status[]` with several values — and with bracket-aware ones (Rack,
  PHP, Node's `qs`). No custom parsing is needed on either side
- Clients will often percent-encode the brackets (`status%5B%5D=paid`); the server decodes before
  matching. Documentation and examples show the brackets unencoded, because that is what a person
  reads and types
- **Order is preserved** and meaningful where the parameter says so (`sort[]`), and irrelevant
  where it does not (`status[]`)
- Duplicate values are harmless and treated as one

## Filtering

Filters are query parameters named after the field they filter on.

- **Equality filters are arrays, and mean "any of"**: `?status[]=paid&status[]=refunded` returns
  orders that are paid *or* refunded. Use the array form even for fields that usually take one
  value — `customer_id[]=cus_3k9d2` — because "any of these" is almost always wanted eventually,
  and turning a scalar parameter into an array later is a breaking change
- **Different filters combine with AND**: `?status[]=paid&customer_id[]=cus_3k9d2` is paid orders
  *belonging to* that customer
- **Boolean filters are scalar** `true` or `false` — `?is_archived=false` — nothing else (`1`,
  `yes`) is accepted
- **Ranges use bracketed operators on the field name**, which say explicitly whether a bound is
  inclusive:

  | Operator | Means | Example |
  | --- | --- | --- |
  | `[gt]` | greater than | `total[gt]=100.00` |
  | `[gte]` | greater than or equal | `created_at[gte]=2026-09-01T00:00:00Z` |
  | `[lt]` | less than | `created_at[lt]=2026-10-01T00:00:00Z` |
  | `[lte]` | less than or equal | `quantity[lte]=10` |

  A time window is written **half-open** — `[gte]` the start, `[lt]` the end — so consecutive
  windows (September, then October) neither overlap nor leave a gap at midnight. Named bounds like
  `created_after` / `created_before` read slightly better but leave inclusivity to the
  documentation, and "is the 1st included?" is the question every reader asks
- **`null` matching**, where needed, is its own documented filter (`?has_shipped=false`,
  `?cancelled_at[exists]=false`) rather than a magic string like `status[]=null`
- **Only documented fields are filterable, and an unknown filter is an error.** This is the rule
  from `SKILL.md` that matters most here: an ignored filter returns an unfiltered list, and an
  unfiltered list fed to a bulk operation is how an entire table gets updated
- **Invalid values are errors too**: `status[]=payed` is a `400` naming the allowed values, not an
  empty result — an empty result reads as "none match", which is a wrong answer rather than a
  failed request
- **Filters are flat**, not namespaced under `filter[...]`. `?status[]=paid` is easier to read and
  type than `?filter[status][]=paid`, and the control parameters below are few enough to reserve by
  name. A field that genuinely collides with one gets its filter renamed and documented

### Reserved parameter names

These are the control parameters, and no filter may use them:

| Parameter | Purpose |
| --- | --- |
| `search` | Free-text search |
| `sort[]` | Sort order |
| `page_size` | Page size |
| `cursor` | Cursor pagination position |
| `page` | Page pagination position, where page pagination is used |
| `include[]` | Embed related resources — see `resources-and-fields.md` |
| `fields[]` | Sparse fields — see `resources-and-fields.md` |

## Search

- **Free-text search is one `search` parameter** holding a string: `?search=blue widget`. It is not
  an array and not split — spaces are part of the query, and how words combine is the search
  engine's job
- It is **different from filtering**: filters are exact and structured; `search` is fuzzy and
  matches across documented fields (a name, a description, a reference number). Each endpoint that
  offers it documents which fields it searches
- `search` combines with filters by AND — search within the filtered set
- **With `search` present and no `sort[]`, results are ordered by relevance**; an explicit
  `sort[]` overrides it. Relevance order is documented as not stable across index updates
- An endpoint that does not support search rejects the parameter, like any unknown parameter
- Use `search`, not `q`: it says what it is to someone who has never seen the API

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

### Page size

- **`page_size`** sets the number of items per page, with a **documented default and maximum**
  (typically 25 and 100; the project records its values in `conventions/api.md`)
- A `page_size` above the maximum is **rejected with an error stating the maximum**, not silently
  clamped. A client that asks for 500 and gets 100 without being told believes it has everything
- `pagination.page_size` in the response echoes the size actually used

### Cursor pagination — the default

```json
"pagination": {
  "page_size": 50,
  "has_more": true,
  "next_cursor": "eyJjIjoi...",
  "next_url": "https://api.example.com/v1/orders?status[]=paid&sort[]=-created_at&page_size=50&cursor=eyJjIjoi..."
}
```

- The client passes `cursor=<next_cursor>` to get the next page, with **the same filters, sort and
  page size**
- **`next_url` is the complete URL of the next page**, every original parameter included. It is
  there for people: a next page can be fetched by copying one value, and a script can paginate
  with a loop that follows `next_url` until it is `null`, without rebuilding a query string
- **The last page has `has_more: false`, `next_cursor: null` and `next_url: null`** — the keys are
  present, as always
- **Cursors are opaque.** They encode the position (the sort-key values and `id` of the last item),
  typically as URL-safe base64, but clients never decode, construct or store them long term. That
  leaves the server free to change what is in them
- **A cursor is bound to its query.** Reusing one with different filters or sort is an error, not
  a guess at what was meant
- A cursor may expire; an expired one is an error with a code that says so, and the client starts
  again from the first page
- `previous_cursor`/`previous_url` are offered only where a client genuinely pages backwards (an
  infinite-scroll UI); most do not

Cursor pagination is the default because it is **correct under change**. Offset pagination
(`LIMIT 50 OFFSET 100`) counts rows: when a row is inserted before the current position while a
client is paging, every later row shifts down one and an item is shown twice; when one is deleted,
an item is skipped entirely. A script exporting every order that way loses records without any
error. A cursor says "after this item", which does not move. It is also fast at any depth, where a
large offset makes the database read and discard every skipped row.

### Page pagination — where it genuinely fits

Page-numbered pagination is acceptable for **small, slowly changing collections that a person
browses** — an admin screen that needs "page 7 of 12" and jump-to-page. It is a registered choice
for that endpoint, not the default.

```json
"pagination": {
  "page": 2,
  "page_size": 25,
  "total_count": 287,
  "total_pages": 12,
  "has_more": true,
  "next_url": "https://api.example.com/v1/users?page=3&page_size=25"
}
```

- `page` is **1-based** — page 1 is the first page, as a person would say it
- A `page` beyond the last is `200` with `"data": []`, not an error

### Totals

- `total_count` is **not** part of cursor pagination by default. Counting a large filtered set is
  often as expensive as the query itself, and the number is stale by the time it is read
- Where a count is genuinely needed and cheap, include it as `pagination.total_count` and document
  it. Where it is needed but expensive, offer it as an explicit opt-in rather than paying for it on
  every page
