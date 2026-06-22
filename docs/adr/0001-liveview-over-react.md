# ADR-0001 — LiveView over a React SPA

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

Data Symphony has a real-time UI: upload progress, async MIDI generation
status, synchronized audio playback, and a synchronized visualization. Two
realistic options exist for delivering that UI:

1. **Phoenix LiveView** — server-rendered HTML with diffs pushed over a
   WebSocket, with JS hooks for the parts that genuinely need client-side
   state (Tone.js transport, p5.js canvas).
2. **A React SPA** backed by a Phoenix JSON or GraphQL API.

Both can ship the MVP. The decision is about which one better matches the
goals of the project, which are explicitly a portfolio demonstration of
modern Elixir engineering.

## Decision

Use **Phoenix LiveView** as the primary UI for the MVP. A React (and later
React Native) client may be added in V2 once a GraphQL API exists, but it
will not replace LiveView.

## Consequences

Positive:

- Showcases LiveView, which is a portfolio differentiator and a stated
  project goal.
- Eliminates a second build pipeline, a second deployable, and a duplicated
  domain layer (form validation, error messages, status).
- Composition status updates ride existing `Phoenix.PubSub` channels with
  no extra API surface.
- Tighter feedback loop during development — one app, one server, one
  language for the request path.

Negative / accepted risks:

- The audio playback and visualization layers are inherently client-side.
  We accept a hybrid model where Tone.js and p5.js run as LiveView JS hooks,
  with the server pushing only the data each hook needs.
- Mobile clients will require either a responsive LiveView or the V2 React
  Native client.
- Some recruiters and audiences expect a React app on a portfolio piece;
  the README and project page should call out the LiveView choice explicitly
  rather than hide it.

## Alternatives Considered

- **React + Phoenix JSON API.** Rejected for the MVP because it duplicates
  state across client and server, adds a build pipeline, and does not
  exercise the LiveView skills the project is meant to demonstrate.
- **React + GraphQL (Absinthe).** Same trade-offs as above, plus the
  GraphQL surface is not justified until multiple clients exist. Deferred
  to V2.
- **Server-rendered HTML without LiveView (e.g., Phoenix HTML + htmx).**
  Would work, but loses the LiveView showcase and still requires a custom
  push mechanism for composition status and playback sync.
