# Tailwind CSS v4

Tailwind is on **v4**, and a new frontend must start there too. v3 is not an option, and neither is
the `cdn.tailwindcss.com` Play CDN, which only ever shipped v3. The v4 equivalent is the browser
build, pinned like every other CDN script:

```html
<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4.3.3"></script>
```

Four things to know before writing markup or CSS against it.

## 1. Configuration is CSS, not JavaScript

v4 has **no `tailwind.config` object** — the browser build throws on one. Theme extensions are
declared in a `<style type="text/tailwindcss">` block as `@theme` custom properties, named by the
**namespace of the utilities they should generate** (`--color-*` for colours, `--font-*` for font
families, `--animate-*` for animations, and so on).

A nested v3 colour like `chrome: { face: '#c0c0c0' }` flattens to `--color-chrome-face`, so the
utility keeps the same name (`bg-chrome-face`) and no markup changes.

`@theme` **extends** the default theme. It only replaces it if a namespace is explicitly reset with
`--color-*: initial`.

## 2. The browser build reads the DOM, not the source

It collects candidates from `document.querySelectorAll('[class]')` and rebuilds on a
`MutationObserver` watching `childList` and the `class` attribute. Two consequences, both of which
matter here:

- A class that exists only inside an Alpine `:class` expression is compiled **when Alpine applies
  it**, not up front
- Because views are fetched at runtime by Pinecone Router, a newly rendered view's utilities are
  compiled **as it is inserted**

Both work, with a frame of unstyled markup first. **Nothing needs safelisting.**

## 3. Some v3 class names changed meaning rather than disappearing

This is the dangerous kind of change: the old name still compiles, so nothing errors — it just does
something different. The ones encountered so far:

| v3 | v4 | Why |
| --- | --- | --- |
| `bg-gradient-to-r` | `bg-linear-to-r` | Renamed for the new conic/radial siblings; the v3 name is a deprecated alias |
| `outline outline-2` | `outline-2` | `outline-<width>` now implies `outline-style: solid`, so the bare `outline` is redundant (and is itself 1px in v4) |
| `outline-none` | `outline-hidden` | v4's `outline-none` really does set `outline-style: none`; `outline-hidden` is v3's behaviour, keeping the forced-colours fallback |
| `drop-shadow` | `drop-shadow-sm` | The whole shadow/blur/radius scale shifted one step, so **every** bare `shadow`/`rounded`/`blur`/`drop-shadow` needs re-reading |

v4 also **drops three Preflight rules** a v3 frontend is probably relying on:

- the default border colour is now `currentColor` rather than `gray-200` — so **always name a border
  colour explicitly**
- `::placeholder` is 50% of the current text colour rather than `gray-400`
- `button` no longer gets `cursor: pointer`

Restore the latter two in the frontend's own `@layer base` block if the look depends on them.

**Do not reach for a v3 → v4 codemod.** Verify instead: compile the frontend's candidates through
the real v4 compiler and check nothing silently produces no CSS.

## 4. Hand-written CSS goes in the Tailwind style block, not a plain `<style>`

A plain stylesheet is **unlayered**, and unlayered CSS beats layered CSS regardless of source order
— so every rule in it silently outranks every Tailwind utility, whatever the markup says. That is
how a hand-written bevel class came to override the `shadow-*` utility sitting beside it on the same
element.

Put each piece where it belongs instead:

| What | Where | Why |
| --- | --- | --- |
| Palette, fonts, animations | `@theme` | Generates the matching utilities (`--animate-blink` → `animate-blink`) |
| Element defaults, resets, `[x-cloak]` | `@layer base` | Loses to every utility, which is what a default should do |
| Reusable component classes | `@utility <name>` | Lands in the utilities layer, sorts correctly, and supports variants |

### Composing two utilities that set the same property

**Two utilities can never both set the same property on one element — one simply loses.** When a
piece of chrome needs to compose (a window drop shadow on top of a bevel, both `box-shadow`), have
one utility set a **custom property** that the other reads:

```css
@utility bevel-drop { --bevel-drop: 4px 4px 0 rgb(0 0 0 / 0.35); }
@utility bevel-out  { box-shadow: inset -1px -1px #000, inset 1px 1px #fff, var(--bevel-drop, 0 0 #0000); }
```

The fallback in `var(--bevel-drop, 0 0 #0000)` is what lets `bevel-out` be used on its own.
