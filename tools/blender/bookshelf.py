"""Bookshelf. 1.6 x 0.3 x 1.8 m, walnut, two bays, five slats per bay.

Widened from the first pass's 0.8 m after review: the object occupies a
1x2-cell footprint, and Bob's call was "whatever looks most natural in
relation to the other elements" — the room's other pieces are real-sized
(bed ~2 m, couch ~2 m, the pack's own "wide" bookcase measured 1.60 m), so
the shelf fills its wall run like furniture, not like a gap with an
invisible wall behind it. The scale catalogue bounds it at 1.30–1.80 m.

Authored in the kit convention (front +Z, width X, depth Z). The room keeps
`mesh_yaw: 90`: the front turns into +X — against the west wall, facing the
room — and the width runs along the 1x2 footprint. Load-bearing for the
`disable_shelf` ending.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, export, join, material, reset

reset()
walnut = material("walnut", (0.45, 0.34, 0.22))
walnut_dark = material("walnut_dark", (0.30, 0.22, 0.14))

parts = [
    box("side_left", (0.03, 0.28, 1.74), (-0.785, 0.0, 0.87), walnut),
    box("side_right", (0.03, 0.28, 1.74), (0.785, 0.0, 0.87), walnut),
    box("divider", (0.03, 0.28, 1.74), (0.0, 0.0, 0.87), walnut),
    box("top", (1.60, 0.30, 0.03), (0.0, 0.0, 1.785), walnut),
    box("bottom", (1.60, 0.30, 0.03), (0.0, 0.0, 0.015), walnut),
    box("back", (1.57, 0.02, 1.71), (0.0, 0.13, 0.885), walnut_dark),
]
for index, z in enumerate([0.34, 0.67, 1.00, 1.33, 1.64]):
    for side, x in (("l", -0.3925), ("r", 0.3925)):
        parts.append(box(f"shelf_{index}_{side}", (0.755, 0.26, 0.03), (x, 0.0, z), walnut))

join(parts, "bookshelf")
export("bookshelf")
