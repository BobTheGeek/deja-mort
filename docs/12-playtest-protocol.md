# 12 — Playtest Protocol

For M3 (greybox) onward. The point is to turn "does it feel right" into data that changes tuning numbers and Rooms 2–4.

## Who

- **Bob** first, alone, no notes open. Then 3–5 people who've never seen the design. Friends who play puzzle games are ideal; one person who doesn't play games at all is worth more than two who do.

## Setup

- Fresh save. No explanation beyond: "You're in a room. Something's coming. Good luck." Do not mention the wheel, the timer, hiding, or the notebook.
- Screen recording on. Think-aloud encouraged but not required.
- Observer takes notes; observer does not help. If the player asks a question, write it down and say "what do you think?"

## Log per player (one sheet)

| Field | What to record |
|---|---|
| Loops to first ending | Count, and which ending |
| Loops 1–3 | What they tried, in order. Did the room's "scripted" first three happen (wander / closet / charge)? |
| First wheel open | Seconds from start. Did they understand the faded slots without being told? |
| Timer awareness | When did they first look at it? Did they ever ration time deliberately? |
| Hidden-and-listening | While hidden, could they say where he was? (Ask afterward.) |
| Notebook | Did they open it unprompted? Did any line make them laugh or say "oh"? Which? |
| Discoveries | Which `???` did they fire, and was it by intent or accident? |
| Post-win screen | Did they notice the ★★★ silhouette? Did they press Replay or Next? Why? |
| Quit point | If they stopped, after which loop, and what did they say? |
| Verbatim | Three quotes: one confusion, one delight, one frustration |

## Questions afterward (in this order)

1. What were you trying to do on the last loop?
2. What do you think the ★★★ was?
3. Where was he when you were hiding?
4. Was the timer too long, too short, or didn't notice?
5. Would you play the next room? (Watch the face, not the words.)

## What changes what

| Observation | Adjust |
|---|---|
| Median loops-to-first-ending > 12 | `timer_s` up, or a hiding spot's search position later, or an inspect line clearer |
| < 4 | Room too easy — add a search-order tweak or shorten a breach cost. Don't add objects |
| Players never ration time | Timer isn't biting: shorten, or raise action durations |
| Can't locate him by ear | Attacker cues too quiet/similar — audio pass, not design pass |
| Wheel opened late or not at all | The first-click affordance is failing — object highlight on hover, or a pulse on the first object |
| Nobody notices the ★★★ silhouette | Win screen layout, not the rubric |
| Nobody presses Replay | The Ways-to-die count and silhouettes aren't visible enough, or the room is done (fine for a tutorial) |
| A death line gets a laugh | Note the template; that's the voice working — write more like it |
| Improvised win nobody saw coming | Solver missed it or the rubric misclassed it; file both |
| Solver `min_loops_estimate` off from human median by > 3 | Refine the estimator; it feeds procedural difficulty later |

## Record

Every session → one row in `docs/playtests/<date>-<room>.md`. Tuning changes that come out of it → `docs/TUNING.md` with the observation that caused them. The solver report before and after the change gets committed alongside.
