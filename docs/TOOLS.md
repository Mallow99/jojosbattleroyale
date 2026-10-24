# Tools selected and verified

Assessed October 24, 2026 against the supplied plan and existing cloud handoff.
Everything marked installed below was actually executed in this cloud workspace.

| Need | Selected tool | State and scope |
| --- | --- | --- |
| AI coding, reviews and test design | Codex in this chat | Available now; no additional coding subscription needed |
| Version history | Git checkout and GitHub remote | Project plan, AI handoff and supporting source are maintained in this repository; use the current main branch |
| Lobby/match builds, source maps and sync server | Rojo 7.7.1 | Installed; both fixture builds and loopback endpoint passed |
| Portable Luau tests and place/model inspection | Lune 0.11.1 | Installed; assertions and binary place deserialization passed |
| Strict checks for portable modules | Luau 0.744 analyzer/compiler/CLI | Installed; valid strict fixture accepted and type error rejected |
| Roblox API type checks | luau-lsp 1.70.1 + locked Roblox definitions | Installed; engine API fixture accepted and incorrect property type rejected |
| Formatting | StyLua 2.6.0 | Installed; Luau formatting check passed |
| Lint | Selene 0.32.0 | Installed; Luau fixture passes, undefined variable rejected |
| Models, UVs, materials, rigs and keyframe animation | Blender 4.3.2 + Python API | Already installed; authored, exported and reimported a textured skinned FBX |
| Preview rendering | Blender Cycles on CPU | Render passed; denoising disabled because this build lacks OpenImageDenoise |
| Sound preparation and capture conversion | FFmpeg/FFprobe 7.1.5 | Already installed; WAV and H.264 MP4 encode/probe checks passed |
| Setup and automation | Python 3.12.14 | Already installed; bootstrap/check scripts need only its standard library |
| Remote automated checks | GitHub Actions workflow | Written, not remotely executed; runs code pipeline on push/PR and manually |
| Concept images, icons and texture references | Native image generation in this chat | Available; no new provider account needed; no generation requested in this setup |

CLI and Roblox definition URLs, versions, licenses and hashes are in
`tools/toolchain.lock.json`. Bootstrap installs into `.tools/bin`, without
replacing global tools. Keep the proxy and TLS trust supplied by the environment.
Hashes pin the artifacts acquired during this task; they are not a claim of
independent publisher signature verification.

Blender and FFmpeg come from the managed base image, not the CLI lock. Their
tested versions are listed above. A replacement Debian environment can install
them with `apt-get install blender ffmpeg` when it has package-manager privilege;
run the asset check after any version change. CPU rendering is sufficient for
small previews. Large-scale rendering would need a separate resource decision.

## What the checks prove

`python3 tools/check.py` formats/lints the tooling fixtures, strictly type-checks
the portable fixture, checks Roblox API types with luau-lsp, and builds separate
lobby and match place files and source
maps, checks 19 module/script/property assertions by deserializing the places,
checks that intentional assertion/type/lint failures fail, and starts/stops an
internal Rojo sync endpoint.

`--assets` also creates a 12-triangle original fixture with UVs, a generated PNG
texture, two deform bones, weights and 24 frames of keyframe animation. It saves
the editable Blender scene, exports FBX, renders on CPU and reimports the FBX to
check mesh/rig/UV/animation survival. It then encodes and probes sound and video.
FBX is the selected Roblox delivery format following the
[Roblox export guidance](https://create.roblox.com/docs/art/modeling/export-requirements).
Roblox scale, shading and animation compatibility still need an import test.

The standalone Luau analyzer covers portable modules. Roblox-aware static checks
use luau-lsp with pinned definitions downloaded through the session proxy; these
accepted a real API fixture and rejected assigning a string to Part.Anchored.
Neither analyzer executes Roblox services. Lune API definitions are not configured.
Selene uses the Luau standard library for portable fixtures. Its native Roblox
stdlib generator attempted a direct DNS lookup and failed in this environment;
no proxy policy was changed. Use luau-lsp for engine adapters until a reviewed
Selene Roblox stdlib is added. Do not suppress engine globals across all source.

## Tools needed at later delivery gates

| Gate | Tools/access | Required evidence |
| --- | --- | --- |
| Studio integration | Existing Studio and matching Rojo plugin on user's Mac | Open fixture, inspect Output and import the FBX; cloud needs no local connection |
| Engine unit/integration tests | Studio TestService/TestEZ candidate | Two-client combat/disc tests; physics and replication behavior |
| Services | Private development experience, lobby/match IDs, Roblox client | Queue cancellation, reserved server flow, failed/partial teleports and requeue |
| Persistence | ProfileStore candidate + Roblox DataStore testing | Failed saves, session conflicts, reward replay and durable receipts |
| Performance | Studio/client MicroProfiler and Developer Console | Streaming traversal and progressive real 8/16/32-player measurements |
| Assets | Studio 3D Importer, Animation Editor and experience asset ownership | Materials/scale/rigs plus permitted meshes, animations and sounds |
| Purchases | PolicyService and receipt-processing simulations | Per-player restrictions, odds, retries and durable grants; real sales disabled |
| Deployment | GitHub review; later Roblox publishing or Open Cloud | Correct private experience and explicit deployment evidence |

Studio is a Windows/macOS application, per
[official setup documentation](https://create.roblox.com/docs/studio/setup).
No Studio, cloud Roblox engine runner, Roblox account credentials or place IDs
are exposed here. The saved handoff says Studio is already installed locally;
the older setup paragraph in the pasted plan is stale. Keep the user’s cloud-only
development preference. The [Studio MCP](https://create.roblox.com/docs/studio/mcp)
is optional local automation, outside this cloud setup.

No Wally, extra game framework, database server, paid model service, or separate
hosting service is necessary yet. Add dependency tooling when a reviewed library
is actually adopted. Roblox supplies match hosting and the planned online APIs.
