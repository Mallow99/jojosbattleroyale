#!/bin/sh
# Regenerate meshes, Roblox files and a preview: tools/stand/render.sh <turnaround|cutscene> [fps] [step]
set -e
mode=${1:-turnaround}
B=.tools/blender/blender-4.3.2-linux-x64/blender
python3 art/star_platinum/textures.py >/dev/null
$B -b --factory-startup --python-exit-code 1 --python art/star_platinum/build_morph.py 2>&1 | grep "MORPH OK"
.tools/bin/lune run tools/stand/build.luau
.tools/bin/lune run tools/stand/preview.luau "$mode" "artifacts/preview/$mode.json" "${2:-30}"
rm -rf "artifacts/preview/$mode"
node tools/preview/capture.mjs "artifacts/preview/$mode.json" "artifacts/preview/$mode" "${3:-1}"
