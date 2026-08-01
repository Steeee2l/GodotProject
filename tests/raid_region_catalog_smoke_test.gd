extends SceneTree

const REGION_CATALOG := preload("res://scripts/raid_region_catalog.gd")
const BUILDING_CATALOG := preload("res://scripts/building_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var zone_ids := REGION_CATALOG.get_zone_ids()
	assert(zone_ids.size() == 5)
	var texture_paths := {}
	var road_signatures := {}
	for zone_id in zone_ids:
		var profile := REGION_CATALOG.get_profile(zone_id)
		assert(str(profile.get("zone_id", "")) == zone_id)
		assert(not str(profile.get("display_name", "")).is_empty())
		assert(not str(profile.get("identity", "")).is_empty())
		var texture_path := str(profile.get("ground_texture_path", ""))
		assert(ResourceLoader.exists(texture_path), "Missing region texture: %s" % texture_path)
		texture_paths[texture_path] = true
		var vertical_bands: Array = profile.get("vertical_road_bands", [])
		var horizontal_bands: Array = profile.get("horizontal_road_bands", [])
		assert(vertical_bands.size() >= 4)
		assert(horizontal_bands.size() >= 4)
		road_signatures[str(vertical_bands) + str(horizontal_bands)] = true
		assert(float(profile.get("entry_safe_radius", 0.0)) >= 30.0)
		assert(not str(profile.get("loot_focus", "")).is_empty())
		assert(not str(profile.get("tactical_rule", "")).is_empty())
		assert(int(profile.get("street_prop_count", 0)) > 0)
		assert(not (profile.get("large_vehicle_pool", []) as Array).is_empty())
		assert(not (profile.get("parked_vehicle_pool", []) as Array).is_empty())
		var adjustment_sum := 0
		for delta in (profile.get("container_adjustments", {}) as Dictionary).values():
			adjustment_sum += int(delta)
		assert(adjustment_sum == 0)
		assert(int(profile.get("recommended_duration_minutes", 0)) in range(20, 31))
		var risk_split: Vector2 = profile.get("risk_split", Vector2.ZERO)
		assert(risk_split.x > 0.0 and risk_split.x < risk_split.y)
		assert(risk_split.y < 1.0)
		var allowed_buildings: Array = profile.get("allowed_buildings", [])
		assert(not allowed_buildings.is_empty())
		for building_id in allowed_buildings:
			assert(
				not BUILDING_CATALOG.get_definition(str(building_id)).is_empty(),
				"Unknown building id %s in %s" % [building_id, zone_id]
			)
		var signature_building_id := str(profile.get("signature_building_id", ""))
		if not signature_building_id.is_empty():
			assert(allowed_buildings.has(signature_building_id))
			var signature_definition := BUILDING_CATALOG.get_definition(signature_building_id)
			assert(signature_definition["footprint_modules"] == Vector2i(8, 4))
			assert(
				(signature_definition.get("districts", []) as Array).has(
					str(profile.get("signature_district", ""))
				)
			)
	assert(texture_paths.size() == 5)
	assert(road_signatures.size() == 5)
	print("RAID_REGION_CATALOG_OK zones=%d textures=%d layouts=%d" % [
		zone_ids.size(), texture_paths.size(), road_signatures.size()
	])
	quit(0)
