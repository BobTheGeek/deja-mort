# Tuning Log

Every change to a tuning constant, with the observation that caused it and the solver report before/after. Constants live in JSON only.

| Date | Constant | Old → New | Because (observation or solver metric) | Solver tightness before → after |
|---|---|---|---|---|
| 2026-09-11 | wet.rate_tiles_per_s | 0.25 (unchanged) | Measured in M1: the kitchen holds 9 walkable floor cells, not 10 — the fridge sits on (2,2). Full flood takes 35.9 s from the tap, against the spec's ~40 s. Left alone; the solver's `tightness` in M2 decides. | n/a (no solver yet) |

## Current baseline (from docs/02-technical-spec.md §17)

player walk 3 t/s · attacker walk 2.5 · tick 0.1s · timer 90s · wet spread 0.25 t/s · phone charge 30s · help delay 75s · patience 40s · search 3s (×2 dark) · sight 6 (3 dark) · throw range 5 · cord range 3 · disable hold 10s · prone 3s · stunned 2s · blinded 4s · shock 3s
| 2026-09-11 | room_01_studio.rubric.two | (default) → `ending != 'evade'` | The default `two` predicate is `damage_taken == 0 \|\| ending != 'kill' \|\| loop.index <= 6`, which hands the second star to every evade, so `evade_phone` scored 2 and docs/03 §6 says it should score 1. Room 1 now overrides `two`: the second star is for stopping him, not for outlasting him. Spec §11 allows a room to override `two`, and this makes the three authored solutions land on 1 / 2 / 3 exactly as the room doc says. The default is untouched for other rooms. | evade 1★ · disable 2★ · kill 3★ |
| 2026-09-11 | timer_s | 90 (unchanged) | Solver Mode A measures tightness (timer minus the seconds the player spends walking and acting) at evade 62.1 s, disable 77.0 s, kill 81.0 s. docs/03 §11 predicted 30-40 s of slack for the kill path, so 90 s is roughly twice as generous as the design assumed. Left alone until M3 playtesting says whether the slack feels like freedom or like dead air. | evade 62.1 · disable 77.0 · kill 81.0 |
| 2026-09-11 | hazard_effects.slippery / .trip | added `on_enter_only` | You slip when you step on the oil, not for as long as you stand on it. Without this an actor on an oiled cell is re-proned every three seconds, cannot walk out of it, and the loop deadlocks — the attacker froze in the doorway for the whole 300 s cap. | n/a |
