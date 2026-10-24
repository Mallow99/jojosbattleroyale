# Cloud development handoff: JoJo relic battle royale

Historical setup handoff. For current repository status, model decisions and the
next task, read `HANDOFF_NEW_CHAT.md` at the repository root first. Statements
below about creating a repository describe the earlier setup stage.

Prepared October 24, 2026. Copy this document into the root of the new GitHub repository as `HANDOFF.md`, commit it, and push it before starting the cloud chat. This document is self-contained; it does not depend on access to the earlier local chat or any local files.

## User instructions and access boundary

The next development chat runs in the cloud and works from the connected GitHub repository. The user explicitly does NOT want that chat to have access to their computer or local files. Do not request local computer access, a remote desktop, a tunnel, a local executor, or a connection to their local Studio MCP server. Do not ask them to switch development to a local chat.

The previous chat performed setup only. Game implementation starts in the new repository. The user will create the repository and cloud chat themselves. Explain unfamiliar steps clearly, minimize manual work, and keep human work within approximately three hours per week.

## Existing local setup (context only)

Roblox Studio is installed and signed in on the user's Mac. GitHub Desktop is installed and signed in. Official Rojo 7.7.1 and its matching Studio plugin are installed; the command works in a new shell. A minimal Rojo place build succeeded. Live file synchronization was not verified; the cloud chat must not describe it as tested.

A direct Studio MCP connection was configured locally and its session listing/Edit-state query worked. This is a local capability only, is outside the cloud chat's access, and is NOT required for cloud development. No separate AI API key was added. Do not attempt to use or recover that connection from the cloud.

No game code, game repository remote, cloud environment, publishing credentials, paid services, or gameplay playtests were created by the setup chat. A disposable local connection-test folder exists but is not part of the game repository and must not be required or imported.

## Cloud workflow

1. Inspect the connected repository, then establish shared Luau source, separate lobby and match Rojo projects, pinned tools, build commands, useful automated tests, repository instructions, and CI within available free quotas. Reuse Rojo 7.7.1 for compatibility unless a concrete reason requires a coordinated upgrade.
2. Keep the repository authoritative for scripts and reproducible map/assets. Build both places in the cloud. Keep generated build outputs out of ordinary source commits; provide downloadable build artifacts or clear local build instructions.
3. The cloud chat can edit source, test engine-independent Luau logic, inspect code, and run Rojo builds. These checks do not verify engine behavior, replication, asset permissions, Roblox services, teleports, visuals, or 32-player performance. Report those limits explicitly.
4. User pulls approved changes through GitHub Desktop. Locally, they can build/open the place files or connect the Rojo plugin to a local `rojo serve` process. Give beginner-friendly instructions when needed. The AI does not need access to their Mac for this step.
5. User manually opens/tests in Studio or the Roblox client and supplies feedback, relevant logs, or screenshots as needed. Do not require a local AI chat, remote-control bridge, or cloud access to Studio. Do not claim in-engine validation unless evidence is supplied.
6. GitHub publication and Roblox publication are separate actions. Private Roblox experiences, place IDs, publishing credentials, and optional Open Cloud deployment come later, when actually required and authorized. Keep purchases disabled during development.

## Starting the new cloud chat

The user will create a private repository, add this file at its root, commit/push, and configure a Codex Cloud environment for that repository. The opening prompt can simply say:

> Read HANDOFF.md. Work only from this repository in the cloud. Do not request access to my computer or local Studio. Begin the approved implementation with the repository foundation and reproducible lobby/match builds, and clearly distinguish automated checks from engine tests I need to run.

## Approved game direction

- Profit-focused JoJo Roblox battle royale; the user selected a direct JoJo fan-game identity. No creator-authorized reusable YBA source was verified. Evaluate resources for provenance, reuse terms, scripts, dependencies, asset permissions, and adaptation effort before adopting them.
- User has at most about three hours weekly, no development budget, and may accept a small publishing expense later. PC only initially. User leads; partner joins later. Favor AI implementation and focused human feedback.
- Target 32-player solo matches lasting 15–20 minutes on an approximately 1,800 by 1,800 stud map with town center, residential, industrial, ruins, woods, and central landmark districts. Smaller tests do not replace the intended battle royale scale.
- Overhead deployment, basic fists, melee/ranged weapons, healing, Stand Arrows, and swappable discs. Initial Stands: Star Platinum and Magician's Red, with two abilities each plus shared basics.
- One active Stand disc and one spare. Swaps require three stationary, undamaged seconds. Cooldowns stay with discs while stored/dropped. Swaps do not restore health or reset cooldowns. Death drops discs; match discs do not persist.
- Requiem Arrow reveals at minute 12; activation unlocks at minute 15 at the final landmark. Carrying is publicly marked. Ten uninterrupted seconds of stationary activation wins with a transformation cinematic. Damage, movement, death, or Stand changes cancel it. Reachable relic drops on death/disconnect. Minute 20 timeout has no winner; last survivor still activates.
- Separate lobby and reserved match servers; cross-server queue. Start at 32, or after two minutes with 12–31 and a reduced starting area. Below 12 keep waiting with lobby practice. Development bypass must be explicit.
- Cosmetics, currency, settings, lifetime and seasonal stats persist. Match equipment resets. Server owns combat, inventory, cooldowns, objectives, outcomes, rewards, and purchases.
- Preseason first. Future seasons are themed updates and paid cosmetics; defer season pass. Tentative 10–12-week cadence only after an update buffer exists. Preserve purchases and collection progress. Extraction with a permanent Stand collection and juggernaut mode are future separate modes.
- Cosmetic gacha: two Common skins at 30% each, two Rare at 17.5% each, two Legendary at 2.5% each. Legendary guarantee on pull 20 without one (50% per Legendary on guaranteed pull). Duplicates grant one shard; direct crafting costs 3/6/12 shards. One earned pull per qualifying match plus one extra for winning; 50 Robux per paid pull is an initial hypothesis. No paid combat advantages. Actual odds, PolicyService restrictions, separate unpaid access, durable grants and idempotent receipts required. Real purchases remain disabled until validated.
- Delivery order: real repository/workflow; combat/discs; match loop/map; online queue/teleports; progressive 8/16/32-player verification; cosmetics/persistence/purchases; limited Preseason release. No promised launch date.


## Official references

- https://rojo.space/docs/v7/getting-started/installation/
- https://rojo.space/docs/v7/getting-started/new-game/
- https://rojo.space/docs/v7/sync-details/
- https://learn.chatgpt.com/docs/environments/cloud-environments
- https://create.roblox.com/docs/projects/teleport
- https://create.roblox.com/docs/production/monetization/paid-random-items
