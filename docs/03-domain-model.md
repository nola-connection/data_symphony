# 03 — Domain Model

The MVP domain has two tables: `Dataset` and `MidiSequence`. Everything else
(source variants, mapping configuration, strategies, limits) lives as
embedded values or as in-code modules rather than its own table.

## Dataset

Represents a parsed CSV upload. A dataset is immutable once accepted; a new
upload creates a new record.

Fields:

- `id`
- `source_type :: string` — discriminator for the polymorphic source
- `source :: polymorphic_embed` — variant-specific metadata
  (`CSVSource`, future `WeatherSource`, etc.)
- `column_headers :: array(string)` — the header row of the CSV
- `row_count :: integer`
- `column_count :: integer`
- `byte_size :: integer`
- `original_blob_ref :: string` — pointer to the stored raw CSV
- `derived_blob_ref :: string | nil` — optional cache of per-cell integers;
  invalidated when a strategy changes
- `inserted_at`, `updated_at`

Individual cells are **not** persisted as DB rows. The raw CSV lives in blob
storage; integer derivation happens on demand.

### Source variants (polymorphic embed)

The `source` field uses [`polymorphic_embed`](https://hex.pm/packages/polymorphic_embed)
with `source_type` as the discriminator.

- MVP: `CSVSource` — `original_filename`, `uploaded_at`, `mime_type`
- Roadmap: `WeatherSource`, `StockSource`, `TrafficSource`, `EarthquakeSource`, …

Each variant module exposes `default_mapping/1`, returning a sensible
starting mapping for that source's known columns.

## MidiSequence

Represents one playable rendering of a dataset. A dataset can have many
sequences — re-mapping creates a new sequence, and the old one stays
playable forever.

Fields:

- `id`
- `dataset_id :: references(:datasets)`
- `mapping :: embed` — see below
- `note_count :: integer`
- `duration_ms :: integer`
- `midi_artifact_ref :: string`
- `status :: enum` — `pending | generating | ready | failed`
- `inserted_at`, `updated_at`

Status changes drive `Phoenix.PubSub` broadcasts for LiveView.

### Mapping (embedded)

The mapping is stored inline on the sequence. See
[ADR-0004](./adr/0004-mapping-embedded-on-midi-sequence.md) for rationale.

```json
{
  "tempo_bpm": 120,
  "scale": "major",
  "quantize": "1/16",
  "columns": {
    "revenue": { "role": "pitch",    "strategy": "linear",     "min": 0,   "max": 127 },
    "orders":  { "role": "velocity", "strategy": "linear",     "min": 0,   "max": 127 },
    "date":    { "role": "duration", "strategy": "string_sum", "min": 100, "max": 800 }
  }
}
```

Fields:

- `tempo_bpm` — global tempo (BPM)
- `scale` — `major | minor | pentatonic | …`; pitches are quantized into this scale
- `quantize` — note-length quantization: `1/4 | 1/8 | 1/16 | 1/32 | none`
- `columns` — per-column `role`, `strategy`, and strategy params

Note timing is **implicit in CSV row order**: note N is the Nth row. Note
**length** is derived from the column assigned to the `duration` role and
then rounded by `quantize`.

#### Column roles

| Role         | Effect                                                 |
| ------------ | ------------------------------------------------------ |
| `pitch`      | Drives note pitch (quantized into the chosen scale)    |
| `velocity`   | Drives note velocity (0–127)                           |
| `duration`   | Drives note length (then rounded by `quantize`)        |
| `gate`       | If derived value is falsy, the note is a rest          |
| (unassigned) | Column is ignored                                      |

#### Rests

A note renders as a rest when:

- The pitch-driving column produces `nil` (e.g. an empty cell), or
- A `gate`-role column produces a falsy value, or
- A strategy explicitly emits a rest

Rests are first-class events; they preserve sequence position and timing.

## Mapping strategies

Strategies are pure functions in code, not rows in a table. They live in a
named registry (`MappingStrategies`) and are referenced by string name from
the embedded mapping. Names are versioned (`name_v2` for breaking changes)
so historical sequences remain reproducible. See
[ADR-0005](./adr/0005-integer-cells-and-row-order.md) for rationale.

MVP strategy set:

| Name                   | Output                                                                  |
| ---------------------- | ----------------------------------------------------------------------- |
| `linear`               | Linear interp from `[min, max]` of derived ints into the role's range   |
| `string_sum`           | Sum of character codes of the cell string, modulo target range          |
| `string_sum_mod_scale` | `string_sum` then quantized into the active scale                       |
| `parity_gate`          | Even/odd of `string_sum` → on/off; used with the `gate` role            |
| `bucketed`             | Hash to one of N buckets (e.g., 12 pitches)                             |

Each strategy receives `(cell_string, derivation_context, params)` and
returns an integer or `nil`. The same derived integer is available to the
visualization layer so audio and visuals stay coherent without duplicate
logic.

## Limits

Upload-time policy lives in a runtime-configured `Datasets.Limits` module,
not in the database. Defaults:

| Knob                       | Default  |
| -------------------------- | -------- |
| `max_byte_size`            | 10 MB    |
| `max_row_count`            | 10,000   |
| `max_column_count`         | 64       |
| `max_cell_length`          | 1 KB     |
| `max_notes_per_sequence`   | 2,000    |
| `midi_service_timeout_ms`  | 30,000   |

`row_count`, `column_count`, and `byte_size` of an accepted upload are
stored on the `Dataset` row for diagnostics — these are *measurements*, not
the limits themselves.

## Entity relationships

```
 Dataset 1 ──< MidiSequence
```

- A `Dataset` carries an embedded `source` (polymorphic).
- A `MidiSequence` carries an embedded `mapping` (with strategy references).

## Future entities (roadmap, not built)

- **`Composition`** — `has_many :sequences, through: :composition_sequences`
  with `position` on the join table. Lets a user assemble multiple sequences
  into an ordered piece. See [05 — Roadmap](./05-roadmap.md).

## Persistence notes

- Original CSVs and generated MIDI bytes live as blob artifacts (object
  storage in production, filesystem in dev). The database stores references
  and metadata only.
- The `source` polymorphic embed is JSONB; `source_type` is a real column
  alongside it to keep "all weather datasets" queries cheap.
- MidiSequence status changes drive `Phoenix.PubSub` broadcasts.
