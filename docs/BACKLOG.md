# Backlog

Ideas outside the current milestone. One line each, dated, with who raised it. Nothing here is approved; Bob promotes items into a milestone.

| Date | Idea | Raised by | Notes |
|---|---|---|---|
| 2026-09-11 | Seconds-cost shown on wheel slot hover | design | polish, post-M3 |
| 2026-09-11 | Highlight valid targets for Use-held-on on slot hover | design | polish, post-M3 |
| 2026-09-11 | Lamp-cord trip: keep in Room 1 or move to Room 2 | design | decide after solver report |
| 2026-09-11 | LLM room-drafting pipeline | design | after demo; see docs/05 §5 |
| 2026-09-11 | Story interludes between rooms | design | after demo; rooms never depend on it |
| 2026-09-11 | Secret room unlocked by campaign mastery | design | after demo |
| 2026-09-11 | Room 1 LOS: strict Bresenham from (1,2) to (5,4) misses the fridge at (2,2), so the doorway sees the living zone. Move the kill standing cell, widen the fridge, or use a thick line. | M1 agent | blocks the `kill_toaster` premise; decide in M2 with the attacker |
| 2026-09-12 | Room 1 kill path costs only 9 s of action time, so no timer puts it in the 30-40 s tightness band. If the signature solution should feel tighter it needs more setup — a content change. | tuning pass 1 | see docs/TUNING.md |
| 2026-09-12 | Patience alone is a 4-action evade win (`min_actions_to_win` 4, both Mode B improvised wins). Decide after M3 whether outlasting him is too cheap. | tuning pass 1 | watch in playtest |
| 2026-09-12 | Audio stance changed in the build but not the docs: the countdown is now silent until the last ten seconds. docs/01 s14 and docs/06 both still describe a tick running under the whole loop with a swell at the end. One of the two should move. | Bob, playtest | see content/audio_map.json |

## Achievements

Claude Design's turn-1 notebook (`docs/ui/SPEC.md`) has a fourth tab: Achievements, earned per profile, stamped with the death number they were earned on, locked ones listed as silhouettes "the same way the endings row is the pitch". It reads well and it is not built on anything — there is no achievement in the docs, the sim, the content or the save file.

Either it becomes a real system (a list in `content/`, evaluated by `sim/outcome.gd` alongside the star rubric, banked in the save) or the tab comes out of the notebook design. Not a UI decision; flagged rather than quietly implemented.

## Portrait on mobile

`docs/06` used to say portrait rotates the room 90° rather than shrinking it. Mobile is landscape-locked as of 12 Sept 2026, so that plan is parked rather than built: a 12×10 room in portrait is either tiny or sideways, the wheel wants the middle of a wide screen, and it is a second layout to test forever on a demo with one room.

Claude Design's turn-1 delivery already contains portrait layouts for the HUD, notebook and win screen (`hud_portrait`, `notebook_portrait`, `win_portrait` in `docs/ui/ui-tokens.json`). If portrait comes back, the design is done and the work is the layout code plus a rotation for the room.

## The wheel on a controller

Steam desktop is a mouse, and the Steam Deck is sticks, trackpads and a touchscreen. Eight fixed compass slots are a gift for a stick — push a direction, release to commit — and Inspect is the face button. None of it is wired: the wheel currently takes a pointer only. The Deck deliberately does not get the phone's thumb-size scale-up, because a trackpad is not a thumb.

## Two objects in Room 1 stand behind taller furniture

With real-scale models, the fridge covers the stove behind it and the bathtub covers the medicine cabinet. `tests/game/picking_test.gd` counts them rather than ignoring them, and fails the build if a third ever joins them.

Neither is unreachable in the sim — you can still push the fridge — but neither can be clicked where it stands. The fix is content: move the fridge or the stove a square, re-run the solver. Flagged rather than done, because the fridge's square is load-bearing (it is the door blocker in one of the three authored solutions).

