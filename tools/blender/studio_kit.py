"""Shared helpers for the First Light studio set.

Every studio piece is built from flat-shaded primitives: metres, one node,
origin at the footprint centre, base at z = 0, front toward -Y in Blender —
which is +Z in Godot after the glTF Y-up conversion, so the room can keep
`mesh_yaw: 0`.

Each model script runs standalone:

    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/<model>.py
"""

from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name: str, rgb, metallic: float = 0.0, roughness: float = 1.0):
    """A flat material; `rgb` values are the family's display values.

    Godot's glTF import re-encodes baseColorFactor when building the
    StandardMaterial3D, so a Blender input of 0.09 arrives as ~0.33. Feeding
    the linear equivalent makes the imported albedo land on the same raw
    value the `models.recolor` family entries use (verified: carbon 0.09).
    """
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (
        _srgb_to_linear(rgb[0]), _srgb_to_linear(rgb[1]), _srgb_to_linear(rgb[2]), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def box(name: str, size, location, mat):
    """A cuboid of full extents `size` metres, centred on `location`."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def cyl(name: str, radius: float, depth: float, location, mat, vertices: int = 12,
        rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def join(parts, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    # Bake every part's transform: origin at the world origin, base at z = 0,
    # the convention docs/06 asks for and `bubble_token.py` already follows.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_flat()
    return obj


def export(name: str) -> None:
    out = ROOT / "assets" / "models" / "studio" / f"{name}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB")
    print(f"{name}: wrote {out}")
