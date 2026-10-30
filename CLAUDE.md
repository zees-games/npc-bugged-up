# npc-bugged-up

Read the family [CLAUDE.md](../../CLAUDE.md) first. Three human-sized insects (soldier ant, giant wasp, giant bee) on dot-npc and dot-npc-ai, for Zombie Zone and any game that adds a pack.

- No `class_name` in pack-loaded scripts (`runtime/`, `view/`, `spawn_provider.gd`): they extend and preload by path. `core/` has class names.
- Every attack is a telegraph then a landing against whoever is still in range and in front. All numbers live in `cfg/addons/npc_bugged_up/*.yml` and `core/bug_config.gd`.
- Damage leaves through the host seam (`bug_targets`, `bug_hit`, `bug_status`, set as meta `bug_host` on the spawner); never import a combat addon.
- Models are build products: `tools/build_bugs.sh` runs `tools/build_bugs.py` in headless Blender. They are node hierarchies with named pivots (no skeleton); `view/bug_view.gd` animates the pivots.
- A server draws nothing: `BugView` does nothing in `_process` headless.
- Test: `./game.sh --no-parse test bug_selftest`. Look: `tools/screenshot.sh --all` (needs Xvfb; headless renders black).
