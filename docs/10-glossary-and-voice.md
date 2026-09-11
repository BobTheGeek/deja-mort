# 10 — Glossary and Voice Guide

## Glossary

Use these words exactly, in code, content, docs, and UI. Synonyms drift; drift makes bugs.

| Term | Meaning |
|---|---|
| **Room** | One self-contained level: grid, objects, attacker profile, timer, rubric. A content unit. |
| **Loop** | One attempt in a room, from timer start to death or ending. |
| **Explore phase** | The countdown before arrival. |
| **Arrival** | Timer hits zero; the attacker begins entering. |
| **Attacker** | The one who comes in. Never "enemy," "monster," or "killer" in code/UI. In-room display names come from the profile (`the Tenant`). |
| **Profile** | The attacker's data: entries, weapon, perception, patience, memory, breach costs, search order. |
| **Ending** | A winning loop's type: `evade`, `disable`, `kill`, `escape`. |
| **Death cause** | The `death_cause` id on a losing loop; the unit of the Ways-to-die checklist. |
| **Verb** | One of the eight wheel actions: inspect (center), grab, push, open, toggle, hide, throw, use-held-on, drop. |
| **Rule** | A `(verb, held tags, target tags, conditions) → effects` record in `rules.json`. The only source of behavior. |
| **Tag** | A capability label on an object (`heavy`, `flammable`). From `tags.json` only. |
| **Tag family** | A group of tags and rules that form one mechanic (water, electricity, fire, slip, gas, escape). |
| **State** | An object's mutable fields (`open`, `locked`, `broken`, `wet`). |
| **Hazard** | A per-cell layer: `wet`, `slippery`, `burning`, `gas`, `shock`, `trip`. |
| **Vulnerable** | An attacker under `prone`, `stunned`, `blinded`, `burning`, `electrocuted`, or `pinned`. The only state in which improvised weapons work. |
| **Exposed** | The player state after striking a non-vulnerable attacker; he attacks immediately. |
| **Brace** | A `blocks-door` object occupying a door's interior cell. |
| **Breach** | The attacker defeating a lock, chain, brace, or flimsy door. Costs seconds from the profile. |
| **Lure** | An object emitting sustained noise/light while `on` (TV, radio). He investigates it. |
| **Patience** | Seconds of failed searching before he leaves. `null` = never leaves. |
| **Memory** | Profile field: `none` / `notice` / `full`. What he carries between loops. |
| **Search order** | The profile's default sequence of hiding-spot categories: `closet`, `behind_furniture`, `curtains`, `bed`, `bathroom`. |
| **Discovery** | A rule combination the player has fired once (`water_and_current`). Hidden as `???` until then. |
| **Interaction** | A `(verb, object)` pair performed at least once. The unit of the Interactions checklist. |
| **Authored solution** | A timed action sequence in the room file that the solver verifies. |
| **Improvised** | A solver-found win not matching any authored solution. Achievement by default. |
| **Signature** | A room's ★★★ predicate. |
| **Rubric** | The per-room star predicates (`two`, `three`) with defaults in `rubric_defaults.json`. |
| **Mastery** | 100% on interactions, discoveries, deaths, endings, plus the collectible. Unlocks a cosmetic. |
| **Dossier** | The per-room completion screen. |
| **Notebook** | The auto-written per-room journal: Room, Attacker, Deaths tabs. |
| **Wheel** | The radial action menu. Not "pinwheel," not "radial," not "context menu" in code. |
| **Diorama** | The rendering frame: two walls, floor, darkness. Also the cosmetic "frame" category. |
| **Campaign** | An ordered playlist of rooms with `introduces` markers. |
| **Solver** | `tools/solve.gd`: verify (A), explore (B), deaths (C). |
| **Tightness** | Solver metric: `timer_s` minus the total action time of the tightest authored solution. |

## Notebook voice guide

The notebook is the only place the game speaks. It is auto-generated from templates keyed to events, so the templates *are* the writing. Every line must pass these rules.

**The voice is a coroner's report written by someone tired.** Flat, factual, past tense, no adjectives that judge, no exclamation marks, no emoji, no second-person advice. The player supplies the emotion; the notebook supplies the facts in the driest possible order.

**Rules**

1. State what happened, then what happened next. Cause, then effect, as two short clauses or two short sentences. The humor lives in the gap between them.
2. Never explain the joke. Never comment on the player. "Hid in the closet. He looked in the closet." — not "Hid in the closet (bad idea!)".
3. Never give advice. The notebook records; it doesn't coach. Players infer.
4. Refer to the attacker as "he" (or the profile's pronoun) and never by a scary noun. Refer to the player as nothing — sentences start with the verb. "Threw the toaster." not "You threw the toaster."
5. Numbers are precise when they're funny and absent when they aren't. "Help was seventy-five seconds away." Yes. "Died at 0:47." Only in the loop header, not in the line.
6. One line per loop in the Deaths tab, ≤ 14 words. Room and Attacker tab lines ≤ 10 words.
7. No mention of "loop," "retry," "again," or "reset." The repetition is shown by the list, never named.
8. Deaths the player caused themselves get the same flat treatment as the others. No extra mockery. "Turned on the tap, stood in the kitchen, threw the toaster."
9. Discoveries are named like lab notes: "Water carries current." "Oil under a rug is still oil."
10. Attacker observations are behavioral and specific: "Checked the closet first." "Broke the window when the door held." Never "He's smart."

**Template shape**

```
death.<cause>[.<hidden_in>]  →  "<what you did>. <what he did>."
discovery.<id>               →  "<fact>."
attacker.<behavior>          →  "<observed behavior, past tense>."
room.<object>.inspect        →  "<one concrete sensory fact>."
```

**Examples that pass**

- Stood in the kitchen. He came through the kitchen.
- Hid under the bed. He looked under the bed.
- Braced the door with the couch. That bought ten seconds.
- Lit the curtains. Stayed near the curtains.
- Called for help. Help was seventy-five seconds away.
- Ran at him with a knife. He also had a knife.
- Sprayed hairspray over the stove. Faced the wrong way.
- Turned on the tap, stood in the kitchen, threw the toaster.

**Examples that fail, and why**

- "Oops — the closet is the first place he checks!" (explains, advises, exclaims)
- "You bravely charged him." (second person, adjective)
- "Died again." (names the repetition)
- "The killer found you." (scary noun, second person)
- "Try turning the lights off next time." (advice)

Room inspect text follows the same restraint: one concrete sensory fact per object, ≤ 10 words, no hints phrased as hints. "Heavy. The casters squeak." tells a player it's movable and noisy without saying either.
