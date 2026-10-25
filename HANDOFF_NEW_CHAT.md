# New chat handoff

Updated October 25, 2026. This is the latest handoff; `docs/HANDOFF.md` describes the
earlier setup stage.

## Where things stand

The game foundation is built: a lobby place (profiles, gacha, cross-server queue) and a
match place (waiting room, deploy, loot, Stand discs, zone, Requiem Arrow guarded by
Silver Chariot Requiem, ten-second activation, results). Read `docs/GAME_FOUNDATION.md`
for the loop, code map, Studio instructions and known gaps.

Assets come from `Main game resources.rbxl` at the repository root, supplied by the user
with permission to use all of it. `tools/extract_resources.luau` extracts what the game
uses into `assets/rbx/` with scripts stripped. `docs/MAIN_RESOURCES_INVENTORY.md` lists
what else is in the file.

Nothing has run in the Roblox engine yet. `python3 tools/check.py` covers formatting,
lint, Roblox API type checks, gameplay rule tests and built-place consistency.

## Likely next work

- Fix whatever the user's first Studio run turns up.
- Stand abilities (none yet; Stands only change stats), starting with Star Platinum.
- Magician's Red needs a model; only its effects are in the resources file.
- Lobby polish, the victory cinematic, combat depth, skin rarity tuning.
- Publishing the private experience and filling in `src/shared/Config/Places.luau`.

## Constraints that still hold

- Keep the work in the cloud. Do not request access to the user's Mac, local files,
  remote desktop or local Studio MCP connection.
- Keep real purchases disabled; don't invent experience ids or credentials.
- Rojo 7.7.1 compatibility; server-owned rules; separate lobby and match places.
- Don't call Lune or static checks a Roblox playtest.
- The rounded procedural Star Platinum prototype stays rejected (`docs/ART_DIRECTION.md`).
- No paid services, subscriptions or GPU rentals.

## Game context

PC-first JoJo battle royale: 32-player solo matches of 15 to 20 minutes, one active Stand
disc plus a spare, the Requiem Arrow at 12:00, activation from 15:00, hard limit 20:00.
Cosmetic skins come from a rotating gacha funded by match rewards (and later, Robux).
`docs/GAME_PLAN.md` holds the full original plan; where it differs from the code, the
user's later instructions (recorded in `docs/GAME_FOUNDATION.md`) win.
