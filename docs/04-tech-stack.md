# 04 — Tech Stack

## Backend (Phoenix application)

- **Elixir** — primary application language
- **Phoenix** — web framework
- **Phoenix LiveView** — real-time UI without a separate SPA
- **Ecto** — schema, changesets, queries
- **`polymorphic_embed`** — typed JSONB embeds with a discriminator
  (for `Dataset.source`)
- **PostgreSQL** — primary datastore
- **Oban** — background job processing
- **Phoenix.PubSub** — broadcasting composition status to LiveView clients
- **Req** (or `Finch` directly) — HTTP client for calling the MIDI service

## Frontend

- **LiveView** — server-rendered, push-based UI
- **Tone.js** — synth voices, transport, MIDI playback in the browser
- **p5.js** — visualization rendering, driven by Tone.js transport time
- **LiveView JS hooks** — bridge between server-pushed events and Tone.js / p5.js

## MIDI Generation Service

- **Python** (3.11+)
- Candidate libraries:
  - [`mido`](https://mido.readthedocs.io/) — low-level MIDI I/O
  - [`pretty_midi`](https://craffel.github.io/pretty-midi/) — higher-level
    MIDI manipulation, instrument helpers
- **Web framework:** FastAPI (recommended) — small, async, easy OpenAPI
- **Communication:** HTTP/JSON between Phoenix and the service

See [ADR-0002](./adr/0002-python-midi-microservice.md) for why this service
is separate from the Elixir application.

## Hosting

- **Phoenix application:** [Fly.io](https://fly.io)
- **Database:** PostgreSQL
  - Preferred provider: [Neon](https://neon.tech)
- **MIDI service:** Fly.io (same region as Phoenix to minimize round trip
  latency on the synchronous generation call)
- **Generated MIDI artifacts:** TBD — likely object storage (S3-compatible)
  to avoid coupling Fly volumes to a single VM. An open question for the
  foundation epic.

## Observability

- **Logger** with structured metadata
- **Telemetry** for Phoenix, Ecto, Oban metrics
- **LiveDashboard** in dev/staging
- Production metrics shipping: out of scope for the MVP but should not be
  designed out

## Development Tooling

- **`mix`** — standard Elixir build and task tool
- **`mix format`** + **`mix credo`** — formatting and linting
- **`mix test`** + **`ExUnit`** — unit and integration tests
- **`mix dialyzer`** — type-spec checking (post-MVP if it slows iteration)
- **GitHub Actions** — CI for Elixir test/lint + Python test/lint
- **Docker Compose** for local dev: Postgres + MIDI service
