# Reusable resource candidates

Both archives below were acquired from their creators' public repositories on
October 24, 2026. Exact commits, download URLs and SHA-256 values are retained in
`tools/resources.lock.json`; bootstrap restores them into `.tools/resources`.
They are cached source candidates, not integrated or executed game dependencies.
Licenses remain inside each original archive.

| Candidate | Reuse terms at captured revision | Dependencies and permissions | Adaptation work |
| --- | --- | --- | --- |
| [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) | Apache-2.0; preserve license/notices on adoption | Roblox DataStoreService, MessagingService, HttpService and RunService; development experience permissions and API testing required; no art assets supplied | Moderate: explicit data schema, migrations, session handling, durable reward/receipt logic and failure simulations |
| [TestEZ](https://github.com/Roblox/testez) | Apache-2.0; preserve license/notices on adoption | Internal source modules; inspected package manifest lists no runtime package dependencies; run with Roblox/Studio context for engine tests | Low for runner wiring; individual integration tests and engine access still needed |

The review so far inspected license/package files and service/import references.
It is not a full security audit or a test of runtime compatibility. Read the full
selected source and exercise it in isolation before adopting it. ProfileStore's
purpose is documented by [its creator](https://madstudioroblox.github.io/ProfileStore/).

## Main game resources

`Main game resources.rbxl` (repository root) came from the YBA:AU team; the user has
permission to use all of it. Its contents are listed in
`docs/MAIN_RESOURCES_INVENTORY.md`, and the assets the game uses are extracted into
`assets/rbx/` by `tools/extract_resources.luau`. Its meshes, sounds and animations are
Roblox asset IDs, so confirm in Studio that they load in our experience.
