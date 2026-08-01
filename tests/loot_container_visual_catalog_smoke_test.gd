extends SceneTree

const VISUAL_CATALOG := preload("res://scripts/loot_container_visual_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var container_types := VISUAL_CATALOG.get_container_types()
	assert(container_types.size() == 6)
	var paths := {}
	for container_type in container_types:
		var definition := VISUAL_CATALOG.get_definition(container_type)
		var texture_path := str(definition.get("texture_path", ""))
		assert(ResourceLoader.exists(texture_path), "Missing container art: %s" % texture_path)
		assert(float(definition.get("world_width", 0.0)) > 0.0)
		assert(float(definition.get("world_height", 0.0)) > 0.0)
		assert(float(definition.get("open_duration", 0.0)) >= 0.5)
		assert(not str(definition.get("icon", "")).is_empty())
		paths[texture_path] = true
	assert(paths.size() == container_types.size())
	print("LOOT_CONTAINER_VISUALS_OK types=%d" % container_types.size())
	quit(0)
