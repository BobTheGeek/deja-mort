# Tuning Log

Every change to a tuning constant, with the observation that caused it and the solver report before/after. Constants live in JSON only.

Read the newest pass first. `tightness_s` is the metric: the countdown minus the seconds the player actually spends walking and acting. Waiting is free, so tightness answers "how much of the timer did this solution not need?"

---

## Pass 1 — 2026-09-12 — the M2 decision gate, against `tightness_s`

`docs/07-milestones.md` puts a decision gate before M3: *tune `timer_s`, breach costs, patience and spread rate against the solver's `tightness_s`*. This is that pass. One constant moved; three did not, and the evidence for leaving them is recorded, because "unchanged" is a decision too.

**Method.** `godot --headless -s tools/solve.gd -- content/rooms/room_01_studio.json`, seed 1. `timer_s` was swept over 90 → 40 in ten steps with all three authored solutions re-verified at each value, then the winning mechanism of the evade path was traced at each value. Everything below is measured, not estimated.

| Date | Constant | Old → New | Because (observation or solver metric) | Solver tightness before → after |
|---|---|---|---|---|
| 2026-09-12 | `room_01_studio.timer_s` | **90 → 75** | The countdown was not a constraint. At 90 s the three authored solutions left 62.1 / 77.0 / 81.0 s unused, against the 30–40 s `docs/03` §11 predicted. The sweep says all three still pass anywhere from 90 down to 40, so the timer is not what makes the room hard — but below 65 the *evade path silently changes meaning* (see the floor below). 75 s cuts a sixth of the dead time, moves evade from 62.1 → 47.1, and keeps the phone as the reason the evade works with a 12.2 s cushion. It is a deliberate first step, not the final answer: the doc's 40 s target for evade needs 70 s, and 70 s leaves only 1.4 s of margin before the mechanism flips. | evade 62.1 → **47.1** · disable 77.0 → **62.0** · kill 81.0 → **66.0** |
| 2026-09-12 | `tenant_knife.patience_s` | 40 (unchanged) | Not the binding mechanism, and correctly so. In the authored evade he burns 27.8 s of his 40 before help arrives, so the phone wins and patience is the backstop — which is what the room is supposed to teach. No measurement suggests a better number, and guessing one before anyone has played the room would be inventing data. **Watch in M3:** both of Mode B's improvised wins are pure patience evades, and `min_actions_to_win` is 4. Outlasting him may simply be too cheap. | evade uses 27.8 / 40 s |
| 2026-09-12 | `tenant_knife.breach_costs` | locked 4 · chained 3 · braced_heavy 10 (unchanged) | The exchange rate is the number to react to, and it looks right. Three actions worth 3.0 s of action duration — lock, chain, push the fridge — delay him 17.3 s: he is inside at 92.0 s with the door untouched and 109.3 s with it locked, chained and braced. Roughly six seconds bought per second spent. Those 17.3 s are exactly what lets help beat him to the bathroom, so this constant and `timer_s` are one system; changing either alone moves the evade path. | barriers buy 17.3 s |
| 2026-09-12 | `wet.rate_tiles_per_s` | 0.25 (unchanged) | Sets a hard floor under `timer_s`, and the floor is far below where we are. The doorway cell (1,2) is wet 35.9 s after the tap, and the tap goes on at 2.2 s, so the kill path needs a countdown longer than ~38 s to exist at all. At 75 s there is 36.9 s of margin. Nothing to fix. | kill 66.0 s slack, flood floor ~38 s |

### The floor the sweep found

**`timer_s` must not drop below 65.** Not because a solution fails — all three pass down to 40 — but because of what wins:

| `timer_s` | He is inside at | Help fires at | Patience used | Why the evade wins |
|---|---|---|---|---|
| 90 | 109.3 s | 115.6 s | 11.8 / 40 s | help arrives |
| 80 | 99.3 s | 115.6 s | 27.8 / 40 s | help arrives |
| **75** | **94.3 s** | **115.6 s** | **27.8 / 40 s** | **help arrives** |
| 70 | 89.3 s | 115.6 s | 38.6 / 40 s | help arrives, by 1.4 s |
| 65 | 84.3 s | 115.6 s | 38.6 / 40 s | help arrives, by 1.4 s |
| 60 | 79.3 s | 115.6 s | 44.4 / 40 s | patience runs out |
| 50 and below | 69.3 s | never | 44.4 / 40 s | patience runs out; **the phone is never used** |

At 60 and below, `evade_phone` still reports `ending=evade` and Mode A still passes — but the player charged a phone, made a call, and won for an entirely different reason. At 50 the call never even lands. Room 1's stated lesson is *buy seconds and let help arrive*; a solver green tick does not notice when the lesson quietly stops being taught. Any future change to `timer_s`, `phone.charge_s`, `help.delay_s` or the breach costs should re-run the mechanism trace above, not just Mode A.

### What this pass did not fix

- **The kill path is loose and the timer cannot fix it.** `kill_toaster` spends 9.0 s acting. `evade_phone` spends 27.8 s. No single countdown puts both in the doc's 30–40 s band; they are 19 s apart in cost. Making the kill tighter is a *content* change — the signature solution needs more setup — and that is Bob's call, not a constant.
- **Prose still says 90 seconds.** `content/rooms/room_01_studio.json`'s `fantasy` field was updated to 75 because it is data that must match data. `docs/01-design-doc.md`, `docs/02-technical-spec.md` §3/§17 and `docs/03-room-01-studio.md` still say 90 and were left alone: they are design documents and the number is Bob's to sign off.

### Schema change made to enable this pass

`authored_solutions[].actions[]` now accepts **`t_after_arrival`** alongside `t`. `t` is absolute; `t_after_arrival` is measured from the countdown hitting zero. Two of Room 1's actions are reactions to him walking in — dropping the shelf while he is prone, throwing the toaster into the water he is standing in — and they were pinned to absolute seconds 93 and 92, which silently broke the moment `timer_s` moved. They are now `+3` and `+2`. Without this, tuning the timer means hand-editing magic numbers in two solutions and hoping.

---

## Earlier entries

| Date | Constant | Old → New | Because (observation or solver metric) | Solver tightness before → after |
|---|---|---|---|---|
| 2026-09-11 | `hazard_effects.slippery` / `.trip` | added `on_enter_only` | You slip when you step on the oil, not for as long as you stand on it. Without this an actor on an oiled cell is re-proned every three seconds, cannot walk out of it, and the loop deadlocks — the attacker froze in the doorway for the whole 300 s cap. | n/a |
| 2026-09-11 | `room_01_studio.rubric.two` | (default) → `ending != 'evade'` | The default `two` predicate is `damage_taken == 0 \|\| ending != 'kill' \|\| loop.index <= 6`, which hands the second star to every evade, so `evade_phone` scored 2 and `docs/03` §6 says it should score 1. Room 1 now overrides `two`: the second star is for stopping him, not for outlasting him. Spec §11 allows a room to override `two`, and this makes the three authored solutions land on 1 / 2 / 3 exactly as the room doc says. The default is untouched for other rooms. | evade 1★ · disable 2★ · kill 3★ |
| 2026-09-11 | `wet.rate_tiles_per_s` | 0.25 (unchanged) | Measured in M1: the kitchen holds 9 walkable floor cells, not 10 — the fridge sits on (2,2). Full flood takes 35.9 s from the tap, against the spec's ~40 s. Left alone; the solver's `tightness` in M2 decides. | n/a (no solver yet) |

---

## Current baseline

Changed from `docs/02-technical-spec.md` §17 in **bold**.

player walk 3 t/s · attacker walk 2.5 · tick 0.1 s · **Room 1 timer 75 s** (spec default 90) · wet spread 0.25 t/s · phone charge 30 s · help delay 75 s · patience 40 s · search 3 s (×2 dark) · sight 6 (3 dark) · throw range 5 · cord range 3 · disable hold 10 s · prone 3 s · stunned 2 s · blinded 4 s · shock 3 s
