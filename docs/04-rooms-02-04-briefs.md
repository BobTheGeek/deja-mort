# 04 — Rooms 2–4: Briefs

Expand these into full room specs (same format as `03-room-01-studio.md`) **only after Room 1 has shipped and been playtested.** Each room breaks one habit Room 1 taught. Each introduces one attacker parameter change and, at most, one new tag family.

Escalation is a property of the *campaign* file, not of these rooms — see `05-campaign-and-progression.md`. Any of these could be reordered or replaced without touching the others.

---

## Room 2 — "After Hours" (open-plan office)

**Fantasy:** A small open-plan office, 11 PM. The cleaning crew left an hour ago. Someone is coming up the service corridor.

**Lesson:** *the room remembers.* What you moved last loop is evidence this loop.

**Breaks:** "brace the one door and hide" — there are two entries, and moved furniture makes him suspicious.

**Attacker — `contractor_knife`:** knife · two entries (`main_door`, `service_corridor`), switches when the current entry's breach cost exceeds the alternative · `memory: notice` (objects with `moved == true` raise suspicion of `hides-player` objects within 2 tiles; avoids cells adjacent to leaning objects) · patience 60s · sight 6 · durability 1.

**New tag family:** `escape`. First room with `exits_locked: false`. The fire exit is `chained`; bolt cutters are in the maintenance closet; cutting is loud (noise 6) and slow (6s). **Escape** is a fourth ending.

**Signature (★★★, proposal):** Lock him *in*. Lure him into the server room with the alarm test button, close and wedge the door with the fire extinguisher, walk out the fire exit. `attacker.trapped && ending == 'escape'`.

**Object ideas (~28):** desks (movable, hides-under), rolling chairs (movable, `trip` when tipped), monitors (fragile, throwable, heavy), coffee machine (wet-source, hot), microwave (metal + toggle = sparks → ignites), paper stacks (flammable), fire extinguisher (heavy, blunt, suppresses burning, `blocks-door`), copier (heavy, blocks-door), server room (lockable from outside, cold), alarm test button (lure, very loud, sustained), fire exit (exit, chained), bolt cutters (tool: `cut` chain), extension cords (trip), whiteboard (movable, blocks-sight), plant (pointless), stapler (pointless weapon), vending machine (heavy, tips).

**Ways to die ideas:** hid under the desk you'd moved · cut the chain, he heard it · burned the paper stacks and the sprinklers didn't exist · trapped yourself in the server room.

---

## Room 3 — "The Hallway" (suburban house: kitchen, hall, pantry)

**Fantasy:** A suburban kitchen at dusk, the hallway to the front door, a pantry, a garage door. He has a gun and a flashlight.

**Lesson:** *cover, not darkness. You cannot wait him out.*

**Breaks:** "kill the lights and hide" (flashlight) and "buy seconds until he leaves" (infinite patience). Evade is impossible; you must disable or kill.

**Attacker — `intruder_gun`:** `weapon: gun` (attack requires LOS within `sight_range`; `blocks-sight` objects are now cover) · `has_flashlight: true` (darkness gives nothing) · `patience_s: null` · single entry (garage door) but he *clears* rooms methodically · durability 1 · breach costs higher (strength 2).

**New tag family:** `gas` at full strength. The gas stove leaks into the kitchen zone over ~50s; any ignition source (his flashlight is *not* one; a light switch *is*; the pilot light is) → explosion in zone: everyone in it dies.

**Signature (★★★):** Leave the gas on, hide in the pantry with the door shut (pantry is its own zone), he flips the kitchen light switch. `attacker.death_cause == 'explosion' && player.zone == 'pantry'`. Mis-time it and you die in the same blast — several Ways-to-die live here.

**Also introduces:** `blocks-sight` as cover mechanics (kitchen island, open fridge door), the first `hot` trap chain (oil in a pan on the stove → thrown → burning), and a `heavy` chandelier/pot rack that drops from a pull cord.

**Object ideas (~30):** gas stove, pan of oil, kitchen island (cover), fridge (door as cover), pantry (hides, own zone, lockable), light switch, hallway table (movable), coat rack (movable, blocks-sight), garage door (entry), dog bowl and leash (pointless), knife block, fire extinguisher, cleaning chemicals (mix two → `toxic` zone → he coughs, `vulnerable`), microwave, pot rack with pull cord, laundry room (second hiding zone), phone (dead — no line, pointless), car keys (pointless; garage is locked from outside).

---

## Room 4 — "Motel" (demo finale)

**Fantasy:** A cheap motel room. One door, one bathroom, one window onto a parking lot. He's been here before. So have you.

**Lesson:** *he remembers.* The challenge isn't finding a solution — it's finding one he hasn't seen.

**Breaks:** every repeated solution.

**Attacker — `revenant_knife`:** knife · `memory: full`, `memory_loops: 3` (searches your last hiding spots first; path cost +100 on cells where a trap fired; avoids wet cells if electrocuted last time; avoids `tips.onto` cells if pinned last time) · patience 45s · durability 1 · single entry, but the window becomes a second entry if the door is braced twice in a row (his memory "learns" it).

**Design consequence:** the room is *small and sparse* on purpose (~18 objects) so that the solution space is tight and the player must rotate through it: evade once, disable once, kill once, then improvise. The ★★★ condition is about *variety*, not a specific trap.

**Signature (★★★):** `loop.win_streak_distinct_endings >= 3` — win three consecutive loops with three different endings. This is the only room whose rubric references loop history; the outcome tracker needs to support it.

**Non-verbal tell (permitted exception to "no dialogue"):** when he enters, he pauses for one beat facing the object you hid in last loop. Animation event, no text.

**Object ideas (~18):** door (lock, chain — no brace-able furniture heavier than the dresser), dresser (heavy, movable, blocks-door, tips), bed (hides-under), bathroom (tub, flimsy door, hair dryer, sink — wet-source in a small zone), ice bucket (wet, small), lamp (blunt, plug-in, trip), Bible drawer (pointless, collectible lives here), TV (lure, fragile), window (openable, breakable, entry on memory), curtains (flammable), ashtray + matches (ignites), coffee maker (hot, wet-source), luggage (container: pointless clothes, one belt = `binds` a pinned attacker → upgrades disable to permanent), phone (calls the front desk: help 90s, but only once — he remembers).

**Ways to die ideas:** hid in the tub twice · he came through the window · braced the door with the dresser twice · the belt trick, one second late.

---

## Sequencing note

Room 2 should start only after Room 1's playtest has answered: is 90s right, does the wheel feel fast, does the notebook read well, does the solver's difficulty estimate match human experience. Those answers change Rooms 2–4 more than any spec here does.
