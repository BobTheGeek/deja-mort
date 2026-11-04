"""Counter run — sink unit. 1.0 x 0.6 x 0.9 m (1.06 m with the faucet).

v2, after Bob's note that the pour did not read: the sink used to be all
pale ceramic, and under the cool ambient its whole face read blue — water
over it had nothing to contrast against, so "the entire cabinet" looked
like water. Now it speaks the run's language: a walnut door up front like
the drawer and block units, the shared dark worktop, a pale raised rim
ringing the basin (the edge the fill and the overflow leave from), and a
proper tall faucet so the running jet is visible above the rim from the
fixed camera.

Authored in the kit convention (front +Z / Blender -Y, origin at footprint
centre, base at z = 0). The scale catalogue bounds `sink` at 0.75-1.15 m.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, cyl, export, join, material, reset

reset()
ceramic = material("ceramic", (0.60, 0.61, 0.60))
worktop = material("worktop", (0.30, 0.31, 0.33), roughness=0.6)
walnut = material("walnut", (0.45, 0.34, 0.22))
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
    # The pale rim: a raised lip around the opening — the edge the overflow
    # leaves from, and a highlight that separates the sink from its run.
    box("rim_back", (0.62, 0.05, 0.02), (-0.05, 0.275, 0.91), ceramic),
    box("rim_front", (0.62, 0.05, 0.02), (-0.05, -0.175, 0.91), ceramic),
    box("rim_left", (0.05, 0.40, 0.02), (-0.335, 0.05, 0.91), ceramic),
    box("rim_right", (0.05, 0.40, 0.02), (0.235, 0.05, 0.91), ceramic),
    # The door: walnut up front like the drawer and block units, framed by
    # the ceramic carcass above and below.
    box("door", (0.86, 0.02, 0.5), (0.0, -0.305, 0.46), walnut),
    box("door_handle", (0.16, 0.02, 0.02), (0.0, -0.325, 0.68), steel),
    # The faucet, tall enough that its jet clears the rim on camera.
    cyl("tap_stem", 0.02, 0.16, (0.05, 0.27, 0.98), steel),
    cyl("tap_spout", 0.016, 0.16, (0.05, 0.20, 1.04), steel,
        rotation=(math.radians(90.0), 0.0, 0.0)),
    cyl("tap_nub", 0.016, 0.03, (0.05, 0.13, 1.025), steel),
]

join(parts, "counter_sink")
export("counter_sink")
