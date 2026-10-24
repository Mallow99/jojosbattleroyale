"""Star Platinum morph meshes for a standard Roblox R6 rig (original geometry for this project).

Run from the repository root:
  .tools/blender/blender-4.3.2-linux-x64/blender -b --factory-startup --python-exit-code 1 \
      --python art/star_platinum/build_morph.py

Everything is modelled in Roblox R6 rest space (studs, ground at y=0, facing -Z) and
converted to Blender axes. Object names are "<Bone>__<Piece>__<colour>"; the in-game
installer (StandMorph) welds each MeshPart to its bone. Four Marker objects give the
installer the import frame, so the result is independent of importer axis/scale settings.

Outputs (art/star_platinum/):
  StarPlatinumMorph.fbx   -> import with Roblox Studio's 3D Importer
  StarPlatinumMorph.blend -> editable source
  morph_report.json       -> per-piece triangle counts and bounds
and artifacts/preview/StarPlatinumMorph.glb for the browser preview.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from atlas import REGIONS  # noqa: E402

PALETTE = {
    "hair": (40, 32, 84),
    "hairLight": (62, 50, 120),
    "gold": (232, 182, 64),
    "goldDark": (168, 116, 36),
    "scarf": (204, 36, 50),
    "scarfDark": (150, 22, 38),
    "cloth": (40, 36, 88),
    "gem": (220, 30, 60),
    "marker": (255, 0, 255),
}
BONE_CENTERS = {
    "Head": (0, 4.5, 0), "Torso": (0, 3, 0),
    "LeftArm": (-1.5, 3, 0), "RightArm": (1.5, 3, 0),
    "LeftLeg": (-0.5, 1, 0), "RightLeg": (0.5, 1, 0),
}


def B(v):
    """Roblox (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def srgb_to_linear(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MATERIALS = {}


def material(key):
    if key in MATERIALS:
        return MATERIALS[key]
    mat = bpy.data.materials.new("SP_" + key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    if key in ("body", "face"):
        image = bpy.data.images.load(str(HERE / ("SP_Body.png" if key == "body" else "SP_Face.png")))
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.7
    else:
        r, g, b = PALETTE[key]
        bsdf.inputs["Base Color"].default_value = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1)
        bsdf.inputs["Roughness"].default_value = 0.35 if key.startswith("gold") else 0.6
        bsdf.inputs["Metallic"].default_value = 0.5 if key.startswith("gold") else 0.0
    MATERIALS[key] = mat
    return mat


def finish(bm, bone, piece, color, smooth=True, bevel=0.0, sharp_angle=40):
    name = f"{bone}__{piece}__{color}"
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material("body" if color == "tex" else "face" if color == "facetex" else color))
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.harden_normals = False
    if smooth:
        mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=math.radians(sharp_angle))
    return obj


# ---------------------------------------------------------------------------------------
# Primitive builders (all inputs in Roblox space)

def add_box(bm, center, size, rotation=None):
    c = Vector(center)
    h = Vector(size) / 2
    rot = rotation or Matrix.Identity(3)
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                local = Vector((sx * h.x, sy * h.y, sz * h.z))
                corners.append(bm.verts.new(B(c + rot @ local)))
    idx = lambda sx, sy, sz: corners[((sx > 0) << 2) | ((sy > 0) << 1) | (sz > 0)]
    faces = [
        [idx(-1, -1, -1), idx(-1, 1, -1), idx(1, 1, -1), idx(1, -1, -1)],
        [idx(-1, -1, 1), idx(1, -1, 1), idx(1, 1, 1), idx(-1, 1, 1)],
        [idx(-1, -1, -1), idx(-1, -1, 1), idx(-1, 1, 1), idx(-1, 1, -1)],
        [idx(1, -1, -1), idx(1, 1, -1), idx(1, 1, 1), idx(1, -1, 1)],
        [idx(-1, 1, -1), idx(-1, 1, 1), idx(1, 1, 1), idx(1, 1, -1)],
        [idx(-1, -1, -1), idx(1, -1, -1), idx(1, -1, 1), idx(-1, -1, 1)],
    ]
    made = []
    for f in faces:
        try:
            made.append(bm.faces.new(f))
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=made)
    return made


def ring_profile(points, radius_x, radius_z, height, y, center=(0, 0, 0), thickness=0.06, segments=40, squareness=0.0):
    """Closed band around a vertical axis; superellipse when squareness > 0."""
    bm = bmesh.new()
    rings = []
    for layer, (ry, r_off) in enumerate([(y - height / 2, 0), (y + height / 2, 0), (y + height / 2, thickness), (y - height / 2, thickness)]):
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ca, sa = math.cos(a), math.sin(a)
            if squareness > 0:
                e = 2 / (2 + squareness * 6)
                ca = math.copysign(abs(ca) ** e, ca)
                sa = math.copysign(abs(sa) ** e, sa)
            x = center[0] + (radius_x + r_off) * ca
            z = center[2] + (radius_z + r_off) * sa
            ring.append(bm.verts.new(B((x, ry, z))))
        rings.append(ring)
    for k in range(4):
        a_ring, b_ring = rings[k], rings[(k + 1) % 4]
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new([a_ring[i], a_ring[j], b_ring[j], b_ring[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def strand(bm, path, width0, thickness0, side_hint=(1, 0, 0), sides=6, tip_width=0.0):
    """Tapered, flattened lock along `path` (Roblox space) ending in a point."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    rings = []
    hint = Vector(side_hint).normalized()
    for i, p in enumerate(pts):
        t = i / (n - 1)
        tangent = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = (hint - tangent * hint.dot(tangent))
        if side.length < 1e-4:
            side = Vector((0, 1, 0)) - tangent * tangent.y
        side.normalize()
        normal = tangent.cross(side).normalized()
        # Width swells slightly after the root, then tapers to the tip.
        w = (width0 * (1 - t) ** 0.85 + tip_width * t) * (1 + 0.25 * math.sin(math.pi * min(1, t * 2.2)))
        th = thickness0 * (1 - t) ** 0.7
        if i == n - 1:
            rings.append([bm.verts.new(B(p))])
            continue
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            offset = side * math.cos(a) * w + normal * math.sin(a) * th
            ring.append(bm.verts.new(B(p + offset)))
        rings.append(ring)
    for i in range(n - 2):
        a_ring, b_ring = rings[i], rings[i + 1]
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new([a_ring[k], a_ring[j], b_ring[j], b_ring[k]])
    tip = rings[-1][0]
    last = rings[-2]
    for k in range(sides):
        bm.faces.new([last[k], last[(k + 1) % sides], tip])
    bm.faces.new(list(reversed(rings[0])))


def curve(p0, p1, p2, steps=7):
    """Quadratic Bezier sample points."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    return [tuple((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2) for t in (i / (steps - 1) for i in range(steps))]


def ellipsoid(bm, center, radii, segments=24, rings=14, keep=None):
    c = Vector(center)
    grid = []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        row = []
        for s in range(segments):
            theta = 2 * math.pi * s / segments
            local = Vector((math.sin(phi) * math.cos(theta) * radii[0], math.cos(phi) * radii[1], math.sin(phi) * math.sin(theta) * radii[2]))
            row.append(local)
        grid.append(row)
    verts = {}
    for r in range(rings):
        for s in range(segments):
            quad = [(r, s), (r, (s + 1) % segments), (r + 1, (s + 1) % segments), (r + 1, s)]
            locals_ = [grid[a][b] for a, b in quad]
            if keep and not all(keep(v) for v in locals_):
                continue
            vs = []
            for (a, b), v in zip(quad, locals_):
                key = (a, b) if 0 < a < rings else (a, 0)
                if key not in verts:
                    verts[key] = bm.verts.new(B(c + v))
                vs.append(verts[key])
            unique = []
            for v in vs:
                if v not in unique:
                    unique.append(v)
            if len(unique) >= 3:
                try:
                    bm.faces.new(unique)
                except ValueError:
                    pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def disc(bm, center, radius, depth, axis="z", segments=32):
    """Short cylinder; axis 'z' faces forward, 'x' faces sideways."""
    c = Vector(center)
    caps = []
    for d in (-depth / 2, depth / 2):
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            if axis == "z":
                local = Vector((math.cos(a) * radius, math.sin(a) * radius, d))
            else:
                local = Vector((d, math.sin(a) * radius, math.cos(a) * radius))
            ring.append(bm.verts.new(B(c + local)))
        caps.append(ring)
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([caps[0][i], caps[0][j], caps[1][j], caps[1][i]])
    bm.faces.new(caps[0])
    bm.faces.new(list(reversed(caps[1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def prism(bm, outline, z, depth):
    """Extrude a 2D outline [(x, y)] in the XY plane at Roblox z, `depth` thick."""
    front = [bm.verts.new(B((x, y, z - depth / 2))) for x, y in outline]
    back = [bm.verts.new(B((x, y, z + depth / 2))) for x, y in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], back[i], back[j], front[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


# ---------------------------------------------------------------------------------------
# Body shells: boxes slightly larger than the R6 parts with per-face atlas UVs.

FACE_FRAMES = {
    # normal: (right, up) as seen from outside, Roblox space
    "front": ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
    "back": ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    "+x": ((1, 0, 0), (0, 0, -1), (0, 1, 0)),
    "-x": ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    "top": ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
    "bottom": ((0, -1, 0), (-1, 0, 0), (0, 0, -1)),
}


def shell(bone, kind, size, outer):
    """`outer` maps "+x"/"-x" to atlas roles (outer/inner or right/left)."""
    center = Vector(BONE_CENTERS[bone])
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    h = Vector(size) / 2
    for face_key, (normal, right, up) in FACE_FRAMES.items():
        role = {"front": "front", "back": "back", "top": "top", "bottom": "bottom"}.get(face_key) or outer[face_key]
        rx, ry, rw, rh = REGIONS[f"{kind}.{role}"]
        n, r, u = Vector(normal), Vector(right), Vector(up)
        half_r = abs(h.dot(Vector(map(abs, r))))
        half_u = abs(h.dot(Vector(map(abs, u))))
        depth = abs(h.dot(Vector(map(abs, n))))
        corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        verts = [bm.verts.new(B(center + n * depth + r * cr * half_r + u * cu * half_u)) for cr, cu in corners]
        face = bm.faces.new(verts)
        for loop, (cr, cu) in zip(face.loops, corners):
            # Inset by 3 px so bevels and filtering never sample a neighbouring region.
            px = rx + 3 + (cr + 1) / 2 * (rw - 6)
            py = ry + 3 + (1 - (cu + 1) / 2) * (rh - 6)
            loop[uv_layer].uv = (px / 1024, 1 - py / 1024)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return finish(bm, bone, "Body", "tex", smooth=True, bevel=0.035, sharp_angle=60)


def head_shell():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=6, use_grid_fill=True)
    half = Vector((0.63, 0.62, 0.6))
    center = Vector(BONE_CENTERS["Head"])
    for v in bm.verts:
        # create_cube is in Blender axes; treat it as a unit cube in Roblox axes directly.
        p = Vector((v.co.x, v.co.z, -v.co.y))
        rounded = p.normalized() * math.sqrt(1.6)
        q = p.lerp(rounded, 0.45)
        q = Vector((max(-1, min(1, q.x)), max(-1.05, min(1.05, q.y)), max(-1, min(1, q.z))))
        v.co = B(center + Vector((q.x * half.x, q.y * half.y, q.z * half.z)))
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            x, y = co.x - center.x, co.z - center.y
            loop[uv_layer].uv = ((0.65 - x) / 1.3, (y + 0.65) / 1.3)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return finish(bm, "Head", "Face", "facetex", smooth=True, sharp_angle=80)


# ---------------------------------------------------------------------------------------

def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hc = Vector(BONE_CENTERS["Head"])
    tc = Vector(BONE_CENTERS["Torso"])

    shell("Torso", "torso", (2.06, 2.04, 1.06), {"+x": "right", "-x": "left"})
    shell("RightArm", "arm", (1.05, 2.04, 1.05), {"+x": "outer", "-x": "inner"})
    shell("LeftArm", "arm", (1.05, 2.04, 1.05), {"+x": "inner", "-x": "outer"})
    shell("RightLeg", "leg", (1.04, 2.04, 1.04), {"+x": "outer", "-x": "inner"})
    shell("LeftLeg", "leg", (1.04, 2.04, 1.04), {"+x": "inner", "-x": "outer"})
    head_shell()

    # Hair: scalp cap plus layered locks sweeping up and back into a mane.
    bm = bmesh.new()
    ellipsoid(bm, hc + Vector((0, 0.16, 0.02)), (0.71, 0.58, 0.75),
              keep=lambda v: not (v.z < -0.25 and v.y < 0.2))
    finish(bm, "Head", "HairCap", "hair")
    locks = [
        # (path control points relative to head centre, root width, thickness, colour)
        ((-0.3, 0.42, -0.45), (-0.45, 0.95, -0.4), (-0.75, 1.15, 0.15), 0.2, 0.12, "hair"),
        ((0.02, 0.45, -0.48), (0.05, 1.1, -0.45), (0.1, 1.35, 0.1), 0.22, 0.13, "hairLight"),
        ((0.32, 0.42, -0.45), (0.5, 0.95, -0.35), (0.8, 1.1, 0.2), 0.2, 0.12, "hair"),
        ((-0.45, 0.55, -0.05), (-0.75, 1.2, 0.4), (-1.15, 1.25, 1.15), 0.32, 0.17, "hairLight"),
        ((0.0, 0.62, 0.0), (0.0, 1.35, 0.5), (0.05, 1.45, 1.45), 0.34, 0.18, "hair"),
        ((0.45, 0.55, -0.05), (0.75, 1.2, 0.4), (1.15, 1.25, 1.15), 0.32, 0.17, "hairLight"),
        ((-0.25, 0.5, 0.35), (-0.45, 0.95, 1.0), (-0.6, 0.85, 1.85), 0.3, 0.16, "hair"),
        ((0.25, 0.5, 0.35), (0.45, 0.95, 1.0), (0.6, 0.85, 1.85), 0.3, 0.16, "hair"),
        ((-0.55, 0.25, 0.4), (-1.0, 0.45, 0.9), (-1.45, 0.15, 1.45), 0.3, 0.16, "hair"),
        ((0.55, 0.25, 0.4), (1.0, 0.45, 0.9), (1.45, 0.15, 1.45), 0.3, 0.16, "hair"),
        ((0.0, 0.3, 0.6), (0.0, 0.4, 1.3), (0.0, -0.15, 2.0), 0.34, 0.17, "hairLight"),
        ((-0.4, 0.0, 0.55), (-0.75, -0.2, 1.05), (-0.95, -1.05, 1.35), 0.3, 0.15, "hair"),
        ((0.4, 0.0, 0.55), (0.75, -0.2, 1.05), (0.95, -1.05, 1.35), 0.3, 0.15, "hair"),
        ((0.0, -0.1, 0.6), (0.0, -0.5, 1.05), (0.1, -1.4, 1.3), 0.32, 0.15, "hair"),
        ((-0.6, 0.15, -0.25), (-0.72, -0.25, -0.25), (-0.78, -0.75, -0.05), 0.15, 0.08, "hair"),
        ((0.6, 0.15, -0.25), (0.72, -0.25, -0.25), (0.78, -0.75, -0.05), 0.15, 0.08, "hair"),
    ]
    for color in ("hair", "hairLight"):
        bm = bmesh.new()
        for p0, p1, p2, w, th, c in locks:
            if c != color:
                continue
            path = [tuple(hc + Vector(p)) for p in curve(p0, p1, p2, 8)]
            # Locks lie flat against the head: widen across the head surface.
            hint = Vector((p2[2], 0.0, -p2[0])) if abs(p2[0]) > 0.3 else (1, 0, 0)
            strand(bm, path, w, th, side_hint=tuple(hint) if isinstance(hint, Vector) else hint, sides=6)
        finish(bm, "Head", "Hair" if color == "hair" else "HairHighlights", color, sharp_angle=50)

    # Headband with crest and ear guards.
    finish(ring_profile(None, 0.655, 0.635, 0.17, hc.y + 0.29, center=tuple(hc), thickness=0.05, squareness=0.55),
           "Head", "Headband", "gold", sharp_angle=50)
    bm = bmesh.new()
    prism(bm, [(hc.x - 0.15, hc.y + 0.2), (hc.x + 0.15, hc.y + 0.2), (hc.x + 0.11, hc.y + 0.42), (hc.x, hc.y + 0.58), (hc.x - 0.11, hc.y + 0.42)],
          hc.z - 0.665, 0.07)
    finish(bm, "Head", "Crest", "gold", smooth=False, bevel=0.012)
    bm = bmesh.new()
    for side in (-1, 1):
        disc(bm, hc + Vector((side * 0.66, 0.02, 0.04)), 0.22, 0.08, axis="x")
    finish(bm, "Head", "EarGuards", "gold", sharp_angle=50)
    bm = bmesh.new()
    for side in (-1, 1):
        disc(bm, hc + Vector((side * 0.705, 0.02, 0.04)), 0.12, 0.04, axis="x")
    finish(bm, "Head", "EarGuardGems", "gem", sharp_angle=50)

    # Scarf: wrap, knot, short front end and two trailing tails.
    finish(ring_profile(None, 0.5, 0.46, 0.3, tc.y + 1.06, center=tuple(tc), thickness=0.14, squareness=0.2),
           "Torso", "ScarfWrap", "scarf", sharp_angle=60)
    bm = bmesh.new()
    ellipsoid(bm, tc + Vector((-0.42, 0.98, -0.48)), (0.15, 0.13, 0.11), segments=16, rings=10)
    strand(bm, [tuple(tc + Vector(p)) for p in curve((-0.45, 0.95, -0.52), (-0.62, 0.75, -0.6), (-0.7, 0.45, -0.55), 6)], 0.12, 0.035)
    finish(bm, "Torso", "ScarfKnot", "scarf")
    bm = bmesh.new()
    strand(bm, [tuple(tc + Vector(p)) for p in curve((0.15, 1.05, 0.45), (0.6, 0.6, 1.1), (1.05, -0.6, 1.65), 9)], 0.24, 0.05,
           side_hint=(0, 0, 1))
    strand(bm, [tuple(tc + Vector(p)) for p in curve((-0.15, 1.05, 0.45), (-0.2, 0.4, 1.2), (0.3, -0.3, 2.0), 9)], 0.22, 0.05,
           side_hint=(0, 0, 1))
    finish(bm, "Torso", "ScarfTails", "scarfDark")

    # Belt, buckle and loincloth.
    finish(ring_profile(None, 1.03, 0.53, 0.26, 2.12, center=tuple(tc), thickness=0.05, squareness=0.85),
           "Torso", "Belt", "gold", sharp_angle=50)
    bm = bmesh.new()
    disc(bm, (0, 2.12, -0.6), 0.2, 0.07)
    finish(bm, "Torso", "Buckle", "goldDark", sharp_angle=50)
    bm = bmesh.new()
    disc(bm, (0, 2.12, -0.645), 0.1, 0.04)
    finish(bm, "Torso", "BuckleGem", "gem", sharp_angle=50)
    bm = bmesh.new()
    prism(bm, [(-0.38, 2.0), (0.38, 2.0), (0.32, 1.05), (0.0, 0.95), (-0.32, 1.05)], -0.56, 0.05)
    prism(bm, [(-0.42, 2.0), (0.42, 2.0), (0.36, 1.1), (-0.36, 1.1)], 0.56, 0.05)
    finish(bm, "Torso", "Loincloth", "cloth", smooth=False, bevel=0.01)
    bm = bmesh.new()
    prism(bm, [(-0.33, 1.13), (0.33, 1.13), (0.0, 1.03)], -0.59, 0.03)
    finish(bm, "Torso", "LoinclothTrim", "gold", smooth=False)

    # Arms: pauldrons, arm bands and gauntlets.
    for side, bone in ((-1, "LeftArm"), (1, "RightArm")):
        ac = Vector(BONE_CENTERS[bone])
        bm = bmesh.new()
        ellipsoid(bm, ac + Vector((side * 0.1, 0.92, 0)), (0.72, 0.5, 0.66), segments=28, rings=16,
                  keep=lambda v: v.y > -0.2)
        finish(bm, bone, "Pauldron", "gold", sharp_angle=60)
        finish(ring_profile(None, 0.74, 0.68, 0.1, ac.y + 0.86, center=tuple(ac + Vector((side * 0.1, 0, 0))), thickness=0.04, segments=36),
               bone, "PauldronRim", "goldDark", sharp_angle=60)
        finish(ring_profile(None, 0.53, 0.53, 0.12, ac.y + 0.2, center=tuple(ac), thickness=0.03, squareness=0.9),
               bone, "ArmBand", "goldDark", sharp_angle=50)
        finish(ring_profile(None, 0.54, 0.54, 0.5, ac.y - 0.45, center=tuple(ac), thickness=0.06, squareness=0.85),
               bone, "Gauntlet", "gold", sharp_angle=50)
        bm = bmesh.new()
        for y in (ac.y - 0.2, ac.y - 0.7):
            add_box(bm, (ac.x, y, ac.z), (1.17, 0.06, 1.17))
        finish(bm, bone, "GauntletTrim", "goldDark", smooth=False, bevel=0.01)

    # Legs: knee guards, ankle bands and boot toes.
    for side, bone in ((-1, "LeftLeg"), (1, "RightLeg")):
        lc = Vector(BONE_CENTERS[bone])
        bm = bmesh.new()
        prism(bm, [(lc.x - 0.36, lc.y - 0.2), (lc.x + 0.36, lc.y - 0.2), (lc.x + 0.4, lc.y + 0.12), (lc.x, lc.y + 0.36), (lc.x - 0.4, lc.y + 0.12)],
              -0.58, 0.14)
        finish(bm, bone, "KneeGuard", "gold", smooth=False, bevel=0.02)
        finish(ring_profile(None, 0.53, 0.53, 0.14, lc.y - 0.62, center=tuple(lc), thickness=0.03, squareness=0.9),
               bone, "AnkleBand", "gold", sharp_angle=50)
        bm = bmesh.new()
        add_box(bm, (lc.x, 0.16, -0.62), (1.0, 0.32, 0.3))
        finish(bm, bone, "BootToe", "cloth", smooth=False, bevel=0.06)

    # Import-frame markers: origin and one stud along each axis (×4 for precision).
    for name, pos in (("O", (0, 0, 0)), ("X", (4, 0, 0)), ("Y", (0, 4, 0)), ("Z", (0, 0, 4))):
        bm = bmesh.new()
        add_box(bm, pos, (0.1, 0.1, 0.1))
        obj = finish(bm, "Marker", name, "marker", smooth=False)
        obj.name = f"Marker__{name}__marker"


def report():
    pieces = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        xs = [v.co for v in mesh.vertices]
        lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
        hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
        # back to Roblox axes
        rlo = (lo.x, lo.z, -hi.y)
        rhi = (hi.x, hi.z, -lo.y)
        pieces.append({"name": obj.name, "triangles": len(mesh.loop_triangles), "min": rlo, "max": rhi,
                       "uv": bool(mesh.uv_layers)})
        evaluated.to_mesh_clear()
    return pieces


def main():
    build()
    pieces = report()
    total = sum(p["triangles"] for p in pieces)
    worst = max(p["triangles"] for p in pieces)
    assert worst <= 20000, "a piece exceeds Roblox's 20k triangle mesh limit"
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "StarPlatinumMorph.blend"))
    bpy.ops.export_scene.fbx(
        filepath=str(HERE / "StarPlatinumMorph.fbx"),
        use_selection=False, object_types={"MESH"}, use_mesh_modifiers=True,
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        path_mode="COPY", embed_textures=True, mesh_smooth_type="FACE", add_leaf_bones=False,
    )
    preview = ROOT / "artifacts/preview"
    preview.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(preview / "StarPlatinumMorph.glb"), export_format="GLB",
                              export_apply=True, export_yup=True)
    (HERE / "morph_report.json").write_text(json.dumps({"total_triangles": total, "pieces": pieces}, indent=1))
    print(f"MORPH OK: {len(pieces)} pieces, {total} triangles, largest {worst}")


main()
