# Routing (Pinecone Router)

Client-side routing uses **[Pinecone Router](https://github.com/rehhouari/pinecone-router) v7** with
the **external templates** pattern, so each route's markup is a separate file fetched at runtime
rather than inlined in `index.html`.

## Declaring Routes

- Routes are declared with `x-route` directives on `<template>` elements in `index.html`
- Each route sets `x-template="/views/route-name.html"` to load its content from a separate HTML file
- A `targetID` is set **globally** (in `app.js`) so all templates render into a single `<div
  id="app">` outlet, rather than each route naming its own target
- Use the `.preload` modifier on routes where prefetching is worthwhile
- **Declare the built-in `notfound` route** so an unmatched path lands somewhere deliberate

Pinecone logs a `ReferenceError: Path: ... was not found` to the console when it falls through to
the `notfound` route. **This is the library's own behaviour, not a fault in the app** — do not chase
it as a bug.

## Guards

Route guards are `x-handler` expressions on the route declaration in `index.html` — they check
session state and redirect — rather than logic inside the view itself. Keeping the guard on the
route means an unauthenticated visitor never renders the protected view at all, not even briefly.

## Route Parameters

**A route with a parameter needs its component to react to that parameter *changing*, not just to
being created.** Pinecone Router reuses the already-rendered template when only a parameter changes,
so `init()` does **not** run again:

```js
this.$watch('$params.userId', () => this.load())
```

Without the watch, the page keeps showing the previous record under the new URL — which looks like a
caching bug and is not one.

## Application Chrome

Anything that surrounds *every* route — a header, a sidebar, a taskbar, a footer — lives directly in
`index.html` around the `#app` outlet, **not in a view**. It is chrome that surrounds every route
rather than the content of any one of them.

The consequence to plan for: **because the shell sits outside every route's component, nothing
re-renders it when state changes inside one.** A login or logout that happens inside a route will
not update a shell that shows session state.

The fix is an explicit event. Route the session writes through two functions (`setSession` /
`clearSession`) that dispatch a custom event on `window`, and have the shell listen for it. **Every
session write must go through those functions**, or the shell falls out of step — which is a class
of bug worth a comment at the definition site.

## Independent Failures

**A screen that loads from two endpoints should let them fail independently.** A list page that also
fetches filter options should disable the filter in place when the options call fails, rather than
sending the whole page to an error route — the list is what the screen is for.

## Document Title

See `reference/accessibility.md` — the title must change with the route, and the mechanism (a
`MutationObserver` mirroring the rendered view's `<h1>`) is a routing concern as much as an
accessibility one.
