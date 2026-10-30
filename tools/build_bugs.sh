#!/usr/bin/env bash
# Rebuild the insect models from primitives. Usage: tools/build_bugs.sh [species...]
set -euo pipefail
cd "$(dirname "$0")/.."
SP=("$@"); [ ${#SP[@]} -gt 0 ] || SP=(ant wasp bee)
for s in "${SP[@]}"; do
    blender -b --factory-startup --python tools/build_bugs.py -- "$s" "addons/npc_bugged_up/models/$s.glb" 2>&1 | grep -E "BUILT|Error|Traceback" || true
done
