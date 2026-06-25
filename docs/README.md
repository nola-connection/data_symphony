# Data Symphony — Documentation

This directory contains the project specification, architecture decisions, and
ticket stubs for **Data Symphony**, a web application that transforms structured
datasets into generative music and synchronized visual art.

## Contents

### Specification

| Document | Purpose |
| --- | --- |
| [01 — Vision & Scope](./01-vision-and-scope.md) | Project vision, portfolio goals, MVP scope, success criteria |
| [02 — Architecture](./02-architecture.md) | High-level data flow, service boundaries, CSV processing, background jobs |
| [03 — Domain Model](./03-domain-model.md) | Dataset, MidiSequence, polymorphic sources, mapping strategies, limits |
| [04 — Tech Stack](./04-tech-stack.md) | Backend, frontend, MIDI service, hosting |
| [05 — Roadmap](./05-roadmap.md) | V2 (external data sources, GraphQL), long-term architecture |
| [09 — Style & Architecture Guidelines](./09-style-and-architecture-guidelines.md) | Canonical Elixir style/architecture reference: structure, context boundaries, naming, process conventions |

### Architecture Decision Records

ADRs capture the engineering judgment behind significant choices. See
[`adr/README.md`](./adr/README.md) for the index.

- [ADR-0001 — LiveView over a React SPA](./adr/0001-liveview-over-react.md)
- [ADR-0002 — Python microservice for MIDI generation](./adr/0002-python-midi-microservice.md)
- [ADR-0003 — Oban for background processing](./adr/0003-oban-async-processing.md)
- [ADR-0004 — Mapping configuration embedded on MidiSequence](./adr/0004-mapping-embedded-on-midi-sequence.md)
- [ADR-0005 — Cells as integers, row order as timing](./adr/0005-integer-cells-and-row-order.md)

### Tickets

- [Ticket Stubs](./tickets.md) — organized by epic, ready to expand into GitHub
  issues once the spec is finalized.

## Status

This spec is a **draft** intended to be reviewed and refined before any
implementation work begins. Treat each section as a starting point for
discussion, not a frozen requirement.
