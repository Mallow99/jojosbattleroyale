"""Re-imports StarPlatinumMorph.fbx in Blender and checks what Studio's importer will receive.

Run: .tools/blender/blender-4.3.2-linux-x64/blender -b --factory-startup --python-exit-code 1 \
         --python tests/stand/fbx_check.py
This is a file round trip, not a Roblox import.
"""
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art/star_platinum"
report = json.loads((ART / "morph_report.json").read_text())

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ART / "StarPlatinumMorph.fbx"), axis_forward="-Z", axis_up="Y")
objects = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
expected = {p["name"] for p in report["pieces"]}
assert set(objects) == expected, f"object names changed: {sorted(set(objects) ^ expected)}"


def roblox_position(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    center = sum(corners, Vector()) / 8
    return Vector((center.x, center.z, -center.y))


for name, target in (("O", (0, 0, 0)), ("X", (4, 0, 0)), ("Y", (0, 4, 0)), ("Z", (0, 0, 4))):
    position = roblox_position(objects[f"Marker__{name}__marker"])
    assert (position - Vector(target)).length < 1e-3, f"marker {name} at {position}, expected {target}"

triangles = 0
for name, obj in objects.items():
    mesh = obj.data
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    triangles += count
    assert count <= 20000, f"{name} has {count} triangles"
    textured = name.endswith("__tex") or name.endswith("__facetex")
    if textured:
        assert mesh.uv_layers, f"{name} lost its UVs"
        images = [n.image for m in mesh.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
        assert images and all(img.packed_file or Path(bpy.path.abspath(img.filepath)).exists() for img in images), (
            f"{name} texture missing")
        for img in images:
            assert max(img.size) <= 1024, f"{img.name} is larger than 1024 px"

head = roblox_position(objects["Head__Face__facetex"])
assert (head - Vector((0, 4.5, 0))).length < 0.05, f"head shell centred at {head}"
print(f"PASS: FBX round trip — {len(objects)} meshes, {triangles} triangles, markers at authored studs, "
      "textures embedded with UVs (Blender re-import, not a Roblox import)")
