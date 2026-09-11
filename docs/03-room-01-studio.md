# 03 — Room 1: "Studio" (vertical slice)

**Fantasy:** A cramped studio apartment, 2 AM. In 90 seconds someone with a knife comes through the front door.

**Lesson:** buy seconds, hide where he looks last, and never charge an armed man. Introduces water, electricity, fire, slip, lure, and the phone.

Everything below is a starting spec. Coordinates and durations are indicative; agents adjust geometry so the authored solutions pass the solver, then commit the solver report.

## 1. Attacker profile — `tenant_knife` ("the Tenant")

```json
{
  "id": "tenant_knife", "display": "the Tenant",
  "entries": ["front_door"],
  "weapon": "knife", "walk_speed": 2.5,
  "sight_range": 6, "hearing_sensitivity": 1.0, "has_flashlight": false,
  "patience_s": 40, "memory": "none", "memory_loops": 0,
  "durability": 1, "strength": 1,
  "breach_costs": { "locked": 4, "chained": 3, "braced_light": 6, "braced_heavy": 10, "flimsy_door": 5, "window": 5 },
  "search_order": ["closet", "behind_furniture", "curtains", "bed", "bathroom"],
  "search_duration_s": 3, "attack_range": 1, "attack_duration_s": 0.5
}
```

Single entry on purpose. The front door opens **into the kitchen**, so the kitchen floor is the chokepoint every solution can exploit.

## 2. Layout

Grid 12 × 10. `#` wall, `.` floor, `D` front door (wall cell + door object), `d` bathroom door, `W` window, `L` light switch (wall object). Row 1 cols 1–5 are counters (objects, not walkable).

```
     0 1 2 3 4 5 6 7 8 9 10 11
 0   # # # # # # W # # # #  #
 1   # s c k n j . . # m t  #     s stove · c counter+drawer · k sink · n counter/knife · j cabinet · m med cabinet · t tub
 2   D . F . . . . . d . t  #     D front door → he enters at (1,2) · F fridge (2,2): push W once → (1,2) braces the door
 3   # . R . . . . . # . o  #     R rug (2,3): push W once → (1,3) · o toilet
 4   # . . . . . . . # # #  #
 5   # B . . . . . l . . N  #     B bookshelf (1,5)-(1,6), tips NORTH onto (1,4),(1,3) · l floor lamp · N nightstand
 6   # B . C C T . . . . b  #     C couch (3,6)-(4,6) · T coffee table · b bed (10,6)-(10,7)
 7   L . . . . . V . . . b  #     L light switch (0,7), adjacent cell (1,7) · V TV
 8   # x x . . y . . . . .  #     x closet (1,8)-(2,8) · y laundry basket
 9   # # # # # # # # # # #  #
```

Path note: from (1,2) his cheapest route to the closet and living area runs through (1,3) — that cell is the trap cell for the slip/shelf solution. The fridge at (2,2) is `blocks-sight`, so from the doorway he cannot see into the living zone until he steps south.

Zones: `kitchen` (1,1)–(5,3) · `living` (2,4)–(7,8) · `entry` = kitchen · `bath` (9,1)–(10,3) · `bed` (8,5)–(10,8). Player start: (6,5). Room starts `lit: true`.

Bathroom is enclosed by walls at col 8 rows 1–3 and row 4 cols 8–10, with a flimsy door at (8,2).

## 3. Objects

| id | pos | tags | state / notes |
|---|---|---|---|
| front_door | (0,2) | entry, openable, lockable, chainable | `locked:false, chained:false, braced_by:null`. Lock/chain toggled from inside only |
| light_switch | (0,7) | light-switch, toggleable | flips `room.lit`. Adjacent cell (1,7) |
| window | (6,0) | openable, breakable | open → hearing mask −1. Breaking is loud (6). Not an entry in this room |
| curtains | (6,1) | flammable, cuttable, hides-player (poor) | search category `curtains`. Fire spreads to nothing else here (walls), but burns the player if they stay |
| stove | (1,1) | toggleable, gas-source, ignites, hot | `on` → cell `hot`. Gas accumulation is enabled by systems but the explosion path is tuned for Room 3; here gas mostly kills the player. Leave the rule generic |
| frying_pan | on stove | carryable, blunt, weapon-improvised, throwable, heavy-ish (`weight 3`) | the classic. Only works on a vulnerable target |
| counter_drawer | (2,1) | container, openable | contains: `charger`, `cooking_oil` |
| charger | in counter_drawer | carryable, charger | use on `phone` → charging |
| cooking_oil | in counter_drawer | carryable, pourable, slippery-source | pour on floor cell → `slippery`. Consumed |
| toaster | (2,1) on counter | carryable, throwable, conductive, plug-in, blunt | `plugged:true`, outlet (2,1), `cord_range 3`. **contains collectible** `bubble_token` (Inspect twice / Open reveals it) |
| sink | (3,1) | toggleable, wet-source | `on` → wet spreads over kitchen floor cells (rows 2–3, cols 1–5) at 0.25 tiles/s ≈ 40s to fill |
| counter_knife | (4,1) | container (knife block) | contains: `kitchen_knife` |
| kitchen_knife | in counter_knife | carryable, sharp, weapon-improvised, throwable | also `cut` curtains. Charging with it = death (loop 3 lesson) |
| cabinet | (5,1) | container, openable | contains: `glass_jar` |
| glass_jar | in cabinet | carryable, throwable, fragile, noisy-on-break | throw for noise 6 → lure |
| fridge | (2,2) | heavy, movable, blocks-door, blocks-sight, container, openable | push W once (from (3,2)) → occupies (1,2) → `front_door.braced_by = fridge` (braced_heavy, 10s). contains: `soda_cans` |
| soda_cans | in fridge | carryable, throwable, noisy | throw → noise 4 → lure |
| rug | (2,3) | movable (light), hides-object | push W once (from (3,3)) → (1,3). Covers a hazard cell → `concealed` |
| bookshelf | (1,5)-(1,6) | heavy, movable, blocks-sight, tips | `tips: {dir:"N", onto:[[1,4],[1,3]]}`. Push N from (1,7): first = leaning, second = falls; actor on `onto` → `pinned` |
| couch | (3,6)-(4,6) | heavy, movable, blocks-door, hides-player | `hide_cells: [[3,7],[4,7]]`, category `behind_furniture`. Pushing it toward the door is possible but too slow to matter (pointless, counts) |
| coffee_table | (5,6) | movable, fragile, breakable | glass top; break → `shards` object (sharp) + noise 6 |
| tv | (6,7) | toggleable, lure, fragile, bright | `on` → sustained noise 3 at (6,7) + light. He investigates it before searching |
| floor_lamp | (7,5) | carryable (`weight 2`), blunt, throwable, toggleable, plug-in | cord over a chokepoint cell → `trip`. Spare weapon |
| closet | (1,8)-(2,8) | hides-player, container, openable | category `closet`. **He checks it first.** contains: `umbrella` |
| umbrella | in closet | carryable, blunt (weak), throwable | pointless weapon — thrown, it stuns nothing. Counts |
| laundry_basket | (5,8) | container, openable | contains: `towel` (carryable, flammable). Pointless |
| bed | (10,6)-(10,7) | hides-player | category `bed`, `hide_cells` = under |
| nightstand | (10,5) | container, openable | contains: `phone`, `lighter`. Outlet (10,5) |
| phone | in nightstand | phone, carryable | `charged:false`. Charger on it → charged after 30s (must stay near outlet: leave it in the nightstand). Toggle when charged → `help_arrives` timer 75s → attacker `leave` when it fires |
| lighter | in nightstand | carryable, ignites | + curtains/towel = fire. + gas = explosion (kills player in this room's geometry unless in bath) |
| bath_door | (8,2) | openable, lockable, flimsy | breach 5s |
| bathtub | (10,1)-(10,2) | hides-player | category `bathroom`. **He checks it last** |
| med_cabinet | (9,1) | container, openable | contains: `hairspray`, `hair_dryer`. Outlet (9,1) |
| hairspray | in med_cabinet | carryable, aerosol, flammable, throwable | use on `hot`/`burning` → 2-tile cone: `blinded` 4s + ignite flammables |
| hair_dryer | in med_cabinet | carryable, conductive, plug-in, throwable | outlet (9,1), cord range 3 → bathroom only. Second electrocution site if you can flood it (you can't here — pointless, counts) |
| toilet | (9,3) | toggleable (flush: noise 3) | pointless. Counts. Flushing is technically a lure |

Total: 32 objects including contained items. Interactions checklist ≈ 70 valid pairs (solver computes the exact number).

## 4. Systems block

```json
"systems": {
  "wet":   { "rate_tiles_per_s": 0.25, "zone": "kitchen", "source_cells_from": "sink" },
  "fire":  { "spread_s": 4, "burn_actor_after_s": 3 },
  "gas":   { "fill_s": 50, "zone": "kitchen" },
  "phone": { "charge_s": 30 },
  "help":  { "delay_s": 75 },
  "disable_hold_s": 10
}
```

## 5. Authored solutions (solver Mode A tests)

Times are earliest-issue seconds; the solver issues each intent at `t` or when the prior action completes.

### 5.1 `evade_phone` — Evade, ★

Buy seconds, hide where he looks last, let help arrive.

**Reach rule:** objects on counters (row 1) are interactable from any 8-connected floor cell, so the drawer at (2,1) is reachable from (1,2) or (3,2) even with the fridge at (2,2). Floor objects (rug, oil cells) use 4-connected adjacency. Rugs are walkable (`walk_over: true`).

```
t=0   walk_to (3,2) ; open counter_drawer ; grab charger
t=4   walk_to (9,5) ; open nightstand ; use_held_on phone        → charging; charged at ~t=38
t=9   walk_to (1,2) ; toggle front_door(lock) ; toggle front_door(chain)
t=12  walk_to (3,2) ; push fridge W                              → fridge at (1,2), door braced (heavy, +10s)
t=15  walk_to (1,7) ; toggle light_switch                        → dark
t=19  walk_to (9,5) ; wait until phone.charged ; toggle phone    → call at ~t=38; help_arrives at ~t=113
t=40  walk_to (9,2) ; open bath_door ; toggle bath_door(lock) ; hide bathtub
```
Expected: he arrives t=90, breaches lock 4 + chain 3 + brace 10 → inside at ~107, dark, walks to the closet, search 6s (dark) → t≈115 > 113 → `help_arrives` → `leave`. Ending `evade`, ★. Player never seen (would qualify for the ★★★ fallback, but the room overrides ★★★ — see rubric).

### 5.2 `disable_shelf` — Disable, ★★

Chain two setups: he slips, you drop the shelf.

```
t=0   walk_to (3,2) ; open counter_drawer ; grab cooking_oil
t=4   walk_to (1,4) ; use_held_on cooking_oil → cell (1,3)        → slippery
t=7   walk_to (3,3) ; push rug W                                   → rug at (1,3), hazard concealed
t=10  walk_to (1,7) ; push bookshelf N (tip_first)                 → leaning over (1,4),(1,3)
t=13  wait
t=92  he enters at (1,2), paths south to (1,3), slips → prone 3s
t=93  push bookshelf N (tip_second)                                → falls onto (1,4),(1,3) → attacker pinned
t=103 ending disable (after disable_hold_s)
```
Non-lethal → ★★ under the default rubric. The shelf blocks his LOS to the player at (1,7). With `memory: notice` (later rooms) the moved rug and leaning shelf would make him avoid (1,3) — that's the point of Room 2.

### 5.3 `kill_toaster` — Kill, ★★★ (signature)

Commit early, kill the lights, let the room do it.

```
t=0   walk_to (3,2) ; toggle sink            → kitchen floor floods over ~40s
t=2   grab toaster (from (3,2), 8-connected reach) → held, still plugged (cord range 3 from (2,1))
t=4   walk_to (1,7) ; toggle light_switch    → dark
t=7   walk_to (5,4)                          → dry (living); fridge blocks LOS from the doorway, and dark sight is 3
t=90  (he enters (1,2) — wet; does not see player at (5,4))
t=92  throw toaster → cell (3,2)             → within cord range of (2,1) and throw range of (5,4); shock on all connected wet cells (incl. (1,2)) for 3s → attacker electrocuted, durability 0 → dead
```
Rubric ★★★: `attacker.death_cause == 'shock' && player.never_seen`. Same kill with the lights on = seen → ★ (or ★★ if no damage and ≤ 6 loops).

### 5.4 Expected Improvised wins the solver should find (leave as achievements unless Bob promotes them)

- Hairspray + lit stove at the door → blinded → pan strike. (Vulnerable rule via `blinded`.)
- Throw the glass jar at the bathroom while hidden under the bed → he investigates → patience burns.
- Tip the shelf without oil: he's not prone, so it misses — should *not* win. Verify.
- Lamp cord across (1,3) → trip → prone → knife strike. (If the solver finds this, it's valid; consider whether trip belongs in Room 1 or gets moved to Room 2.)

## 6. Star rubric

```json
"rubric": {
  "three": "attacker.death_cause == 'shock' && player.never_seen"
}
```
★ any win · ★★ default (`damage_taken == 0 || ending != 'kill' || loop.index <= 6`) · ★★★ as above.

## 7. Ways to die (target: 12)

1. Stabbed in the open (loop 1)
2. Stabbed in the closet (loop 2 — he checks it first)
3. Charged him with a weapon — exposed (loop 3 lesson)
4. Stabbed behind the couch
5. Stabbed behind the curtains
6. Stabbed under the bed
7. Stabbed in the bathtub (patience not exceeded / help not called)
8. Electrocuted yourself (standing on wet cells when the shock fired)
9. Burned (lit the curtains and stayed)
10. Slipped on your own oil, then stabbed
11. Blinded yourself with the hairspray, then stabbed
12. Stabbed mid-phone-call (standing at the nightstand at arrival)

Solver Mode C confirms reachability of each. Notebook lines (deadpan, from templates): "Hid in the closet. He looked in the closet." · "Ran at him with a knife. He also had a knife." · "Turned on the tap, stood in the kitchen, threw the toaster. Physics." · "Called for help. Help was seventy-five seconds away."

## 8. Discoveries (`???` until fired)

`water_and_current` · `oil_under_rug` · `shelf_drop` · `aerosol_flash` · `lure_noise` · `brace_door` · `lights_out` · `curtain_fire` · `phone_help` · `cord_trip` (if kept)

## 9. Collectible

`bubble_token` inside the toaster (Open toaster, or Inspect it a second time). Finding it costs ~8s of the 90 and nothing in the room needs you to look there.

## 10. First-loop choreography (not scripted — emerges from the room)

Loop 1: the player wanders, timer hits 0, door opens, he walks in and finds them in ~10s. Loop 2: most players hide in the closet — search_order[0]. Loop 3: knife from the block, charge — `strike` on a non-vulnerable target → `exposed` → dead. If playtests show players skipping straight to a good hiding spot, that's fine; the room doesn't need loops 1–3 to happen, only to be *available*.

## 11. Open tuning questions for the slice

- Is 90s right? Solver `tightness` for the kill path should land ~30–40s of slack; the evade path ~40s.
- Does the flood ever reach a cell the player must stand on? Zone limit should prevent it; verify.
- Player at (5,4) for the kill: the fridge at (2,2) blocks LOS from (1,2); once he steps to (1,3) he has a line. The throw must land before he does — the solver will tell us if 0.5s is enough slack, otherwise the standing cell moves to (5,5).
- Should `cord_trip` ship in Room 1 or be held for Room 2? Default: ship, count it as an interaction, let the solver decide if it's a win.
