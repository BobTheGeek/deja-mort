"""Bubble token — First Light, Direction A.

The collectible: a small glass bubble with a short neck, 0.16 m tall and
0.13 m wide, one flat material, origin at footprint centre, base at z = 0,
front +Z. The in-game collectible look repaints it amber at emission 1.4, so
the shape is the deliverable.

Run (background instance; safe next to an open GUI):

    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/bubble_token.py

Writes assets/models/studio/bubble_token.glb relative to the repo root.
"""

from pathlib import Path

import bpy

OUT = Path(__file__).resolve().parents[2] / "assets" / "models" / "studio" / "bubble_token.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)

# Body: a low-poly sphere, flattened a touch. Radius 0.065 m top and bottom.
bpy.ops.mesh.primitive_uv_sphere_add(
    segments=12, ring_count=8, radius=0.065, location=(0.0, 0.0, 0.06175))
body = bpy.context.active_object
body.scale = (1.0, 1.0, 0.95)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# Neck: a short cylinder that meets the sphere's crown and tops out at 0.16 m.
bpy.ops.mesh.primitive_cylinder_add(
    vertices=10, radius=0.022, depth=0.04, location=(0.0, 0.0, 0.14))
neck = bpy.context.active_object

bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
neck.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
token = bpy.context.active_object
token.name = "bubble_token"

# One flat material: warm glass, fully rough so nothing reads as plastic.
material = bpy.data.materials.new("bubble")
principled = material.node_tree.nodes.get("Principled BSDF")
principled.inputs["Base Color"].default_value = (0.72, 0.62, 0.50, 1.0)
principled.inputs["Roughness"].default_value = 1.0
principled.inputs["Metallic"].default_value = 0.0
token.data.materials.append(material)

# Origin at the footprint centre with the base at z = 0, flat-shaded faces.
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.shade_flat()

OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB")
print(f"bubble_token: wrote {OUT}")
