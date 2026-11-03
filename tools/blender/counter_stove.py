"""Counter run — stove. 1.0 x 0.6 x 0.9 m.

Ceramic body, dark worktop, four steel burners, a proud oven door and handle
on the front (-Y in Blender, +Z in Godot). Part of the authored counter
family that replaces the Kenney kitchen units in Room 1.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, cyl, export, join, material, reset

reset()
ceramic = material("ceramic", (0.60, 0.61, 0.60))
worktop = material("worktop", (0.30, 0.31, 0.33), roughness=0.6)
steel = material("steel", (0.62, 0.63, 0.64), metallic=0.4, roughness=0.5)

parts = [
    box("carcass", (1.0, 0.6, 0.85), (0.0, 0.0, 0.425), ceramic),
    box("worktop", (1.0, 0.6, 0.05), (0.0, 0.0, 0.875), worktop),
    box("oven_door", (0.78, 0.02, 0.40), (0.0, -0.305, 0.42), worktop),
    box("oven_handle", (0.50, 0.02, 0.02), (0.0, -0.325, 0.64), steel),
]
for index, (x, y) in enumerate([(-0.22, -0.15), (-0.22, 0.15), (0.22, -0.15), (0.22, 0.15)]):
    parts.append(cyl(f"burner_{index}", 0.075, 0.012, (x, y, 0.906), steel))

join(parts, "counter_stove")
export("counter_stove")
