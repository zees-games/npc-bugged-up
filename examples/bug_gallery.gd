extends Node3D

## A viewing stage for the bugs and the render target of tools/screenshot.sh.
## Args: `-- --species ant --anims idle,walk,attack,dead --cam three --out /tmp/shot`; each clip is stepped at a
## fixed 60 fps for --t seconds and saved as <out>_<species>_<anim>.png. With no --out it just shows the bug.

const View := preload("../addons/npc_bugged_up/view/bug_view.gd")

var _args := {}
var _view: Node3D = null
var _cam: Camera3D = null


func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	_build_stage()
	_view = View.new()
	_view.species = StringName(String(_args.get("species", "ant")))
	_view.manual = _args.has("out")
	add_child(_view)
	_frame_camera(String(_args.get("cam", "three")))
	if _args.has("out"):
		_run_shots.call_deferred()
	else:
		_view.anim = View.Anim.WALK
		_view.speed = 2.0


func _parse(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < argv.size():
		if argv[i].begins_with("--"):
			out[argv[i].substr(2)] = argv[i + 1] if i + 1 < argv.size() else ""
			i += 2
		else:
			i += 1
	return out


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_energy = 1.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.22, 0.18)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 40.0
	add_child(_cam)


func _frame_camera(mode: String) -> void:
	var target := Vector3(0, 0.55, 0)
	var pos := Vector3(2.6, 1.7, -2.8)
	match mode:
		"side":
			pos = Vector3(3.6, 0.9, 0)
		"front":
			pos = Vector3(0, 1.0, -3.4)
		"top":
			pos = Vector3(0.01, 4.2, 0.4)
	_cam.position = pos
	_cam.look_at(target, Vector3.UP)


func _run_shots() -> void:
	var out := String(_args["out"])
	var species := String(_args.get("species", "ant"))
	var speeds := {"walk": 2.0, "run": 8.0}
	for name in String(_args.get("anims", "idle")).split(","):
		var id: int = View.Anim.get(String(name).strip_edges().to_upper(), -1)
		if id < 0:
			push_error("no clip %s" % name)
			continue
		_view.anim = id
		_view.speed = float(speeds.get(String(name), 0.0))
		for i in int(float(_args.get("t", 0.5)) * 60.0):
			_view.step(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s_%s_%s.png" % [out, species, name]
		get_viewport().get_texture().get_image().save_png(path)
		print("wrote ", path)
	get_tree().quit()
