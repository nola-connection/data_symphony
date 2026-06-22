# ADR-0002 — Python microservice for MIDI generation

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

The application needs to turn a normalized list of notes into a playable MIDI
file. MIDI generation is a well-trodden problem with mature libraries in
several ecosystems. The two realistic options are:

1. Generate MIDI **natively in Elixir**, either by writing the format by hand
   or by using a community library.
2. Generate MIDI in a small **Python service** that the Phoenix application
   calls over HTTP, leveraging `mido` and `pretty_midi`.

The MVP requires single-track MIDI today, but the roadmap calls for
multi-track composition, chord generation, scale quantization, and
instrument selection — all of which are first-class in the Python tooling
and would need to be built from scratch in Elixir.

## Decision

Run MIDI generation as a **separate Python service** behind an HTTP/JSON
interface. The Phoenix application is the only client. The service is
stateless and accepts a normalized note payload.

## Consequences

Positive:

- Uses mature Python libraries (`mido`, `pretty_midi`) rather than
  reimplementing the MIDI format or relying on a less-maintained Elixir
  package.
- The service boundary is a portfolio demonstration in itself —
  service-oriented architecture, an explicit contract between two
  languages, and a path to scale or replace the service independently.
- Future enhancements (chord generation, scale quantization, instrument
  selection) reuse Python ecosystem strengths.
- The Elixir application stays focused on orchestration, persistence, and
  real-time UI.

Negative / accepted risks:

- A second deployable: a Python service in production, with its own image,
  health checks, and CI lane.
- An extra network hop in the composition pipeline. Mitigated by Oban
  dispatch (the user is not waiting synchronously) and by colocating the
  service in the same region.
- A cross-language contract that must be kept in sync. Mitigated by
  treating the request/response schema as a first-class artifact (likely
  OpenAPI from FastAPI) and contract-testing it.

## Alternatives Considered

- **Elixir-native MIDI generation.** Rejected because the available
  libraries are less mature than `mido`/`pretty_midi`, and the roadmap
  features would multiply the implementation cost.
- **A NIF or Port wrapping a C/Rust MIDI library.** Higher operational
  complexity than an HTTP service for no measurable benefit at this scale.
  Reconsider only if HTTP latency becomes a bottleneck.
- **Generating MIDI in the browser.** Possible for the MVP shape, but
  pushes work and trust to the client and blocks server-side persistence
  of canonical MIDI artifacts.
