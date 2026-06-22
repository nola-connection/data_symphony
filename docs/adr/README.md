# Architecture Decision Records

This directory captures **why** significant design choices were made. ADRs are
short, immutable records — when a decision is reversed, a new ADR supersedes
the old one rather than editing it in place.

## Index

| # | Title | Status |
| --- | --- | --- |
| [0001](./0001-liveview-over-react.md) | LiveView over a React SPA | Accepted |
| [0002](./0002-python-midi-microservice.md) | Python microservice for MIDI generation | Accepted |
| [0003](./0003-oban-async-processing.md) | Oban for background processing | Accepted |
| [0004](./0004-mapping-embedded-on-midi-sequence.md) | Mapping configuration embedded on MidiSequence | Accepted |
| [0005](./0005-integer-cells-and-row-order.md) | Cells as integers, row order as timing | Accepted |

## Template

When a new ADR is added, copy this skeleton:

```markdown
# ADR-NNNN — <Short title>

- **Status:** Proposed | Accepted | Superseded by ADR-XXXX
- **Date:** YYYY-MM-DD

## Context

What is the problem? What constraints or forces matter here?

## Decision

What did we choose? State it plainly.

## Consequences

What becomes easier or harder because of this choice? What follow-on work
or risks does it introduce?

## Alternatives Considered

What other options were on the table, and why were they rejected?
```

## Conventions

- ADRs are numbered sequentially and never renumbered.
- File names are kebab-case after the number, e.g. `0004-some-decision.md`.
- Keep each ADR short — if it exceeds a single page, the decision is probably
  two decisions.
