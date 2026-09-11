# 11 — Decision Log

Decisions already made, with the reasoning, so nobody relitigates them by accident — and so that if one *must* change, whoever changes it knows what it was protecting. Add new entries at the bottom; never edit old ones, supersede them.

| # | Decision | Why | What it protects | Revisit if |
|---|---|---|---|---|
| 1 | Godot 4, GDScript | Text-based scenes diff cleanly for agents; real headless mode; no licensing; isometric-friendly | Agent-driven development; solver/CI | Sim performance forces a GDExtension port (allowed; sim is engine-free by design) |
| 2 | Mobile renderer from day one | Switching renderers late is where teams get surprised; art direction needs only one shadowed light | Mobile release as a release, not a port | Never for the demo |
| 3 | 2.5D: low-poly 3D, fixed iso camera, diorama | Object states are free (mesh swaps, not sprites); consistency automatic; agents can build geometry; mood is a lighting rig | The state-explosion problem; art budget | — |
| 4 | Single-input: click/tap + eight-slot wheel, Inspect at center | One interaction on mouse/touch/controller; fixed slots for muscle memory; faded slots are the tutorial | Portability; teaching without prompts | Playtest shows the wheel is too slow — fix speed, not layout |
| 5 | Real-time; wheel open = paused; actions cost seconds | Thinking free, doing costly = triage is the skill | "Thinking game, not clicking game" | — |
| 6 | Sim is pure logic, headless, deterministic | Enables the solver, tests, CI re-verification, and agent work without a display | Everything | Never |
| 7 | No object-specific code; tags + rules only | Keeps content generation open to agents/LLMs; infinite rooms | Scalability | Never — add a tag or a rule instead |
| 8 | Attacker = GOAP planner over the same rules; not LLM at runtime | Deterministic, testable, fast; symmetry means traps work without scripting | Solver; "same rules apply to him" | — |
| 9 | Memory is a per-room profile field (`none`/`notice`/`full`) | Escalation as data; different characters from one planner | Campaign scalability | — |
| 10 | Vulnerable rule: weapons only work on a vulnerable attacker | Keeps it a puzzle game, not a fight; every room builds on it | Genre identity | Never |
| 11 | Rooms sealed by default; `exits_locked` flag per room | Escape as an ending type without every room becoming an escape room | Pressure stays on the attacker | — |
| 12 | Stars authored (rubric), completion computed | Designer names what to celebrate; the solver finds what exists | Replayability without authoring burden | — |
| 13 | Never gate progress on stars | Any ending advances; stars are for replay | Player flow | — |
| 14 | Pointless interactions count toward completion | They teach the tag system and feed the completionist itch | Completion as a grind feature | — |
| 15 | Deaths stylized, no blood; no dialogue; no VO | Deadpan tone; faceless figures; removes a production track | Tone; scope | — |
| 16 | Music only between loops; timer is the soundtrack during play | Room must be quiet enough to hear him | Sound-as-sensor | — |
| 17 | Sound events on one bus consumed by both attacker perception and audio | Symmetry; what he hears is what you hear | Architecture | — |
| 18 | Demo = 4 rooms, one lesson each | Prove the loop and the systems before content volume | Scope | — |
| 19 | Rooms know nothing about neighbors; campaigns are playlists | Infinite rooms without breaking escalation | Long-term growth | — |
| 20 | Rule changes re-verify every room in CI | Systems can evolve under a growing back catalog | Content integrity | Never |
| 21 | Greybox until M3; no assets before the loop is proven | Art is a swap, not a rebuild | Schedule; sunk cost | — |
| 22 | Asset sourcing: CC0 packs + one Synty pack if a fit exists + agent-built bespoke | Budget < $100; consistency via lighting | Art budget | — |
| 23 | Title: DÉJÀ MORT, slug `deja-mort`, tagline *You've died here before.* | Chosen over Punctual / Standing Appointment / By Heart for memorability and the pun | Brand | Trademark or French-market collision found |
| 24 | Knife in Room 1, gun from Room 3 | Knife makes distance/obstacles matter — the tutorial's lesson; gun re-breaks habits later | Tutorial design | — |
| 25 | Room 1's front door opens into the kitchen | The wet floor becomes the natural chokepoint for the signature kill | Room 1 signature | Solver shows it trivializes evade |
| 26 | Phone starts dead; charger in the kitchen | Evade needs a find; two more interactions | Evade isn't free | — |
