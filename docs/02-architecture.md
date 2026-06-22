# 02 — Architecture

## High-Level Data Flow

```
 CSV Upload
     ↓
 Dataset Parser           (streaming reader, stores raw CSV as blob)
     ↓
 Dataset                  (Ecto row: headers, counts, blob refs)
     ↓
 Mapping Configuration    (per-column role + strategy + range, embedded)
     ↓
 Oban Job                 (async dispatch)
     ↓
 Note Derivation          (strategies turn cells into integers, then notes)
     ↓
 MIDI Generator Service   (Python HTTP service)
     ↓
 MidiSequence             (Ecto row + MIDI artifact)
     ↓
 Playback Engine          (Tone.js, LiveView)
     ↓
 Visualization Engine     (p5.js, syncs to Tone.js, shares derived ints)
```

## Service Boundaries

The MVP has two deployable services:

1. **Phoenix application** — owns the database, LiveView UI, dataset and
   sequence domains, mapping configuration, note derivation, background
   jobs, and orchestration.
2. **MIDI generation service** — a small Python HTTP service that turns
   normalized note data into a MIDI file. See
   [ADR-0002](./adr/0002-python-midi-microservice.md) for rationale.

The Phoenix application is the only client of the MIDI service. Communication
is HTTP/JSON; the service is stateless.

## CSV Processing

**Goal:** parse uploads as a stream, persist the raw file as a blob, and keep
the database small. Type inference is intentionally not performed — see
[ADR-0005](./adr/0005-integer-cells-and-row-order.md) for rationale.

A CSV library may be used internally for tokenization, but it must be wrapped
behind an application-specific interface:

```elixir
DatasetParser.parse(file)
```

Responsibilities:

- Stream the file line by line (no whole-file loads)
- Validate row shape and header presence
- Enforce `Datasets.Limits` (byte size, row count, column count, cell length)
- Aggregate structured error reports rather than failing on the first issue
- Write the raw CSV to blob storage
- Return a normalized `dataset_attrs` struct: headers, counts, blob ref

Per-cell integer derivation happens later, driven by the mapping's strategies
when a `MidiSequence` is generated. Changing strategies does not require a
re-upload.

## Background Processing

Heavy operations run asynchronously via [Oban](https://hexdocs.pm/oban).
See [ADR-0003](./adr/0003-oban-async-processing.md) for the rationale.

```
 CSV Upload
     ↓
 Create Dataset (sync; raw CSV → blob storage)
     ↓
 User configures mapping (LiveView)
     ↓
 Enqueue MidiSequence generation job
     ↓
 Worker derives notes via MappingStrategies → calls MIDI service
     ↓
 Persist MidiSequence + MIDI artifact
     ↓
 Broadcast to LiveView via Phoenix.PubSub
```

Benefits:

- Upload completes quickly; LiveView shows progress
- Retries, backoff, and observability are handled by Oban
- The same pipeline supports future async sources (weather, stocks, etc.)

## MIDI Generation Service

The service accepts normalized note data and returns a generated MIDI artifact.

Example request:

```json
{
  "tempo": 120,
  "quantize": "1/16",
  "notes": [
    { "pitch": 64,   "velocity": 100, "duration_ms": 500 },
    { "pitch": null, "velocity": 0,   "duration_ms": 250 },
    { "pitch": 67,   "velocity": 90,  "duration_ms": 750 }
  ]
}
```

A note with `pitch: null` (or `velocity: 0`) is rendered as a rest. The
service applies note-length quantization server-side using the `quantize`
value.

Example response:

```json
{
  "midi_file_url": "/generated/example.mid"
}
```

The response format may evolve to inline base64 MIDI bytes rather than a URL
to avoid shared storage between services — this is an open design question
to resolve before implementation.

## Audio Playback

[Tone.js](https://tonejs.github.io/) is responsible for:

- MIDI playback in the browser
- Synthesizer voicing
- Transport timing

MVP synth presets: Sine, Square, Triangle, Sawtooth, FM Synth, Ambient Pad.
Users switch presets from a dropdown in the LiveView.

## Visualization

[p5.js](https://p5js.org/) renders the visualization. The Tone.js transport
clock drives visual playback so the audio and visuals stay in sync.

Suggested mappings:

| Musical attribute | Visual attribute      |
| ----------------- | --------------------- |
| Pitch             | Vertical position     |
| Velocity          | Brightness            |
| Duration          | Width                 |
| Instrument        | Shape                 |
| Time              | Animation position    |

```
Audio    ██████████████████
Visual   ██████████████████
```

Both timelines remain synchronized for the duration of playback.
