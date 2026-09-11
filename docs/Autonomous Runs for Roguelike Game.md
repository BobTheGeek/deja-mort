# 13 — Running Milestones Autonomously with `/goal`

`/goal` sets a completion condition. After every turn, a separate small model checks the transcript against that condition; if it isn't met, Claude starts another turn without you. It clears when the condition is met, judged impossible, or a hard error occurs. (Docs: code.claude.com/docs/en/goal.)

## The three things that make it work

1. **Pair it with auto mode.** `/goal` removes per-*turn* prompts; auto mode removes per-*tool* prompts. Without auto mode, Claude still stops to ask before each shell command your settings don't already allow. Set auto mode (or at minimum pre-allow `godot`, `git`, and the test runner in `.claude/settings.json`) before setting the goal.
2. **The evaluator only sees the transcript.** It doesn't run commands or open files. So the condition must be phrased as output Claude will *print*: "`godot --headless -s tools/verify_all.gd` exits 0 and its summary is shown" works; "the sim is done" doesn't. Every condition below ends with a required visible check.
3. **One goal per session, one end state per goal.** Compound goals confuse the evaluator. Run milestones as sequential goals, and keep the human gates (the M1 plan review, the M2 tuning review) as *breaks between goals*, not steps inside one.

Also: include a turn cap (`or stop after N turns`) as a safety bound, and keep `docs/BLOCKERS.md` as the escape hatch — the condition tells Claude to write there and stop rather than redefine the milestone.

## Condition template

```
/goal <measurable end state>, proven by <stated check that prints output>,
      without <constraints>, or stop after <N> turns.
      If any acceptance criterion in docs/07-milestones.md §<M> cannot be met
      under docs/02-technical-spec.md, write the conflict to docs/BLOCKERS.md
      and stop instead of changing the spec.
```

## Ready-made goals per milestone

Paste after the human gate for that milestone has passed. Adjust turn caps to taste.

### M0 — skeleton (short; you could just prompt it)

```
/goal The repo has a Godot 4 project with the Mobile renderer set in project.godot, the folder layout from CLAUDE.md, gdUnit4 installed, a CI workflow that runs lint, tests, and tools/verify_all.gd on push, and docs/BACKLOG.md, docs/TUNING.md, docs/BLOCKERS.md, assets/README.md created from docs/stubs. Proven by: `godot --headless -s tools/verify_all.gd` runs and prints "0 rooms", and the test runner prints a passing result for at least one test. Constraint: do not start any sim/ code. Or stop after 15 turns.
```

Then, as a normal prompt (not a goal): "Write docs/M1-PLAN.md per docs/09-kickoff-prompt.md and stop for review."

### M1 — headless sim core (after you approve M1-PLAN.md)

```
/goal Milestone M1 in docs/07-milestones.md is complete: sim/ contains grid, world, objects, rules, verbs, actors, hazards, events, and rng as RefCounted classes with no Node dependencies; content/tags.json, content/rules.json, content/verbs.json, content/systems.json exist; content/rooms/room_01_studio.json loads with every object from docs/03-room-01-studio.md §3; and tools/play_headless.gd runs. Proven by all of the following printed in the transcript: (1) the test runner reports every rule id in content/rules.json has at least one passing test and zero failures; (2) the determinism test passes; (3) loading room_01_studio prints its valid (verb, object) pair count; (4) a headless script shows the sink toggle flooding the kitchen zone in about 40 seconds and a plugged toaster thrown into a wet cell producing shock cells including (1,2). Constraints: no attacker code, no game/ scenes, no tuning literals in GDScript, no object-specific branches. Work in small commits with tests first. Or stop after 80 turns. If any acceptance criterion cannot be met under docs/02-technical-spec.md, write docs/BLOCKERS.md and stop.
```

### M2 — attacker, outcome, solver

```
/goal Milestone M2 in docs/07-milestones.md is complete: sim/attacker/ (perception, GOAP planner, actions, memory none/notice/full), sim/outcome.gd (endings, death causes, rubric evaluation, completion sets, notebook templates), tools/solve.gd modes A/B/C, and tools/verify_all.gd. Proven by all of the following printed in the transcript: (1) `godot --headless -s tools/solve.gd -- content/rooms/room_01_studio.json` shows evade_phone, disable_shelf, and kill_toaster each verified with their declared ending and stars (1, 2, 3); (2) mode B lists at least two IMPROVISED wins; (3) mode C reports at least 10 reachable death causes; (4) running the solver twice prints identical output; (5) content/rooms/room_01_studio.solver.json is committed and shown; (6) the attacker and outcome test suites pass with zero failures. Constraints: attacker behavior comes only from profile data and the planner, never room-specific code; the attacker suffers hazard effects through the same world.step() path as the player. Or stop after 100 turns. If the authored solutions cannot all be made to pass without changing the room geometry, adjust coordinates in room_01_studio.json, document each change in docs/TUNING.md, and continue; if they cannot pass under the spec at all, write docs/BLOCKERS.md and stop.
```

Then, as a normal prompt: "Write the first tuning pass in docs/TUNING.md against tightness_s and stop for review before M3."

### M3 — greybox playable

```
/goal Milestone M3 in docs/07-milestones.md is complete: game/ has the iso camera with one shadowed light and vignette, RoomRenderer building greybox meshes from room JSON with the state→visual table, click-to-walk, the eight-slot wheel with Inspect at center and faded unavailable slots that pauses stepping while open, HUD, sub-second death reset, notebook UI, win screen with endings silhouettes and Replay/Next, JSON save data, and AudioDirector playing placeholder cues for every attacker event in docs/06-art-and-audio-requirements.md plus the timer tick. Proven by: (1) an exported desktop build path is printed; (2) a screenshot or short capture of the wheel open on the fridge and of the win screen is attached to the PR and referenced in the transcript; (3) a scripted playthrough via the intent API reaches all three authored endings with the renderer running, and the log is printed; (4) `godot --headless -s tools/verify_all.gd` still exits 0; (5) an Android or iOS export completes without errors and its path is printed. Constraints: no game logic in game/; presentation reads sim state and events only; no assets, greybox only. Or stop after 120 turns.
```

The human acceptance for M3 is *playing it*. The goal gets you to a build; you do the playtest per docs/12-playtest-protocol.md.

### M4 onward

Write M4 (art) and each room in M5 as their own goals using the same template. Art goals should require a screenshot set as the proof; room goals should require the solver report and the `.solver.json` diff.

## Watching a run

- `/goal` with no argument shows elapsed time, turns, tokens, and the evaluator's last reason. Ctrl+O shows the reason behind each verdict inline.
- If Claude stops using tools for several turns, Claude Code halts the loop and hands control back with the goal still set — that's your cue that it's stuck or arguing with the evaluator. Read the last reason, prompt once, and it resumes.
- `/goal clear` cancels. Resuming a session (`--continue`) restores an active goal.
- Background subagents defer evaluation until they finish; long runs get a check-in after 30 minutes.

## Non-interactive (overnight)

```
claude -p "/goal <condition>" --output-format stream-json --verbose > logs/m1-$(date +%F).log
```

Only do this for goals whose constraints you trust — M1 and M2 are good candidates because the solver and tests are the judge. M3 needs your eyes.
