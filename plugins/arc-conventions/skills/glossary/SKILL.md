---
name: glossary
description: The project-level glossary — one markdown file per term in glossary/, an alphabetical index.md, a fixed entry template with a canonical one-sentence definition, and the rule that a definition lives in exactly one place and every other document links to it. Use when defining a term or acronym, adding or editing a glossary entry, or when a document is about to explain what a term means.
---

# Project Glossary

A project keeps a single source of truth for what its terms **mean**, separate from documentation of
how the system is built. This skill covers how that glossary is structured and how the rest of the
documentation refers to it.

The glossary defines **vocabulary**, not architecture. A glossary entry answers "what does this word
mean, and what are its rules?"; architecture documentation answers "how is it built and how does it
fit together". The two are easy to blur and expensive to blur: an architecture document that
restates a definition becomes a second, competing source of truth that drifts.

**A definition lives in exactly one place.** When a term is defined in the glossary, every other
document links to the entry rather than restating it. If an entry is wrong or incomplete, fix the
entry — never work around it locally.

## Structure

```
glossary/
  index.md          # index of every entry — the only place that lists them all
  <term-slug>.md    # one file per term
```

- **One term per file.** Never group several related terms into one file — cross-link them instead.
  Grouping is what makes a definition hard to find and easy to duplicate
- **Filenames** are the kebab-cased term: lowercase, alphanumerics and hyphens only
- Name the file after the **full term, not its abbreviation**, so the abbreviation never has to be
  expanded to find the file — `single-sign-on.md`, not `sso.md`. This matters most for the terms a
  project abbreviates constantly, which are exactly the ones a newcomer cannot expand
- Files live **flat** in `glossary/` — no sub-directories, no per-service grouping. A term belongs to
  the system, not to one service

## Entry Format

Every entry follows this template:

```markdown
# <Term> (<Abbreviation>)

> One-sentence definition, written so it can be lifted verbatim into `index.md`.

**Also known as:** <alternative names, abbreviations, or spellings> *(omit if there are none)*

<Body — one or more `##` sections expanding the definition: what it is, the rules that govern it,
its format, and what it is explicitly *not*.>

## Related

- [<Other Term>](./<other-term>.md) — one line on how it relates
```

- The `>` blockquote immediately under the `#` heading is the **canonical one-sentence definition**.
  It must stand alone without the rest of the entry, because it is the line copied into `index.md`
- Write entries in the **third person, present tense**, defining the thing itself ("A User ANCHOR
  uniquely identifies…"), not the reader's use of it ("You use a User ANCHOR to…")
- Where a term has hard rules — a format, a prohibition, a cardinality — state them as a bulleted
  list of **MUST/NEVER**-style statements, so they can be cited directly from a code review or a
  spec
- Say what the term is explicitly **not**. A definition's boundary is the part readers get wrong
- Keep entries self-contained but not encyclopaedic. If an explanation runs past roughly a page it
  has become architecture documentation: keep the definition here and link out for the detail
- Every entry ends with a **Related** section linking sibling entries. An entry with no relatives
  omits the section rather than leaving it empty

## The Index

`glossary/index.md` contains:

1. A short intro stating what the glossary is and pointing at the project's glossary conventions
2. A single **alphabetically ordered** list of every entry, one line each:
   `- [<Term>](./<term-slug>.md) — <the entry's one-sentence definition>`

The index is maintained by hand and **must be updated in the same change** as any entry that is
added, renamed, or removed. An entry not listed in `index.md` does not exist as far as readers are
concerned.

## Referencing the Glossary

- On a term's **first use** in any document, link it to its entry with a relative path (e.g.
  `[User ANCHOR](../glossary/user-anchor.md)`). Subsequent uses in the same document are plain text
- **Never restate a definition** outside the glossary
- Link to the **file**, never to a heading anchor inside it — headings within an entry are free to
  change, but the file path is stable
- **Don't link from places a link is impractical.** Mermaid diagram labels, SQL and Terraform
  comments, Mingrammer node labels, generated PNGs, table cells of column descriptions and log
  messages all name terms as plain text. Link from the surrounding prose instead, and only where
  that prose exists — "first use in a document" means first use in its **prose**

## Adding a Term

Adding an entry and adding its `index.md` line are one change, never two. When a document
introduces a term that has no entry yet, write the entry in the same change as the document — a
term used in prose but absent from the glossary is the failure mode this convention exists to
prevent.

## Related

- `documentation` skill — where architecture, instructions and proposals live, and how they link out
  to glossary entries
- `conventions` skill — how a project records its own rules, including which terms it treats as
  domain vocabulary
