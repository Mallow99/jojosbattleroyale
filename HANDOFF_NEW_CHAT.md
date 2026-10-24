# New chat handoff — JoJo Roblox models

Prepared October 24, 2026. This is the latest handoff. Read it before the older
`docs/HANDOFF.md`, which describes an earlier setup stage.

## What I want you to do now

Continue finding and preparing a good **Star Platinum model for our Roblox game**.
Search existing models first. Use the new chat's intended broader network access
to acquire and inspect actual files. Don't restart the tool research or build
another model from generic rounded primitives.

The last model was unacceptable. It did not look like Roblox and did not fit our
game. It was explicitly rejected. Working exports and a rig did not make it a
good asset. The next result needs to meet the visual bar of an actual Roblox JoJo
game, with the right proportions, face, hair, costume and texture work.

## Instructions and constraints

- Work autonomously on research, downloads, inspection, adaptation and checks.
  Don't stop for routine confirmation or make me do work you can do yourself.
- Keep this work in the cloud. Do not request access to my Mac, local files,
  remote desktop, a tunnel or my local Studio MCP connection.
- Favor free resources. No new paid subscriptions, GPU rentals or purchases have
  been approved. A $2 model was found but was not purchased.
- I specifically asked to investigate reused/ripped game models and public Google
  Drive collections as well as creator-shared resources. Those are search leads,
  not verified packages or established reuse permissions. Record what you find
  accurately; don't claim either acquisition or permission without evidence.
- Inspect downloaded packages without running their embedded scripts. Preserve
  provenance, licenses/credits and asset dependencies. Check Roblox permissions
  and compatibility separately from appearance.
- Don't call a concept image a 3D model. Show previews of the actual source or
  adapted geometry and say whose work it is.

## Immediate art direction

Use Roblox humanoid/Stand proportions and an articulated rig as the baseline.
Prioritize existing models designed for Roblox. Identity should come from
well-shaped hair and armor, a convincing face, costume and controlled texture
detail. Avoid the rejected model's rounded toy anatomy, cone hair, stacked muscle
primitives and mannequin face.

YBA-style blocky Roblox versus AUT-style detailed Roblox was asked as an optional
preference. **The user has not answered it. Neither style is approved.** Continue
useful research and present real visual comparisons rather than making that
choice a blocker. The InspWinship thumbnail shown in the last chat is also only
a candidate, not an approved final direction.

Read `docs/ART_DIRECTION.md` for the recorded rejection and selection criteria.

## Network status: verify it first

The user changed environment settings and expects the new chat to have network
access. **That has not been verified for the new chat.** The last running chat
still reported revision 8, `restricted`, `enforced`, with the `package_managers`
preset and no additional allowed hosts. Normal proxied requests to Creator Store,
Roblox asset delivery and Models Resource failed with tunnel 403 errors.

At the start of this chat, read the cloud runtime skill, check the environment
status and applicable network policy, then test an actual required public
download. Preserve the supplied proxy and TLS trust. Do not reuse the old policy
as proof that the new environment is blocked, and do not claim unrestricted
access merely because it was selected in a settings draft.

The previous guidance was: Settings → Codex Cloud → Environments → Edit → Allow
Codex to access internet → Allow domains: All (unrestricted) → Save → Republish.
Existing chats can retain their old working state. Broad network access does not
provide private-account login or API credentials.

## Existing model leads

None of the following model binaries has been acquired in the previous chat.
Listings/previews were researched through web tools. Rigging and actual package
quality remain unverified.

1. **Star Platinum The World Roblox — InspWinship**
   - https://sketchfab.com/3d-models/star-platinum-the-world-roblox-45900749eff04ffab2cc1c0d00d8a84d
   - Source listing reports a free download, CC Attribution, approximately
     120,700 triangles. Creator profile invites use in Roblox games.
   - Relevant Roblox-style candidate, but it is the The World variant and not
     automatically the right costume/version. Inspect geometry and rig; optimize
     only after judging visual fit. A listing's license does not settle unrelated
     underlying rights or Roblox asset permissions.
2. **Star Platinum OVA Roblox — InspWinship**
   - https://sketchfab.com/models/7b6e5108e737462cb4b90486453f0bc7/embed
   - A second Roblox-specific variant. Exact license and package not verified.
   - Creator profile: https://sketchfab.com/InspWinship
3. **Rigged Star Platinum Upgraded — @daiquim**
   - https://create.roblox.com/store/asset/133358155983760/Rigged-Star-Platinum-Upgraded
   - Indexed listing reports 59,057 triangles and 26 MeshParts. The title is not
     proof of a correct, usable rig. Inspect scripts and asset references.
4. **Star Platinum — @IDK_howtodoit**
   - https://create.roblox.com/store/asset/4503106667/Star-Platinum
   - Indexed listing reports 69,006 triangles and 18 MeshParts; not downloaded.
5. **Star platinum Roblox — suthiphan-kha22, CGTrader**
   - https://www.cgtrader.com/3d-models/character/other/star-platinum-roblox
   - Listed at $2 with a marketplace Royalty Free License, BLEND/FBX/OBJ.
     Reference only under the current budget; nothing purchased.
6. **Star Platinum from Eyes of Heaven — uploaded by Ziella**
   - https://models.spriters-resource.com/playstation_4/jojosbizarreadventureeyesofheaven/asset/312605/
   - Listing includes FBX/DAE/PNG, approximately 12 MB. Existing-game lead,
     secondary to Roblox-specific models after the user's style correction.
7. **Star Platinum from Jump Force — uploaded by Ziella**
   - https://models.spriters-resource.com/pc_computer/jumpforce/asset/311360/
   - Listing includes FBX/DAE and multiple material maps, approximately 39 MB.
     Secondary reference; package size does not establish runtime suitability.

An investigated Steam/Google Drive lead was **Daniel J. D'Arby, not Star Platinum**.
Do not pass it off as the requested archive. No verified Star Platinum Drive
collection or creator-authorized reusable YBA source was acquired.

See `docs/MODEL_SEARCH.md` and `assets/model_candidates/star_platinum.json` for
the detailed shortlist and source preview URL. Search beyond these when useful.

## Recommended next work

1. Verify the new environment and restore files/tools if needed.
2. Inspect the Roblox-specific candidates and find additional good free models.
   Compare actual source previews against the intended game style.
3. Acquire the best accessible packages. Log source URL, revision/asset ID,
   checksum, terms, dependencies and acquisition result. Don't execute kits.
4. Inspect meshes, textures, rig/joints, embedded scripts and external asset IDs.
   A high triangle count or the word "rigged" is not a sufficient conclusion.
5. Prepare a credible candidate for Roblox and show honest front/side/back and
   three-quarter previews. Preserve editable source and provide the appropriate
   FBX/GLB/RBXM output, with exact geometry and rig information.
6. Validate exports and deformations where possible. Identify Studio/client
   checks that remain. Do not claim in-engine testing from Blender or Lune.

If the available tools cannot reach the required visual quality, say so plainly
and present concrete source options. Do not substitute another poor primitive
character and label the model problem solved.

## Workspace and repository state

Previous workspace: `/workspace/jojosbattleroyale`.
Remote: https://github.com/Mallow99/jojosbattleroyale.git

The user has asked for the concept, plan and context to be committed and shared
through this repository. The landing branch is `main`; start from the current
GitHub checkout and verify its branch and status. These documents and the
supporting source belong in that checkout. Earlier messages and the older source
bundle described an uncommitted workspace; that was the state before this
publication step, not the intended continuing workflow.

The companion source bundle is a fallback snapshot of the handoff, plan, tools,
tests and notes, including dotfiles. Prefer the repository's current versions.
If restoration is necessary, check for existing work first; do not overwrite
unrelated changes or create another worktree without a reason/user request.

The bundle excludes `.git`, installed binaries/caches, generated artifacts and
the rejected model's binary/render outputs. Restore the pinned tools with
`python3 tools/bootstrap.py`. That script targets Linux x86_64 and uses the
standard Python library. It also restores cached ProfileStore/TestEZ candidates.

Key files:

- `AGENTS.md`, `README.md`: current workspace instructions.
- `docs/GAME_PLAN.md`: the full supplied game plan.
- `docs/ART_DIRECTION.md`, `docs/MODEL_SEARCH.md`: current model task and correction.
- `docs/TOOLS.md`, `docs/AI_TOOLS.md`, `docs/RESOURCES.md`: setup/research findings.
- `tools/bootstrap.py`, `tools/check.py`, lockfiles and tooling fixture tests.
- `.github/workflows/toolchain.yml`: written, not remotely executed.
- `assets/star_platinum/README.md`, `tools/create_star_platinum.py`: explicitly
  rejected historical experiment. Do not run it as the next modeling step.

## Tools already exercised in the previous cloud workspace

| Purpose | Tool |
| --- | --- |
| Place builds, source maps, local sync endpoint | Rojo 7.7.1 |
| Portable Luau tests and place deserialization | Lune 0.11.1 |
| Portable type checks | Luau 0.744 |
| Roblox-aware static API checks | luau-lsp 1.70.1 plus locked definitions |
| Formatting and portable lint | StyLua 2.6.0, Selene 0.32.0 |
| Meshes, rigs, export and CPU previews | Blender 4.3.2 |
| Audio/video conversion and inspection | FFmpeg/FFprobe 7.1.5 |
| Setup scripts | Python 3.12.14 |

`python3 tools/check.py` passed fixture builds, 19 place/module assertions,
type/lint failure controls and a local Rojo endpoint check. `--assets` also passed
the small Blender/FBX/UV/rig/animation/audio/video pipeline fixture. Those are tool
checks, not implemented gameplay or Roblox engine tests. Selene's Roblox stdlib
generator failed in the old proxy setup; Roblox API checks use luau-lsp instead.

ProfileStore and TestEZ were cached at pinned revisions, with Apache-2.0 licenses,
but not integrated or executed. No paid AI service or model account was connected.
Higgsfield was assessed for image/video/promotional work; Meshy/Tripo as optional
3D accelerators. Image generation availability must be checked in the new chat.
GPU-dependent generation models were not installed.

## Game context to preserve

PC-first JoJo Roblox battle royale: 32-player solo matches lasting 15–20 minutes,
an approximately 1,800 × 1,800 stud map across six districts, instance streaming,
separate lobby and reserved match servers, and server-authoritative gameplay.
Initial Stands are Star Platinum and Magician's Red.

Players have one active Stand disc and one spare. Swaps require three stationary,
undamaged seconds. Cooldowns follow each disc while stored/dropped and never
reset on swapping. Death drops discs; match equipment does not persist.

The Requiem Arrow reveals at minute 12. Activation unlocks at minute 15 and
requires ten uninterrupted seconds at the final landmark. Movement, damage,
death or changing Stands cancels it. Carrier is publicly marked; death/disconnect
drops the relic at a reachable location. Last survivor still activates. Minute
20 is a hard timeout with no winner if activation is unfinished.

Cross-server queue starts full matches at 32; after two minutes it permits 12–31
with a reduced starting area. Below 12, wait and offer practice. Development
bypass must be explicit. Cosmetics/settings/currency/stats persist; match discs
do not. Preseason comes first; season pass and extraction mode are deferred.
Keep real purchases disabled. Full economy and test requirements are in the plan.

The user has roughly three hours a week and no development budget. Studio and
Rojo are already installed on their Mac according to the earlier handoff, but
cloud access to that Mac is not permitted. No Roblox publishing credentials,
experience/place IDs or completed engine/multiplayer tests exist in this chat.
There is no playable game implementation yet and no promised launch date.
