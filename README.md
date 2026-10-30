# npc-bugged-up

A pack of human-sized insects for Godot 4: a soldier ant (bite), a giant wasp (poisoning sting) and a giant bee (fast sting). Built on dot-npc and dot-npc-ai, delivered as a dot-cloud pack, and spawnable from any game's spawn menu.

## Use

Link the pack into a game's `addons/` and let the game's pack scan read `provides.json`. Numbers are in `cfg/addons/npc_bugged_up/*.yml`. The game supplies damage through a host object with `bug_targets()`, `bug_hit(npc, victim, amount, kind, info)` and `bug_status(victim, status, seconds, info)`, set as meta `bug_host` on the `DotNpcSpawner`.

## Tests and pictures

`./game.sh test` parses every script and runs the suites. `tools/screenshot.sh --all` writes frames to `screenshots/`. `tools/build_bugs.sh` rebuilds the models (Blender 4.x).

## Credits

The models are original work, built from primitives by `tools/build_bugs.py`, released CC0-1.0. No third-party art is included. See [CREDITS.md](CREDITS.md) and `licence.json`.
