# READMEs

Two kinds of directory carry a mandatory `README.md` with a fixed section list: a Lambda, and a
shared library. Both formats are exact — the sections, and their order, are the convention.

## Lambda READMEs

Every Lambda directory must contain a `README.md`, **in addition to** the `schema.md` required by
the `lambdas-go` / `lambdas-node` skills. The two have different jobs: `schema.md` is the detailed
input contract; the README is the narrative overview for a reader who wants to understand what the
Lambda does and how it fits together without reading the code.

Exactly these four sections, in this order:

1. **Invocation** — how the Lambda is triggered: API Gateway method + route, queue name, the bus
   and event pattern it subscribes to, manual invocation, an identity-provider trigger, and so on.
   One or two sentences. For a `bus-` Lambda this is the only place the subscribed event is named
   in prose — the directory name deliberately describes the behaviour instead.
2. **Purpose** — no more than two paragraphs (ideally one) describing **what** the Lambda does, not
   how it is implemented.
3. **Interface** — a high-level schema of the request payload and, if any, the response payload.
   "Request payload" means the request body for an API-triggered Lambda, or the event/message body
   for a queue, event-bus or manual invocation. Keep it high-level — shape and key fields, not every
   validation rule. `schema.md` remains the authoritative, detailed contract.
4. **Implementation** — a **rendered flow diagram** of the Lambda's process, plus high-level prose
   walking through that flow: what other APIs and services it calls, where the complexity is, and
   any non-obvious decisions. Do not drop to code-level detail.

The flow diagram follows the conventions in `reference/diagrams.md` — Mingrammer Diagrams,
generated PNG, embedded in the markdown. Represent services the Lambda calls with the provider's
icon set and its own process steps as plain nodes. **Name the script and PNG
`readme--implementation-flow.py` / `.png`**, co-located with the Lambda's `README.md`.

## Shared Library READMEs

Every shared library must contain a `README.md`. A library is consumed by more than one deployable
unit and has no `schema.md`, no route and no trigger to explain it, so its README is the only place
a reader can find out what it is for — and the only thing standing between a shared dependency and
somebody guessing.

Exactly these four sections, in this order:

1. **Purpose** — what the library is and what problem it solves, in no more than two paragraphs.
   **Say what it deliberately does *not* do**, since a shared library's boundaries matter more than
   an internal package's: the boundary is what stops it accreting caller-specific behaviour.
2. **How It Works** — the mechanism: the sequence it performs, what it talks to, and the non-obvious
   decisions. This is the section that saves a reader from reading the source.
3. **Usage** — the dependency declaration a consumer adds, the build-system entry its packaging
   needs, and a short worked example of calling it. For Go, that means the `require`/`replace` lines
   and the Terraform `hash_extra` entry — see the `lambdas-go` skill's shared-libraries reference,
   because omitting the latter fails silently.
4. **Consumers** — every unit that imports it, as a list. **Kept current**, because where each
   consumer is separately deployed this is the only way to know the blast radius of a change before
   making it.

A flow diagram is **optional** here, unlike in a Lambda README — most libraries are a single call
path and a diagram would restate the prose. Add one only where the mechanism genuinely warrants it.
