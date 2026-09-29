---
name: mysql
description: MySQL and Aurora MySQL conventions — snake_case identifiers, plural resource tables, alphabetical singular pivot tables, UUIDv7 CHAR(36) primary keys, mandatory created_at/updated_at with a BEFORE UPDATE trigger, column ordering under ALTER TABLE, and SQL formatting. Use when writing or reviewing DDL, migrations, ALTER TABLE statements, repository queries, or a data-design document.
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

## Related

- Testing repository code against a schema: see the `lambdas-go` skill's testing reference
  (`go-sqlmock`, and how to assert a query *doesn't* select a column)
- Documenting a schema: see the `documentation` skill — data designs live in
  `architecture/<service>/data-design-mysql.md`, and ER diagrams are MermaidJS `erDiagram` blocks
  rendered to a PNG
- Naming the *concepts* the tables represent: see the `glossary` skill
