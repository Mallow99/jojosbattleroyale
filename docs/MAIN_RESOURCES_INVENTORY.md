# Inventory: `Main game resources.rbxl`

Inspected October 25, 2026 from `origin/main` (commit `58c952e`, 75,359,419 bytes).
The place was deserialized read-only with Lune 0.11.1; nothing in it was run. Counts
below are instance counts from that pass. Sections marked "binary scan" come from a
small Python reader of the file's string properties, because Lune 0.11.1 cannot read
Content properties.

## Source and permission

The place is a full game: 354,345 instances, 1,194 scripts (about 326,000 lines) and
hard-coded production place IDs. Its loading-screen credits list the YBA:AU team
(founder/head developer zakuxo, lead programmers Artyom_MM and fisqb, VFX weakylol,
modelers rse_ill, focus33333333, Grand_Gator and S0_Build, and others). The user
obtained it from them and confirmed on October 25, 2026 that we have permission to
use everything in it.

Technical note (binary scan): the models, sounds and animations are not embedded.
They point at Roblox asset IDs (about 4,700 unique mesh IDs, 1,870 sound IDs, 880
animation IDs, 1,760 texture IDs). Roblox loads an asset in our experience only if
it is public or its owner shared it with our experience/group, so the first Studio
session should confirm which ones load.

## What is in it

| Service / folder | Contents |
| --- | --- |
| `ServerStorage/Stands` | About 89 Stand folders, mostly a `StandMorph` model each (R15-style MeshPart rigs) |
| `ReplicatedStorage/Stands` | About 87 matching Stand configs: idle/move animations, `StandSkills` key bindings, summon sounds, aura emitters, `Skill Tree` models |
| `ServerStorage/StandModels` | 7 Shadow The World variants |
| `ServerStorage/Skins` | About 165 Stand skins |
| `ServerStorage/Mobs` | 34 NPC/boss models with scripts (Jotaro, Dio, Doppio, Koichi, thugs, dummies) |
| `ServerStorage/Tools` | 88 tools, including Mysterious/Lucky/Requiem Arrow, Rokakaka, discs, Stone Mask, weapons |
| `ServerStorage/Dialogues`, `Modules` | 102 NPC dialogue trees; 26 modules (Inventory, StandLibrary, StandSkillsLibrary, ItemSpawn, ZonePlus, Janitor, Trove, Maid) |
| `ReplicatedStorage/Cosmetics` | 100 hair/hat/mask cosmetics |
| `ReplicatedStorage/Specs` | 42 fighting-style specs (Hamon, Boxing, Vampirism, Sword Style, ...) |
| `ReplicatedStorage/Assets` | Objects (936 MeshParts), Effects (562 items), Anims (233), Sounds (1,162), 23 utility modules, Gradients |
| `Workspace/Map` | Town map: about 3,500 models (buildings, trees, lamps), spawns, arenas |
| `ServerScriptService/Game Modes` | `SBRLoader` (Steel Ball Run mode), `ArenaLoader`, `BRLoader`, `TradingHubLoader` |
| `ServerStorage/YBA:AU ASSETS` | Duplicate asset set: objects, effects, sounds, anims and four loading screens |
| `MaterialService` | One PBR kit, "Asus's PBR Kit" |

## Models for the project's two launch Stands

**Star Platinum** (5 related Stand folders):
`Star Platinum`, `Star Platinum: The World`, `「Star Platinum」`, `Star Platinum: Over Heaven`,
`『Fish Platinum』` and Star Platinum skins (Stone, Female, Manga, Festive, Bob, Retro, ...).
The base `ServerStorage/Stands/Star Platinum/StandMorph` is a 17-part R15 MeshPart rig
with an `AnimationController`; the matching `ReplicatedStorage/Stands/Star Platinum`
carries Idle, Move and PlayerIdle animations, nine key-bound skills, an aura emitter,
summon sounds and a Rage value. Two older `StandMorph old` models are also kept.

**Magician's Red**: no Stand folder exists in `Stands` or `Skins`. Only the effects set
`ReplicatedStorage/Assets/Objects/Magicians_Red_Assets` (hand flames and trails,
Crossfire impact, Ankh, red bind pieces, rocks). Its rig and moveset would need to be built.

## Usable now versus reference only

Usable as concrete material for the game:

- Stand rig structure: the `StandMorph` R15 MeshPart layout with an `AnimationController`,
  plus the idle/move/summon wiring that drives it.
- Effects: particle emitters, shockwave meshes, slash meshes, trails and Magician's Red
  fire pieces.
- Tool and pickup models: arrows, discs, Stone Mask, Rokakaka, weapons.
- Item and spawn layout: `Item_Spawns`, `Mob_Spawns`, `Gift_Spawns` and `ItemSpawnMod`.
- Map modules and props: buildings, trees, street furniture, arenas.
- Generic libraries, if licenses check out: ZonePlus, Janitor, Trove, Maid, Promise, PartCache,
  CameraShaker, Bezier, RichText, Lightning modules.

Reference only (do not adopt as written):

- The combat, data, inventory, quest, admin, webhook and anti-cheat scripts. Our rules require
  server-owned game rules in this repository.
- Anything touching DataStores, teleports, dev products, game passes or bans. Purchases stay
  disabled, and the hard-coded place IDs are not ours.
- Non-JoJo content: Gojo, Goku, Zeno, Aizen, Genos, Vergil, Law, Gura and other crossover
  Stands, tools and specs.

## What the foundation extracted

`tools/extract_resources.luau` writes these to `assets/rbx/` with every script stripped:
eight Stand packages (Star Platinum, The World, Crazy Diamond, King Crimson, Gold
Experience, Whitesnake, Silver Chariot, The Hand) with idle/move animations, aura and
summon sound; Chariot Requiem as the boss; 26 skins for those Stands from the place's
own `ObtainableSkins` table; the disc, Stand Arrow and Requiem Arrow models; Katana,
Dagger, DIO's Knife and Shovel tools; Tea as a heal; the punch-combo animations and hit
sounds; the Magician's Red effects; the town map with its item-spawn markers and named
districts; and the sky, atmosphere and post-processing. Rerun it after changing the list:

    lune run tools/extract_resources.luau "Main game resources.rbxl"
