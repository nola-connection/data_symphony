# 09 — Elixir Style & Architecture Guidelines

This is the **canonical reference** for how Elixir code is structured and styled
in Data Symphony. Reviewers point to it in PRs, and it is the document new
contributors read first. It builds on the specification docs (especially
[02 — Architecture](./02-architecture.md) and [03 — Domain Model](./03-domain-model.md))
and turns the intended shape of the system into concrete, enforceable rules.

When this guide and a tool disagree, the tool wins for mechanical concerns
(`mix format`) and this guide wins for judgment calls. Where a rule can be
automated, it is encoded in [`.credo.exs`](../.credo.exs) so the guideline is
enforced rather than merely aspirational — see
[Enforcement & tooling](#enforcement--tooling).

## Enforcement & tooling

Every change must pass the same gates CI runs (see
[07 — CI Pipeline](./07-ci-pipeline.md)):

```sh
mix format --check-formatted   # mechanical formatting
mix credo --strict             # style/architecture rules (config in .credo.exs)
mix compile --warnings-as-errors
mix test                       # ExUnit, incl. the per-ticket "guard" tests
mix dialyzer                   # type/spec analysis
```

- **Formatting is never debated.** `mix format` is the source of truth. Do not
  hand-format around it.
- **Credo encodes the automatable rules in this guide.** If a rule below can be
  checked mechanically, it should be enabled in `.credo.exs`. The
  [Credo mapping](#how-this-maps-to-credo) section lists which rules are
  enforced versus left to review.
- Line length is capped at **120 characters** (Credo `MaxLineLength`).

## Directory & module structure

The application is split into two top-level namespaces, mirroring the
generated Phoenix layout:

- `DataSymphony.*` (`lib/data_symphony/`) — the **core domain**: contexts,
  schemas, pure modules, processes, and infrastructure adapters. No web or
  HTTP concerns leak in here.
- `DataSymphonyWeb.*` (`lib/data_symphony_web/`) — the **web boundary**:
  endpoint, router, controllers, LiveViews, components, and plugs. This layer
  calls into the domain; the domain never calls back out to it.

Rules:

- **One module per file.** The only exception is a module used solely by its
  parent (e.g. a small struct or a test support module).
- **Module name mirrors the file path.** `DataSymphony.Datasets.Dataset` lives
  at `lib/data_symphony/datasets/dataset.ex`. Each namespace segment is a
  directory.
- **`snake_case` filenames for `CamelCase` modules**; keep acronyms uppercase
  (`CSVSource`, `MIDIClient`), per the Elixir naming conventions.
- Do **not** repeat a fragment across a namespace (`Datasets.Dataset` is fine;
  `Datasets.DatasetItem` over `Datasets.Item` is not — prefer `Datasets.Item`).

## Contexts, schemas, and pure modules

Data Symphony leans on **Phoenix Contexts** as the public API of the domain.
The boundary question — "where does this code belong?" — is answered as:

| Kind | Responsibility | Examples |
| --- | --- | --- |
| **Context** | Public entry point for a domain area. Orchestrates persistence, side effects, and pure logic. Returns plain data or `{:ok, _} / {:error, _}`. | `Datasets`, `MidiSequences` |
| **Schema** | Ecto struct, `changeset/2`, and *query-shaping* helpers (`filter/3`, `sort/2`, `projection/2`, `load_dependencies/2`). No business decisions. | `Datasets.Dataset`, `MidiSequences.MidiSequence` |
| **Pure module** | Side-effect-free domain logic — takes data, returns data. Trivially unit-testable, no DB or network. | `MappingStrategies`, `NoteDerivation`, `Datasets.Limits` |
| **Process** | Stateful or concurrent work that must be supervised. | Oban workers, GenServers |
| **Adapter** | Wraps an external dependency behind an app-defined interface. | `BlobStorage`, the MIDI service client |

Boundary rules:

- **Cross-context calls go through the other context's public functions**, never
  by reaching into its schemas or `Repo` directly. `MidiSequences` asks
  `Datasets` for a dataset; it does not query the `datasets` table itself.
- **Schemas never call the `Repo`.** Persistence lives in contexts. Schemas only
  describe data and shape queries.
- **Wrap third-party libraries.** A CSV tokenizer, the MIDI HTTP client, and
  blob storage are all reached through an app-specific interface
  (`DatasetParser.parse/1`, `BlobStorage`, …), so the dependency can change
  without rippling through the domain.
- **Validate untrusted input at the boundary.** Controller params, LiveView
  event params, and webhook payloads are validated/normalized *before* business
  logic branches on them — never thread raw, unvalidated maps deep into a
  context.

## Context module function patterns

Context modules follow a predictable shape so any context reads the same way.
Order the module **fetching functions first, then modifying functions, then
private helpers.** Add only the functions a context actually needs — this is a
menu, not a checklist.

Query building belongs in the **schema**, not the context. Importing
`Ecto.Query` into a context should be rare; delegate `where`/`order_by`/`select`
to schema functions so there is a single place to reason about indexes.

```elixir
# Build a queryable from options; preloads are applied here, never after fetch.
def query(opts \\ []) do
  id = Keyword.get(opts, :id, :unset)
  status = Keyword.get(opts, :status, :unset)
  preloads = Keyword.get(opts, :preloads, [])
  sort = Keyword.get(opts, :sort, {:desc, :inserted_at})

  MidiSequence
  |> MidiSequence.filter(:id, id)
  |> MidiSequence.filter(:status, status)
  |> MidiSequence.load_dependencies(preloads)
  |> MidiSequence.sort(sort)
end
```

The schema owns the matching `filter/3`, `sort/2`, `projection/2`, and
`load_dependencies/2` clauses, each handling the `:unset` sentinel by returning
the query unchanged.

Standard context functions and their contracts:

| Function | Returns | Notes |
| --- | --- | --- |
| `query/1` | queryable | Single source of truth for filters/sort/preloads. |
| `get/2`, `get!/2` | struct \| nil / raises | Thin wrappers over `Repo.get`. |
| `list/1` | `[struct]` | Builds on `query/1`. |
| `fetch/2` | `{:ok, struct} \| {:error, :not_found}` | **Prefer `fetch` over `get`** inside `with` chains. |
| `map/2`, `group_by/2` | map | O(1) lookups / one-to-many grouping. |
| `insert/1`, `update/2` | `{:ok, struct} \| {:error, changeset}` | Go through `changeset/2`. |
| `change/2` | changeset | For form-driving in LiveView. |

**Prefer `fetch/2` over `get/2`** for lookups used in `with` chains: a
`{:ok, _} / {:error, :not_found}` result composes cleanly, whereas a nil result
forces extra branching.

## Naming conventions

Follow the [Elixir naming conventions](https://hexdocs.pm/elixir/naming-conventions.html):
`snake_case` for atoms, functions, and variables; `CamelCase` for modules.

- **Modules** are nouns describing a thing or area: `Datasets`,
  `MidiSequences.MidiSequence`, `MappingStrategies`. Keep acronyms uppercase
  (`CSVSource`, `MIDIClient`).
- **Functions** are verbs or verb phrases for actions (`generate/1`,
  `derive_notes/2`) and nouns for accessors (`note_count/1`).
- **Predicates** that return a boolean end in `?` (`ready?/1`,
  `rest?/1`). The `is_` prefix is reserved for **guard-safe** macros
  (`defguard is_pending(status) when ...`). Never name a regular function
  `is_thing`.
- **Schemas** are singular (`Dataset`, `MidiSequence`); the table is plural
  (`datasets`, `midi_sequences`).
- **Workers** carry a `Worker` suffix and live under the context they serve
  (`MidiSequences.GenerationWorker`).
- A private helper must not share a name with a public function; avoid the
  `def name` / `defp do_name` pattern — find a more descriptive name for the
  private one.
- Custom types: name a module's primary type `t` (e.g. the struct's type spec).

## Pure vs side-effecting functions

Keep decision-making pure and push effects to the edges.

- **Pure modules** (`MappingStrategies`, `NoteDerivation`) take data and return
  data with no DB, network, or process interaction. They are the easiest code
  to test and the safest to reuse — note derivation runs identically for audio
  and for the visualization layer because it is pure.
- **Side effects** (DB writes, HTTP calls to the MIDI service, blob storage,
  PubSub broadcasts) live in contexts and workers, ideally as a thin shell
  around pure logic: parse/validate → compute (pure) → persist/broadcast.
- **Do not write `handle_response/1`-style wrappers** whose only job is to
  pattern-match a result tuple. Handle `{:ok, _}` / `{:error, _}` inline in a
  `case` or `with` so the branching is visible at the call site.
- Use `Repo.transact/1` with a `with` chain for multi-step writes that must be
  atomic; return `{:error, _}` from any step to roll back. Reach for
  `Ecto.Multi` only when you genuinely need its data-collecting semantics.

## Process & supervision conventions

Processes are for **state and concurrency that must be supervised**, not a
default tool. The domain logic above should be reachable without spawning
anything.

- **Reach for a process when** you need durable async work, long-lived state,
  serialized access to a resource, or fan-out with back-pressure.
- **Do _not_ introduce a process when** a plain module function will do. A
  GenServer that only wraps a pure computation, or that exists to "cache" a
  value better derived on demand, is a liability — it adds a single-point
  bottleneck and a supervision concern for no benefit.

Conventions:

- **Background work uses Oban**, not bespoke `Task.Supervisor` pipelines (see
  [ADR-0003](./adr/0003-oban-async-processing.md)). Workers must be
  **idempotent and safe to retry**; the composition-generation path enqueues a
  job and returns immediately.
- **Status/progress is broadcast via `Phoenix.PubSub`** for LiveView to consume
  (`MidiSequence` status changes → broadcast → LiveView updates). Contexts
  broadcast; LiveViews subscribe.
- **Name OTP primitives in their child spec.** `DynamicSupervisor` and
  `Registry` require a `name:` (`{DynamicSupervisor, name: DataSymphony.SomeSup}`)
  so children can be started against it.
- Everything that must survive a restart belongs in the supervision tree in
  `DataSymphony.Application`, started in dependency order.
- Use `Task.async_stream/3` (usually with `timeout: :infinity`) for concurrent
  enumeration that needs back-pressure, rather than unbounded `spawn`.

## Ecto & data-access conventions

- **Preload in the query**, never after fetching, and only what the caller
  needs.
- Share changeset field lists via module attributes so `cast/3` and
  `validate_required/3` have a single source of truth:

  ```elixir
  @required_fields [:dataset_id, :mapping]
  @optional_fields [:note_count, :duration_ms]
  @all_fields @required_fields ++ @optional_fields
  ```

- **Fields set programmatically** (e.g. `dataset_id`, `status`) are **not** in
  `cast/3`; set them explicitly when building the struct.
- Access changeset fields with `Ecto.Changeset.get_field/2`, never
  `changeset[:field]` (structs don't implement `Access`).
- Write **safe migrations** (avoid table locks/downtime); follow the
  [safe Ecto migrations](https://github.com/fly-apps/safe-ecto-migrations)
  guidance.
- Keep **error messages short and user-facing** ("dataset not found"), and do
  not interpolate internal IDs/values into them.

## Formatting & style essentials

These are applied by `mix format` and/or enforced by Credo; the highlights:

- Pipe (`|>`) for multi-step transforms; **don't pipe a single call** — write
  `String.downcase(s)`, not `s |> String.downcase()`. Start a pipeline from a
  bare value.
- Prefer literal atom lists (`[:pitch, :velocity]`) over `~w(...)a` sigils.
- Use `with` for happy-path chains; use multi-line `with`/`else` when there is
  more than one clause or an `else`.
- `case`/`cond` clauses that need more than one line use multi-line syntax for
  **all** clauses, separated by blank lines; end `cond` with `true ->`.
- Never use `unless` with `else` — rewrite positive-first.
- Module contents are ordered: `@moduledoc`, `@behaviour`, `use`, `import`,
  `require`, `alias`, attributes, `defstruct`, `@type`, callbacks, then
  functions. Always include a `@moduledoc` (or `@moduledoc false`).
- Place `@spec` directly above the function, after `@doc`, with no blank line
  between.

## Testing conventions

- ExUnit + `Phoenix.LiveViewTest`; tests live under `test/` mirroring `lib/`.
- **Acceptance-criteria "guard" tests:** each foundation ticket gets a test
  whose `@moduledoc` names the ticket and whose `describe "criterion N: ..."`
  blocks map one-to-one to the ticket's criteria (see
  `test/data_symphony/deploy_scaffold_test.exs`). New tickets follow suit.
- Put the expression under test on the **left** of an assertion
  (`assert actual == expected`), except for pattern-match assertions
  (`assert {:ok, x} = ...`).
- Drive LiveView assertions off stable DOM IDs via `has_element?/2` and
  `element/2`; don't assert against raw HTML strings.
- Give every form/key element a unique DOM `id` so tests can target it.

## How this maps to Credo

`mix credo --strict` enforces the automatable subset of this guide. Notable
mappings already enabled in [`.credo.exs`](../.credo.exs):

| Guideline | Credo check |
| --- | --- |
| Module/file naming | `Readability.ModuleNames`, `Readability.FunctionNames` |
| Predicate naming (`?`) | `Readability.PredicateFunctionNames` |
| Module contents ordering | `Readability.StrictModuleLayout` |
| Alphabetized aliases | `Readability.AliasOrder` |
| `@moduledoc` required | `Readability.ModuleDoc` |
| No single-element pipe | `Readability.SinglePipe` |
| 120-char line limit | `Readability.MaxLineLength` |
| `unless ... else` banned | `Refactor.UnlessWithElse` |
| `cond` redundancy / negation | `Refactor.CondStatements`, `Refactor.NegatedConditionsWithElse` |

Judgment-based rules in this guide (context boundaries, pure-vs-effecting
placement, when to add a process) are **not** automatable and are enforced in
code review using this document as the reference.

