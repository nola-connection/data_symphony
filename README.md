# DataSymphony

Data Symphony is a web application that transforms structured datasets into generative music and synchronized visual art.  Users upload CSV files containing any type of data (sales reports, weather history, sports statistics, stock prices, scientific measurements, etc.) and convert those datasets into musical compositions and visual experiences.

## Requirements

The Elixir/OTP toolchain is pinned in [`.tool-versions`](.tool-versions) so
local development and CI stay in sync (use [asdf](https://asdf-vm.com) or
[mise](https://mise.jdx.dev) to install it):

- **Elixir** `1.15.8` (OTP 25)
- **Erlang/OTP** `25.3.2.21`
- **PostgreSQL** (a local server reachable at `localhost:5432`)

## Running the Phoenix app

From the repository root:

```sh
mix setup            # fetch deps, create/migrate the DB, install & build assets
mix phx.server       # start the server at http://localhost:4000
```

`mix setup` runs `mix deps.get`, `mix ecto.setup`, and the asset build. If you
prefer to run the steps individually, use `mix deps.get`, `mix ecto.create`,
`mix ecto.migrate`, then `mix phx.server`.

## Development tooling

```sh
mix format --check-formatted   # formatting
mix credo --strict             # linting (config in .credo.exs)
mix dialyzer                   # type/spec analysis (PLTs cached in priv/plts)
mix test                       # ExUnit test suite
```

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

## Phoenix App

This repository now hosts the bootstrapped Phoenix + LiveView application
(Ecto/PostgreSQL, Bandit, esbuild + Tailwind) that the rest of the product is
built on — see "Running the Phoenix app" above. The specs in `docs/` describe
the broader intended architecture (Oban, the Python MIDI service, etc.), which
is layered on top of this foundation in later epics. The browser MVP under
`priv/static` remains as an early end-to-end product prototype.
