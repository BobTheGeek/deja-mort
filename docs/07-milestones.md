# 07 — Milestones

Ordered. Each milestone has acceptance criteria that a human (Bob) checks before the next starts. Agents work within the current milestone only; ideas go to `docs/BACKLOG.md`.

Estimates are agent-days of focused work, not calendar time, and they're rough.

---

## M0 — Skeleton (≈1 day)

Repo, Godot project (Mobile renderer set), `CLAUDE.md` at root, `docs/` populated from this package, gdUnit4 installed, CI running lint + tests on push, folder layout from `CLAUDE.md`.

**Accept:** `godot --headless -s tools/verify_all.gd` runs (and reports no rooms). CI green on an empty test.

**Split:** one agent.

---

## M1 — Headless simulation core (≈4–6 days)

`sim/` with no Node dependencies: grid + A* + LOS · object model + tag loading + lint · rule table loading, matching, effects · the eight verbs and availability computation · actor model, intents, action scheduling with durations · hazard layers (wet spread, slippery, shock, fire, trip, gas) · event bus · world timer and 10 Hz stepping · determinism with injected RNG.

Room 1's objects loaded from JSON (`room_01_studio.json`) with the full rule set from the spec. **No attacker yet.** A `tools/play_headless.gd` REPL that accepts intents and prints state is enough to poke at it.

**Accept:** unit tests for every rule id in `rules.json`. Determinism test passes. Loading Room 1 reports the valid `(verb, object)` pair count. Tap on → kitchen floods in ~40s in the log. Toaster thrown into wet → shock cells listed.

**Split:** Agent A: grid/LOS/pathing + actors + scheduling. Agent B: objects/tags/rules/verbs + hazards. Agent C: tests as A and B land, lint tool. Interface contracts from `02-technical-spec.md` §5–§8 first, then parallel.

---

## M2 — Attacker + outcome + solver (≈5–7 days)

`sim/attacker/`: perception, GOAP planner, action library, memory (`none` fully; `notice` and `full` implemented but only unit-tested). `outcome.gd`: endings, death causes, rubric evaluation, completion sets, notebook line generation from templates. `tools/solve.gd` Modes A, B, C; `tools/verify_all.gd`; `<room>.solver.json` output.

**Accept:** Room 1's three authored solutions pass Mode A with the declared endings and stars. Mode B finds them without guidance plus at least two improvised wins. Mode C reaches ≥10 death causes. Solver is deterministic across runs. Bob reviews the improvised list and the difficulty numbers. **Playable-in-log:** a scripted loop reads correctly in the event log from timer start to ending.

**Split:** Agent A: perception + planner + actions. Agent B: outcome + rubric + completion + notebook templates. Agent C: solver (starts with Mode A the moment planner exists). Agent D: attacker tests, memory unit tests.

Decision gate: tune `timer_s`, breach costs, patience, spread rate against the solver's `tightness_s` before M3. Record the tuning rationale in `docs/TUNING.md`.

---

## M3 — Greybox playable (≈5–7 days)

`game/`: iso camera + light + vignette · `RoomRenderer` from JSON (boxes/capsules, state→visual table) · click-to-walk · the wheel (eight fixed slots, Inspect center, fading, pause-on-open) · HUD (timer, loop counter, held, hidden) · death → reset in <1s · notebook UI · win screen with endings silhouettes, stars, completion %, Replay/Next · save data · placeholder audio via `AudioDirector` for the *attacker* cues at minimum (the information-bearing ones), tick metronome.

**Accept:** Bob plays Room 1 start to finish in greybox and reaches all three authored endings. Wheel feels fast. Death reset is under a second. He can locate the attacker by ear while hidden in the tub. Runs on a phone build (touch), even if ugly.

**Playtest questions to answer (feed into `docs/TUNING.md` and Rooms 2–4):** Is 90s right? Is the wheel legible at phone size? Does the notebook read well? Does the solver's `min_loops_estimate` match how many loops Bob needed?

**Split:** Agent A: camera/renderer/state visuals. Agent B: wheel + HUD + input (mouse/touch/controller). Agent C: notebook + win screen + save. Agent D: AudioDirector + audio map + placeholder cues.

**Status (12 Sept 2026):** built, and three acceptance lines are still open — Bob has not reached all three endings in play, there has been no phone build, and locating the attacker by ear is untested (he has one footstep cue, not one per zone material). The UI was rebuilt a second time in M4 against Claude Design's delivery. See `docs/M4-CLOSEOUT.md`.

---

## M4 — Art pass, Room 1 (≈4–6 days)

Kenney/Quaternius imports · palette and lighting rig · character figures · state visuals for real meshes · stylized death animations · particles (water, fire, shock, dust) · diorama base · the collectible.

**Accept:** Room 1 looks like the style target under the lighting rig. Every object state has a visual. Bob signs off on a screenshot set (light on / light off / flooded / shelf tipped / death frame).

**Split:** Agent A: imports + materials + lighting. Agent B: animations + particles. Agent C: Blender-scripted bespoke pieces (attacker figure, anything the packs lack).

**Status (12 Sept 2026):** the list is built apart from dust particles and the collectible's model; "every object state has a visual" is **not** met — seven states have no look, and `locked`, `chained` and `braced_by` are facts the player acts on and cannot see. The screenshot set is regenerated and awaiting sign-off. Full accounting, including what was done that M4 did not ask for, in `docs/M4-CLOSEOUT.md`.

---

## M5 — Rooms 2–4 (≈3–5 days per room, sequential)

Expand each brief into a full spec (same format as Room 1) → JSON → solver → tune → art. Implement `notice` (R2), gun/flashlight/cover/gas (R3), `full` memory + variety rubric + non-verbal tell (R4) as they're reached. Campaign file, chapter unlock flow, `introduces` UI.

**Accept, per room:** authored solutions pass; Bob plays it; difficulty ramps in the solver numbers *and* in play. **Accept, milestone:** the campaign is playable start to finish.

---

## M6 — Demo polish (≈4–6 days)

Mastery + cosmetics (frames, outfit, notebook cover) · between-loop and win music placeholders · full audio pass on player/system cues · settings (audio, accessibility: timer size, colorblind-safe hazard tints, reduced flicker) · title screen · builds for Windows/macOS/Linux + a phone build · a web build as a shareable demo link if it works on the Mobile renderer without pain.

**Accept:** a stranger can install and play all four rooms without instructions. Bob's completion run of Room 1 hits 100% and unlocks the frame.

---

## After the demo (not scheduled)

LLM room-drafting pipeline (§5 of `05-campaign-and-progression.md`) · procedural extras · story interludes · Steam integration · composed score · localization · room editor.

---

## Working agreements with agents

- Read `CLAUDE.md` and the current milestone before starting any task.
- A task is one PR. Include the solver report when content changed.
- Sim changes require tests first. Presentation changes require a screenshot or short capture in the PR.
- If a spec detail is ambiguous, implement the data-driven interpretation and flag it in the PR. Do not silently pick.
- If a milestone's acceptance criteria look unreachable with the current spec, stop and say so in `docs/BLOCKERS.md` rather than redefining the milestone.
