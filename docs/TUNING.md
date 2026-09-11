# Tuning Log

Every change to a tuning constant, with the observation that caused it and the solver report before/after. Constants live in JSON only.

| Date | Constant | Old → New | Because (observation or solver metric) | Solver tightness before → after |
|---|---|---|---|---|
| 2026-09-11 | wet.rate_tiles_per_s | 0.25 (unchanged) | Measured in M1: the kitchen holds 9 walkable floor cells, not 10 — the fridge sits on (2,2). Full flood takes 35.9 s from the tap, against the spec's ~40 s. Left alone; the solver's `tightness` in M2 decides. | n/a (no solver yet) |

## Current baseline (from docs/02-technical-spec.md §17)

player walk 3 t/s · attacker walk 2.5 · tick 0.1s · timer 90s · wet spread 0.25 t/s · phone charge 30s · help delay 75s · patience 40s · search 3s (×2 dark) · sight 6 (3 dark) · throw range 5 · cord range 3 · disable hold 10s · prone 3s · stunned 2s · blinded 4s · shock 3s
