"""Bookshelf. 0.8 x 0.3 x 1.8 m, walnut, five slats, a darker back panel.

Authored in the kit convention (front +Z, width X, depth Z). The room KEEPS
`mesh_yaw: 90` from the Kenney piece: that turns the front into +X — against
the west wall, facing the room — and the width along the 1x2 footprint.
Yaw 0 would sit the shelf across its deep footprint facing the wall.
Load-bearing for the `disable_shelf` ending.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, export, join, material, reset

reset()
walnut = material("walnut", (0.45, 0.34, 0.22))
walnut_dark = material("walnut_dark", (0.30, 0.22, 0.14))

parts = [
    box("side_left", (0.03, 0.28, 1.74), (-0.385, 0.0, 0.87), walnut),
    box("side_right", (0.03, 0.28, 1.74), (0.385, 0.0, 0.87), walnut),
    box("top", (0.8, 0.30, 0.03), (0.0, 0.0, 1.785), walnut),
    box("bottom", (0.8, 0.30, 0.03), (0.0, 0.0, 0.015), walnut),
    box("back", (0.74, 0.02, 1.71), (0.0, 0.13, 0.885), walnut_dark),
]
for index, z in enumerate([0.34, 0.67, 1.00, 1.33, 1.64]):
    parts.append(box(f"shelf_{index}", (0.74, 0.26, 0.03), (0.0, 0.0, z), walnut))

join(parts, "bookshelf")
export("bookshelf")
