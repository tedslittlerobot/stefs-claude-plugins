# Diagrams

Two diagram technologies, chosen by what is being drawn. Both render to a PNG that is committed and
embedded in the markdown, so a reader never has to run a tool to see the picture.

Both share one naming pattern:

```
<source-filename-without-ext>--<section-slug>.png
```

So a diagram for the "Architecture Overview" section of `design.md` is
`design--architecture-overview.png`, and one for a Lambda's `README.md` implementation flow is
`readme--implementation-flow.png`. The PNG sits in the same directory as the markdown that embeds
it.

## Architecture, Infrastructure & Flow Diagrams

- Use **[Mingrammer Diagrams](https://diagrams.mingrammer.com)** (the `diagrams` Python library)
- Write each diagram as a **standalone Python script**, co-located with the documentation file it
  belongs to
- Run it to generate the PNG: `python3 <diagram-script>.py`
- **The script must set the output filename explicitly** with the `filename` parameter on the
  `Diagram` context manager, following the pattern above. Left to itself the library names the file
  after the diagram title, which drifts from the document
- After generating, embed the PNG below the relevant section:
  `![<section title>](./<png-filename>.png)`
- Use the cloud provider's own icon set (`diagrams.aws.*` for AWS) to represent managed services,
  and plain nodes for the system's own process steps

The script is the source and the PNG is the artefact, but **both are committed** — the PNG so the
markdown renders anywhere, the script so the diagram can be changed rather than redrawn.

## Database / ER Diagrams

- Use **MermaidJS `erDiagram`**
- Embed the diagram in the markdown as a fenced code block with the `mermaid` language tag — this is
  the source, and it lives inline rather than in a separate file
- **Whenever a MermaidJS ER diagram is created or edited, render it to a PNG alongside the source**
  - Render with `mmdc` (Mermaid CLI): `mmdc -i <source-file> -o <output-file>.png`
  - Name the PNG with the same `<source-filename-without-ext>--<section-slug>.png` pattern
  - Place it in the same directory as the markdown file containing the diagram
  - Embed it **below** the mermaid code block: `![<section title>](./<png-filename>)`

Keeping both the fenced block and the PNG is deliberate: the fenced block is diffable and renders
natively on hosts that support Mermaid, and the PNG covers the ones that do not.

## Choosing

| Drawing | Use |
| --- | --- |
| Services, infrastructure, deployment topology | Mingrammer Diagrams |
| A process or control flow (e.g. a Lambda's implementation) | Mingrammer Diagrams |
| Tables, columns, relationships, cardinality | MermaidJS `erDiagram` |

A diagram that would restate the prose beside it should not be drawn at all. Diagram the things
prose is bad at: topology, fan-out, and which of several paths a request takes.
