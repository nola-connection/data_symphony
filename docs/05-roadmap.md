# 05 — Roadmap

The MVP intentionally focuses on one source (CSV) and one client (LiveView).
This roadmap captures the directions the project is designed to grow in
without committing to a delivery date.

## V2 — External Data Sources

Generate compositions from live public APIs. The `DataSource` abstraction
already accommodates this — each external source becomes a new variant that
produces a standard `Dataset`.

Candidate sources:

- Weather (e.g., Open-Meteo)
- Air quality
- Earthquakes (USGS)
- Traffic
- Stock markets
- Cryptocurrency
- Space launch data

Engineering implications:

- Scheduled Oban jobs to pull from APIs
- Per-source rate-limit handling
- Source credentials managed via runtime config / secrets
- Source-specific normalization layer that feeds the shared dataset pipeline

## V2 — Compositions (Multi-Sequence Works)

In the MVP, `MidiSequence` is the top-level playable entity. V2 introduces
`Composition`, an ordered collection of sequences via a `composition_sequences`
join table carrying `position`. A composition can mix sequences from
different datasets, enabling longer, hand-curated pieces without changing how
individual sequences are generated.

## V2 — GraphQL API

GraphQL becomes valuable once multiple clients exist. The likely clients are:

- A React web app (parallel to LiveView, not a replacement)
- A React Native mobile app
- External integrations / partner consumers

Technology: [Absinthe](https://absinthe-graphql.org/).

Sample queries and mutations to scope when this work begins:

```graphql
query {
  midiSequences {
    id
    status
    noteCount
    durationMs
    generatedAt
  }
}

mutation {
  generateMidiSequence(datasetId: ID!, mappingInput: MappingInput!) {
    id
    status
  }
}
```

Once `Composition` ships (see above), a `compositions` query and a
`generateComposition` mutation join the schema alongside the
`midiSequences` examples here.

Note that LiveView remains the default client; GraphQL is additive.

## Long-Term Architecture

```
 CSV Upload ─┐
 Weather API ─┤                                          ┌──→ Music
 Traffic API ─┼──→ Dataset → MidiSequence → Composition ─┼──→ Visual Art
 Stock API ───┤                                          └──→ Ambient Mode
 Earthquakes ─┘
```

"Ambient mode" is a speculative output channel: long-running, low-intensity
generative output suitable for background play, driven by streaming data
sources rather than discrete datasets.

## Other Candidate Improvements

These are not committed and are listed only to capture intent:

- Multi-track / chord-aware composition
- Scale quantization beyond the MVP set
- Instrument selection per column
- Composition sharing via public links
- Per-user accounts and libraries
- Mobile-friendly playback UI
- Export to WAV / MP4 (audio + visual render)
