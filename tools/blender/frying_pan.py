"""Frying pan. 0.42 m across, 0.53 m floor span with the handle.

Carbon body and a short handle; the existing carbon read from
`models.recolor` becomes the model's own material.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio_kit import box, cyl, export, join, material, reset

reset()
carbon = material("carbon", (0.09, 0.09, 0.10))

parts = [
    cyl("body", 0.21, 0.045, (0.0, 0.0, 0.0225), carbon, vertices=16),
    box("handle", (0.03, 0.12, 0.02), (0.0, -0.26, 0.02), carbon),
]

join(parts, "frying_pan")
export("frying_pan")
