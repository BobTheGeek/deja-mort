# 08 — Room layout: how furniture is placed

Bob, sixth playtest: *"The fridge is in front of the stove. A fridge should always be against a wall. The table the knife block is on is crooked. The lamp is in the middle of the room."*

He was right three times, and the third one is the tell: none of this was decided, it accumulated. This is the standard Room 1 and every room after it is held to, where it comes from, and which parts `tools/lint_room.gd` enforces so the next room cannot repeat it.

---

## Where the numbers come from

| source | what it gives us | note |
|---|---|---|
| **NKBA Kitchen & Bath Planning Guidelines**, 5th edition | kitchen clearances, work triangle, landing areas | the North American standard for kitchen planning; the guidelines themselves are a paid document, and the figures below come from published summaries of them |
| Furniture spacing guides (living room, bedroom) | sofa-to-table, bed clearance, dresser clearance, walkway widths | these agree with each other and with Neufert / Metric Handbook conventions |

Sources consulted, 14 Sept 2026:

- [NKBA — Kitchen and Bath Planning Guidelines](https://nkba.org/planning-guidelines/) (the guidelines themselves; numbers not published free)
- [Kitchen Design Guidelines & Clearances — NKBA Standards Explained](https://www.thewcsupply.com/pages/kitchen-design-guidelines-standard-clearances)
- [Kitchen Layout and Floor Plan Recommendations From The NKBA](https://planforward.net/design-matters/kitchen-layout-and-floor-plan-recommendations-from-the-nkba)
- [Furniture Spacing Guidelines: Room-by-Room Clearance Rules](https://www.roomsketch3d.com/learn/traffic-flow-spacing/furniture-spacing-guidelines)
- [Furniture Clearance and Walkway Standards](https://roomsketch3d.com/help/dimensions/clearance-around-furniture)

**One grid square is one metre**, set by `models.kenney.metres_per_unit` and checked in `tests/game/scale_test.gd`. Every figure below is converted to squares at that scale.

---

## The standard

### Clearances

| rule | standard | in squares | why it matters here |
|---|---|---|---|
| Walkway | 36 in / 91 cm | **1** | one free square is a corridor |
| Kitchen work aisle, one cook | 42 in / 107 cm | **2** | a person and an open appliance door |
| Doorway | 32 in / 81 cm | **1** | |
| Sofa to coffee table | 14–18 in / 36–46 cm | **adjacent** | they touch on this grid; a square between them is a room away |
| Bed, walking side | 24 in min, 36 in better | **1** | the other long side may be against a wall |
| In front of a dresser or wardrobe | 36 in | **1** | you have to open it |
| Conversation distance | 6–10 ft / 1.8–3 m | **2–3** | past that, two sofas are two rooms |

### Kitchen

- **Work triangle** — sink, cooking surface, refrigerator. Each leg 4–9 ft (**1–3 squares**), the three legs together no more than 26 ft (**8 squares**). Traffic should not cross it.
- **Landing area** — 15 in beside the refrigerator, 12 in one side and 15 in the other of the cooking surface, 24 in and 18 in either side of the sink. On this grid that is **one counter square next to each**, which is what a run of cabinets gives for free.
- **Never put the cooking surface under an operable window.**
- The refrigerator door has to open. It needs a free square in front of it, and it belongs at the **end** of a run, not in the middle of the floor.

### Placement, stated as rules

1. **Fixtures go against a wall.** A cooker, a sink, a counter, a fridge, a wardrobe, a bookcase, a bath, a lavatory, a bed. If it is heavy and nobody moves it daily, one of its squares touches a wall.
2. **Fronts face the room.** A cabinet with its doors to the wall is a box. This is a rendering fact as much as a realism one — it is what made Room 1 unreadable for three playtests.
3. **Everything opens into a free square.** A fixture with no walkable square in front of it cannot be used and cannot be understood.
4. **Nothing is marooned.** Furniture touches a wall or touches other furniture. A floor lamp alone in the middle of the carpet reads as a mistake, because it is one.
5. **Groups are groups.** Sofa, table and television belong on one axis, within conversation distance.

---

## What the lint checks

`godot --headless -s tools/lint_room.gd` fails the build on the first three, and warns on the fourth:

| check | rule |
|---|---|
| `fixture-off-wall` | every object tagged `fixture` has a footprint square orthogonally touching a wall |
| `faces-a-wall` | no object's front (from `mesh_yaw`, with the pack facing +Z at 0) points into a wall |
| `no-room-to-use` | every `fixture` has a walkable square in front of it |
| `marooned` *(warning)* | a non-carryable object touches neither a wall nor another non-carryable object |

**Declared exceptions.** A room may carry `layout_exceptions: {"<object id>": "<reason>"}`. The check still runs and still reports, but a declared exception does not fail the build. The point is that a violation is either fixed or it is a decision somebody wrote down.

---

## Room 1's one declared exception

`fridge` stands free at (2, 2) rather than against a wall.

It is the object `evade_phone` pushes into the doorway square to brace the front door, and a push moves it exactly one square away from the player. Only two squares in this room can reach the doorway square in one push: (2, 2), which is free-standing, and (1, 3), which is against the west wall and is where the oil goes and where the bookshelf falls. Moving the fridge to (1, 3) was tried: **two of the three authored solutions stop verifying.**

So it stays, and the reason is in the room file. The way out, if it matters enough later, is to re-author Room 1's entry — move the front door so that the square one push from it is a wall square. That is a room redesign, not a placement fix, and it is Bob's call.
