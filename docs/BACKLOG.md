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
