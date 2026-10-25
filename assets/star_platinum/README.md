# REJECTED — Star Platinum rounded prototype

The user rejected this visual direction on October 24, 2026. It does not meet the
project's Roblox style or quality bar. Preserve these files only as history;
do not use this geometry, proportions, face or render as a game asset or design
baseline. See `docs/ART_DIRECTION.md` for the replacement criteria.

This is an original procedural mesh interpretation of the Star Platinum character,
created for this project's first model review. It uses no downloaded game geometry,
texture maps, external asset IDs or embedded gameplay scripts. It is a fan-character
prototype, not a claim to own the underlying character.

## Rebuild

From the repository root:

```sh
blender --background --factory-startup --threads 2 --python-exit-code 1 --python tools/create_star_platinum.py
```

Tested with Blender 4.3.2. The generator writes into `artifacts/star-platinum/`:

- `star-platinum.blend`: editable mesh, humanoid prototype rig, idle animation,
  lighting and camera.
- `star-platinum.fbx`: selected character mesh and skeleton, excluding render stage.
- `star-platinum.glb`: self-contained model for a compatible 3D viewer.
- `hero.png`, `front.png`, `side.png`, `back.png`: renders of the delivered geometry.
- `report.json`: geometry counts, weight checks and FBX round-trip results.

The look uses amethyst skin, broad muscle planes, swept dark hair, a gold headband
with an emerald inset, gold shoulder armor, green guards and ivory scarf/cloth.
Color materials are authored in Blender; there are no painted image textures.
The mesh has UVs for later texture work. The idle animation is 48 frames at 24 fps.
The current export has 12,607 triangles, 6,572 vertices, 16 bones and 12 materials.

## Validation and limits

The build enforces a 20,000-triangle ceiling, verifies normalized skin weights,
and reimports its FBX to check geometry, UVs, skeleton, weights and animation.
It also validates the GLB container, skeleton, skin attributes and animation.
Exact counts and results are in the generated report.

This is a review prototype built from disconnected mesh surfaces with rigid bone
assignments. It needs joint/topology refinement and deformation testing before
combat animation. Fingers are sculpted as a closed fist; no finger or facial rig
is included. The 16-bone skeleton is a custom humanoid prototype and has not been
validated as a Roblox avatar/R15 rig. No collision or gameplay setup is provided.
Studio import scale, materials, animation playback and performance remain untested.

After an art-direction review, refine the silhouette/face, replace intersecting
joint surfaces with production topology, establish a tested Roblox skeleton and
texture atlas, then produce summon/idle/punch/barrage animations.

Stand models now come from `Main game resources.rbxl`; see `docs/MAIN_RESOURCES_INVENTORY.md`.
