"""Body atlas layout shared by textures.py (painting) and build_morph.py (UVs)."""

# Atlas regions in pixels (x, y, w, h); keys are "<part>.<face role>".
REGIONS = {
    "torso.front": (0, 0, 256, 256), "torso.back": (256, 0, 256, 256),
    "torso.right": (512, 0, 128, 256), "torso.left": (640, 0, 128, 256),
    "torso.top": (768, 0, 256, 128), "torso.bottom": (768, 128, 256, 128),
    "arm.front": (0, 256, 128, 256), "arm.back": (128, 256, 128, 256),
    "arm.outer": (256, 256, 128, 256), "arm.inner": (384, 256, 128, 256),
    "arm.top": (512, 256, 128, 128), "arm.bottom": (640, 256, 128, 128),
    "leg.front": (0, 512, 128, 256), "leg.back": (128, 512, 128, 256),
    "leg.outer": (256, 512, 128, 256), "leg.inner": (384, 512, 128, 256),
    "leg.top": (512, 512, 128, 128), "leg.bottom": (640, 512, 128, 128),
}
