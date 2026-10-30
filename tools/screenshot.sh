#!/usr/bin/env bash
#
# Render a bug and save frames, so a person can look at it.
#
#   tools/screenshot.sh ant                            # screenshots/three_ant_<clip>.png
#   tools/screenshot.sh wasp --anims idle,walk,attack,dead --cam side --t 0.4
#   tools/screenshot.sh --all                          # every bug, idle
#
# Clips are stepped at a fixed 60 fps for --t seconds (default 0.5). Not --headless: that driver saves a black
# PNG. This runs the real renderer on an Xvfb framebuffer (Mesa llvmpipe).
set -uo pipefail
cd "$(dirname "$0")/.."
command -v Xvfb >/dev/null || { echo "Xvfb not installed (apt install xvfb)" >&2; exit 3; }
OUT_DIR="${OUT:-screenshots}"
mkdir -p "$OUT_DIR"; touch screenshots/.gdignore 2>/dev/null || true
SPECIES=(); ANIMS="idle,walk,attack"; CAM="three"; T="0.5"
while [ $# -gt 0 ]; do
    case "$1" in
        --all) SPECIES=(ant wasp bee); shift ;;
        --anims) ANIMS="$2"; shift 2 ;;
        --cam) CAM="$2"; shift 2 ;;
        --t) T="$2"; shift 2 ;;
        -h|--help) sed -n '2,/^set/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) SPECIES+=("$1"); shift ;;
    esac
done
[ ${#SPECIES[@]} -gt 0 ] || SPECIES=(ant)
for sp in "${SPECIES[@]}"; do
    disp=$((90 + RANDOM % 8))
    Xvfb ":$disp" -screen 0 "1280x720x24" >/dev/null 2>&1 &
    xpid=$!
    sleep 1.5
    DISPLAY=":$disp" LIBGL_ALWAYS_SOFTWARE=1 timeout 180 godot --path . --resolution 1280x720 \
        --rendering-driver opengl3 res://examples/bug_gallery.tscn -- \
        --species "$sp" --cam "$CAM" --anims "$ANIMS" --t "$T" --out "$OUT_DIR/$CAM" 2>&1 | grep -i "error\|wrote"
    kill "$xpid" 2>/dev/null
done
