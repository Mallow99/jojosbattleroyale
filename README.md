# JoJo battle royale

Continuing in a new chat: read [the latest handoff](HANDOFF_NEW_CHAT.md) first.

The concept is a PC-first Roblox battle royale with **32-player solo matches
lasting 15–20 minutes**. Players deploy across six districts, collect equipment,
and swap Stand discs. The initial Stands are **Star Platinum and Magician's Red**.
Victory requires obtaining the Requiem Arrow and completing a contested
activation at the final landmark. The last survivor must still activate it.

The [game plan](docs/GAME_PLAN.md) contains the match rules, progression,
technical architecture, monetization defaults and delivery gates. The
[art direction](docs/ART_DIRECTION.md) records the rejection of the first model;
future work must use a credible Roblox style. No replacement model is approved.

The game foundation is in place: a lobby place (profiles, rotating skin gacha,
cross-server queue) and a match place (deploy, loot, Stand discs, zone, Requiem
Arrow guarded by Silver Chariot Requiem, activation, rewards). See
[the game foundation](docs/GAME_FOUNDATION.md) for the loop, code map and how to
try it in Studio. Nothing has been run in the Roblox engine yet.

The cloud workspace is ready to code, build place files, test portable Luau, and
author meshes, rigs, textures and animations. No purchase, new account, or local
computer connection was needed for this preparation.

```sh
python3 tools/bootstrap.py
python3 tools/check.py
python3 tools/check.py --assets
rojo build lobby.project.json -o lobby.rbxl
rojo build match.project.json -o match.rbxl
```

Bootstrap restores exact CLI versions and caches two source-library candidates
using SHA-256 locks. It targets Linux x86_64 and requires Python 3 and network
access to the recorded GitHub URLs. Asset checks additionally require Blender
and FFmpeg; both are installed in this workspace.

- [Tool inventory and testing limits](docs/TOOLS.md)
- [AI tool assessment, including Higgsfield](docs/AI_TOOLS.md)
- [Game foundation](docs/GAME_FOUNDATION.md)
- [Main game resources inventory](docs/MAIN_RESOURCES_INVENTORY.md)
- [Resource candidates](docs/RESOURCES.md)
- [Current art direction and rejected prototype](docs/ART_DIRECTION.md)
- [Supplied game plan](docs/GAME_PLAN.md)
- [Historical setup handoff](docs/HANDOFF.md)

Generated output is in `artifacts/` and is ignored by Git. `artifacts/game/` holds
the built lobby and match places; `artifacts/code/` holds toolchain fixtures. Blender produces a fixture
`.blend`, textured `.fbx`, preview image, and an FBX round-trip report. FFmpeg
produces a test WAV and a one-second preview MP4. CLI checks stop their temporary
Rojo server automatically.

These checks do not run the Roblox engine or validate replication, collisions,
asset loading, publishing, live services, teleports, purchases, or 32-player
performance. GitHub CI is configured but has not been run remotely. Nothing has
been published to Roblox.
