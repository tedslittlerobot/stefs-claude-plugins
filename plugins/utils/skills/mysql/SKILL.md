---
name: mysql
description: MySQL and Aurora MySQL conventions — snake_case identifiers, plural resource tables, alphabetical singular pivot tables, UUIDv7 CHAR(36) primary keys, mandatory created_at/updated_at with a BEFORE UPDATE trigger, column ordering under ALTER TABLE, SQL formatting (!= never <>, explicit AS and other optional keywords, the ->> and -> JSON shorthand over JSON_UNQUOTE(JSON_EXTRACT())), and making efficient use of indexes (EXPLAIN, composite index order, sargable predicates, indexing JSON through generated columns). Use when writing or reviewing DDL, migrations, ALTER TABLE statements, repository queries, WHERE clauses, JOINs, JSON column queries, an index, a slow query, or a data-design document.
---

# MySQL Conventions

These are the schema and query rules for every MySQL/Aurora MySQL database in the project. A
project may add its own database-specific notes in its `conventions/sql.md` — where that file and
this skill disagree, the project file wins.

## Naming

- Database, table, and column names use **snake_case** — alphanumerics and underscores only, with
  underscores separating words (`global_identity`, `study_members`, `created_at`)
- **Resource tables are the plural of the resource** — a `User` resource becomes `users`, a `Study`
  resource becomes `studies`
- **Pivot/join tables are the singular of each related table, ordered alphabetically, joined with
  an underscore** — a pivot between `studies` and `users` is `study_user`, never `users_studies` or
  `study_users`. Alphabetical ordering means two people naming the same pivot independently arrive
  at the same name

## Required Columns

- Every table has an `id` column as its **first** column, **except** many-to-many pivot tables —
  unless explicitly specified otherwise for a given table
  - It is a UUID `PRIMARY KEY` — `CHAR(36)`, application-generated **UUIDv7**, lowercase
    hyphenated. Not an auto-increment integer, and not the composite-key-of-two-FKs style that a
    pivot table uses
  - UUIDv7 rather than v4 because it is time-ordered, so inserts append to the index rather than
    scattering across it
- Every table has `created_at` and `updated_at`, **except** many-to-many pivot tables — unless
  explicitly specified otherwise for a given table
  - Both are `DATETIME NOT NULL DEFAULT NOW()`
  - `updated_at` **also** needs a `BEFORE UPDATE` trigger named `trg_<table>_before_update` setting
    `NEW.updated_at = NOW()` on every update. `DEFAULT NOW()` alone only covers the insert case, so
    without the trigger `updated_at` silently stays equal to `created_at` forever
  - `created_at` then `updated_at`, in that order, are always the **last two columns** in the table

## Adding Columns

- When altering an existing table in place, add new columns **before** `created_at`/`updated_at`, so
  the timestamp pair stays last
- Always place a new column explicitly with `AFTER <column>` — never let `ALTER TABLE` default it to
  the end of the table. Put it after the column it is most closely related to

## SQL Formatting

- **UPPERCASE** for all MySQL keywords (`SELECT`, `FROM`, `JOIN`, `INSERT INTO`, `ON DUPLICATE KEY
  UPDATE`, …)
- **One clause per line**, indenting to group statements and show hierarchy
- Comment any non-trivial section of a query with a one-line explanation of what it does and why —
  a query is read far more often than it is written
- **`!=`, never `<>`.** They mean the same thing in MySQL; `!=` is the one every reader recognises
  from every other language they write, and one spelling means a search for "not equal" finds
  every instance
- **Never omit an optional keyword.** Write the keyword a clause would still work without, so a
  query says what it does rather than relying on the reader knowing the default:

  | Write | Not |
  | --- | --- |
  | `FROM users AS u` | `FROM users u` |
  | `SELECT COUNT(*) AS user_count` | `SELECT COUNT(*) user_count` |
  | `INNER JOIN studies AS s ON …` | `JOIN studies s ON …` |
  | `LEFT OUTER JOIN study_user AS su ON …` | `LEFT JOIN study_user su ON …` |
  | `ORDER BY created_at ASC` | `ORDER BY created_at` |
  | `INSERT INTO users …` | `INSERT users …` |
  | `ALTER TABLE users ADD COLUMN …` | `ALTER TABLE users ADD …` |

  A missing `AS` is the one that bites: `SELECT id name FROM users` is valid SQL that returns the
  `id` column *renamed* `name`, where the author forgot a comma. With `AS` required everywhere, an
  alias without one is visibly a bug

### JSON columns

- **Use the JSON path operators wherever they apply**: `->>` rather than
  `JSON_UNQUOTE(JSON_EXTRACT(…))`, and `->` rather than `JSON_EXTRACT(…)`:

  ```sql
  -- the study's display name, unquoted
  SELECT
      id,
      settings->>'$.display_name' AS display_name
  FROM studies
  WHERE settings->>'$.visibility' = 'public';
  ```

  The shorthand says the same thing in a fraction of the space, and the nested-function form is
  where a missing `JSON_UNQUOTE` hides — `JSON_EXTRACT` alone returns `"public"` with its quotes,
  so a comparison against `'public'` silently matches nothing
- **Fall back to the functions only where the shorthand cannot be used**: the operators need a
  column name on the left and a string-literal path on the right, so an expression
  (`JSON_EXTRACT(COALESCE(a, b), '$.x')`), a path held in a variable or parameter, or several paths
  in one call keeps the function form. Say why in a comment when it does

## Indexes and Query Efficiency

**Every query makes efficient use of an index.** A query that scans the whole table works in
development against a hundred rows and times out in production against a million, and nothing in
between warns anyone. Design the index with the query, not after the first slow-query report.

- **Check with `EXPLAIN`** before a new or changed repository query is merged. `type: ALL` (a full
  table scan) or `key: NULL` on a table of any size is a missing index, not a detail; so is
  `Using filesort` or `Using temporary` on a query that runs often
- **Index what the query filters, joins and sorts on.** Every column in a `WHERE` equality, a
  `JOIN … ON`, or an `ORDER BY` that the query depends on is covered by an index. Every foreign key
  column has one
- **Order a composite index for the query**: equality columns first, then the one range column,
  then the sort column. MySQL uses an index from its leftmost column onward and stops at the first
  range, so `(study_id, status, created_at)` serves
  `WHERE study_id = ? AND status = ? ORDER BY created_at` entirely, while
  `(created_at, study_id, status)` serves almost none of it
- **Keep predicates sargable** — never hide an indexed column inside a function or expression, or
  the index cannot be used:

  | Uses the index | Scans the table |
  | --- | --- |
  | `created_at >= ? AND created_at < ?` | `DATE(created_at) = ?` |
  | `email = ?` with a case-insensitive collation | `LOWER(email) = ?` |
  | `name LIKE 'smi%'` | `name LIKE '%smi%'` |
  | `id = '0192…'` (a `CHAR(36)` compared with a string) | `id = 123` (an implicit type conversion) |

  Joined columns must share a type and collation for the same reason — a `utf8mb4_general_ci`
  column joined to a `utf8mb4_0900_ai_ci` one converts every row before comparing
- **Index a JSON value through a generated column** (or, on MySQL 8.0.13+ and Aurora MySQL 3, a
  functional index on the same expression) when it is filtered on regularly — a JSON column cannot
  be indexed directly, so `settings->>'$.visibility'` in a `WHERE` otherwise reads every row:

  ```sql
  ALTER TABLE studies
      ADD COLUMN visibility VARCHAR(20)
          GENERATED ALWAYS AS (settings->>'$.visibility') STORED AFTER settings,
      ADD INDEX idx_studies_visibility (visibility);
  ```

  A value filtered on that often is also a sign it may belong in a real column
- **Select only the columns the code uses.** `SELECT *` reads every column from every matched row,
  and prevents a covering index — one that holds every selected column — from answering the query
  without touching the table at all
- **Paginate on the index.** `LIMIT … OFFSET` reads and discards every skipped row, so a list
  endpoint's `ORDER BY` is on an indexed column with `id` as the final tiebreaker, and a very large
  or deep list uses keyset (cursor) pagination instead — see the `api-design` skill's lists
  reference, beside this one in `utils`
- **Do not index speculatively.** Every index is written on every insert and update and takes
  space; add one for a query that exists, and remove one no query uses


## Related

- Testing repository code against a schema: see the `lambdas-go` skill's testing reference, in
  `prototype-conventions` where installed (`go-sqlmock`, and how to assert a query *doesn't* select
  a column)
- Documenting a schema: see the `documentation` skill, in `documentation-and-planning` where
  installed — data designs live in
  `architecture/<service>/data-design-mysql.md`, and ER diagrams are MermaidJS `erDiagram` blocks
  rendered to a PNG
- Naming the *concepts* the tables represent: see the `glossary` skill, in the same plugin
- Precedence between this skill and a project's `conventions/sql.md`: see the `conventions` skill,
  in the same plugin
