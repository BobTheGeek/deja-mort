# 09 — Kickoff Prompt for Claude Code

Paste this as the first message in a fresh Claude Code session, from the root of an empty repo that already contains this package under `docs/`.

---

You are starting development of DÉJÀ MORT, a die-and-retry room-survival puzzle game in Godot 4. The complete design and technical handoff is in `docs/`. Read, in this order, before doing anything else: `docs/README.md`, `docs/00-CLAUDE.md`, `docs/02-technical-spec.md`, `docs/07-milestones.md`. Skim `docs/01-design-doc.md` and `docs/03-room-01-studio.md` so you know what the sim has to support.

Then:

1. Copy `docs/00-CLAUDE.md` to `./CLAUDE.md`. Create the stub files it references: `docs/BACKLOG.md`, `docs/TUNING.md`, `docs/BLOCKERS.md`, `assets/README.md` (templates are in `docs/stubs/`).
2. Execute **Milestone M0** exactly as specified in `docs/07-milestones.md`: Godot 4 project with the **Mobile renderer** set in `project.godot`, the folder layout from `CLAUDE.md`, gdUnit4 installed, a CI workflow that runs lint + tests + `tools/verify_all.gd` on push, and a passing empty test.
3. Before starting **M1**, write `docs/M1-PLAN.md`: the interface contracts for `sim/` (class names, public methods, the event record shape, the intent API) derived from `docs/02-technical-spec.md` §5–§10. Keep it under two pages. Stop and show me that plan before writing sim code — I want to approve the contracts first so parallel agents can build against them.

Rules that override anything else you might infer:
- `sim/` is pure `RefCounted` logic, runs headless, deterministic with an injected RNG. No Nodes, no scene tree.
- No object-specific code, ever. Objects are tags + state; behavior lives in `content/rules.json`.
- Tuning numbers are JSON, never literals.
- One task per PR, tests first for sim changes, solver output in the PR when content changes.
- Greybox until M3. No assets.
- If the spec is ambiguous, choose the data-driven interpretation and flag it in the PR. If a milestone looks unreachable, write `docs/BLOCKERS.md` instead of redefining the milestone.
- Ideas outside the current milestone go in `docs/BACKLOG.md`, not into code.

When M0 is done, report: what was created, what CI runs, and any deviation from the spec with the reason. Then present the M1 plan and wait.

---

## For the M1 session (after approving the plan)

> M1 plan approved with the changes noted. Split M1 into the three agent tracks from `docs/07-milestones.md` (grid/actors/scheduling · objects/tags/rules/verbs/hazards · tests/lint). Build against the contracts in `docs/M1-PLAN.md`. Load `content/rooms/room_01_studio.json` from `docs/03-room-01-studio.md` as the first content file — it's the acceptance target. Report when `tools/play_headless.gd` can run the kitchen flood and the toaster shock from the spec's §5.3, and when every rule in `content/rules.json` has a passing test.

## For the M2 session

> Start M2. Planner first (Agent A), outcome/rubric/notebook second (Agent B), solver as soon as the planner can complete a loop (Agent C), attacker tests throughout (Agent D). Acceptance is the solver verifying all three authored solutions in `docs/03-room-01-studio.md` §5 with the declared endings and stars, and finding at least two improvised wins. Commit `content/rooms/room_01_studio.solver.json`. Then write `docs/TUNING.md` with the first tuning pass against `tightness_s` and stop for my review before M3.
