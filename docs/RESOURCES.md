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

No creator-authorized YBA kit or reusable Stand model was established. No scraped,
leaked or copied game kit was imported. The Blender fixture is original procedural
test geometry and depends on no outside asset IDs. Environment and Stand packs
should be selected against actual art requirements after the initial blockout.

For each future asset, record source URL, creator, exact revision/asset ID,
license evidence, required credit/notices, dependencies, ownership permissions,
adaptation work, and development-experience import/test results. AI-generated
assets additionally need the provider, generation settings and applicable output
terms. A package license does not establish permission to use unrelated franchise
art, animations or audio inside that package.
