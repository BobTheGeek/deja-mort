"""Counter run — sink unit. 1.0 x 0.6 x 0.9 m (0.945 with the tap).

Ceramic carcass, dark worktop built as four strips around a real recessed
basin, short steel tap. Front toward -Y in Blender (+Z in Godot).
Height stays under 0.95 m: the scale catalogue bounds `sink` at 0.75–0.95
(the Kenney piece measured 0.98 and failed it).
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, cyl, export, join, material, reset

reset()
ceramic = material("ceramic", (0.60, 0.61, 0.60))
worktop = material("worktop", (0.30, 0.31, 0.33), roughness=0.6)
steel = material("steel", (0.62, 0.63, 0.64), metallic=0.4, roughness=0.5)

# Worktop strips around an opening x -0.31..0.21, y -0.15..0.25.
parts = [
    box("carcass", (1.0, 0.6, 0.85), (0.0, 0.0, 0.425), ceramic),
    box("worktop_back", (1.0, 0.05, 0.05), (0.0, 0.275, 0.875), worktop),
    box("worktop_front", (1.0, 0.15, 0.05), (0.0, -0.225, 0.875), worktop),
    box("worktop_left", (0.19, 0.40, 0.05), (-0.405, 0.05, 0.875), worktop),
    box("worktop_right", (0.29, 0.40, 0.05), (0.355, 0.05, 0.875), worktop),
    # The basin: a floor and four walls, visible through the opening.
    box("basin_floor", (0.52, 0.40, 0.015), (-0.05, 0.05, 0.7925), steel),
    box("basin_front", (0.52, 0.02, 0.10), (-0.05, -0.15, 0.85), steel),
    box("basin_back", (0.52, 0.02, 0.10), (-0.05, 0.25, 0.85), steel),
    box("basin_left", (0.02, 0.40, 0.10), (-0.31, 0.05, 0.85), steel),
    box("basin_right", (0.02, 0.40, 0.10), (0.21, 0.05, 0.85), steel),
    # The tap: short and low so the cabinet stays under 0.95 m overall.
    cyl("tap_stem", 0.018, 0.045, (0.05, 0.27, 0.9225), steel),
    cyl("tap_spout", 0.013, 0.10, (0.05, 0.21, 0.93), steel,
        rotation=(math.radians(90.0), 0.0, 0.0)),
]

join(parts, "counter_sink")
export("counter_sink")
