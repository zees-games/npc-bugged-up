extends Node3D

## Draws one bug: loads `models/<species>.glb` (a node hierarchy, no skeleton) and animates its named pivots
## from [member anim]. Does nothing in `_process` headless (a server never renders); a suite or screenshot
## calls [method step]. No `class_name`: a mounted pack's globals do not register.

enum Anim { IDLE, WALK, RUN, ATTACK, DEAD }

var species: StringName = &"ant"
var anim: int = Anim.IDLE:
	set(value):
		if value != anim:
			anim = value
			_anim_t = 0.0
## Horizontal speed, m/s, for the gait.
var speed: float = 0.0
## Set by a suite or a screenshot that steps the view itself.
var manual: bool = false

var _anim_t: float = 0.0
var _phase: float = 0.0
var _clock: float = 0.0
var _model: Node3D = null
var _nodes: Dictionary = {}
var _rest: Dictionary = {}
var _fall: float = 0.0


func _ready() -> void:
	var path: String = get_script().resource_path.get_base_dir().get_base_dir().path_join("models/%s.glb" % species)
	var packed: Variant = load(path) if ResourceLoader.exists(path) else null
	if not (packed is PackedScene):
		push_error("BugView: no model at %s" % path)
		return
	_model = (packed as PackedScene).instantiate() as Node3D
	add_child(_model)
	_index(_model)


func _index(n: Node) -> void:
	if n is Node3D and not (n is MeshInstance3D):
		_nodes[String(n.name)] = n
		_rest[String(n.name)] = (n as Node3D).transform
	for c in n.get_children():
		_index(c)


func has_pivot(pivot: String) -> bool:
	return _nodes.has(pivot)


func _process(delta: float) -> void:
	if manual or DisplayServer.get_name() == "headless":
		return
	step(delta)


## Advances the clock and poses every pivot.
func step(delta: float) -> void:
	_anim_t += delta
	_clock += delta
	if anim == Anim.WALK or anim == Anim.RUN:
		_phase += delta * (4.0 + speed * 1.6)
	apply()


func _rot(pivot: String, euler: Vector3) -> void:
	var n: Node3D = _nodes.get(pivot)
	if n != null:
		var rest: Transform3D = _rest[pivot]
		n.transform = Transform3D(rest.basis * Basis.from_euler(euler), rest.origin)


func apply() -> void:
	if _model == null:
		return
	var moving := anim == Anim.WALK or anim == Anim.RUN
	var amp := 0.35 if anim == Anim.WALK else 0.5
	var attack := 0.0
	if anim == Anim.ATTACK:
		attack = sin(clampf(_anim_t / 0.7, 0.0, 1.0) * PI)
	for side in ["L", "R"]:
		for k in 3:
			# Alternating tripod: legs 1 and 3 on one side move with leg 2 on the other.
			var tri := 0.0 if (k % 2 == 0) == (side == "L") else PI
			var swing := sin(_phase + tri) * amp if moving else 0.0
			var lift := maxf(0.0, cos(_phase + tri)) * amp * 0.8 if moving else 0.0
			var sx := -1.0 if side == "L" else 1.0
			_rot("leg%s%d" % [side, k + 1], Vector3(swing * 0.6, 0.0, sx * lift * 0.5))
			_rot("leg%s%d_lo" % [side, k + 1], Vector3(lift * 0.4, 0.0, 0.0))
		_rot("antenna" + side, Vector3(sin(_clock * 3.0 + (1.0 if side == "L" else 0.0)) * 0.12 + attack * 0.4, 0.0, 0.0))
		_rot("mandible" + side, Vector3(0.0, (-1.0 if side == "L" else 1.0) * (0.15 - attack * 0.6), 0.0))
		_rot("wing" + side, Vector3(0.0, 0.0, (1.0 if side == "L" else -1.0) * sin(_clock * 48.0) * (0.55 if anim != Anim.DEAD else 0.0)))
	_rot("abdomen", Vector3(0.12 * sin(_clock * 1.5) - attack * 0.5, 0.0, 0.0))
	_rot("stinger", Vector3(-attack * 0.5, 0.0, 0.0))
	_rot("head", Vector3(attack * 0.5 + sin(_clock * 1.2) * 0.04, 0.0, 0.0))
	var body: Node3D = _nodes.get("body")
	if body != null:
		var rest: Transform3D = _rest["body"]
		var bob := (absf(sin(_phase)) * 0.04 if moving else sin(_clock * 2.0) * 0.01)
		_fall = move_toward(_fall, 1.0 if anim == Anim.DEAD else 0.0, 0.04)
		body.transform = Transform3D(rest.basis * Basis.from_euler(Vector3(-attack * 0.35, 0.0, _fall * PI)), rest.origin + Vector3(0.0, bob - _fall * 0.3, attack * 0.0))
	if anim == Anim.DEAD:
		for side in ["L", "R"]:
			for k in 3:
				_rot("leg%s%d" % [side, k + 1], Vector3(0.0, 0.0, (-1.0 if side == "L" else 1.0) * _fall * 0.9))
				_rot("leg%s%d_lo" % [side, k + 1], Vector3(_fall * 1.2, 0.0, 0.0))


func describe() -> Dictionary:
	return {"species": String(species), "anim": Anim.keys()[anim], "pivots": _nodes.size()}
