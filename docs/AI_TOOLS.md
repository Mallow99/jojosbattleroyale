# AI tools for this project

Assessment checked October 24, 2026. These are capability and access findings,
not a visual-quality benchmark: no paid-provider generation was run. The baseline
uses tools available here without a new account or development budget.

| Tool | Useful job | Access finding and decision |
| --- | --- | --- |
| Codex | Luau, procedural models, tests, build tools and reviews | Already available; use now |
| Native image generation | Character/Stand references, district concepts, icons and texture drafts | Available in this chat; use when a concrete art task starts |
| AI-directed Blender Python | Actual editable meshes, UVs, textures, rigs, animation and exports | Installed and pipeline-tested; main 3D workflow now |
| Meshy | Text/image-to-3D, texturing, remeshing, rigging and motion | Relevant optional model accelerator; free tier has no API and restrictive downloads; defer paid access |
| Tripo | 3D generation, topology processing, rigging and animation | Relevant optional alternative; web and API access/billing are distinct; no account or key connected here |
| Higgsfield | Generated images, video, shot concepts and promotional clips | Best fit is later concepts/trailers; not a verified Roblox mesh/rig delivery pipeline |
| Runway | Generated/edited promotional video and audio | Plugin found, unconnected; duplicates optional marketing work and is unnecessary now |
| TRELLIS.2 | Self-hosted image-to-3D generation | Official setup requires an NVIDIA GPU with at least 24 GB VRAM; none is exposed in this workspace; defer |
| TripoSR | Open-source image-to-3D baseline | Defaults use about 6 GB VRAM; CPU paths exist but no useful inference benchmark here; defer large weights/dependency setup |

## Higgsfield in plain language

Higgsfield is a service for making AI images and videos, with several underlying
generation models and creative workflows. For this project it could help design
a cinematic shot or make promotional material. Generated footage does not give
us the controllable character meshes, skeletons, collision or combat systems
needed inside Roblox. Its API uses a separate prepaid balance from its website
subscription and currently requires a $5 minimum top-up.
[Official API explanation](https://higgsfield.ai/creator-hub/help-center/integrations/what-is-the-higgsfield-api).

A supported Higgsfield plugin was found in the plugin directory, but it is not
installed or connected. Connecting requires the user's Higgsfield account. It
is optional and does not block the existing image/Blender workflow. No account,
subscription, API key, purchase or connection was created during this task.

## Which 3D service would be worth trying?

If a budget becomes available, compare Meshy and Tripo on the same small asset
brief before choosing either. Measure import success, cleanup time, silhouettes,
UVs, texture consistency, topology and skin deformation. Try a simple prop first;
evaluate a Stand character only after that. An attractive preview is insufficient
evidence of a usable Roblox character. Generated rig presets may require
retargeting to our chosen Roblox skeleton.

Meshy's current free plan allows limited downloads of untextured Meshy 6 Lite
models, excludes textured downloads, requires attribution, and does not provide
API access. This prevents assuming its free plan can supply an unattended
textured-asset pipeline.
[Free plan details](https://help.meshy.ai/en/articles/15696428-what-is-included-on-the-free-plan),
[API access and costs](https://help.meshy.ai/en/articles/16815622-how-many-credits-does-each-meshy-api-task-cost).

Tripo's current web documentation lists free credits, export/version restrictions
and attribution requirements. Its developer API publishes separate pay-as-you-go
costs for generation, rigging and retargeting. No API free quota or commercial
rights beyond the documented plan terms have been assumed.
[Web pricing and licensing](https://www.tripo3d.ai/product-doc/getting-started/pricing-credits),
[API pricing](https://developers.tripo3d.ai/en/pricing),
[rigging workflow](https://www.tripo3d.ai/product-doc/module-post-processing/rigging-animation).

Self-hosting avoids a generation subscription but still requires compatible
hardware, model downloads, dependency builds and time. Do not rent GPUs or fetch
many gigabytes of weights simply to add a tool name to the project.
[TRELLIS.2 prerequisites](https://github.com/microsoft/TRELLIS.2#-installation),
[TripoSR requirements](https://github.com/VAST-AI-Research/TripoSR#getting-started).

## Production workflow selected now

Use generated references when helpful, then create or clean actual geometry in
Blender. Keep `.blend` sources and deterministic Python scripts. Export FBX and
textures, validate geometry/UVs/weights, import into the development experience,
and test rigging, streaming and performance. Build gameplay animation, particles,
hitboxes and timings as game systems. Use FFmpeg for audio preparation and review
clips, with original or appropriately licensed production audio.

The present Blender fixture proves authoring/export tools work; it does not
prove polished character-art quality. The same asset ownership/reuse review in
the game plan applies to generated and downloaded resources.
