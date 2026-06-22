# ADR-0003 — Oban for background processing

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

Generating a composition involves parsing a potentially large CSV, calling an
external MIDI service over HTTP, and persisting artifacts. The naive approach
is to do all of this inside the LiveView request and stream progress back to
the user. Three realistic options:

1. **Synchronous processing** inside the LiveView mount/event handler.
2. **A bespoke `Task.Supervisor`-based pipeline** managed by the application.
3. **Oban** for durable, observable background jobs backed by PostgreSQL.

The project is explicitly meant to demonstrate event-driven workflows and a
production-shaped architecture.

## Decision

Use **Oban** for asynchronous work. The upload path persists a `Dataset`,
enqueues a composition-generation job, and returns immediately. The worker
calls the MIDI service, persists the `Composition`, and broadcasts status
changes via `Phoenix.PubSub` for the LiveView to consume.

## Consequences

Positive:

- Uploads complete quickly; users see a "generating" state with live status
  updates rather than a long blocking request.
- Retries, backoff, uniqueness, scheduling, and observability are handled by
  Oban rather than reinvented.
- The pipeline already supports the V2 external data sources (weather,
  stocks, etc.) without architectural change — they are just more jobs.
- Failures are durable and inspectable in the database; jobs survive
  deploys and restarts.
- Demonstrates a production-shaped architecture (queues, workers,
  pub/sub) that interviewers expect to see.

Negative / accepted risks:

- Adds Oban tables and indexes to the production database. Acceptable; the
  expected job volume is low and Oban is designed for this pattern.
- Slightly more moving parts during local development. Mitigated by running
  Oban in the same `iex -S mix phx.server` process by default.
- Workers must be idempotent and safe to retry. This is a constraint we
  accept and enforce in code review.

## Alternatives Considered

- **Synchronous processing.** Rejected because it produces a worse UX,
  hides the architecture, and fails to demonstrate the event-driven
  workflow goal.
- **Bespoke `Task.Supervisor` pipeline.** Rejected because it reimplements
  what Oban already provides (durability, retries, observability) without
  the maturity or the portfolio signal.
- **Broadway / GenStage.** Overkill for the MVP volume. A reasonable
  consideration if and when streaming external sources become the primary
  ingest path.
