# Game foundation

Written October 25, 2026. This describes the first playable-loop code: what exists, how it
fits together, how to try it in Studio, and what is still placeholder. Nothing here has
run in the Roblox engine yet; the cloud checks are static analysis, rule tests and place
builds.

## The loop

1. **Lobby.** Players spawn on a platform, see their Coins and Shards, open the gacha
   banners or their skin collection, and press PLAY to queue.
2. **Queue.** Lobby servers share one MemoryStore queue. A full match starts at 32
   players; after two minutes, 12 to 31 players start with a smaller zone. The server
   holding a short lease reserves a match server and every lobby teleports its own
   assigned players there.
3. **Waiting room.** The match server waits for the expected players (45 s timeout),
   holding them on a platform above the town.
4. **Deploy.** Everyone rides a flight line across the zone; Space drops, and the
   flight's end drops everyone left. Falls are slowed until landing.
5. **Loot.** Nobody starts with a Stand. Discs, Stand Arrows, weapons and Tea lie around
   the town. A disc fills the active slot, then the spare; a third replaces the spare
   and drops it. X swaps (3 s, cancelled by moving or damage), G drops the spare.
6. **Zone.** Five phases shrink the circle toward the final landmark; outside it hurts.
7. **Requiem Arrow.** At 12:00 it appears inside the coming zone, guarded by Silver
   Chariot Requiem. Defeating the boss drops it. The carrier glows and has a marker
   everyone can see. Death or disconnecting drops it somewhere reachable.
8. **Activation.** From 15:00 the carrier holds F at the beacon for ten seconds. Moving,
   taking damage, dying or changing Stand cancels it. Completing it wins. The last
   survivor still has to activate. 20:00 ends the match with no winner.
9. **Results.** Coins are granted (one pull's worth per qualifying match, one more for
   the win), the end screen offers spectating or returning to the lobby, and everyone
   is sent back after 20 s.

## Code map

| Path | Place | What it does |
| --- | --- | --- |
| `src/shared/Config/` | both | Match pacing, zone phases, boss, Stands, loot, gacha, economy, place ids |
| `src/shared/Logic/` | both | Pure rules with tests: gacha, disc slots, channels, zone, match clock, matchmaking, rewards |
| `src/shared/Net.luau`, `Ui.luau` | both | Remote lookup; small UI helpers |
| `src/server/PlayerData.luau` | both | DataStore profiles; match rewards as idempotent pending grants |
| `src/server/Purchases.luau` | lobby | Coin products with receipt idempotency and paid-random-item policy check (disabled) |
| `src/lobby/server/` | lobby | `QueueService` (cross-server queue, teleports), `GachaService` (pulls, crafting, equipping) |
| `src/lobby/client/` | lobby | Lobby UI |
| `src/match/server/` | match | `MatchService` runs the match; Map, Deploy, Zone, Loot, Stand, Combat, Relic, Boss, Channels, Damage |
| `src/match/client/` | match | HUD, input, end screen, spectating |
| `assets/rbx/` | match | Models extracted from `Main game resources.rbxl` |
| `tests/gameplay/` | | Rule tests and built-place consistency checks |

Rules live on the server. Clients only send intents (attack, swap, drop, deploy) and
play their own animations.

## Gacha

The standard banner holds every skin and never leaves. One limited banner is live at a
time and rotates every 14 days through Stardust Crusaders, Diamond is Unbreakable and
Golden Wind, so banners cycle in and out without manual dates (`limitedRotation` in
`src/shared/Config/Gacha.luau`). Featured skins on a limited banner take half of their
rarity's drops. Rates are 60% Common, 35% Rare, 5% Legendary, with a guaranteed Legendary
by pull 20 (separate pity for standard and limited, limited pity carries between limited
banners). Duplicates give a shard; shards craft a chosen skin (3/6/12). The banner panel
shows each skin's exact odds. Skin rarities are first-pass picks to tune.

Coins come from playing (100 per qualifying match, +100 for the win; a pull is 100).
Buying coins with Robux is wired through `Purchases` but stays off until
`Places.purchasesEnabled` is set and product ids exist. Restricted players cannot buy
coins, because coins buy random items. An equipped skin replaces that Stand's model
whenever its disc is active in a match.

## Trying it in Studio

1. Pull the branch, then build both places:

       rojo build lobby.project.json -o lobby.rbxl
       rojo build match.project.json -o match.rbxl

2. Open `match.rbxl` and press Play. Studio skips the queue: the match starts five
   seconds after you load, with any number of players. Use Test > Clients and Servers for
   several players.
3. Late-match phases take 12 to 15 minutes at normal speed. Before pressing Play, select
   Workspace and add a number attribute `DevTimeScale` (for example 10) to speed the match
   clock. It only works in Studio.
4. Open `lobby.rbxl` to try the gacha. Without Studio API access, profiles don't save and
   start with 2,000 test Coins. PLAY queues locally only: teleports don't work in Studio.

Real queue-to-match teleports need the private experience published with both places and
their ids in `src/shared/Config/Places.luau`.

## Placeholders and known gaps

- **Stand abilities are not implemented.** A Stand currently raises punch damage, max
  health and sometimes speed while its disc is active. The disc keeps a cooldown table
  so abilities can be added without changing swapping or dropping.
- **Magician's Red has no model** in the resources file, only its effects
  (`assets/rbx/effects/MagiciansRed.rbxm`). The launch roster uses the eight Stands that
  do have models.
- Combat is a basic melee hitbox so eliminations work. No blocking, combos or knockback.
- The victory "transformation" is an announcement; the cinematic is not built.
- The lobby is a plain platform; there is no lobby practice area yet.
- Terrain from the resources file is not carried over (Rojo cannot sync it). The town's
  ground is parts, so the map stands without it.
- Profiles have no session locking. Match servers only add pending grants and lobby saves
  keep any grant they didn't claim, which covers the lobby/match handoff. Adopt ProfileStore
  if more servers need to write.
- The final landmark is placed in "The Bar" district (`finalLandmarkDistrict`).

## What still needs a real Studio session

Everything engine-side is unverified: that the extracted meshes, animations and sounds
load in our experience, Stand following and animation, deploy gliding and landing,
ProximityPrompts on streamed loot, tool grips, the boss's movement, DataStore saves,
MemoryStore queueing and teleports. Logs or screenshots from the first Studio run will
show what to fix first.
