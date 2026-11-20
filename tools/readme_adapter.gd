extends RefCounted

## The README studio's view of this pack (dot-bootstrap tools/readme/, run by tools/gen_readme.sh): which bugs, their
## models and poses, and the default-profile rows the README prints. Every number is read from the pack's effective
## config (BugConfig: the built-in defaults merged with cfg/addons/npc_bugged_up/*.yml) and the catalogue's NPC
## definition, never typed here.

const Config := preload("res://addons/npc_bugged_up/core/bug_config.gd")
const Catalogue := preload("res://addons/npc_bugged_up/core/bug_catalogue.gd")
const View := preload("res://addons/npc_bugged_up/view/bug_view.gd")

const SPEEDS := {"walk": 2.6, "run": 5.4}

var _cfg: Config = Config.load_config()


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for sp in Config.SPECIES:
		out.append(String(sp))
	return out


func model(id: String) -> Node3D:
	var v := View.new()
	v.species = StringName(id)
	v.manual = true
	return v


## Step the clip at a fixed 60 fps for `t` seconds, so the same pose is the same picture every run.
func pose(node: Node3D, id: String, pose_name: String, opts: Dictionary) -> void:
	var anim: int = View.Anim.get(pose_name.to_upper(), -1)
	if anim < 0:
		push_error("readme_adapter: %s has no clip %s" % [id, pose_name])
		return
	node.set("anim", anim)
	node.set("speed", float(opts.get("speed", SPEEDS.get(pose_name, 0.0))))
	var steps := int(float(opts.get("t", 0.5)) * 60.0)
	for i in steps:
		node.call("step", 1.0 / 60.0)


func profile(id: String) -> Dictionary:
	var c := _cfg.species(StringName(id))
	var def := Catalogue.def_for(StringName(id), _cfg)
	var weight := {DotNpcDef.Weight.NORMAL: "Normal", DotNpcDef.Weight.HEAVY: "Heavy", DotNpcDef.Weight.BOSS: "Boss"}
	var a: Dictionary = c.get("attack", {})
	var verb := "Sting" if id != "ant" else "Bite"
	var hit := "%s damage, %s m reach, every %s s (%s s windup)" % [_n(a.get("damage")), _n(a.get("reach")), _n(a.get("interval")), _n(a.get("windup"))]
	if str(a.get("status", "")) != "":
		hit += "; %s for %s s" % [a.status, _n(a.get("status_seconds"))]
	var body: Dictionary = c.get("body", {})
	var rows: Array = [
		["Health", _n(def.max_health)],
		["Speed", "%s m/s walking, %s m/s running" % [_n(c.get("walk_speed")), _n(c.get("run_speed"))]],
		[verb, hit],
		["Sight", "%s m, %s deg cone" % [_n(def.sight_range), _n(def.sight_half_angle_deg * 2.0)]],
		["Hearing", "%s m" % _n(def.hearing_range)],
		["Weight class", weight.get(def.weight, str(def.weight))],
		["Spawn cost", _n(def.cost)],
		["Body", "%s m tall, %s m radius" % [_n(body.get("height")), _n(body.get("radius"))]],
	]
	var dmg := "%s %s" % [_n(a.get("damage")), verb.to_lower()]
	if str(a.get("status", "")) != "":
		dmg += " + %s" % a.status
	return {
		"name": def.display_name,
		"npc_id": String(def.id),
		"summary": {"Health": _n(def.max_health), "Damage": dmg, "Weight": weight.get(def.weight, "")},
		"rows": rows,
	}


## A number as a reader writes it: 160, 0.35, 5.4.
static func _n(v: Variant) -> String:
	if v == null:
		return "-"
	var f := float(v)
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return ("%.2f" % f).rstrip("0").rstrip(".")
