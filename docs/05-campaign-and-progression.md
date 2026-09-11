# 05 — Campaign, Progression, and the Infinite-Rooms Architecture

## 1. The principle

Rooms are self-contained. Campaigns order them. Global systems power them. Nothing in a room knows what came before or after. This is what lets the game grow from 4 rooms to 400 without the escalation path becoming a rewrite.

```
content/rooms/*.json         ← content units (self-contained, solver-verified)
content/campaigns/*.json     ← playlists: order + "introduces" markers + gates
content/rules.json, tags.json, systems.json, attackers/*.json   ← global systems
```

## 2. Campaign schema (`content/campaigns/demo.json`)

```json
{
  "schema_version": 1,
  "id": "demo",
  "title": "Déjà Mort — Demo",
  "chapters": [
    {
      "id": "ch1", "title": "Repeat",
      "rooms": [
        { "room": "room_01_studio",  "introduces": ["wheel", "hide", "brace", "water", "electricity", "fire", "slip", "phone"] },
        { "room": "room_02_office",  "introduces": ["two_entries", "memory_notice", "escape"] },
        { "room": "room_03_hallway", "introduces": ["gun", "flashlight", "cover", "gas", "no_patience"] },
        { "room": "room_04_motel",   "introduces": ["memory_full", "variety_rubric"] }
      ],
      "unlock": "any_ending_previous",
      "interlude": null
    }
  ],
  "mastery_rewards": {
    "room_01_studio": "cosmetic.frame.brass",
    "room_02_office": "cosmetic.outfit.janitor",
    "room_03_hallway": "cosmetic.notebook.ledger",
    "room_04_motel":   "cosmetic.frame.glass_case"
  }
}
```

- `unlock`: `any_ending_previous` (default; never gate on stars), `stars_total >= N` (optional for bonus chapters), `mastery_of <room>` (for secret rooms).
- `introduces[]`: free-form markers. Used by the UI ("New: he has a gun") and by the content pipeline to validate that a room doesn't *require* a mechanic the campaign hasn't introduced yet.
- `interlude`: optional reference to a story beat scene between rooms. Null for the demo. The story wrapper is a later layer; it must never be required by a room.

## 3. Room metadata (in each room JSON, `meta{}`)

```json
"meta": {
  "attacker_archetype": "knife",
  "tag_families": ["water", "electricity", "fire", "slip"],
  "requires": ["wheel", "hide"],
  "entries": 1, "exits": 0,
  "size": "small",
  "difficulty": null
}
```

`difficulty` is **written by the solver**, never by hand, into `<room>.solver.json`:

```json
{ "solutions_found": 7, "authored_verified": 3, "improvised": 4,
  "min_actions_to_win": 5, "min_loops_estimate": 3,
  "tightness_s": 31, "deaths_reachable": 12, "interactions_total": 71, "discoveries_total": 10 }
```

`min_loops_estimate` is a heuristic: number of distinct "facts" a player must learn (hiding-spot order, a hazard's existence, a timing) before the cheapest solution becomes findable. Refine with playtest data.

## 4. How escalation scales

Each chapter introduces **one attacker archetype** and **one tag family**. The room that introduces it is designed around it; later rooms combine.

| Chapter | Attacker archetype | Tag family | What breaks |
|---|---|---|---|
| 1 (demo) | knife → gun → memory | water/electricity/fire/slip → escape → gas → variety | see room briefs |
| 2 | two attackers (planner runs two instances; they share perception) | sound design: `silent` objects, `distraction` beyond lure | "one trap, one target" |
| 3 | non-human (no doors: vents; no `lockable` respect; `patience` replaced by `hunger`) | animals / biology (`bait`, `scent`) | "he comes through the door" |
| 4 | the one that talks (still no dialogue — it *writes in your notebook*) | light: `blinding`, `shadow` as cover | "the notebook is mine" |

These are directions, not commitments. The point is that each is an *attacker profile field* plus a *tag family*, never a new engine.

## 5. Content pipeline (for volume)

The room is JSON and the solver is the gatekeeper, so rooms can come from anywhere:

1. **Hand-authored** (the demo).
2. **LLM-drafted**: prompt = a room's `fantasy` line + the tag vocabulary + the rule table + three example rooms → draft JSON. Then `lint_room` → `solve` → human review of the solver report → tune → ship. The solver does the playtesting a human can't do at scale.
3. **Procedural**: template rooms (studio, office, motel) with object pools and randomized placement, solver-filtered for `solutions_found >= 2 && tightness_s in [15, 45]`. Daily room / endless mode.
4. **Community** (much later): a room editor that emits the same JSON; the solver runs before publish.

All four produce the same content unit and land in campaign playlists or in an `extras` pool. None require code.

## 6. Mastery and cosmetics

Mastery = 100% on all four checklists (interactions, discoveries, deaths, endings) plus the collectible. Rewards are cosmetic only:

- **Diorama frames** — the base the room sits on: plain, brass, glass case, museum plinth. Visible on every room.
- **Outfits** — for the faceless player figure. Silhouette-level changes.
- **Notebook covers**.

Global mastery (all rooms in a campaign) → a secret room, unlocked via `mastery_of` gate. Design later.

## 7. Versioning

- Every content file carries `schema_version`. Loaders migrate forward; `tools/lint_room.gd` rejects unknown versions.
- Rule and tag changes bump `rules.json` `version`. CI re-verifies every room's authored solutions on any change and diffs every `<room>.solver.json`. A difficulty drift of more than ±20% on `tightness_s` or a change in `solutions_found` on an unchanged room fails the build until a human acknowledges it.
- Save data is versioned separately (`game/save_migrations.gd`).

## 8. Story (deferred, but reserved)

The loop theme gives a natural spine: *why does this keep happening?* If used, it lives in `interlude` scenes between rooms and in a handful of notebook lines that appear only after specific mastery thresholds. Rooms never depend on it. The demo ships with `interlude: null` everywhere.
