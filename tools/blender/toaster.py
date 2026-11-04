"""Toaster. 0.29 x 0.19 x 0.19 m.

Silver body, dark slot panel on top, a small lever on the front face.
Two flat materials so the body keeps its shape at phone size.
Front toward -Y in Blender (+Z in Godot).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, export, join, material, reset

reset()
silver = material("silver", (0.72, 0.73, 0.75), metallic=0.4, roughness=0.5)
carbon = material("carbon", (0.12, 0.12, 0.13))

parts = [
    box("body", (0.29, 0.19, 0.17), (0.0, 0.0, 0.085), silver),
    box("slot_panel", (0.20, 0.10, 0.015), (0.0, 0.0, 0.1775), carbon),
    box("lever", (0.025, 0.015, 0.05), (-0.11, -0.10, 0.09), carbon),
]

join(parts, "toaster")
export("toaster")
