# Ticket Stubs

These are stubs intended to be expanded into GitHub issues once the spec is
finalized. Each is grouped by epic and roughly ordered by dependency.

Each stub includes a one-line summary and acceptance hints. Detailed
descriptions, designs, and edge-case lists are deliberately deferred until
the spec is signed off.

## Epic 1 — Project Foundation

- **F-1: Bootstrap Phoenix application.** Generate Phoenix + LiveView app,
  pin Elixir/OTP versions, set up `mix format` / `credo` / `dialyzer`.
- **F-2: PostgreSQL + Ecto setup.** Configure Ecto, create initial migration,
  connect to local Postgres via Docker Compose, document Neon for prod.
- **F-3: CI pipeline (Elixir).** GitHub Actions running `mix test`,
  `mix format --check-formatted`, `mix credo --strict` on every PR.
- **F-4: Application telemetry baseline.** LiveDashboard, structured Logger,
  Phoenix/Ecto telemetry handlers in place.
- **F-5: Fly.io deploy scaffold.** `fly.toml`, release config, secret
  management, staging deploy from `main`.
- **F-6: Blob storage adapter.** Behaviour + filesystem (dev) and
  S3-compatible (prod) implementations; used by datasets and sequences.

## Epic 2 — CSV Upload & Parsing

- **CSV-1: LiveView upload UI.** Drag-and-drop + file picker, surfaces
  active limits, server-side persistence to temp storage.
- **CSV-2: `DatasetParser.parse/1`.** Streaming reader; validates row
  shape, enforces limits, aggregates structured errors.
- **CSV-3: `Datasets.Limits` module.** Runtime-config-driven policy
  (byte size, row count, column count, cell length).
- **CSV-4: Raw CSV blob storage.** Write uploaded CSV to the blob
  adapter; store the reference on the dataset row.
- **CSV-5: Structured upload error reporting.** Surface aggregated errors
  in the LiveView with row/column context.

## Epic 3 — Dataset Domain Model

- **DS-1: `Dataset` schema and migration.** Headers, counts, byte size,
  blob refs, polymorphic `source` embed, `source_type` discriminator.
- **DS-2: `CSVSource` polymorphic embed variant.** Module with metadata
  fields and `default_mapping/1`.
- **DS-3: `Datasets` context.** `create/1`, `get/1`, `list_recent/1`;
  tests covering polymorphic embed round-tripping.
- **DS-4: Dataset preview LiveView.** Show headers, counts, and the first
  N rows streamed from blob storage.

## Epic 4 — Mapping & Strategies

- **MAP-1: `MappingStrategies` registry.** MVP strategies (`linear`,
  `string_sum`, `string_sum_mod_scale`, `parity_gate`, `bucketed`) as
  pure functions registered by versioned names.
- **MAP-2: Mapping configuration LiveView.** Per-column role, strategy,
  and range; global tempo, scale, and quantize controls.
- **MAP-3: Note derivation pipeline.** Pure function: `(Dataset, mapping)`
  → ordered list of note events for the MIDI service.
- **MAP-4: Musical scale quantization.** Major, minor, pentatonic;
  quantize derived pitch integers into the chosen scale.
- **MAP-5: Note-length quantization.** Apply `1/4`, `1/8`, `1/16`,
  `1/32`, or `none` rounding to derived durations.
- **MAP-6: Rest handling.** `nil` pitch and falsy `gate` columns produce
  rests; rests preserve sequence position and timing.

## Epic 5 — MIDI Generation Service

- **MIDI-1: FastAPI service skeleton.** `/health`, `/generate` endpoints,
  pinned Python version, requirements file, lint/test config.
- **MIDI-2: `mido`/`pretty_midi` generator.** Single-track MIDI from a
  normalized note payload (`pitch | null`, velocity, duration_ms);
  returns artifact reference + metadata.
- **MIDI-3: Artifact storage strategy.** Decide between inline base64 vs
  shared object storage; implement chosen path.
- **MIDI-4: Service CI + container image.** GitHub Actions for Python
  lint/test; Dockerfile; Fly deploy config for the service.
- **MIDI-5: Contract tests between Phoenix and the service.** Round-trip
  fixture-based tests run in Elixir CI against a containerized service.

## Epic 6 — Background Processing (Oban)

- **OBAN-1: Install and configure Oban.** Migrations, queues, supervision
  tree wiring.
- **OBAN-2: `SequenceWorker`.** Loads dataset + embedded mapping, runs
  the derivation pipeline, calls the MIDI service, persists the sequence.
- **OBAN-3: PubSub status broadcasts.** Emit `:pending`, `:generating`,
  `:ready`, `:failed` updates that the LiveView subscribes to.
- **OBAN-4: Retry & failure policy.** Backoff, max attempts, dead-letter
  observability for failed jobs.

## Epic 7 — Audio Playback (Tone.js)

- **AUDIO-1: Tone.js LiveView hook.** Mount a transport-aware hook, load
  a sequence payload, expose play/pause/stop.
- **AUDIO-2: Synth preset dropdown.** Sine, Square, Triangle, Sawtooth,
  FM Synth, Ambient Pad; switching reconfigures the active voice.
- **AUDIO-3: Tempo and transport controls.** Tempo slider, position
  scrubber, current-time display.
- **AUDIO-4: MIDI ingestion.** Parse the artifact returned by the MIDI
  service into a Tone.js-friendly schedule, including rests.

## Epic 8 — Visualization (p5.js)

- **VIS-1: p5.js LiveView hook.** Sketch lifecycle bound to the LiveView
  element; pause/resume with the audio transport.
- **VIS-2: Shared derived integers.** Visualization reads the same
  strategy-derived per-row integers used for audio, ensuring coherence.
- **VIS-3: Audio-visual synchronization.** Drive the sketch clock from the
  Tone.js transport; verify drift over multi-minute playback.
- **VIS-4: Visualization preset (MVP).** One opinionated visual style for
  the MVP; design hooks so a second can be added later without rework.

## Epic 9 — MidiSequence Persistence & Replay

- **SEQ-1: `MidiSequence` schema and migration.** Status, artifact ref,
  embedded mapping, dataset reference, note count, duration_ms.
- **SEQ-2: Sequences index LiveView.** List a user's saved sequences with
  metadata and a "play" action.
- **SEQ-3: Sequence detail LiveView.** Reuse the audio + visualization
  hooks to replay a saved sequence.
- **SEQ-4: Re-mapping flow.** From a saved sequence, clone the embedded
  mapping and regenerate against the same dataset.

## Epic 10 — Deployment & Observability

- **OPS-1: Production secrets and config.** Phoenix release secrets, Neon
  connection string, MIDI service URL, blob storage credentials.
- **OPS-2: Phoenix production deploy on Fly.io.** First non-staging deploy
  with health checks and rolling restarts.
- **OPS-3: MIDI service production deploy.** Same region as Phoenix;
  internal networking; restricted ingress.
- **OPS-4: Logging and error reporting.** Structured logs, an error-reporting
  destination (e.g., Sentry) for both services.

## Epic 11 — Documentation & Polish (pre-V1 freeze)

- **DOC-1: README expansion.** Project overview, screenshots, link to the
  ADRs, and a "Why these choices?" section that mirrors the ADR titles.
- **DOC-2: Demo dataset library.** A small set of canonical CSVs (sales,
  weather, sports) shipped in-repo for first-time users.
- **DOC-3: Onboarding doc.** Local setup including Postgres, MIDI service,
  blob storage adapter, and how to seed the demo datasets.
