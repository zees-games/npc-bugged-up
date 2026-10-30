class_name BugCatalogue
extends RefCounted

## The bugs as [DotNpcDef]s built from [BugConfig]. Body and brain are named by path relative to this file,
## so a rebased mounted pack finds them.

const Config := preload("bug_config.gd")
const IDS := {&"ant": &"bug_ant", &"wasp": &"bug_wasp", &"bee": &"bug_bee"}


static func dir() -> String:
	return (new().get_script() as Script).resource_path.get_base_dir().get_base_dir()


static func id_of(species: StringName) -> StringName:
	return IDS.get(species, &"")


static func species_of(npc_id: StringName) -> StringName:
	for k in IDS:
		if IDS[k] == npc_id:
			return k
	return &""


static func def_for(species: StringName, config: Config) -> DotNpcDef:
	var c := config.species(species)
	var base := dir()
	var def := DotNpcDef.make(id_of(species), base.path_join("runtime/bug_body.tscn"))
	def.display_name = str(c.get("name", String(species)))
	def.category = &"monster"
	def.faction = &"hostile"
	def.brain_script_path = base.path_join("runtime/bug_brain.gd")
	def.weight = DotNpcDef.Weight.NORMAL
	def.cost = int(c.get("cost", 2))
	def.max_health = float(c.get("health", 100.0))
	def.move_speed = float(c.get("run_speed", 5.0))
	def.sight_range = float(c.get("sight_range", 30.0))
	def.sight_half_angle_deg = float(c.get("sight_half_angle", 80.0))
	def.hearing_range = float(c.get("hearing_range", 22.0))
	def.eye_height = float(c.get("eye_height", 1.0))
	def.require_line_of_sight = true
	def.meta = {"species": String(species), "cfg": c}
	return def


static func build(config: Config = null) -> DotNpcCatalogue:
	var cat := DotNpcCatalogue.new()
	add_to(cat, config)
	return cat


## Returns how many were added; a refused definition is logged and skipped.
static func add_to(catalogue: DotNpcCatalogue, config: Config = null) -> int:
	var cfg := config if config != null else Config.load_config()
	var added := 0
	for sp in Config.SPECIES:
		var res := catalogue.add(def_for(sp, cfg))
		if res.ok:
			added += 1
		else:
			DotLog.warn("bug.catalogue", "a bug definition was refused", {"species": String(sp), "why": res.error.message})
	return added
