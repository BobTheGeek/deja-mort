# DÉJÀ MORT — Handoff Package

A die-and-retry room-survival puzzle game. You are locked in a room. A visible timer counts down. When it hits zero, someone comes in to kill you. Every death teaches you the room. You win when he can't.

This package is the complete planning output for the demo (4 rooms) and the architecture that lets the game grow to hundreds of rooms afterward. It is written for Claude Code agents to execute, with a human (Bob) reviewing at milestone boundaries.

Title: **DÉJÀ MORT**. Tagline: *You've died here before.*

Naming rationale: déjà vu, but you die. It's the loop and the deadpan tone in two words, and it's the name people repeat to a friend. No existing game by that name found on Steam/itch/web (Sept 2026). The MV's theme ("tautology" — repetition as the substance of life) stays as the *design* theme.

Conventions: display title is always **DÉJÀ MORT** with the accents. ASCII slug everywhere machines need it: `deja-mort` (repo, domain, save folder, store URL). Alternate taglines held in reserve: *Die. Remember. Repeat.* · *Same room. Same knife. Later.*

**Before the name goes public:** run a USPTO TESS search (Class 9 downloadable game software; Class 41 entertainment services), a Steam store search including the unaccented spelling, a check for French-language collisions (films, books, games), and grab `dejamort` / `deja-mort` domains and handles. This package's sweep was Steam/itch/web only, not a trademark search.

## Read in this order

| File | What it is | Who reads it |
|---|---|---|
| `00-CLAUDE.md` | Drop into the repo root as `CLAUDE.md`. Conventions and hard rules for agents. | Every agent, every session |
| `01-design-doc.md` | Vision, pillars, loop, tone, interaction, win/star/completion systems, progression architecture | Everyone once; designers repeatedly |
| `02-technical-spec.md` | Architecture, engine settings, data schemas, tag vocabulary, rule table, attacker planner, solver, testing | Engineering agents — the source of truth |
| `03-room-01-studio.md` | Room 1 in full: layout, every object, attacker profile, authored solutions as solver tests, star rubric, deaths list | Content + engineering for the vertical slice |
| `04-rooms-02-04-briefs.md` | Rooms 2–4 as one-page briefs. Expand only after Room 1 ships. | Content agents, later |
| `05-campaign-and-progression.md` | Campaign file format, room metadata, mastery/cosmetics, content pipeline for infinite rooms | Engineering + content |
| `06-art-and-audio-requirements.md` | Visual target, renderer, asset sourcing, the demo's required sound list | Presentation agents |
| `07-milestones.md` | Ordered milestones with acceptance criteria and suggested agent task splits | Whoever is planning work |
| `08-logo-brief.md` | Paste-ready brief for a design assistant plus image-generator prompts for the logo | Bob, with a separate AI or designer |
| `09-kickoff-prompt.md` | The first messages to give Claude Code for M0, M1, M2 | Bob, when starting sessions |
| `10-glossary-and-voice.md` | Canonical vocabulary for code/content/UI, and the notebook voice guide with pass/fail examples | Every agent; anyone writing templates |
| `11-decision-log.md` | Every settled decision with its rationale and revisit conditions | Anyone tempted to change something |
| `12-playtest-protocol.md` | How to run and log playtests from M3 on, and which observations change which numbers | Bob, observers |
| `13-autonomous-runs.md` | How to run each milestone unattended with `/goal` — ready-made conditions per milestone | Bob |
| `brand/` | Vector mark and lockups, icon PNGs, `BRAND.md` with tokens, Godot constants, and export targets | Presentation agents; Bob for store art |
| `stubs/` | Templates for `BACKLOG.md`, `TUNING.md`, `BLOCKERS.md`, `assets/README.md` — copy into the repo at M0 | M0 agent |

## The three rules that keep this project buildable

1. **Simulation is pure logic and runs headless.** No Node dependencies in the sim. If it can't run in a test, it's in the wrong layer.
2. **Never write object-specific code.** Objects are tags + state. Behavior comes from the global rule table. If a solution needs a special case, add a tag or a rule, not an `if`.
3. **Every room is verified by the solver, in CI, every time rules change.** A room with no authored solution passing the solver does not ship.

## Decisions already made (do not relitigate without Bob)

- Engine: Godot 4.x (latest stable), GDScript, **Mobile renderer**
- Perspective: 2.5D — low-poly 3D, fixed orthographic isometric camera, diorama framing
- Input: single click/tap. Radial "pinwheel" action wheel, eight fixed slots, Inspect at center
- Time: real-time countdown; pauses while the wheel is open; actions cost seconds
- Attacker: goal-oriented planner over the same tag/rule system the player uses. Not LLM-driven at runtime
- Attacker memory is a per-room profile parameter (none / notice / full)
- Rooms are sealed by default; `exits_locked: false` rooms allow an Escape ending
- Deaths: stylized, visible, not graphic. No blood
- No dialogue. No voiceover. The notebook carries the voice
- Music between loops and on win screens only; during play the timer is the soundtrack
- Demo scope: 4 rooms. Stars authored per room; completion computed from data
