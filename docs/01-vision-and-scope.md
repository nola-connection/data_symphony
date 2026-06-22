# 01 — Vision & Scope

## Vision

Data Symphony is a web application that transforms structured datasets into
generative music and synchronized visual art. Users upload a CSV containing any
kind of data — sales reports, weather history, sports statistics, stock prices,
scientific measurements — and the application converts that dataset into a
musical composition paired with an animated visualization.

The project exists to showcase modern software engineering practice end-to-end:
real-time UI, event-driven processing, service-oriented architecture, and
multimedia generation.

## Portfolio Goals

The implementation should demonstrate:

- Elixir and Phoenix expertise
- Phoenix LiveView real-time UI development
- PostgreSQL data modeling with Ecto
- Background job processing (Oban)
- Service-oriented architecture (Elixir ↔ Python)
- External API integrations (V2)
- Audio generation pipelines
- Visualization systems synchronized to audio
- Extensible domain modeling
- Event-driven workflows

## MVP Scope

The MVP focuses on a single end-to-end workflow with one data source (CSV).
External data sources, GraphQL, and multi-track composition are explicitly
out of scope for the MVP and live in the [roadmap](./05-roadmap.md).

### User Workflow

1. Upload a CSV file.
2. Parse and validate the dataset.
3. Infer column types.
4. Configure mappings from data columns to musical attributes.
5. Generate a MIDI composition.
6. Play the composition in-browser.
7. Render synchronized visualizations.
8. Save compositions for later playback.

### Worked Example

CSV input:

```csv
date,revenue,orders
2026-01-01,1500,12
2026-01-02,1800,14
2026-01-03,1200,9
```

Example mapping:

- `revenue` → pitch
- `orders` → velocity
- `date` → timing

Output:

- A MIDI sequence
- Audio playback via Tone.js
- An animated visualization rendered with p5.js

### Out of Scope for MVP

- Live external data sources (weather, stocks, earthquakes, etc.)
- GraphQL API
- React or React Native clients
- Multi-track or chord-aware composition
- User accounts beyond what is needed to save compositions
- Mobile-optimized UI

## Success Criteria

The MVP is complete when a user can:

1. Upload a CSV.
2. View parsed data with inferred column types.
3. Configure a mapping from columns to musical attributes.
4. Generate a composition asynchronously.
5. Play the music in-browser.
6. See a synchronized visualization during playback.
7. Save and replay a generated composition.

At that point the application is a unique, technically interesting portfolio
project demonstrating modern Elixir engineering, service-oriented
architecture, multimedia generation, and real-time user experiences.
