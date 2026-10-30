extends "res://addons/dot_npc_ai/runtime/dot_npc_ai_brain.gd"

## The mind of every bug: hunt what the senses committed to, then telegraph and land one attack on whoever is
## still in reach. Extends the AI brain by path (a mounted pack's globals do not register). Server-authoritative;
## damage leaves only through the host's methods.

const CHANNEL := "bug.brain"
const Pose := preload("../view/bug_view.gd")
const Host := preload("../core/bug_host.gd")

var species: StringName = &""
var cfg: Dictionary = {}
var host: Object = null
var _next_attack: float = 0.0
var _landed: bool = false
## What a suite reads: how many attacks this bug has started.
var attacks_started: int = 0


func _npc_ready() -> void:
	species = StringName(tune_string(&"species", "ant"))
	var raw: Variant = npc.def.meta.get("cfg", {}) if npc != null and npc.def != null else {}
	cfg = raw if raw is Dictionary else {}
	super()
	var body := _body()
	if body != null and body.has_method(&"setup"):
		body.call(&"setup", species, cfg.get("body", {}))


func _build() -> void:
	machine = DotNpcAiMachine.new()
	initial_state = &"idle"
	var attack: Dictionary = cfg.get("attack", {})
	var windup := _f(attack, "windup", 0.3)
	var idle := DotNpcAiState.make(&"idle", _tick_idle).when(_has_prey, &"hunt")
	var hunt := DotNpcAiState.make(&"hunt", _tick_hunt).when(_no_prey, &"idle")
	hunt.when(_can_attack, &"attack")
	var strike := DotNpcAiState.make(&"attack", _tick_attack.bind(windup))
	strike.on_enter = _enter_attack
	strike.on_exit = _exit_attack
	strike.after(windup + 0.35, &"hunt")
	for s in [idle, hunt, strike]:
		machine.add(s)


func _f(d: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = d.get(key, fallback)
	return float(v) if v is float or v is int else fallback


func _has_prey(_c: DotNpcAiContext) -> bool:
	return npc != null and npc.has_target()


func _no_prey(_c: DotNpcAiContext) -> bool:
	return not _has_prey(_c)


func _can_attack(_c: DotNpcAiContext) -> bool:
	if context.now < _next_attack or not npc.has_target():
		return false
	var attack: Dictionary = cfg.get("attack", {})
	return _flat(npc.position(), target_position(npc.position())) <= _f(attack, "reach", 1.7)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tick_idle(_c: DotNpcAiContext) -> void:
	_set_action(-1)
	if remembers_target():
		steer_along_path(last_known_position(), _f(cfg, "walk_speed", 2.6), context.delta)
	else:
		halt()


func _tick_hunt(_c: DotNpcAiContext) -> void:
	_set_action(-1)
	if not npc.has_target():
		return
	var to := target_position(npc.position())
	var far := _flat(npc.position(), to) > 8.0
	steer_along_path(to, _f(cfg, "run_speed", 5.0) if far else _f(cfg, "walk_speed", 2.6) * 1.4, context.delta)


func _enter_attack(_c: DotNpcAiContext) -> void:
	_landed = false
	attacks_started += 1
	_set_action(Pose.Anim.ATTACK)
	halt()
	face(_dir_to_target())


func _exit_attack(_c: DotNpcAiContext) -> void:
	_set_action(-1)


func _tick_attack(_c: DotNpcAiContext, windup: float) -> void:
	halt()
	var t := machine.elapsed(context.now)
	if t < windup * 0.8:
		face(_dir_to_target())
	if _landed or t < windup:
		return
	_landed = true
	var attack: Dictionary = cfg.get("attack", {})
	_next_attack = context.now + _f(attack, "interval", 1.0)
	var h := _host()
	var fwd := -(npc.node as Node3D).global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var me := npc.position()
	for e in h.call(&"bug_targets"):
		var pos: Vector3 = e["position"]
		var flat := Vector2(pos.x - me.x, pos.z - me.z)
		if flat.length() > _f(attack, "reach", 1.7) + 0.5 or absf(pos.y - me.y) > 3.0:
			continue
		if flat.length() > 0.5 and fwd.dot(Vector3(flat.x, 0.0, flat.y).normalized()) < 0.2:
			continue
		var dir := Vector3(flat.x, 0.0, flat.y).normalized()
		h.call(&"bug_hit", npc, e["id"], _f(attack, "damage", 8.0), &"bite" if species == &"ant" else &"sting", {"impulse": dir * 2.0, "source": me})
		if attack.has("status"):
			h.call(&"bug_status", e["id"], StringName(str(attack["status"])), _f(attack, "status_seconds", 3.0), {"source": me})


func _body() -> Node:
	return npc.node if npc != null else null


func _set_action(anim: int) -> void:
	var b := _body()
	if b != null:
		b.set(&"action", anim)


func _dir_to_target() -> Vector3:
	var to := target_position(npc.position())
	var d := Vector3(to.x - npc.position().x, 0.0, to.z - npc.position().z)
	if d.length() < 0.01:
		return -(npc.node as Node3D).global_transform.basis.z
	return d.normalized()


func _host() -> Object:
	if host != null and is_instance_valid(host):
		return host
	if director != null and director.has_meta(&"bug_host"):
		host = director.get_meta(&"bug_host")
	else:
		host = Host.new(director)
		if director != null:
			director.set_meta(&"bug_host", host)
	return host


func _npc_died(_by: StringName) -> void:
	_set_action(Pose.Anim.DEAD)
	halt()


func describe() -> Dictionary:
	var out := super()
	out["species"] = String(species)
	out["state"] = String(machine.current()) if machine != null else "-"
	out["attacks"] = attacks_started
	return out
