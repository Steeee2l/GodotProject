extends SceneTree

const REGION_CATALOG := preload("res://scripts/raid_region_catalog.gd")
const BUILDING_CATALOG := preload("res://scripts/building_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_script: Script = load("res://scripts/procedural_map.gd")
	for zone_index in REGION_CATALOG.get_zone_ids().size():
		var zone_id := REGION_CATALOG.get_zone_ids()[zone_index]
		var profile := REGION_CATALOG.get_profile(zone_id)
		var city: Node3D = map_script.new()
		city.set("raid_zone_id", zone_id)
		city.set("map_seed", 91357 + zone_index * 101)
		root.add_child(city)
		await process_frame
		await physics_frame

		assert(str(city.call("get_region_id")) == zone_id)
		var snapshot: Dictionary = city.call("get_map_snapshot_data")
		assert(str(snapshot.get("raid_zone_id", "")) == zone_id)
		var risk_bands: Dictionary = snapshot.get("risk_bands", {})
		assert(risk_bands.values().has("safe"))
		assert(risk_bands.values().has("scavenge"))
		assert(risk_bands.values().has("restricted"))
		var allowed_buildings: Array = profile.get("allowed_buildings", [])
		var building_count := 0
		var cover_count := 0
		var generated_building_ids := {}
		for child in city.get_children():
			if child.is_in_group("road_cover_obstacle"):
				cover_count += 1
				var cover_collision := child.get_node_or_null("CoverCollision") as CollisionShape3D
				assert(cover_collision != null)
				assert(cover_collision.shape is BoxShape3D)
			if not child.has_meta("building_id"):
				continue
			building_count += 1
			var building_id := str(child.get_meta("building_id"))
			generated_building_ids[building_id] = true
			assert(allowed_buildings.has(building_id))
			assert(str(child.get_meta("raid_zone_id", "")) == zone_id)
			assert(str(child.get_meta("risk_band", "")) in ["safe", "scavenge", "restricted"])
			var definition := BUILDING_CATALOG.get_definition(building_id)
			var footprint: Vector2i = definition.get("footprint_modules", Vector2i.ZERO)
			var collision := child.get_node_or_null("BuildingCollision") as CollisionShape3D
			assert(collision != null)
			var box := collision.shape as BoxShape3D
			assert(box != null)
			assert(is_equal_approx(box.size.x, footprint.x * 2.0))
			assert(is_equal_approx(box.size.z, footprint.y * 2.0))
		assert(building_count >= 10)
		assert(cover_count >= 2)
		var signature_building_id := str(profile.get("signature_building_id", ""))
		if not signature_building_id.is_empty():
			assert(
				generated_building_ids.has(signature_building_id),
				"Missing signature building %s in %s" % [signature_building_id, zone_id]
			)

		city.queue_free()
		await process_frame
	print("RAID_REGION_GENERATION_OK zones=%d" % REGION_CATALOG.get_zone_ids().size())
	quit(0)
