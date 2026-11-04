"""Counter run — drawer unit. 1.0 x 0.6 x 0.9 m.

Walnut drawer fronts with steel handles over a ceramic carcass, dark worktop.
Front toward -Y in Blender (+Z in Godot).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, export, join, material, reset

reset()
ceramic = material("ceramic", (0.60, 0.61, 0.60))
worktop = material("worktop", (0.30, 0.31, 0.33), roughness=0.6)
walnut = material("walnut", (0.45, 0.34, 0.22))
steel = material("steel", (0.62, 0.63, 0.64), metallic=0.4, roughness=0.5)

parts = [
    box("carcass", (1.0, 0.6, 0.85), (0.0, 0.0, 0.425), ceramic),
    box("worktop", (1.0, 0.6, 0.05), (0.0, 0.0, 0.875), worktop),
    box("front_low", (0.86, 0.02, 0.26), (0.0, -0.305, 0.28), walnut),
    box("handle_low", (0.16, 0.02, 0.02), (0.0, -0.325, 0.28), steel),
    box("front_high", (0.86, 0.02, 0.26), (0.0, -0.305, 0.60), walnut),
    box("handle_high", (0.16, 0.02, 0.02), (0.0, -0.325, 0.60), steel),
]

join(parts, "counter_drawer")
export("counter_drawer")
