# Revised plan: 32-player JoJo battle royale

## 1. Game direction and match structure

Build toward **32-player solo matches lasting 15–20 minutes**, with a larger map, swappable Stand discs, and victory through successful relic activation.

Smaller development tests will validate individual systems. They will not replace the intended battle royale format.

| Element | Revised starting specification |
|---|---|
| Map | Approximately 1,800 × 1,800 studs, with six distinct loot districts |
| Geography | Town center, residential streets, industrial area, ruins, wooded outskirts, and a central landmark |
| Deployment | Brief overhead deployment with selectable drop timing and controlled descent |
| Equipment | Basic fists, world weapons, healing items, Stand Arrows, and Stand discs |
| Stands | Star Platinum and Magician’s Red initially; shared framework supports later additions |
| Inventory | One active Stand disc and one spare |
| Objective | One Requiem Arrow, followed by a contested activation and victory transformation |
| Persistence | Cosmetics, currency, settings, statistics, and seasonal progress |
| Initial devices | PC |

Use modular buildings and selective interiors. Make districts recognizable through layout, landmarks, lighting, and materials. Enable instance streaming and test traversal through unloaded areas; Roblox recommends streaming for larger worlds. [Streaming documentation](https://create.roblox.com/docs/workspace/streaming).

**Initial pacing defaults:**

- Minutes 0–5: deploy, acquire equipment, and choose a Stand.
- Minutes 5–12: closing zones encourage movement and encounters.
- Minute 12: reveal the relic at a location inside the remaining safe area.
- Minute 15: unlock activation at the marked final landmark.
- Activation requires ten uninterrupted seconds. Movement, damage, death, or changing Stands cancels it.
- Successful activation triggers the transformation and ends the match. Minute 20 is the hard limit; unfinished matches have no winner.

The carrier receives a public marker. Death or disconnect drops the relic at a reachable location. The last survivor still completes activation.

Use a separate lobby and reserved match servers so eliminated players can immediately queue again. Start full matches when 32 players are ready; after a two-minute queue wait, permit 12–31 players with a reduced starting play area. Below 12, keep waiting and offer lobby practice. Development sessions can explicitly bypass this minimum.

A shared cross-server queue avoids splitting a small audience across isolated lobbies. Roblox documents this lobby-to-match pattern using MemoryStore queues. [Matchmaking building blocks](https://create.roblox.com/docs/cloud-services/memory-stores/queue).

## 2. Stand discs, reusable resources, and seasons

### Stand discs

Choose **one active disc and one spare**. This gives players meaningful swapping without building a large inventory system.

- A Stand Arrow grants a random base Stand, represented by an equipped disc.
- Found discs can enter the spare slot; replacing a full slot drops its previous disc.
- Swapping takes three seconds and is interrupted by damage or movement.
- Cooldowns belong to each disc and continue while stored or dropped. Swapping never restores health or resets abilities.
- Eliminated players drop their discs.
- Your equipped cosmetic automatically applies when you acquire its matching Stand.
- Match discs disappear when the match ends.

An extraction mode that lets players keep Stand discs is a later, separate mode. Its persistent collection and loss economy should not affect the initial battle royale.

### Existing resources

Resource reuse becomes an early workstream, before creating polished assets.

Search for creator-released Stand kits, reusable rigs and animations, environment packs, effects, UI components, and established utility libraries. For example, [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) provides saving and session-locking functionality worth evaluating.

**YBA resources are candidates to investigate; no reusable, creator-authorized YBA source has been verified yet.** A copied game being widespread does not establish permission or compatibility.

For each candidate, record its source, reuse terms, dependencies, required asset permissions, and adaptation cost. Inspect scripts in an isolated test place before running them. Verify meshes, animations, and audio under our experience’s ownership; an asset working in its original game does not establish that it will load in ours. [Roblox asset permissions](https://create.roblox.com/docs/projects/assets/packages).

Adopt useful components individually. Keep match rules, combat validation, inventory, and purchases understandable and maintained in our repository.

### Seasons

Launch with **Preseason**, followed by themed content updates and paid cosmetic releases. Defer a season pass.

- Keep the first gacha banner permanent during Preseason.
- A season can introduce cosmetics, a landmark change, balance adjustments, and an optional Stand or relic when ready.
- Start with a tentative 10–12-week content cadence only after an update buffer exists.
- Preserve purchased cosmetics, currency, and collection progress across seasons.
- Store seasonal statistics separately from lifetime statistics.
- Avoid paid gameplay advantages and seasonal wipes of purchases.
- Revisit a pass after repeat play and production capacity justify another progression system.

Do not promise new Stands, maps, and relics every season. The content schedule must fit the actual workload.

## 3. Technical and commercial foundation

Use one GitHub repository with shared gameplay modules and separate lobby and match builds. Maintain a private development experience and a separate production experience before public launch.

The server owns combat validation, disc inventory, cooldowns, relic possession, match outcomes, rewards, and purchases. Add configuration for match size, zone timings, loot, Stand definitions, cosmetics, and seasons.

The development workflow is:

**GitHub → Codex cloud tasks → reviewed source → local Rojo sync/build → Studio tests → private Roblox playtests → production release.**

Rojo synchronizes project files into Studio and builds place files. Treat repository files as authoritative for scripts. Capture approved Studio-created models back into the project; Studio changes do not automatically become GitHub changes. Terrain and some properties have live-sync limitations, so the initial map should favor reproducible modular models. [Rojo workflow and limitations](https://rojo.space/docs/v7/sync-details/).

Keep the previous cosmetic-gacha defaults for Preseason:

- Six skins: two Common at 30% each, two Rare at 17.5% each, and two Legendary at 2.5% each.
- Guaranteed Legendary on pull 20 without one; either Legendary has a 50% chance on that pull.
- Duplicates grant one shard; specific skins cost 3/6/12 shards by rarity.
- One earned pull for a qualifying completed match, plus one extra for winning.
- Initial paid-pull hypothesis: 50 Robux.

Display actual odds, enforce per-player paid-random-item restrictions, and provide the separate unpaid acquisition route. Save purchase grants durably and make receipt retries safe. Enable real purchases only after persistence and purchase simulations pass. [Paid random item requirements](https://create.roblox.com/docs/production/monetization/paid-random-items).

## 4. Beginner setup walkthrough

Walk through this **one checkpoint at a time**, explaining unfamiliar controls as they appear. You already have GitHub Desktop installed; Roblox Studio was not found in the standard Applications folders.

| Step | Your part | AI part and completion check |
|---|---|---|
| **1. Install Studio** | Download [Roblox Studio](https://create.roblox.com/docs/studio/setup), install it, and sign into your Roblox account | Help resolve installation or login issues. Checkpoint: Studio’s home screen opens |
| **2. Learn the essentials** | Create a Baseplate; learn camera movement, Explorer, Properties, Output, Play, and Stop | Guide a short exercise. Checkpoint: you can run and stop the empty place and find its objects |
| **3. Initialize this folder** | No manual file creation required | Initialize the existing project folder, Git history, starter documentation, build configuration, and ignored generated files |
| **4. Publish to GitHub** | In GitHub Desktop, choose **File → Add Local Repository**, select this project folder, then **Publish repository**, keeping it private | Check the repository contains the intended files. Checkpoint: the files appear on GitHub |
| **5. Connect Codex Cloud** | Choose **Work in → Cloud → Create environment**, authorize the repository, and complete account prompts | Configure pinned development tools and run the first build/check. Checkpoint: a cloud task builds the project successfully |
| **6. Connect Studio automation** | Open Studio’s **Assistant → … → Manage MCP Servers**, enable Studio as an MCP server, and complete the supported Codex connection flow | Verify access to the correct Studio session and run a harmless inspection/playtest. Checkpoint: the client reads the place and starts/stops a test |
| **7. Connect Rojo** | Install the official Rojo Studio plugin and connect to the local server when guided | Install the matching command-line tool, build the starter place, and start synchronization. Checkpoint: a repository change appears in Studio |
| **8. Publish a private development game** | Use Studio’s **File → Publish** flow, retain private access, and complete necessary account prompts | Record the experience and place IDs; guide creation of the lobby and match places. Checkpoint: the development game appears in Creator Hub |
| **9. Test through Roblox** | Join through the Roblox client with an approved tester | Verify lobby-to-match teleporting and return flow. Teleports require published-client testing; Studio alone cannot validate them |
| **10. Establish normal updates** | Practice fetching changes in GitHub Desktop, opening Studio, testing, and reporting feedback | Provide repeatable build/test commands and a short checklist. Checkpoint: you can test a new AI-built version without editing code |

Official references: [GitHub Desktop publishing](https://docs.github.com/en/desktop/adding-and-cloning-repositories/adding-an-existing-project-to-github-using-github-desktop?platform=mac), [Codex cloud environments](https://learn.chatgpt.com/docs/environments/cloud-environments), [Studio MCP](https://create.roblox.com/docs/studio/mcp), [Rojo setup](https://rojo.space/docs/v7/getting-started/new-game/), and [teleport testing](https://create.roblox.com/docs/projects/teleport).

Cloud tasks handle coding and automated checks while your Mac is off. Local Studio automation requires your Mac and Studio to remain available. Your account interactions and subjective playtesting remain your responsibility.

## 5. Delivery gates and next action

1. **Workflow:** GitHub, cloud build, Rojo sync, Studio automation, and private publishing all work.
2. **Combat and discs:** one Stand, two clients, swapping, cooldown preservation, dropping, and pickup.
3. **Battle royale:** full map blockout, second Stand, deployment, zones, relic victory, and round cleanup.
4. **Online flow:** queue, reserved servers, failed-teleport recovery, elimination, requeue, and durable results.
5. **Scale verification:** progressively test 8, 16, then 32 connected players. Synthetic activity can stress systems but does not replace a real 32-player session.
6. **Collection and release:** add polished cosmetics, purchase handling, analytics, and release eligibility checks.
7. **Preseason learning:** measure queue waits, early deaths, match completion, repeat play, performance, and spending before committing to seasonal production.

Tests include simultaneous pickups, disc duplication attempts, cooldown bypasses, carrier disconnects, streamed-out objectives, queue cancellation, partial teleport failures, repeated rewards, receipt retries, and failed saves.

The larger format adds substantial map, networking, matchmaking, and population work. Keep the three-hour weekly limit by making AI deliver small, testable changes and using your time for focused reviews. Do not commit to a release date yet.

**The first guided session starts with installing Studio and running a Baseplate.** Its goal is a working development connection—not building the map or store.
