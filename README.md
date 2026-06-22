# DataSymphony

Data Symphony is a web application that transforms structured datasets into generative music and synchronized visual art.  Users upload CSV files containing any type of data (sales reports, weather history, sports statistics, stock prices, scientific measurements, etc.) and convert those datasets into musical compositions and visual experiences.


## Local MVP

This branch includes a dependency-light browser MVP under `priv/static`.

Run a local static server from the repository root:

```sh
python3 -m http.server 4000 -d priv/static
```

Then open:

```text
http://localhost:4000
```

The MVP supports the first end-to-end workflow from the specs:

- upload or load a sample CSV
- inspect parsed rows and inferred column types
- map columns to pitch, velocity, duration, and gate roles
- generate a playable sequence asynchronously
- play synthesized audio in-browser
- view a synchronized canvas visualization
- save and replay sequences from browser local storage

## Future Phoenix App

The specs in `docs/` describe the intended Phoenix LiveView, Ecto, Oban, and
Python MIDI-service architecture. The current local MVP is intentionally small
so the product loop can be tested before the full service stack is bootstrapped.
