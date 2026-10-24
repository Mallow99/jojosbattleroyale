"""Paints Star Platinum's body atlas and face textures (original artwork for this project).

Run: python3 art/star_platinum/textures.py
Writes SP_Body.png (1024²) and SP_Face.png (512²) next to this script. Atlas regions are
shared with build_morph.py (REGIONS); each face is painted as seen from outside the body.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from atlas import REGIONS

HERE = Path(__file__).resolve().parent
SS = 2  # supersampling factor

SKIN = (116, 96, 192)
SKIN_LIGHT = (140, 120, 214)
SKIN_SHADE = (88, 70, 160)
LINE = (44, 30, 98)
CLOTH = (40, 36, 88)
CLOTH_LIGHT = (60, 54, 120)
CLOTH_DARK = (26, 22, 62)
EYE = (96, 234, 238)
EYE_WHITE = (236, 240, 255)
LIPS = (70, 50, 138)


class Face:
    """Draws into one region using 0..1 coordinates (x right, y down as seen from outside)."""

    def __init__(self, draw, region):
        self.d = draw
        x, y, w, h = region
        self.x, self.y, self.w, self.h = x * SS, y * SS, w * SS, h * SS

    def p(self, u, v):
        return (self.x + u * self.w, self.y + v * self.h)

    def poly(self, points, fill):
        self.d.polygon([self.p(u, v) for u, v in points], fill=fill)

    def rect(self, u0, v0, u1, v1, fill):
        self.d.rectangle([self.p(u0, v0), self.p(u1, v1)], fill=fill)

    def rrect(self, u0, v0, u1, v1, radius, fill):
        self.d.rounded_rectangle([self.p(u0, v0), self.p(u1, v1)], radius=radius * SS, fill=fill)

    def ellipse(self, u0, v0, u1, v1, fill):
        self.d.ellipse([self.p(u0, v0), self.p(u1, v1)], fill=fill)

    def line(self, points, width, fill):
        self.d.line([self.p(u, v) for u, v in points], fill=fill, width=int(width * SS), joint="curve")

    def arc(self, u0, v0, u1, v1, start, end, width, fill):
        self.d.arc([self.p(u0, v0), self.p(u1, v1)], start, end, fill=fill, width=int(width * SS))

    def vgradient(self, top, bottom, v0=0.0, v1=1.0):
        steps = 48
        for i in range(steps):
            t = i / (steps - 1)
            c = tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
            self.rect(0, v0 + (v1 - v0) * i / steps, 1, v0 + (v1 - v0) * (i + 1) / steps + 0.002, c)

    def side_shade(self, color, width=0.18):
        steps = 12
        for i in range(steps):
            alpha = 1 - i / steps
            c = tuple(int(color[k]) for k in range(3)) + (int(38 * alpha),)
            u = width * i / steps
            self.d.rectangle([self.p(u, 0), self.p(u + width / steps, 1)], fill=c)
            self.d.rectangle([self.p(1 - u - width / steps, 0), self.p(1 - u, 1)], fill=c)


def torso(draw):
    f = Face(draw, REGIONS["torso.front"])
    f.vgradient(SKIN_LIGHT, SKIN)
    f.side_shade(SKIN_SHADE)
    # collarbones
    f.line([(0.2, 0.08), (0.45, 0.12)], 3, LINE)
    f.line([(0.8, 0.08), (0.55, 0.12)], 3, LINE)
    # pecs
    for side in (0, 1):
        u0 = 0.06 if side == 0 else 0.51
        f.rrect(u0, 0.16, u0 + 0.43, 0.42, 22, SKIN_LIGHT)
        f.arc(u0, 0.1, u0 + 0.43, 0.43, 20, 160, 4, LINE)
    f.line([(0.5, 0.14), (0.5, 0.82)], 3, LINE)
    # abs: three rows of two blocks with dark gaps
    for row in range(3):
        v = 0.47 + row * 0.12
        for u0 in (0.3, 0.515):
            f.rrect(u0, v, u0 + 0.185, v + 0.1, 8, SKIN_LIGHT)
    # serratus / obliques
    for side in (0, 1):
        sx = (lambda u: u) if side == 0 else (lambda u: 1 - u)
        for k in range(3):
            v = 0.47 + k * 0.08
            f.line([(sx(0.14), v), (sx(0.24), v + 0.05)], 3, LINE)
        f.line([(sx(0.2), 0.72), (sx(0.3), 0.85)], 3, LINE)
    f.ellipse(0.48, 0.83, 0.52, 0.86, LINE)
    f.rect(0, 0.87, 1, 1, CLOTH)
    f.rect(0, 0.87, 1, 0.885, CLOTH_DARK)

    b = Face(draw, REGIONS["torso.back"])
    b.vgradient(SKIN, SKIN_SHADE)
    b.side_shade(SKIN_SHADE)
    b.line([(0.5, 0.1), (0.5, 0.85)], 3, LINE)
    b.arc(0.12, 0.12, 0.46, 0.5, 200, 340, 4, LINE)
    b.arc(0.54, 0.12, 0.88, 0.5, 200, 340, 4, LINE)
    b.line([(0.18, 0.55), (0.38, 0.75)], 3, LINE)
    b.line([(0.82, 0.55), (0.62, 0.75)], 3, LINE)
    b.rect(0, 0.87, 1, 1, CLOTH)

    for role in ("torso.left", "torso.right"):
        s = Face(draw, REGIONS[role])
        s.vgradient(SKIN, SKIN_SHADE)
        s.line([(0.3, 0.35), (0.6, 0.6)], 3, LINE)
        s.rect(0, 0.87, 1, 1, CLOTH)
    Face(draw, REGIONS["torso.top"]).rect(0, 0, 1, 1, SKIN)
    Face(draw, REGIONS["torso.bottom"]).rect(0, 0, 1, 1, CLOTH)


def arm(draw):
    for role in ("arm.front", "arm.back", "arm.outer", "arm.inner"):
        f = Face(draw, REGIONS[role])
        f.vgradient(SKIN_LIGHT if role != "arm.back" else SKIN, SKIN_SHADE)
        f.side_shade(SKIN_SHADE, 0.22)
        if role in ("arm.front", "arm.outer"):
            f.arc(-0.1, -0.15, 1.1, 0.3, 20, 160, 4, LINE)  # deltoid
            f.rrect(0.2, 0.18, 0.8, 0.42, 14, SKIN_LIGHT)  # bicep
            f.line([(0.3, 0.5), (0.7, 0.52)], 3, LINE)  # elbow crease
            f.line([(0.3, 0.6), (0.45, 0.78)], 3, LINE)
        else:
            f.line([(0.5, 0.15), (0.5, 0.42)], 3, LINE)
            f.line([(0.35, 0.55), (0.6, 0.5)], 3, LINE)
        # fist at the bottom of the arm
        f.rect(0, 0.84, 1, 1, SKIN)
        if role == "arm.front":
            for k in range(1, 4):
                f.line([(k * 0.25, 0.86), (k * 0.25, 0.99)], 3, LINE)
            f.line([(0.05, 0.86), (0.95, 0.86)], 3, LINE)
        elif role == "arm.inner":
            f.rrect(0.15, 0.82, 0.55, 0.97, 8, SKIN_LIGHT)  # thumb
            f.line([(0.15, 0.82), (0.55, 0.82)], 3, LINE)
    Face(draw, REGIONS["arm.top"]).rect(0, 0, 1, 1, SKIN)
    bottom = Face(draw, REGIONS["arm.bottom"])
    bottom.rect(0, 0, 1, 1, SKIN_SHADE)
    for k in range(1, 4):
        bottom.line([(k * 0.25, 0.1), (k * 0.25, 0.9)], 3, LINE)


def leg(draw):
    for role in ("leg.front", "leg.back", "leg.outer", "leg.inner"):
        f = Face(draw, REGIONS[role])
        # shorts, bare knee band, boot
        f.vgradient(CLOTH_LIGHT, CLOTH, 0, 0.34)
        f.line([(0.2, 0.12), (0.45, 0.28)], 3, CLOTH_DARK)
        f.rect(0, 0.33, 1, 0.35, CLOTH_DARK)
        f.vgradient(SKIN_LIGHT, SKIN_SHADE, 0.35, 0.56)
        if role == "leg.front":
            f.arc(0.15, 0.36, 0.85, 0.56, 200, 340, 3, LINE)
        f.vgradient(CLOTH_LIGHT, CLOTH_DARK, 0.56, 1.0)
        f.rect(0, 0.56, 1, 0.58, CLOTH_DARK)
        if role == "leg.front":
            f.rect(0.42, 0.6, 0.58, 0.95, CLOTH_LIGHT)
        f.side_shade(CLOTH_DARK, 0.2)
    Face(draw, REGIONS["leg.top"]).rect(0, 0, 1, 1, CLOTH)
    Face(draw, REGIONS["leg.bottom"]).rect(0, 0, 1, 1, (20, 16, 40))


def face_texture():
    size = 512 * SS
    img = Image.new("RGBA", (size, size), SKIN + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    f = Face(d, (0, 0, 512, 512))

    # Head-space helper: x in [-0.65, 0.65] (character's right is image left), y up.
    def hp(x, y):
        return ((0.65 - x) / 1.3, (0.65 - y) / 1.3)

    def poly(points, fill):
        f.poly([hp(x, y) for x, y in points], fill)

    def line(points, width, fill):
        f.line([hp(x, y) for x, y in points], width, fill)

    f.vgradient(SKIN_LIGHT, SKIN, 0.0, 1.0)
    # Hairline: everything above the headband is hair.
    f.rect(0, 0, 1, hp(0, 0.34)[1], (40, 32, 84))
    for side in (1, -1):  # 1 = character's right
        s = side
        # brow: heavy, angled down toward the nose
        poly([(s * 0.06, 0.06), (s * 0.36, 0.17), (s * 0.4, 0.12), (s * 0.08, 0.0)], LINE)
        # eye white, iris, pupil, lash
        poly([(s * 0.09, -0.02), (s * 0.34, 0.06), (s * 0.36, 0.0), (s * 0.12, -0.07)], EYE_WHITE)
        poly([(s * 0.17, -0.055), (s * 0.27, -0.03), (s * 0.27, 0.035), (s * 0.17, 0.01)], EYE)
        poly([(s * 0.2, -0.04), (s * 0.24, -0.03), (s * 0.24, 0.02), (s * 0.2, 0.01)], (14, 40, 64))
        poly([(s * 0.07, 0.0), (s * 0.37, 0.09), (s * 0.38, 0.05), (s * 0.09, -0.025)], LINE)
        line([(s * 0.12, -0.085), (s * 0.33, -0.03)], 2, LINE)
        # cheek and jaw lines
        line([(s * 0.3, -0.12), (s * 0.24, -0.26)], 2.5, LINE)
        line([(s * 0.42, -0.2), (s * 0.34, -0.42)], 2.5, LINE)
    # nose
    line([(-0.02, -0.02), (-0.04, -0.17)], 2.5, LINE)
    poly([(-0.09, -0.19), (0.09, -0.19), (0.06, -0.165), (-0.06, -0.165)], LINE)
    # mouth: firm lips with a dark parting line
    poly([(-0.17, -0.32), (0.17, -0.32), (0.13, -0.37), (-0.13, -0.37)], LIPS)
    poly([(-0.15, -0.3), (0.15, -0.3), (0.12, -0.32), (-0.12, -0.32)], LIPS)
    line([(-0.19, -0.322), (0.19, -0.322)], 3, LINE)
    line([(-0.06, -0.43), (0.06, -0.43)], 2.5, LINE)
    out = img.filter(ImageFilter.GaussianBlur(0.6)).resize((512, 512), Image.LANCZOS)
    out.convert("RGB").save(HERE / "SP_Face.png")


def body_texture():
    size = 1024 * SS
    img = Image.new("RGBA", (size, size), SKIN + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    torso(d)
    arm(d)
    leg(d)
    out = img.filter(ImageFilter.GaussianBlur(0.6)).resize((1024, 1024), Image.LANCZOS)
    out.convert("RGB").save(HERE / "SP_Body.png")


if __name__ == "__main__":
    body_texture()
    face_texture()
    print("Wrote", HERE / "SP_Body.png", HERE / "SP_Face.png")
