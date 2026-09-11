# 01 — Design Document

## 1. One-liner

You're locked in a room with a countdown. When it hits zero, someone comes in to kill you. You will die. Then you'll die again, a little smarter. You win when he can't kill you.

## 2. Inspiration and tone

Source: the Yorushika "Abuku (Bubble)" music video — a man in a locked room, shot by an assassin, over and over, each loop a slightly different attempt. The MV was built on the theme of *tautology*: repetition as the substance of life, not the absence of it.

**Tone stance: deadpan.** The world is quiet, oppressive, and never winks. The comedy comes from what the systems let the player do — killing a hitman with a toaster is funny *because* the game treats it with total seriousness. The game never writes a joke. Players supply the laughter. The loop counter ("Death 47") and the auto-written death log are the only comedy engine, and they're dry.

Reference feel: Hitman GO (menace in a diorama), Outer Wilds (knowledge is the only progression), Twelve Minutes (the loop), Hitman (one sandbox, many solutions — inverted: you're the target).

## 3. Design pillars

1. **Progress is knowledge.** The player never gets stronger. The room resets every loop. Only what you've learned persists. Every death is your fault and the next one will be later.
2. **The room is the puzzle; the attacker is the pressure.** Nearly every object is interactable. Solutions emerge from combining objects, not from finding *the* key.
3. **Thinking is free; doing costs seconds.** Time pauses while you plan. The countdown bites when you act. Triage is the core skill.
4. **The same rules apply to him.** No scripted attacker weaknesses. He walks into your trap because the room's physics don't care who's standing there.
5. **Every room is a place worth returning to.** Multiple endings, star tiers, a completion checklist, and a collectible make replay a feature, not a grind.

## 4. Core loop

```
Stage intro (≤5s): establishing shot, arrival time shown. Timer visible from frame one.
  │
  ▼
EXPLORE (default 90s): move, inspect, act. Wheel open = paused. Actions cost time.
  │
  ▼
ARRIVAL: attacker enters via a planned entry, perceives, plans, hunts.
  │
  ├── Player dies ──► reset in <1s ──► notebook gains a line ──► back to EXPLORE
  │
  └── Attacker defeated ──► WIN SCREEN ──► Replay / Next Room
```

**Between loops, only knowledge persists.** The room state resets completely. The notebook (auto-written, never typed) persists per room.

**Death is fast.** Under one second from death to control. Slow deaths kill "one more try."

## 5. Perspective and control

- **2.5D isometric**: low-poly 3D rendered through a fixed orthographic isometric camera, diorama framing (a lit box floating in darkness). See `06-art-and-audio-requirements.md`.
- **One input**: click/tap. Click floor to walk. Click an object to open the wheel. Identical on mouse, touch, and controller (cursor + stick-select on the wheel).
- Logic lives on a tile grid; visuals are free-form. Line of sight, hearing, pathing, and hazards are all grid computations.

## 6. The action wheel

Click an object → a radial menu with **eight fixed slots** in fixed positions (muscle memory under pressure) and **Inspect in the center**, shown instantly with no selection needed.

| Slot | Verb | Lit when… |
|---|---|---|
| N | Grab | object is `carryable` and hands are free |
| NE | Push/Pull | object is `movable` |
| E | Open/Close | object is `openable` |
| SE | Toggle | object is `toggleable` (lights, taps, stove, TV, locks) |
| S | Hide | object is `hides-player` |
| SW | Throw | player is holding something (targets the clicked object/tile) |
| W | Use held on | player is holding something and a rule exists for `(held.tags, target.tags)` |
| NW | Drop/Place | player is holding something (places on/into the clicked object or tile) |

Slots with no valid rule are **faded and unselectable** — and visible. The faded wheel is the tutorial: "Throw" greyed on the couch tells you it's heavy; "Use held on" lit when you hold a lighter and click the curtains tells you something.

**Time semantics:** wheel open = simulation paused. Selecting a verb resumes time; the character auto-paths to the object (walking costs time) and performs the action (each verb/rule has a duration). Distance matters. Clever players pre-position objects.

Later polish (not demo): show seconds-cost on slot hover; highlight valid targets for Use-held-on.

## 7. The attacker

A single planner (`sim/attacker/`) drives every attacker. Rooms differ by **profile**, which is data:

| Parameter | What it does |
|---|---|
| `entries[]` | Which openings he can use, in preference order |
| `weapon` | knife (must reach you) / gun (line of sight kills) / hands |
| `sight_range`, `hearing_sensitivity` | Perception; sight halved in darkness unless `has_flashlight` |
| `patience_s` | Seconds of failed searching before he leaves (evade win). `null` = infinite |
| `memory` | `none` / `notice` (moved objects raise suspicion nearby) / `full` (last N loops seed his plan) |
| `durability` | Hits-while-vulnerable to kill; `strength` for breaking barriers |
| `search_order[]` | Default ordering of hiding-spot categories |
| `breach_costs{}` | Seconds to defeat lock / chain / brace / flimsy door |

**The one rule every player must learn:** improvised weapons only work on a **vulnerable** attacker — prone, stunned, blinded, burning, electrocuted, pinned. Charge a man with a knife and you die. Set him up, then strike.

**Seconds are the currency.** Every barrier costs him seconds. Every noise costs you concealment. Evade = buy enough seconds. Disable/kill = get him into a tile where a rule fires.

## 8. Win types (endings)

| Ending | Definition |
|---|---|
| **Evade** | He fails to locate you for `patience_s`, or outside help arrives, and he leaves |
| **Disable** | He is pinned, trapped, locked in, or incapacitated and cannot reach you before the loop ends |
| **Kill** | He dies |
| **Escape** | You leave the room (only in rooms with `exits_locked: false`) |

Any ending unlocks the next room. **Never gate progress on stars.**

## 9. Stars (authored) vs completion (computed)

**Stars are authored** — a small rubric block per room, evaluated as predicates on the winning loop's end state:

- ★ — any win. Generic; nothing to author.
- ★★ — default rubric (`content/rubric_defaults.json`): no damage taken, **or** non-lethal, **or** ≤ N loops. Rooms may override.
- ★★★ — one authored predicate per room: the **signature solution**. Falls back to `player.never_seen` if not authored.

The solver enumerates wins and reports which land in ★ by default. The designer decides: bug, promote to ★★★, or leave as an **Improvised** achievement.

**Completion is computed** from the data that already exists. The room dossier tracks:

| Checklist | Source |
|---|---|
| **Interactions** | Every valid `(verb, object)` pair performed at least once. Derived from the rule table. Pointless interactions count. |
| **Discoveries** | Rule *combinations* fired (water+toaster, oil+rug, hairspray+stove). Shown as `???` until found. |
| **Ways to die** | Distinct death causes. Collectibles. The deadpan death log *is* the joke. |
| **Endings** | Each ending type found, shown as locked silhouettes until achieved. Plus Improvised wins. |
| **Collectible** | One per room, hidden where no solution needs you to look. |

**100% mastery** of a room unlocks a cosmetic: character outfits, diorama frames (plain / brass / glass case), notebook covers. Never gameplay.

## 10. The notebook

Auto-populated, never typed. Persists per room. Three tabs:

- **Room** — objects discovered; tag hints revealed on Inspect ("feels heavy", "smells of gas").
- **Attacker** — behaviors observed: "came through the door", "broke the window when the door was braced", "searched the closet first".
- **Deaths** — one dry line per loop: what you tried, how it ended. This is the self-writing hint system.

## 11. Post-win screen

Stars earned · loop count · time survived · **Endings row with silhouettes for undiscovered endings** · completion % · Ways-to-die count · **[Replay] [Next Room]**.

The silhouettes are the pitch: the empty ★★★ slot tells you something better exists. No text needed.

## 12. The first three loops are scripted by the room

No tutorial prompts. Room 1 is designed so the obvious attempts fail in an instructive order:

1. Loop 1: poke around, he walks in, you die.
2. Loop 2: hide in the closet — the obvious spot. He opens it.
3. Loop 3: grab the knife and charge. The vulnerable rule kills you.

By loop 4 the player knows the grammar and the notebook has three lines.

## 13. Progression architecture (built for infinite rooms)

Three independent data layers. Rooms never know their neighbors.

1. **Rooms** — self-contained content units with descriptive metadata (size, entries, exits, attacker archetype, tag families used) and *computed* difficulty from the solver.
2. **Campaigns** — ordered playlists of rooms with "introduces" markers. The demo is a 4-line file. Chapters, floors, districts are more playlists. Reordering never touches rooms. Long-term escalation lives here: each chapter introduces one attacker archetype and one tag family.
3. **Global systems** — the rule table, tag vocabulary, attacker profiles and planner. Adding a tag family expands every future room.

Consequences: generated and community rooms are the same content unit and are solver-verified before they ship; story is an optional wrapper layered across campaigns; rule changes re-verify the whole back catalog in CI. Details in `05-campaign-and-progression.md`.

## 14. Audio stance (design-level; production later)

1. **Sound is a system in both directions.** The attacker hears `noisy` events; the player must hear *him* (the lock being tested, the closet opening, footsteps between zones). When hidden, audio is your only sensor. One event bus, two consumers.
2. **No dialogue, no VO.** Faceless figures, silent attacker. The notebook carries the voice. Permitted exception: a non-verbal animation tell (Room 4's attacker pausing at the closet he found you in last time).
3. **The timer is the soundtrack.** A tick or heartbeat as metronome, near-silence underneath, a swell in the final ten seconds, then the door. Music only between loops and on the win screen.

## 15. Demo scope

Four rooms, four lessons: buy time and hide (1), the room remembers (2), cover not darkness (3), he remembers (4). Room 1 is the vertical slice and is fully specified. Rooms 2–4 are briefs until Room 1 ships.

## 16. Explicitly out of scope for the demo

Story wrapper · room editor · generated rooms pipeline (design only) · online anything · consoles · composed score · localization · achievements platform integration (track locally, wire later).
