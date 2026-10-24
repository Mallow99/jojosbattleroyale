# JoJo battle royale

Continuing in a new chat: read [the latest handoff](HANDOFF_NEW_CHAT.md) first.

The concept is a PC-first Roblox battle royale with **32-player solo matches
lasting 15–20 minutes**. Players deploy across six districts, collect equipment,
and swap Stand discs. The initial Stands are **Star Platinum and Magician's Red**.
Victory requires obtaining the Requiem Arrow and completing a contested
activation at the final landmark. The last survivor must still activate it.

**First asset:** the [Star Platinum awakening cutscene](docs/STAND_CUTSCENE.md). It
includes an R6 Star Platinum rig, a mesh morph to import with Studio's 3D Importer, R6
KeyframeSequences for the player and the stand, a client cutscene module, and a demo place
(`stand.project.json`). Open it in Studio by following that page.

The [game plan](docs/GAME_PLAN.md) contains the match rules, progression,
technical architecture, monetization defaults and delivery gates. The
[art direction](docs/ART_DIRECTION.md) records the rejection of the first model;
future work must use a credible Roblox style. No replacement model is approved.

This checkout contains the development tools and pipeline checks for the supplied
32-player Roblox plan. Gameplay implementation has not started.

The cloud workspace is ready to code, build place files, test portable Luau, and
author meshes, rigs, textures and animations. No purchase, new account, or local
computer connection was needed for this preparation.

```sh
python3 tools/bootstrap.py
python3 tools/check.py
python3 tools/check.py --assets
```

Bootstrap restores exact CLI versions and caches two source-library candidates
using SHA-256 locks. It targets Linux x86_64 and requires Python 3 and network
access to the recorded GitHub URLs. Asset checks additionally require Blender
and FFmpeg; both are installed in this workspace.

- [Tool inventory and testing limits](docs/TOOLS.md)
- [AI tool assessment, including Higgsfield](docs/AI_TOOLS.md)
- [Resource candidates and provenance](docs/RESOURCES.md)
- [Star Platinum model search](docs/MODEL_SEARCH.md)
- [Star Platinum awakening cutscene](docs/STAND_CUTSCENE.md)
- [Current art direction and rejected prototype](docs/ART_DIRECTION.md)
- [Supplied game plan](docs/GAME_PLAN.md)
- [Historical setup handoff](docs/HANDOFF.md)

Generated output is in `artifacts/` and is ignored by Git. The two `.rbxl` files
are **toolchain fixtures**, not playable game builds. Blender produces a fixture
`.blend`, textured `.fbx`, preview image, and an FBX round-trip report. FFmpeg
produces a test WAV and a one-second preview MP4. CLI checks stop their temporary
Rojo server automatically.

These checks do not run the Roblox engine or validate replication, collisions,
asset ownership, publishing, live services, teleports, purchases, or 32-player
performance. GitHub CI is configured but has not been run remotely. Nothing has
been published to Roblox.
