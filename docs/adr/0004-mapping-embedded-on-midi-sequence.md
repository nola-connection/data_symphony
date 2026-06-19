# ADR-0004 — Mapping configuration embedded on MidiSequence

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

Earlier drafts modeled `Mapping` as its own table with a foreign-key
relationship to a `Composition`. With the MVP simplification to one
playable entity (`MidiSequence`), and with the observation that mappings
are conceptually immutable with respect to the sequence they generated,
a table-per-mapping starts to feel like ceremony.

Three options were on the table:

1. Dedicated `Mapping` table, referenced by `MidiSequence`.
2. Embedded mapping value object on `MidiSequence` (JSONB).
3. Mapping computed on the fly from `(DataSource variant, user inputs)`
   and never persisted.

## Decision

Embed the mapping as a value object on `MidiSequence`. Each `DataSource`
variant exposes a `default_mapping/1` function in code; the user overrides
it per-sequence in the LiveView. The mapping schema (tempo, scale,
quantize, per-column role/strategy/range) is part of the `MidiSequence`
changeset.

## Consequences

Positive:

- One fewer table, one fewer relationship, no orphan mappings.
- Sequences are self-describing — the mapping used is right there alongside
  the artifact reference.
- Re-mapping a dataset produces a new `MidiSequence` with a different
  embedded mapping; the old sequence remains playable forever.
- Default mappings can evolve in code without migrations.

Negative / accepted risks:

- Mappings cannot be reused across sequences without copying the value.
  Acceptable at MVP scale; the copy is small.
- A "favorite mappings" or "share a mapping with another user" feature would
  later require promoting the embed to a real table. Easy to add when there
  is concrete demand.

## Alternatives Considered

- **Dedicated `Mapping` table.** Adds joins and an orphan-management
  question for no benefit at this scale. Also raises a versioning problem:
  what happens to a sequence whose source `Mapping` row is edited after the
  fact? The embedded model side-steps this entirely.
- **No persisted mapping at all.** Breaks reproducibility — we could not
  replay an existing sequence or describe how it was generated.
