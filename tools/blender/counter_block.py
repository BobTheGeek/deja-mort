"""Counter run — knife-block cabinet. 1.0 x 0.6 x 0.9 m.

Walnut carcass with one wide drawer front and steel handle, dark worktop.
The knife read comes from the `kitchen_knife` object's own model, which the
renderer stacks onto this cell when the block is open; drawing knives here
too would double it. Front toward -Y in Blender (+Z in Godot).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, export, join, material, reset

reset()
worktop = material("worktop", (0.30, 0.31, 0.33), roughness=0.6)
walnut = material("walnut", (0.45, 0.34, 0.22))
steel = material("steel", (0.62, 0.63, 0.64), metallic=0.4, roughness=0.5)

parts = [
    box("carcass", (1.0, 0.6, 0.85), (0.0, 0.0, 0.425), walnut),
    box("worktop", (1.0, 0.6, 0.05), (0.0, 0.0, 0.875), worktop),
    box("front", (0.86, 0.02, 0.30), (0.0, -0.305, 0.45), walnut),
    box("handle", (0.16, 0.02, 0.02), (0.0, -0.325, 0.45), steel),
]

join(parts, "counter_block")
export("counter_block")
