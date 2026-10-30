extends Node

## Proves the bugs load, pose their pivots, read their numbers from yml, and that an attack lands once for
## the configured damage and only when the target is in reach. Run: `./game.sh test bug_selftest`.
## How it looks is `tools/screenshot.sh` and somebody looking.

const View := preload("../addons/npc_bugged_up/view/bug_view.gd")
const Config := preload("../addons/npc_bugged_up/core/bug_config.gd")
const Catalogue := preload("../addons/npc_bugged_up/core/bug_catalogue.gd")
const Host := preload("../addons/npc_bugged_up/core/bug_host.gd")
const Provider := preload("../addons/npc_bugged_up/spawn_provider.gd")

const CHECKS := 37
const SECTIONS := 6

var _passed := 0
var _failed := 0
var _failures := PackedStringArray()
var _entered := 0
var _completed := 0
var _world: Node3D = null


func _ready() -> void:
	DotLog.set_level(DotLog.Level.ERROR)
	_run.call_deferred()


func _run() -> void:
	print("npc_bugged_up self-test")
	_world = Node3D.new()
	add_child(_world)
	_floor()

	_test_config()
	_test_catalogue()
	_test_models()
	await _test_ant()
	await _test_wasp()
	_test_provider()

	print("")
	print("%d passed, %d failed" % [_passed, _failed])
	for line in _failures:
		print("  FAIL  %s" % line)
	print("%d of %d sections ran to their last line" % [_completed, _entered])
	if _entered != SECTIONS or _completed != _entered:
		print("ERROR: %d sections entered and %d completed, %d expected." % [_entered, _completed, SECTIONS])
		get_tree().quit(1)
		return
	if CHECKS != 0 and _passed + _failed != CHECKS:
		print("ERROR: %d checks ran, %d expected. A section aborted part-way." % [_passed + _failed, CHECKS])
		get_tree().quit(1)
		return
	get_tree().quit(1 if _failed > 0 else 0)


func _section(title: String) -> void:
	_entered += 1
	print(title)


func _done() -> void:
	_completed += 1


func _check(ok: bool, what: String, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % what)
	else:
		_failed += 1
		_failures.append(what if detail == "" else "%s (%s)" % [what, detail])
		print("  FAIL  %s" % (what if detail == "" else "%s (%s)" % [what, detail]))


func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	body.position.y = -0.5
	body.name = "Floor"
	_world.add_child(body)


func _arena(tweak: Callable = Callable()) -> Dictionary:
	# The last scenario's bugs would still stand at the origin and the next would spawn inside them.
	for c in _world.get_children():
		if c.name != "Floor":
			_world.remove_child(c)
			c.queue_free()
	var cfg := Config.load_config()
	if tweak.is_valid():
		tweak.call(cfg.data)
	var spawner := DotNpcSpawner.new()
	spawner.authoritative = true
	spawner.catalogue = Catalogue.build(cfg)
	_world.add_child(spawner)
	var host := Host.new(spawner)
	spawner.set_meta(&"bug_host", host)
	return {"spawner": spawner, "host": host}


func _prey(spawner: DotNpcSpawner, at: Array) -> void:
	var list: Array = []
	var i := 0
	for p in at:
		list.append(DotNpcSenses.Candidate.new(StringName("p%d" % i), p, &"player", 100.0))
		i += 1
	spawner.set_candidates(list)


func _sim(spawner: DotNpcSpawner, seconds: float) -> void:
	for i in int(seconds * 60.0):
		spawner.tick(1.0 / 60.0)
		await get_tree().physics_frame


func _spawn(spawner: DotNpcSpawner, species: StringName) -> DotNpcInstance:
	var npc := spawner.spawn(Catalogue.id_of(species), Vector3.ZERO)
	await get_tree().physics_frame
	return npc


func _quick(d: Dictionary) -> void:
	for sp in d:
		d[sp]["attack"]["windup"] = 0.15


func _hits(host: Object) -> Array:
	return host.history.filter(func(h): return h["op"] == "hit")


func _test_config() -> void:
	_section("config")
	var d := Config.defaults()
	_check(d.size() == 3 and d.has("ant") and d.has("wasp") and d.has("bee"), "defaults describe every bug")
	var cfg := Config.load_config()
	_check(cfg.source != "defaults", "the yml directory was found and read", cfg.source)
	for sp in Config.SPECIES:
		var c := cfg.species(sp)
		_check(float(c.get("health", 0.0)) > 0.0 and c.get("attack") is Dictionary, "%s has health and an attack" % sp)
	_check(is_equal_approx(float(cfg.species(&"ant")["attack"]["damage"]), 14.0), "ant damage comes from ant.yml")
	_check(cfg.species(&"wasp")["attack"].get("status") == "poison", "the wasp's attack carries poison")
	_done()


func _test_catalogue() -> void:
	_section("catalogue")
	var cat := Catalogue.build(Config.load_config())
	_check(cat.size() == 3, "one definition per species", str(cat.size()))
	for sp in Config.SPECIES:
		var def := cat.get_npc(Catalogue.id_of(sp))
		_check(def != null and def.validate().ok, "%s validates" % sp)
		_check(def != null and ResourceLoader.exists(def.scene_path) and ResourceLoader.exists(def.brain_script_path), "%s names a scene and a brain that exist" % sp)
		_check(def != null and def.meta.get("species") == String(sp) and def.meta.get("cfg") is Dictionary, "%s carries its species and numbers in meta" % sp)
	_check(Catalogue.species_of(&"bug_bee") == &"bee" and Catalogue.species_of(&"nope") == &"", "ids map back to species")
	_done()


func _test_models() -> void:
	_section("models")
	var needs := {
		"ant": ["body", "abdomen", "head", "antennaL", "mandibleL", "legL1", "legR3"],
		"wasp": ["body", "abdomen", "head", "wingL", "wingR", "stinger", "legL2"],
		"bee": ["body", "abdomen", "head", "wingL", "wingR", "stinger", "legR1"],
	}
	for sp in Config.SPECIES:
		var v = View.new()
		v.species = sp
		v.manual = true
		_world.add_child(v)
		var missing := PackedStringArray()
		for p in needs[String(sp)]:
			if not v.has_pivot(p):
				missing.append(p)
		_check(missing.is_empty(), "%s has every pivot it animates" % sp, ", ".join(missing))
		var finite := true
		for anim in View.Anim.values():
			v.anim = anim
			for i in 20:
				v.step(0.05)
			for m in v.find_children("*", "Node3D", true, false):
				finite = finite and (m as Node3D).transform.origin.is_finite()
		_check(finite, "%s: stepping every clip keeps every pivot finite" % sp)
		v.queue_free()
	_done()


func _test_ant() -> void:
	_section("ant")
	var a := _arena(_quick)
	var spawner: DotNpcSpawner = a["spawner"]
	var host = a["host"]
	var npc := await _spawn(spawner, &"ant")
	_check(npc != null, "an ant spawns")
	_prey(spawner, [Vector3(1.0, 0.0, 0.0)])
	await _sim(spawner, 0.9)
	var hits := _hits(host)
	_check(hits.size() >= 1, "an ant in reach bites", str(hits.size()))
	_check(not hits.is_empty() and is_equal_approx(float(hits[0]["amount"]), 14.0) and hits[0]["kind"] == &"bite", "the bite is the configured damage")
	_check(host.history.filter(func(h): return h["op"] == "status").is_empty(), "an ant sends no status")

	var b := _arena(_quick)
	var npc2 := await _spawn(b["spawner"], &"ant")
	_prey(b["spawner"], [Vector3(60.0, 0.0, 0.0)])
	await _sim(b["spawner"], 1.0)
	_check(_hits(b["host"]).is_empty() and npc2 != null, "a target out of reach is not hit")
	_done()


func _test_wasp() -> void:
	_section("wasp")
	var a := _arena(_quick)
	var spawner: DotNpcSpawner = a["spawner"]
	var host = a["host"]
	var npc := await _spawn(spawner, &"wasp")
	_prey(spawner, [Vector3(1.0, 0.0, 0.0)])
	await _sim(spawner, 0.9)
	var st: Array = host.history.filter(func(h): return h["op"] == "status")
	_check(npc != null and not _hits(host).is_empty(), "a wasp in reach stings")
	_check(not st.is_empty() and st[0]["status"] == &"poison", "the sting poisons")
	_check(not st.is_empty() and is_equal_approx(float(st[0]["seconds"]), 4.0), "for the configured seconds")
	_done()


func _test_provider() -> void:
	_section("provider")
	var entries := Provider.spawn_entries()
	_check(entries.size() == 3, "one menu entry per species", str(entries.size()))
	for e in entries:
		_check(e.get("kind") == "npc" and (e["spawn_fn"] as Callable).is_valid(), "%s is an npc entry with a spawn_fn" % e.get("id"))
	var r = Provider._spawn({"authoritative": false}, &"ant")
	_check(r is DotResult and not r.ok, "a client cannot spawn bugs")
	_done()
