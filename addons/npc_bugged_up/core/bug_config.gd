class_name BugConfig
extends RefCounted

## Every number that tunes a bug: yml merged over [method defaults] by DotAddonConfig (reached by reflection so an
## older dot-core still parses), then env and argv. With no yml a bug must still spawn.

const CHANNEL := "bug.config"
const ADDON := "npc_bugged_up"
const SPECIES := [&"ant", &"wasp", &"bee"]
const ADDON_CONFIG_PATH := "res://addons/dot_core/core/dot_addon_config.gd"

var data: Dictionary = {}
var source: String = "defaults"


## Distances are metres, times seconds, damage on the host's own scale (a survivor has about 100).
## The `attack` windup is the telegraph: the hit lands at its end and range is rechecked then.
static func defaults() -> Dictionary:
	return {
		"ant": {
			"name": "Soldier Ant", "health": 160.0, "walk_speed": 2.6, "run_speed": 5.4, "sight_range": 28.0, "sight_half_angle": 80.0,
			"hearing_range": 22.0, "eye_height": 1.0, "cost": 2, "body": {"radius": 0.55, "height": 1.25},
			"attack": {"damage": 14.0, "reach": 1.7, "interval": 1.1, "windup": 0.35},
		},
		"wasp": {
			"name": "Giant Wasp", "health": 90.0, "walk_speed": 3.2, "run_speed": 6.8, "sight_range": 34.0, "sight_half_angle": 90.0,
			"hearing_range": 26.0, "eye_height": 1.0, "cost": 3, "body": {"radius": 0.5, "height": 1.2},
			"attack": {"damage": 9.0, "reach": 1.9, "interval": 1.3, "windup": 0.3, "status": "poison", "status_seconds": 4.0},
		},
		"bee": {
			"name": "Giant Bee", "health": 120.0, "walk_speed": 2.8, "run_speed": 5.8, "sight_range": 30.0, "sight_half_angle": 90.0,
			"hearing_range": 24.0, "eye_height": 1.0, "cost": 2, "body": {"radius": 0.55, "height": 1.2},
			"attack": {"damage": 7.0, "reach": 1.6, "interval": 0.9, "windup": 0.25},
		},
	}


static func load_config() -> BugConfig:
	var out := BugConfig.new()
	out.data = defaults()
	if not ResourceLoader.exists(ADDON_CONFIG_PATH):
		return out
	var script: Variant = load(ADDON_CONFIG_PATH)
	if not (script is Script) or not (script as Script).has_method(&"load_dir"):
		return out
	var res: Variant = (script as Script).call(&"load_dir", ADDON, defaults())
	if res is DotResult and (res as DotResult).ok and (res as DotResult).value is Dictionary:
		out.data = (res as DotResult).value
		out.source = String(script.call(&"dir_for", ADDON)) if (script as Script).has_method(&"dir_for") else "cfg"
	elif res is DotResult:
		DotLog.warn(CHANNEL, "bug config refused, using built-in defaults", {"why": (res as DotResult).error.message})
	return out


## One species' tree with every default key present, even when a yml wrote half of it.
func species(id: StringName) -> Dictionary:
	var got: Variant = data.get(String(id), {})
	return _merged(defaults().get(String(id), {}), got if got is Dictionary else {})


static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.get(k) is Dictionary and over[k] is Dictionary:
			out[k] = _merged(out[k], over[k])
		elif typeof(out.get(k)) == typeof(over[k]) or (out.get(k) is float and over[k] is int):
			out[k] = float(over[k]) if out.get(k) is float else over[k]
		elif not out.has(k):
			out[k] = over[k]
	return out


func describe() -> Dictionary:
	return {"source": source, "species": SPECIES.size()}
