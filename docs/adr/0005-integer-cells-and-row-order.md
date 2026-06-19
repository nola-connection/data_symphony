# ADR-0005 — Cells as integers, row order as timing

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

The original spec implied type inference at upload time (integer, float,
date, datetime, string, boolean) so the mapping UI could intelligently
filter columns by compatibility — e.g. "only date columns drive timing."
That added meaningful complexity to the parser and to the UI.

An alternative is to treat every cell as an opaque string and derive a
single integer from it via a chosen strategy (literal parse, sum of
character codes, hashed bucket, etc.). Note placement on the timeline is
then driven by **CSV row order**, not by the value of any column.

## Decision

The parser performs no type inference. Every cell is a string at the data
layer. Per-cell integers are derived at sequence-generation time via the
strategy named in the embedded mapping. Note timing is **implicit in CSV
row order** (note N is the Nth row). Note **length** is derived from the
column assigned to the `duration` role, then rounded by a global `quantize`
knob (`1/4`, `1/8`, `1/16`, `1/32`, `none`).

## Consequences

Positive:

- The parser does one thing: stream-validate the CSV against limits and
  persist it as a blob. No date/number guessing, no type-compatibility
  matrix in the UI.
- Strategies become the single point where "what is a cell worth?" is
  decided, and they are versioned by name so historical sequences remain
  reproducible.
- Any column can drive any role; the user picks via dropdown and strategy
  rather than being constrained by inferred types.
- "Creative mode" (string-derived musical values for categorical or noisy
  columns) is a first-class strategy, not a special case.

Negative / accepted risks:

- Compositions cannot be temporally weighted by a date column without
  reintroducing typed parsing. We accept this for the MVP. Adding a real
  temporal axis returns as a roadmap item.
- The MVP loses the "show inferred types" UX in the dataset preview. Users
  still see column headers, row count, and a sample of rows.
- If a strategy algorithm changes, old sequences must continue to render
  with the *old* algorithm. We enforce this by versioning strategy names
  (`name_v2`) rather than mutating existing ones.

## Alternatives Considered

- **Full type inference (original spec).** Powerful but adds parser
  complexity and UI complexity for limited MVP benefit.
- **Type inference deferred to the mapping step.** Still requires
  cell-level type tracking and complicates the strategy contract for no
  meaningful gain.
- **Hard-coded `cell.to_integer` semantics.** Insufficient — string
  columns and timestamps would need bespoke handling, which is exactly
  what the strategy registry already provides cleanly.
