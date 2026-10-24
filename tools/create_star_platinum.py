"""REJECTED VISUAL DIRECTION. Historical generator; do not use for game assets.

The user rejected the rounded proportions and art quality on October 24, 2026.
Retained for history only. See docs/ART_DIRECTION.md before any replacement work.

Run: blender -b --factory-startup --threads 2 --python-exit-code 1 --python tools/create_star_platinum.py
No external models, textures or executable kits are used.
"""
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/star-platinum"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "NONE"
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 48


def material(name, color, metal=0.0, rough=0.45):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    return mat


M = {
    "skin": material("Amethyst skin", (0.27, 0.105, 0.52)),
    "light": material("Raised muscle planes", (0.39, 0.18, 0.65)),
    "dark": material("Recessed violet", (0.14, 0.045, 0.25)),
    "hair": material("Midnight plum hair", (0.035, 0.018, 0.075)),
    "hairlight": material("Hair ridge highlights", (0.075, 0.035, 0.14)),
    "gold": material("Brushed gold", (0.8, 0.47, 0.10), 0.65, 0.32),
    "goldlight": material("Gold edges", (1.0, 0.74, 0.24), 0.55, 0.28),
    "green": material("Emerald armor", (0.025, 0.26, 0.15), 0.25, 0.3),
    "gem": material("Emerald inset", (0.05, 0.7, 0.38), 0.45, 0.2),
    "cloth": material("Ivory cloth", (0.83, 0.80, 0.7), 0, 0.8),
    "white": material("Eyes", (0.94, 0.96, 0.85), 0, 0.3),
    "black": material("Ink accents", (0.008, 0.006, 0.015), 0, 0.7),
}
parts = []


def finish(obj, name, mat, bone="UpperTorso", smooth=True):
    obj.name = name
    obj.data.materials.append(M[mat])
    if smooth:
        for face in obj.data.polygons:
            face.use_smooth = True
    # Bake transforms so every disconnected surface shares one consistent bind space.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    parts.append(obj)
    return obj


def oval(name, position, scale, mat, bone="UpperTorso", segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=position)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone)


def box(name, position, scale, mat, bone="UpperTorso", bevel=0.06, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Small machined edge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat, bone, smooth=False)


def spike(name, start, end, radius, mat, bone="Head", vertices=7):
    direction = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.015,
                                    depth=direction.length, location=(Vector(start) + Vector(end)) / 2)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, mat, bone)


def muscle(name, start, end, radius, mat, bone):
    direction = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                      location=(Vector(start) + Vector(end)) / 2)
    obj = bpy.context.object
    obj.scale = (radius, radius * 0.85, direction.length * 0.57)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, mat, bone)


def ring(name, position, major, minor, mat, bone="UpperTorso", rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=5,
                                    major_radius=major, minor_radius=minor,
                                    location=position, rotation=rotation)
    return finish(bpy.context.object, name, mat, bone)


def surface(name, vertices, faces, mat, bone):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    return finish(obj, name, mat, bone, False)


# Tapered torso shell: visible anatomy comes from broad planes and low-poly muscle forms.
levels = [(3.65, .53, .32), (4.0, .57, .34), (4.5, .67, .38),
          (5.0, .96, .43), (5.45, 1.02, .4), (5.65, .73, .30)]
vertices = []
for z, width, depth in levels:
    for i in range(12):
        angle = i * math.tau / 12
        vertices.append((math.cos(angle) * width, math.sin(angle) * depth, z))
faces = []
for level in range(len(levels) - 1):
    for i in range(12):
        a, b = level * 12 + i, level * 12 + (i + 1) % 12
        faces.append((a, b, b + 12, a + 12))
faces.extend([tuple(reversed(range(12))), tuple(range(60, 72))])
surface("Torso foundation", vertices, faces, "skin", "UpperTorso")

oval("Pelvic foundation", (0, 0, 3.65), (.68, .37, .38), "dark", "LowerTorso")
oval("Neck", (0, 0, 5.86), (.28, .27, .45), "skin", "Head")
for sign in (-1, 1):
    oval("Pectoral", (sign * .47, -.36, 5.2), (.52, .24, .32), "light")
    muscle("Trapezius", (sign * .18, .02, 5.75), (sign * 1.0, .02, 5.45), .25, "skin", "UpperTorso")
    oval("Latissimus", (sign * .63, .21, 4.92), (.33, .20, .6), "skin")
    for i, z in enumerate((4.8, 4.48, 4.18)):
        oval("Abdominal plane", (sign * .22, -.36 + i * .02, z), (.225, .13, .18), "light")
    muscle("Oblique", (sign * .55, -.17, 4.65), (sign * .47, -.16, 3.97), .18, "skin", "UpperTorso")

# Armor silhouette, loincloth and separated, visibly jointed limbs.
box("Waist belt", (0, -.005, 3.88), (1.3, .78, .19), "gold", "LowerTorso")
box("Belt front inset", (0, -.43, 3.88), (.37, .09, .26), "green", "LowerTorso")
oval("Belt centerpiece", (0, -.50, 3.89), (.105, .045, .105), "gem", "LowerTorso")
surface("Front ivory cloth", [(-.43,-.43,3.78),(.43,-.43,3.78),(.46,-.47,3.15),
        (.24,-.52,2.93),(0,-.56,3.01),(-.24,-.52,2.93),(-.46,-.47,3.15)],
        [(0,1,4),(1,2,3,4),(0,4,5,6)], "cloth", "LowerTorso")
surface("Back ivory cloth", [(-.43,.34,3.78),(.43,.34,3.78),(.48,.45,3.0),
        (0,.50,2.9),(-.48,.45,3.0)], [(0,3,1),(1,3,2),(0,4,3)], "cloth", "LowerTorso")

bones = {
    "Root": ((0,0,3.3),(0,0,3.65),None),
    "LowerTorso": ((0,0,3.65),(0,0,4.25),"Root"),
    "UpperTorso": ((0,0,4.25),(0,0,5.65),"LowerTorso"),
    "Head": ((0,0,5.65),(0,0,7.0),"UpperTorso"),
}
for sign, side in ((-1, "Right"), (1, "Left")):
    hip, knee, ankle = (sign*.49,0,3.55), (sign*.54,0,2.18), (sign*.56,0,.65)
    shoulder, elbow, wrist = (sign*1.13,0,5.42),(sign*1.62,-.015,4.55),(sign*1.86,-.06,3.78)
    bones[side+"UpperArm"] = (shoulder, elbow, "UpperTorso")
    bones[side+"LowerArm"] = (elbow, wrist, side+"UpperArm")
    bones[side+"Hand"] = (wrist, (sign*1.91,-.09,3.35), side+"LowerArm")
    bones[side+"UpperLeg"] = (hip, knee, "LowerTorso")
    bones[side+"LowerLeg"] = (knee, ankle, side+"UpperLeg")
    bones[side+"Foot"] = (ankle, (sign*.56,-.65,.34), side+"LowerLeg")
    ua, la, hand = side+"UpperArm", side+"LowerArm", side+"Hand"
    ul, ll, foot = side+"UpperLeg", side+"LowerLeg", side+"Foot"
    oval("Deltoid", shoulder, (.43,.38,.45), "skin", ua)
    muscle("Bicep", shoulder, elbow, .35, "light", ua)
    oval("Elbow", elbow, (.245,.24,.245), "dark", la)
    muscle("Forearm", elbow, wrist, .34, "skin", la)
    oval("Upper leg", (sign*.51,.01,2.95), (.43,.38,.68), "skin", ul)
    muscle("Front quadriceps", (sign*.5,-.20,3.38), (sign*.54,-.20,2.3), .26, "light", ul)
    oval("Knee joint", knee, (.28,.28,.28), "dark", ll)
    muscle("Shin", knee, ankle, .30, "skin", ll)
    oval("Calf", (sign*.56,.15,1.56), (.27,.25,.46), "light", ll)
    box("Knee gold rim", (sign*.54,-.27,2.18), (.49,.17,.46), "gold", ll)
    box("Emerald knee face", (sign*.54,-.37,2.18), (.35,.09,.31), "green", ll)
    box("Boot", (sign*.56,-.21,.42), (.65,.98,.54), "dark", foot, .12)
    box("Boot gold toe", (sign*.56,-.68,.40), (.65,.13,.25), "gold", foot)
    ring("Boot cuff", (sign*.56,0,.72), .28,.075,"gold", ll)
    oval("Palm glove", (sign*1.9,-.09,3.52), (.30,.25,.32), "green", hand)
    for finger in range(4):
        x = sign * (1.68 + finger * .14)
        box("Curled finger", (x,-.30,3.5), (.125,.19,.27), "skin", hand, .04)
        box("Gold knuckle", (x,-.42,3.62), (.12,.07,.10), "goldlight", hand, .025)
    oval("Thumb", (sign*1.63,-.26,3.47), (.12,.15,.21), "skin", hand)
    # Green guard laid on the front of the forearm with small raised studs.
    box("Forearm gold guard", (sign*1.79,-.32,4.02), (.52,.19,.55), "gold", la, .06,
        rotation=(0,sign*-.23,0))
    box("Forearm green guard", (sign*1.79,-.43,4.02), (.40,.09,.40), "green", la, .045,
        rotation=(0,sign*-.23,0))
    for dx in (-.12,.12):
        oval("Guard rivet", (sign*1.79+dx,-.49,4.02), (.038,.025,.038), "goldlight", la, 8, 4)
    oval("Gold shoulder armor", (sign*1.15,-.01,5.62), (.58,.45,.28), "gold", ua)
    oval("Shoulder face", (sign*1.18,-.35,5.62), (.41,.10,.19), "goldlight", ua)
    ring("Shoulder medallion", (sign*1.19,-.44,5.63), .13,.025,"green",ua,
         rotation=(math.pi/2,0,0))

# Pale neck scarf with a small rear tail.
ring("Scarf lower fold", (0,0,5.73), .39,.12,"cloth")
ring("Scarf upper fold", (0,0,5.89), .36,.11,"cloth")
surface("Scarf tail", [(-.23,.31,5.88),(.15,.38,5.84),(.55,.75,5.35),
        (.24,.69,5.10),(-.05,.57,5.48)], [(0,1,4),(1,2,3,4)], "cloth", "UpperTorso")

# Sculpted stylized face: cheek planes, brows, eyes, nose, jaw and lip.
oval("Head core", (0,-.015,6.58), (.43,.34,.59), "skin", "Head", 16,10)
box("Jaw", (0,-.12,6.28), (.61,.47,.33), "skin", "Head", .11)
for sign in (-1,1):
    oval("Ear", (sign*.445,.0,6.54), (.095,.10,.18), "skin", "Head")
    oval("Cheek plane", (sign*.245,-.283,6.47), (.16,.115,.22), "light", "Head")
    box("Eye shadow", (sign*.18,-.333,6.66), (.30,.08,.135), "dark", "Head", .02)
    box("Eye white", (sign*.18,-.38,6.665), (.235,.035,.069), "white", "Head", .01)
    box("Emerald iris", (sign*.16,-.403,6.665), (.055,.024,.069), "gem", "Head", .006)
    box("Pupil", (sign*.16,-.418,6.665), (.022,.012,.057), "black", "Head", .004)
    box("Angular brow", (sign*.18,-.39,6.75), (.31,.075,.067), "hair", "Head", .015,
        rotation=(0,sign*-.18,0))
surface("Nose bridge", [(-.07,-.34,6.75),(.07,-.34,6.75),(-.08,-.46,6.42),
        (.08,-.46,6.42),(0,-.53,6.48)], [(0,2,4),(0,4,1),(1,4,3),(2,3,4)], "light", "Head")
box("Mouth line", (0,-.374,6.31), (.23,.025,.028), "dark", "Head", .006)
oval("Lower lip", (0,-.356,6.265), (.13,.035,.035), "light", "Head")

# Thick flowing, pointed hair locks and the characteristic gold/emerald headband.
oval("Hair cap", (0,.045,6.99), (.49,.38,.36), "hair", "Head")
for i in range(13):
    angle = math.pi * (i / 12)
    x = .47 * math.cos(angle)
    y = .10 + .28 * math.sin(angle)
    spike("Swept back hair", (x,y,7.03), (x*1.45,y+.30,7.60+.20*math.sin(i*1.9)),
          .19,"hairlight" if i%3==0 else "hair")
for sign in (-1,1):
    for i in range(5):
        spike("Flowing side lock", (sign*(.34+.035*i),.19,7.02-.08*i),
              (sign*(.60+.06*i),.40+.06*i,6.35-.16*i), .17,
              "hairlight" if i%2==0 else "hair")
    spike("Temple lock", (sign*.39,-.05,7.02), (sign*.47,-.08,6.48), .13,"hair")
box("Gold forehead band", (0,-.341,6.96), (.88,.11,.16), "gold", "Head", .025)
for sign in (-1,1):
    box("Headband side", (sign*.41,-.16,6.96), (.12,.41,.16), "gold", "Head", .02)
oval("Headband emerald setting", (0,-.427,6.96), (.16,.055,.17), "dark", "Head",12,6)
oval("Headband emerald", (0,-.479,6.96), (.11,.035,.125), "gem", "Head",10,5)

# One skinned mesh and a 16-bone humanoid prototype rig, with no Roblox scripts.
bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
character = bpy.context.object
character.name = "StarPlatinum_Prototype"
# Consolidate repeated material slots before export.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(island_margin=.015)
bpy.ops.object.mode_set(mode="OBJECT")
character.data.calc_loop_triangles()
triangle_count = len(character.data.loop_triangles)
assert triangle_count < 20000, f"Prototype triangle budget exceeded: {triangle_count}"

armature = bpy.data.armatures.new("StandSkeleton")
rig = bpy.data.objects.new("StarPlatinum_Rig", armature)
scene.collection.objects.link(rig)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name,(head,tail,parent) in bones.items():
    bone = armature.edit_bones.new(name)
    bone.head,bone.tail = head,tail
    if parent:
        bone.parent = armature.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
rig.show_in_front = True
modifier = character.modifiers.new("Stand skinning", "ARMATURE")
modifier.object = rig
character.parent = rig
for vertex in character.data.vertices:
    assert vertex.groups and abs(sum(g.weight for g in vertex.groups)-1) < 1e-5

# A subtle breathing loop demonstrates that the exported rig carries keyframes.
for name, amplitude in (("UpperTorso", .014), ("Head", -.008),
                        ("RightUpperArm", .018), ("LeftUpperArm", -.018)):
    pose = rig.pose.bones[name]
    pose.rotation_mode = "XYZ"
    for frame,multiplier in ((1,0),(24,1),(48,0)):
        pose.rotation_euler.y = amplitude * multiplier
        pose.keyframe_insert(data_path="rotation_euler", frame=frame)
rig.animation_data.action.name = "Prototype_Idle_2s"
scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
character.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(filepath=str(OUT/"star-platinum.fbx"), use_selection=True,
    object_types={"MESH","ARMATURE"}, add_leaf_bones=False, mesh_smooth_type="FACE",
    bake_anim=True, bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False,
    path_mode="COPY", embed_textures=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/"star-platinum.glb"), export_format="GLB",
    use_selection=True, export_animations=True)

# Studio lighting and a clean plinth provide honest renders of the actual mesh.
floor_mat = material("Stage charcoal", (.018,.022,.034), .2,.65)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,.015))
floor = bpy.context.object
floor.name = "RenderStage_NOT_FOR_EXPORT"
floor.data.materials.append(floor_mat)
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=2.65, depth=.16, location=(0,0,-.03))
plinth = bpy.context.object
plinth.name = "RenderPlinth_NOT_FOR_EXPORT"
plinth.data.materials.append(material("Plinth", (.04,.045,.07), .3,.4))

def point_at(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


for name,location,energy,color,size in [
    ("Key", (4,-7,10),1700,(.82,.86,1),6),
    ("Fill", (-5,-3,6),1000,(.57,.75,1),5),
    ("Rim", (3,4,9),2200,(.75,.45,1),4),
    ("Warm edge", (-4,3,5),1200,(1,.64,.28),4),
]:
    bpy.ops.object.light_add(type="AREA",location=location)
    light=bpy.context.object
    light.name=name
    light.data.energy,light.data.color,light.data.size=energy,color,size
    point_at(light,(0,0,4))
bpy.ops.object.camera_add()
camera=bpy.context.object
camera.name="ReviewCamera"
scene.camera=camera
camera.data.type="ORTHO"
camera.data.ortho_scale=9.3
scene.world.color=(.055,.055,.065)
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=24
scene.cycles.use_denoising=False
scene.render.resolution_x=960
scene.render.resolution_y=1080
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.view_settings.view_transform="AgX"
camera.location=(10,-18,10)
point_at(camera,(0,0,3.85))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"star-platinum.blend"))
for name,location in [("hero",(10,-18,10)),("front",(0,-20,6.7)),
                      ("side",(20,0,6.7)),("back",(0,20,6.7))]:
    camera.location=location
    point_at(camera,(0,0,3.85))
    scene.render.filepath=str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)

report={"name":"Star Platinum original stylized prototype", "source":"tools/create_star_platinum.py",
    "external_geometry":False,"external_textures":False,"triangles":triangle_count,
    "vertices":len(character.data.vertices),"bones":len(bones),"materials":len(M),
    "uv_layers":len(character.data.uv_layers),"weights":"all vertices assigned, normalized",
    "animation":"Prototype_Idle_2s; 48 frames at 24 fps",
    "roblox_import":"not tested","status":"REJECTED visual direction; historical only"}

# Validate the delivered FBX itself rather than just the pre-export scene.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(OUT/"star-platinum.fbx"))
imported_meshes=[obj for obj in scene.objects if obj.type=="MESH"]
imported_rigs=[obj for obj in scene.objects if obj.type=="ARMATURE"]
assert len(imported_meshes)==1 and len(imported_rigs)==1
imported=imported_meshes[0]
imported.data.calc_loop_triangles()
assert len(imported.data.loop_triangles)==triangle_count
assert len(imported.data.uv_layers)>0
assert len(imported_rigs[0].data.bones)==len(bones)
assert imported_rigs[0].animation_data and imported_rigs[0].animation_data.action
assert all(v.groups and abs(sum(g.weight for g in v.groups)-1)<1e-4 for v in imported.data.vertices)
report["fbx_round_trip"]="passed: geometry, UV, skeleton, animation and normalized weights"
glb=(OUT/"star-platinum.glb").read_bytes()
magic,version,size=struct.unpack_from("<4sII",glb)
assert magic==b"glTF" and version==2 and size==len(glb)
chunk_length,chunk_kind=struct.unpack_from("<I4s",glb,12)
assert chunk_kind==b"JSON"
gltf=json.loads(glb[20:20+chunk_length])
assert len(gltf["skins"])==1 and len(gltf["skins"][0]["joints"])==len(bones)
assert gltf.get("animations")
for primitive in gltf["meshes"][0]["primitives"]:
    assert "JOINTS_0" in primitive["attributes"] and "WEIGHTS_0" in primitive["attributes"]
report["glb_validation"]="passed: container, skeleton, skin attributes and animation"
(OUT/"report.json").write_text(json.dumps(report,indent=2)+"\n")
print("PASS:",json.dumps(report))
