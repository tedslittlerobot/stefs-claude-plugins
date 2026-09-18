# Accessibility Patterns

These are **settled** — a new screen follows them rather than re-deciding them. They exist because a
committed visual idiom is exactly the situation in which accessibility gets quietly traded away, and
none of these cost anything visually.

## Announcements

**Anything that appears in response to an action announces itself.** An error banner gets
`role="alert"`; a block-level loading placeholder gets `role="status"`. Without one, a failed submit
changes the page silently for anyone not watching that region.

## Motion

**`prefers-reduced-motion` is handled once, in the base layer** — a blanket rule collapsing
`transition-duration` and `animation-duration` — rather than a `motion-reduce:` variant remembered
per element. Handled once, it covers hover lifts and anything added later; handled per element, it
is forgotten on the next component.

`<marquee>` is the one exception: it is not a CSS animation and **cannot be stopped from a
stylesheet**, so each one must be stopped from script (`stopIfReducedMotion($el)` from an
`x-init`). It has to be per-element rather than a single sweep on load, because views are fetched at
runtime and their marquees do not exist yet when `app.js` runs.

## Document Title

**The document title changes with the route.** Mirror the rendered view's own `<h1>` into
`document.title` via a `MutationObserver` on the `#app` outlet — so a new route needs nothing added,
and a view that rewrites its own heading updates the title with it.

A SPA that leaves one static title makes every route bookmark, appear in history and announce itself
identically — [WCAG 2.4.2](https://www.w3.org/WAI/WCAG22/Understanding/page-titled).

## Popups and Menus

**A popup closes on Escape and hands focus back to the button that opened it**, and opening one
moves focus to its first item.

The focus move is not optional politeness: a menu that sits *before* its bar in the document — which
is the usual way to build a bottom-anchored bar — would otherwise send a Tab from the trigger *away*
from the menu rather than into it.

**No `role="menu"` / `role="menuitem"`.** Those announce the ARIA menu keyboard contract — arrow
keys, Home/End, a single tab stop — which the app does not implement, so the announcement is a lie.
Plain `<ul>` + `<button>` is announced correctly, is tab-reachable, and needs no JavaScript.

## Headings

**One `<h1>` per page**, supplied by the view. Persistent chrome that reads as a heading (a site
banner) is **styled text, not a second `<h1>`**.

## Pressed States

**`:active` matches ancestors.** A pressed-state rule must be scoped to what is actually pressable:

```css
&:is(button, a, [role="button"]):active { /* … */ }
```

Otherwise pressing anything inside a container also triggers the container's own pressed state,
which on a bevelled or 3D idiom is very visible.

## Contrast and Focus

- Text meets **WCAG AA** contrast — including text over a patterned or tiled background, which is
  where a period idiom most often fails
- Controls are **real focusable elements** (`<button>`, `<a>`) with a **visible focus state**. A
  period-appropriate focus ring (a dotted marquee, say) is fine; no focus state is not
- Decorative chrome is hidden from assistive technology with `aria-hidden`
