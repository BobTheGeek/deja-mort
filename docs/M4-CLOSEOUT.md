# M4 close-out — what is actually done

Written 12 Sept 2026, against `docs/07-milestones.md` § M4. Bob has not signed off yet; this is the honest state for him to sign off against, not a claim that it passed.

---

## M4's list, item by item

| asked for | state |
|---|---|
| Kenney / Quaternius imports | **done.** 140 Kenney models (CC0), 2 Quaternius figures (CC0), licences and scale documented in `assets/README.md` |
| Palette and lighting rig | **done.** One bulb with shadows, warm key, cold fill, global saturation pulled to 0.62, diorama base |
| Character figures | **done.** Player and Tenant, keyed on the actor's *role* so a new attacker profile needs no code |
| State visuals for real meshes | **done.** See below |
| Stylised death animations | **done.** `game/death_beat.gd` — six causes staged, the lights flicker for current and fire, and the ending is named at the end of the beat rather than across it |
| Particles | **water, fire, shock, gas. No dust.** M4 asked for dust; nothing produces it, and a shelf hitting the floor is where it would go |
| Diorama base | **done** |
| The collectible | **in the sim, not in the art.** `bubble_token` exists, is collectible, and renders as a greybox. It has no model and does not read as a thing worth finding |

### State visuals

`content/visuals.json` has looks for fourteen states: `burning`, `on`, `lit`, `open`, `broken`, `tipped`, `leaning`, `wet`, plus `charging`, `charged`, `cut`, `locked`, `chained` and `braced_by`.

The last three were the gap that mattered: you locked the front door, put the chain on, shoved the fridge against it, and nothing on screen changed. They now carry a small solid mark on the object — size, offset and brand colour from `state_visual`, so a new state is a table entry rather than a code change, and nothing about it names an object.

Two states deliberately have none, declared in `state_visual_none` with the reason attached:

- `inspected` is bookkeeping. Drawing it would tell the player what they already know.
- `plugged` is the *starting* state of the toaster, the lamp and the hair dryer, so a mark on each is three marks that never change. What matters is a cord pulled **out**, and that already shows as the trip hazard on the floor.

`tests/game/state_visual_test.gd` fails the build when a state is neither drawn nor on that list, so the exceptions stay reviewable instead of becoming an oversight.

---

## Acceptance

> Room 1 looks like the style target under the lighting rig.

Bob's first verdict was "it does not meet the style target". Six structural fixes followed (the lighting rig, real furniture scale, the wall treatment, the characters, smoothed movement, the tipping axis). It has not been re-judged since. **Open — needs Bob's eyes.**

> Every object state has a visual.

**Met**, with two declared exceptions that carry their reason in the table (§ above). `docs/screenshots/m4_secured.png` is the front door locked and chained.

> Bob signs off on a screenshot set (light on / light off / flooded / shelf tipped / death frame).

The set is regenerated at 1920×1080 and current as of this commit:

| file | what it shows |
|---|---|
| `docs/screenshots/m4_lit.png` | the room under the bulb |
| `docs/screenshots/m4_dark.png` | the light switch off |
| `docs/screenshots/m4_flood.png` | the tap running, water spreading across the kitchen |
| `docs/screenshots/m4_fire.png` | the curtains alight |
| `docs/screenshots/m4_tipped.png` | the bookshelf down, fallen into the room |
| `docs/screenshots/m4_death.png` | mid-swing, the body down, no banner across it |

**Open — awaiting sign-off.**

---

## M3's acceptance is still open too

M4 was built on top of it, so this is worth stating plainly:

- **"Bob plays Room 1 start to finish and reaches all three authored endings."** Not done. The solver reaches all three; Bob has reached none. His recorded session ended in a loss on loop 1.
- **"Runs on a phone build (touch)."** Never built. There is an Android export preset and no iOS one, and nothing has been run on a device. The arithmetic for touch targets and safe areas is in `game/ui_scale.gd` and is checked against published device numbers only.
- **"He can locate the attacker by ear while hidden in the tub."** Not tested. His footsteps, the door, the breach and the search all have cues, but they are one footstep sound rather than one per zone material, so *where* he is walking is not audible — which is the half that makes this criterion work.
- **"Is 90s right?"** Answered: 75s, and Bob said "feels okay, for now".
- **"Is the wheel legible at phone size?"** Answered on desktop — it was not, and was rebuilt. Still unanswered on a phone.

---

## Work done during M4 that M4 did not ask for

Worth listing so the milestone doc is not mistaken for the history:

- **The whole UI, rebuilt** from Claude Design's turn-1 delivery: wheel, HUD, notebook, win screen. That is M3's list, done a second time to a design.
- **The title screen**, which is an **M6** item, pulled forward because the same delivery covered it.
- **Mobile landscape, UI scale and safe areas** — M6's "phone build" groundwork minus the build itself.
- **The session log** (`game/session_log.gd`, `tools/session_report.gd`), which is not on any milestone and exists because two playtest reports could not be reproduced from a description.
- **Four real bugs found by playing**, all fixed: carrying did not carry, the doorway was drawn over by its own wall, tipped objects fell the wrong way, and clicks resolved to the floor square rather than the object.

---

## Before M5 starts

1. Bob plays Room 1 and reaches all three endings, or says which one he cannot reach and why.
2. Sign-off on the screenshot set, or a list of what still misses the style target.
3. A phone build, once, even ugly. Everything about touch is currently arithmetic.

Not blockers, but they are the difference between "M4 is done" and "M4 looks done".

---

## Numbers as of this commit

- **442 tests**, 0 failures
- `lint_room` — 13 overlapping (verb, object) pairs, 13 resolved by declared shadowing, 0 left
- `rule_coverage` — 38 of 38 rule ids have a passing test
- `verify_all` — 3 of 3 authored solutions, tightness 47.1 / 62.0 / 66.0s
- Every drawn object in Room 1 has at least 400 clickable screen pixels; the smallest is the frying pan at ~693
