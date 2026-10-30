extends RefCounted

## Puts the bugs in a game's spawn menu; `class_name`-free because a mounted pack's globals do not register.
## `cfg_hint.count` (1 to 4) is honoured. Hits are only recorded until a game sets `runtime.host`.

const Config := preload("core/bug_config.gd")
const Catalogue := preload("core/bug_catalogue.gd")
const Runtime := preload("core/bug_runtime.gd")
const CHANNEL := "bug.spawn"
const MAX_ALIVE := 12

## Zombie Zone draws a pack's bug as one of its own zombie bodies; the quick ones as the leaper.
const BODIES := {&"ant": "common", &"wasp": "leaper", &"bee": "common"}


## The `spawn` shape is the one Zombie Zone's pack scan reads; the menu's Callable is `spawn_fn`.
static func spawn_entries() -> Array[Dictionary]:
	var cfg := Config.load_config()
	var out: Array[Dictionary] = []
	for sp in Config.SPECIES:
		var c := cfg.species(sp)
		var atk: Dictionary = c.get("attack", {})
		out.append({
			"category": "NPCs",
			"id": String(Catalogue.id_of(sp)),
			"name": str(c.get("name", String(sp))),
			"icon": "res://addons/npc_bugged_up/icons/%s.png" % String(sp),
			"kind": "npc",
			"spawn": {
				"health": float(c.get("health", 100.0)),
				"speed": float(c.get("run_speed", 5.0)),
				"damage": float(atk.get("damage", 8.0)),
				"reach": float(atk.get("reach", 1.7)),
				"body": String(BODIES.get(sp, "common")),
			},
			"spawn_fn": Callable(load("res://addons/npc_bugged_up/spawn_provider.gd"), &"_spawn").bind(sp),
			"cfg_hint": {"count": 1, "health": c.get("health"), "special": {"wasp": "poison sting", "ant": "bite", "bee": "fast sting"}.get(String(sp), "")},
		})
	return out


## Runs on the server. Returns a DotResult.
static func _spawn(ctx: Dictionary, species: StringName) -> Variant:
	if not bool(ctx.get("authoritative", false)):
		return DotResult.fail(DotError.CODE_INVALID, "Bugs are spawned by the server.")
	var world: Variant = ctx.get("world")
	if not (world is Node) or not is_instance_valid(world):
		return DotResult.fail(DotError.CODE_INVALID, "No world to put a bug in.")
	var runtime: Object = Runtime.find_or_create(world as Node)
	if runtime.spawner.world_count() >= MAX_ALIVE:
		return DotResult.fail(DotError.CODE_INVALID, "Too many bugs already.")
	var at: Vector3 = ctx.get("at", Vector3.ZERO)
	var hint: Variant = ctx.get("cfg_hint", {})
	var count := clampi(int((hint as Dictionary).get("count", 1)) if hint is Dictionary else 1, 1, 4)
	var made := 0
	for i in count:
		if runtime.call(&"spawn", species, at + Vector3(float(i) * 1.8, 0.0, 0.0), StringName(str(ctx.get("player_id", &"")))) != null:
			made += 1
	DotLog.info(CHANNEL, "spawn menu asked for bugs", {"species": String(species), "made": made})
	if made == 0:
		return DotResult.fail(DotError.CODE_INVALID, "The bug could not be spawned there.")
	return DotResult.success(made)
