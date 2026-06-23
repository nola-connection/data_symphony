# 08 — Fly.io Monthly Cost Estimate

A **rough, order-of-magnitude** estimate of the monthly Fly.io cost for the
deploy scaffold introduced in **F-5**. Numbers are approximate pay-as-you-go
figures and will drift with usage and Fly's pricing; treat them as planning
guidance, not a quote. Always confirm against the current
[Fly.io pricing page](https://fly.io/docs/about/pricing/).

## Assumptions

- Both apps run `shared-cpu-1x` machines with **512 MB** RAM (see `fly.toml` /
  `fly.staging.toml`).
- **Staging** sets `min_machines_running = 0` with auto-stop/auto-start, so it
  scales to zero when idle and only bills while serving requests.
- **Production** sets `min_machines_running = 1`, so one machine runs 24/7.
  (Production deploy itself is OPS-2; the config is committed now as the
  staging baseline.)
- The database is **Neon** (external — see `docs/06-database-setup.md`), so it
  is **not** part of the Fly.io bill and is listed separately below.
- Region: single region (`iad`). No dedicated IPv4 (shared IPv4 + anycast IPv6
  are free).
- Low MVP traffic: well under typical free bandwidth allowances.

## Unit costs used (approximate)

| Resource                        | Approx. price        |
| ------------------------------- | -------------------- |
| `shared-cpu-1x`, 256 MB, 24/7   | ~$1.94 / mo          |
| Extra RAM (to reach 512 MB)     | ~$1.25 / mo (+256MB) |
| `shared-cpu-1x`, 512 MB, 24/7   | ~$3.19 / mo          |
| Dedicated IPv4 (optional)       | $2.00 / mo           |
| Shared IPv4 + anycast IPv6      | $0.00                |
| Outbound bandwidth (NA/EU)      | ~$0.02 / GB          |

## Estimate

| Component                          | Sizing / usage                  | Est. monthly |
| ---------------------------------- | ------------------------------- | ------------ |
| Production app (`data-symphony`)   | 1 × 512 MB machine, 24/7        | ~$3.20       |
| Staging app (`data-symphony-staging`) | 1 × 512 MB, scale-to-zero    | ~$1–3        |
| Public IPs                         | shared IPv4 + IPv6              | $0.00        |
| Bandwidth                          | light MVP traffic (< a few GB) | ~$0–1        |
| **Fly.io subtotal**                |                                 | **~$5–8**    |

### External (not billed by Fly.io)

| Component        | Notes                                             | Est. monthly |
| ---------------- | ------------------------------------------------- | ------------ |
| Neon PostgreSQL  | Free tier for early dev; ~$19 for Launch plan     | $0–19        |

## Scenarios

- **Lean dev (staging mostly idle, Neon free tier):** ~**$3–5 / mo** on Fly.io.
- **Staging + always-on prod + Neon Launch:** ~**$25–30 / mo** all-in.

## Cost levers

- Keep `min_machines_running = 0` on staging (already set) so idle time is free.
- Right-size memory: drop to 256 MB if the release fits, roughly halving compute.
- Stay on shared (not dedicated) IPv4 to avoid the $2/mo per-IP charge.
- The future MIDI Python service (see `docs/02-architecture.md`,
  `docs/tickets.md` OPS-3) will add another small machine — budget a similar
  ~$2–4/mo when it ships; it is **not** part of this scaffold.
