#!/bin/bash
# Publishes this pack to the dot-cloud CDN. Linked addons stay out.
#   tools/publish.sh VERSION [extra publish_pack.sh flags, e.g. --token-file F --dry-run]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V=${1:?usage: tools/publish.sh VERSION [flags]}; shift
exec "$HERE/../dot-cloud/tools/publish_pack.sh" publish --source "$HERE" --id npc-bugged-up --version "$V" \
    --exclude-dir dot_core --exclude-dir dot_npc --exclude-dir dot_npc_ai --exclude-dir dot_profile --exclude-dir examples --exclude-dir tools --exclude-dir screenshots --exclude-dir docs --exclude-dir ci \
    --lock "$HERE/content.lock.json" "$@"
