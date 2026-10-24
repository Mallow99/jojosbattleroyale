# Star Platinum model search

Checked October 24, 2026. The user requested existing models first, including
game-rip and Google Drive leads, with an example model as fallback.

| Candidate | Evidence found | Acquisition and adaptation status |
| --- | --- | --- |
| [Eyes of Heaven / PS4, uploaded by Ziella](https://models.spriters-resource.com/playstation_4/jojosbizarreadventureeyesofheaven/asset/312605/) | Listing identifies Star Platinum, with FBX, DAE and PNG files in an approximately 12 MB archive | Strong existing-game asset lead. Binary not acquired; download hosts are outside this cloud workspace's HTTP allowlist. Mesh, rig and texture integrity unverified. |
| [Jump Force / PC, uploaded by Ziella](https://models.spriters-resource.com/pc_computer/jumpforce/asset/311360/) | Listing includes Star Platinum FBX/DAE and multiple material maps in an approximately 39 MB archive | Strong detailed-model lead. Binary not acquired; same network constraint. Would require material conversion, geometry/rig inspection and a Roblox import test. |
| [Rigged Star Platinum Upgraded, @daiquim](https://create.roblox.com/store/asset/133358155983760/Rigged-Star-Platinum-Upgraded) | Search-index listing reports 59,057 triangles and 26 MeshParts | Potential Roblox-native starting point; no asset package acquired or scripts run. Ownership, embedded scripts and upload permissions remain unverified. |
| [Star Platinum, @IDK_howtodoit](https://create.roblox.com/store/asset/4503106667/Star-Platinum) | Search-index listing reports 69,006 triangles and 18 MeshParts | Potential Roblox-native alternative. Counts need verification against a downloaded package; no in-engine test. |
| [InspWinship's Star Platinum The World](https://sketchfab.com/3d-models/star-platinum-the-world-roblox-45900749eff04ffab2cc1c0d00d8a84d) | Indexed as a free-download model; profile invites use in Roblox games | Detail page returned 403 to the browser tool. Exact license and package contents not verified. |
| [JoJo Source Filmmaker collection](https://steamcommunity.com/sharedfiles/filedetails/?id=1558660821) | Contains JoJo game ports and a Google Drive link | The inspected Drive link belongs to Daniel J. D'Arby, not Star Platinum. It is not evidence of the requested Star Platinum archive. Steam collection is marked removed/incompatible. |

Searches included Star Platinum + Google Drive, JoJo/Eyes of Heaven model packs,
YBA + Google Drive, Roblox Creator Store, Models Resource and Sketchfab. No
verified reusable YBA source or Star Platinum Google Drive package was acquired.
The existence of a listing is distinct from verified package contents and reuse
permission; permission to republish these game assets was not established.

## Updated direction after user rejection

The user rejected the original rounded prototype. Prioritize Roblox-specific
models and rig proportions now; the Eyes of Heaven and Jump Force game assets
below are secondary technical references, not the chosen visual direction.
See `docs/ART_DIRECTION.md` and `assets/model_candidates/star_platinum.json`.

Useful current candidates:

- [Star Platinum The World Roblox, InspWinship](https://sketchfab.com/3d-models/star-platinum-the-world-roblox-45900749eff04ffab2cc1c0d00d8a84d):
  source listing describes a free Roblox model and lists CC Attribution. It
  reports about 120,700 triangles, so it needs geometry/rig inspection and possible
  optimization. The preview is a style reference, not an acquired game asset.
- [Star Platinum OVA Roblox, InspWinship](https://sketchfab.com/models/7b6e5108e737462cb4b90486453f0bc7/embed):
  another Roblox-specific variant from the same profile. Detail-page access and
  binary/rig/license verification remain incomplete.
- [Star platinum Roblox, suthiphan-kha22](https://www.cgtrader.com/3d-models/character/other/star-platinum-roblox):
  Roblox-style source offered in BLEND/FBX/OBJ for $2 under the marketplace's
  listed Royalty Free License. Reference only; nothing purchased. Rigging and
  actual package quality remain unverified.

The active runtime was rechecked after the user changed environment settings:
revision 8 still reports enforced restricted networking with only the package
manager preset. Normal proxied HTTP requests to Creator Store, Roblox asset
delivery and Models Resource all failed with tunnel 403 errors. No attempt was
made to bypass that policy. New environment settings have not reached this VM.

## Secondary existing-game candidates

Inspect the Eyes of Heaven package first if network access becomes available:
it offers a smaller source archive than Jump Force, but archive size alone does
not establish a lower triangle count or better runtime performance. Treat both
as technical candidates. Review terms and credits, inspect files without executing
scripts, count geometry/materials, inspect the skeleton and weights, convert
materials and test a private Roblox import before selecting a production asset.

For the 32-player game, account for the character and Stand rendering together.
The Creator Store candidates' listed triangle counts justify a closer performance
check; they do not on their own prove that the models are too expensive.

The original rounded prototype in `assets/star_platinum/README.md` is explicitly
rejected. Do not use it as a substitute for these candidates or as a quality bar.
