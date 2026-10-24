"""Original disposable mesh/rig fixture; executed by Blender, never a downloaded kit."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / "artifacts/assets"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# A small skinned mesh with UVs and a generated texture exercises the asset tools.
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
mesh = bpy.context.object
mesh.name = "PipelineProbe"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.uv.smart_project()
bpy.ops.object.mode_set(mode="OBJECT")
image = bpy.data.images.new("ProbeTexture", width=32, height=32)
pixels = []
for y in range(32):
    for x in range(32):
        pixels.extend((0.12, 0.65, 0.85, 1) if (x // 8 + y // 8) % 2 else (0.8, 0.35, 0.12, 1))
image.pixels = pixels
image.filepath_raw = str(OUT / "texture.png")
image.file_format = "PNG"
image.save()
image.pack()
material = bpy.data.materials.new("ProbeMaterial")
material.use_nodes = True
texture = material.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = image
shader = material.node_tree.nodes.get("Principled BSDF")
material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
shader.inputs["Roughness"].default_value = 0.55
mesh.data.materials.append(material)

bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = "ProbeRig"
bpy.ops.object.mode_set(mode="EDIT")
root = rig.data.edit_bones[0]
root.name = "Root"
root.head = (0, 0, 0)
root.tail = (0, 0, 1)
tip = rig.data.edit_bones.new("Tip")
tip.head = (0, 0, 1)
tip.tail = (0, 0, 2)
tip.parent = root
tip.use_connect = True
bpy.ops.object.mode_set(mode="OBJECT")
for name, upper in (("Root", False), ("Tip", True)):
    group = mesh.vertex_groups.new(name=name)
    indices = [v.index for v in mesh.data.vertices if (v.co.z > 1) == upper]
    group.add(indices, 1.0, "REPLACE")
modifier = mesh.modifiers.new("Skin", "ARMATURE")
modifier.object = rig
mesh.parent = rig
pose = rig.pose.bones["Tip"]
pose.rotation_mode = "XYZ"
for frame, angle in ((1, 0), (12, math.radians(25)), (24, 0)):
    pose.rotation_euler.y = angle
    pose.keyframe_insert(data_path="rotation_euler", frame=frame)
rig.animation_data.action.name = "ProbeBend"
scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, 24
scene.frame_set(12)
scene.render.fps = 24
mesh.data.calc_loop_triangles()
assert len(mesh.data.loop_triangles) == 12
assert len(mesh.data.uv_layers) == 1
assert len(rig.data.bones) == 2
assert len(rig.animation_data.action.fcurves) > 0

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=str(OUT / "probe.fbx"), use_selection=True,
    object_types={"MESH", "ARMATURE"}, add_leaf_bones=False,
    bake_anim=True, bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False,
    path_mode="COPY", embed_textures=True,
)

bpy.ops.object.camera_add(location=(5, -7, 4))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1)) - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera
for location, energy, size in (((2, -4, 6), 800, 5), ((-3, 1, 4), 500, 4)):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 8
scene.cycles.use_denoising = False
scene.render.resolution_x = 384
scene.render.resolution_y = 384
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / "preview.png")
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "probe.blend"))
bpy.ops.render.render(write_still=True)

# Reimport to verify exported geometry, skeleton, weights and animation survive.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(OUT / "probe.fbx"))
meshes = [obj for obj in scene.objects if obj.type == "MESH"]
rigs = [obj for obj in scene.objects if obj.type == "ARMATURE"]
assert len(meshes) == 1 and len(rigs) == 1
assert len(meshes[0].data.vertices) == 8
assert len(meshes[0].data.uv_layers) > 0
assert len(meshes[0].vertex_groups) == 2
assert len(rigs[0].data.bones) == 2
assert rigs[0].animation_data and rigs[0].animation_data.action
for filename in ("probe.blend", "probe.fbx", "texture.png", "preview.png"):
    assert (OUT / filename).stat().st_size > 100
(OUT / "report.json").write_text(json.dumps({
    "blender": bpy.app.version_string, "triangles": 12, "bones": 2,
    "uv_layers": 1, "animation_frames": 24, "fbx_round_trip": "passed",
    "roblox_import": "not tested", "purpose": "toolchain fixture, not a game asset",
}, indent=2) + "\n")
print("PASS: Blender authoring, animation, CPU render and FBX round trip")
