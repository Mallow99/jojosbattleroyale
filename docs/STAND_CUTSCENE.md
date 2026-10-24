# Star Platinum awakening cutscene

A 12.6-second R6 cutscene. The player takes out a Star Platinum stand disc, looks it over,
slots it into the front of their neck, recoils, and Star Platinum materialises behind them.
Both finish in a point-and-glare pose with the stand-name title card and the menacing
"ゴ" glyphs.

Everything ships as standard Roblox content:

| Piece | What it is | Where |
| --- | --- | --- |
| Star Platinum rig | Standard R6 character (Roblox's own R6 joint C0/C1 values, Humanoid, Animator, BodyColors, classic head mesh, character attachments) | `src/assets/StarPlatinum.rbxmx` → `ReplicatedStorage.StandAssets` |
| Star Platinum morph | 37 mesh pieces welded onto the R6 parts: textured body shells and face, hair, headband, scarf, pauldrons, gauntlets, belt, loincloth, knee guards and boots (≈10k triangles) | `art/star_platinum/StarPlatinumMorph.fbx` (import in Studio) |
| User animation | `KeyframeSequence` for any R6 character, including the `Disc` prop joint and KeyframeMarkers for each beat | `ServerStorage.RBX_ANIMSAVES.StandUser.UserDiscAwakening` |
| Stand animation | `KeyframeSequence` for the Star Platinum rig | `ServerStorage.RBX_ANIMSAVES.StarPlatinum.StarPlatinumAwakening` |
| Disc prop | Engine cylinder with an iridescent label drawn by SurfaceGui, built at runtime | `StandCutscene.StandDisc` |
| Cutscene | Client module: plays both animations through `Animator`, scripted camera, letterbox, flash, colour grade, aura particles, shock rings, summon glow, title card | `ReplicatedStorage.StandCutscene` |
| Demo place | Plaza with a disc on a pedestal. Its prompt runs the cutscene; avatars are forced to R6 | `stand.project.json` |

The model is an original Roblox-style interpretation built for this project. It uses no
downloaded models, kits or asset IDs.

## Open it in Studio

1. Build the place: `rojo build stand.project.json -o StandAwakeningDemo.rbxl` and open the
   file. You can also run `rojo serve stand.project.json` and connect the Rojo 7.7.1 plugin.
2. Press **Play**, walk to the disc on the pedestal and hold **E**. The cutscene plays even
   before the meshes are imported. Star Platinum then appears as a plain purple R6 figure.
3. To get the full look, use **File → Import 3D** and choose
   `art/star_platinum/StarPlatinumMorph.fbx`. Defaults are fine; the installer corrects
   position, rotation and scale. Insert it, rename the imported model `StarPlatinumMorph` and
   move it into `ReplicatedStorage.StandMeshes`. The cutscene welds it on automatically.
4. Optional: to also see the morph on the stored rigs (and in the Animation Editor), run this
   in the Command Bar:
   `require(game.ReplicatedStorage.StandCutscene.StandMorph).bake()`
5. Save the place. The importer uploads the meshes and textures to your account; they are
   your assets from then on.

`rojo serve` leaves `ReplicatedStorage.StandMeshes` alone because the project gives that
folder no path, so the imported model survives syncs. A rig you bake in step 4 will be
replaced by the next Rojo sync of `StandAssets`; the runtime install in step 3 does not
depend on baking.

## Editing and publishing the animations

- Select `Workspace.AnimationRigs.StandUser` or `.StarPlatinum` and open the Animation
  Editor. Each rig's `AnimSaves` value points at its saves in `ServerStorage.RBX_ANIMSAVES`,
  where the editor's save list looks. After **Save**, the next playtest uses your edits; the
  demo server copies the saves to `ReplicatedStorage.StandAnimations` on start.
- Keyframes are dense in places, because the authored eases are baked as Linear poses so the
  preview matches playback. The `Disc` pose is under `Right Arm` in the user animation.
- Playtests in Studio use unpublished animations through
  `KeyframeSequenceProvider:RegisterKeyframeSequence`. **Live games cannot.** Publish both
  sequences (Animation Editor ⋯ → Publish to Roblox, or right-click the KeyframeSequence →
  Save to Roblox) and paste the IDs into `StandCutscene.Config`.

## Using it in the match place

`Cutscene.play(anchor?)` runs on the client and yields until the cutscene ends. The demo
server shows the intended split: the server decides that a disc is used, anchors the
player and records `Stand = "StarPlatinum"`, then fires the client. The stand clone,
camera and effects are local to that player; other players see the player's own animation
replicate, but not the stand. Showing the stand to everyone belongs to the stand system,
when it exists.

The user animation is R6. In a place whose avatar setting is R15, an R15 player gets the
`StandUser` fallback rig in their place for the cutscene. The plan's YBA-style blocky
direction suggests R6 for the game; that is your call.

## Regenerating

```sh
python3 tools/get_blender.py                 # pinned Blender 4.3.2 into .tools/blender
python3 art/star_platinum/textures.py        # body atlas + face textures
.tools/blender/blender-4.3.2-linux-x64/blender -b --factory-startup --python-exit-code 1 \
    --python art/star_platinum/build_morph.py   # FBX, .blend, report, preview GLB
.tools/bin/lune run tools/stand/build.luau   # rigs, stage, KeyframeSequences
tools/stand/render.sh cutscene               # all of the above + preview frames
```

Poses live in `tools/stand/Animations.luau`, in each parent part's axes and in degrees.
Shoulder and hip +X swings the limb forward, right-side +Z swings it outward, Neck −X looks
down, and RootJoint +X leans back. Camera shots and effect timing live in
`src/ReplicatedStorage/StandCutscene/Awakening.luau`.

## What was checked, and what was not

`python3 tools/check.py` (with `--stand-assets` for the Blender half) checks:

- The generated rigs, stage and animations are current with their sources and
  byte-for-byte reproducible.
- Every runtime script passes the Roblox API type check (luau-lsp with pinned Roblox
  definitions), StyLua and Selene.
- The place builds with Rojo 7.7.1. 8,438 Lune assertions run on the built file: R6 joint
  values match Roblox's, rest poses are consistent, the `AnimSaves` links resolve, every
  Pose targets a real part under the right parent, markers sit on their beats, and the
  saved keyframes reproduce the authored motion within 0.6°. They also check that the disc
  stays in the hand, docks at the throat and ends inside the neck; that the feet stay
  grounded; that the stand never overlaps the user; and that the camera never enters a
  character.
- The morph installer gives identical results under rotated, translated and rescaled
  imports, including metre/stud conversion, and rejects mirrored imports. It runs against a
  **simulated** importer.
- The FBX round-trips through Blender with object names, marker positions, UVs, embedded
  textures, and every piece under Roblox's 20k-triangle limit.

The preview video and turnarounds are rendered in a browser (three.js) from these exact
files: the R6 rigs, the morph placed by the shipped installer, the saved keyframes
interpolated as Roblox does, and the shipped camera and effect tracks. Roblox's renderer,
particles and fonts look different. The preview approximates them; it is not a screenshot.

**Not verified, because no Roblox engine was available:**

- How Studio's 3D Importer names and places the FBX pieces. The installer is built to
  tolerate this, but the real import has not been run.
- Animator playback of the sequences, including the prop joint.
- `RegisterKeyframeSequence` on the client.
- Highlight, particle and SurfaceGui rendering.
- Whether the Animation Editor's save list picks up the generated saves.
- Behaviour with R15 or Rthro avatars.
- Multiplayer.

Run the demo in Studio first and send back the Output window if anything fails.
