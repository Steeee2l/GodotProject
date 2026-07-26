extends SceneTree


const SCRIPTS := [
	"res://scripts/main.gd",
	"res://scripts/enemy.gd",
	"res://scripts/bullet_projectile.gd",
	"res://scripts/building_loot_module.gd",
	"res://scripts/rocket_boss.gd",
	"res://scripts/rocket_projectile.gd",
	"res://scripts/enemy_grenade.gd",
	"res://scripts/enemy_alert_overlay.gd",
	"res://scripts/game_state.gd",
	"res://scripts/inventory_ui.gd",
	"res://scripts/rescued_cat_follower.gd",
	"res://scripts/mod_chip_button.gd",
	"res://scripts/mod_slot_drop_panel.gd",
	"res://scripts/shelter_workbench_module.gd",
	"res://scripts/scratcher_bank_module.gd",
	"res://scripts/catnip_scraper_module.gd",
	"res://scripts/shelter_training_module.gd",
	"res://scripts/building_entrance_portal.gd",
	"res://scripts/resident_portrait_catalog.gd",
	"res://scripts/shelter_resident_cat.gd",
	"res://scripts/shelter_contract_trainer.gd",
	"res://scripts/shelter_interior.gd",
	"res://scripts/tactical_map.gd",
]


func _initialize() -> void:
	for script_path in SCRIPTS:
		var script_resource := load(script_path) as Script
		if script_resource == null or not script_resource.can_instantiate():
			push_error("FIELD_SYSTEM_COMPILE: failed to load %s" % script_path)
			quit(1)
			return
	var enemy_source := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	var projectile_source := FileAccess.get_file_as_string("res://scripts/bullet_projectile.gd")
	var building_loot_source := FileAccess.get_file_as_string("res://scripts/building_loot_module.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var shelter_source := FileAccess.get_file_as_string("res://scripts/shelter_interior.gd")
	var building_portal_source := FileAccess.get_file_as_string("res://scripts/building_entrance_portal.gd")
	if not enemy_source.contains("if reinforcement_call_active:\n\t\t_cancel_reinforcement_call()"):
		push_error("FIELD_SYSTEM_COMPILE: taking a hit must interrupt a reinforcement call")
		quit(1)
		return
	if not enemy_source.contains("func get_projectile_hit_radius() -> float:"):
		push_error("FIELD_SYSTEM_COMPILE: enemies need a logical projectile silhouette")
		quit(1)
		return
	if not projectile_source.contains("side * PROJECTILE_COLLISION_RADIUS"):
		push_error("FIELD_SYSTEM_COMPILE: fast bullets need a widened swept collision test")
		quit(1)
		return
	if building_loot_source.contains("GameState.scrap +="):
		push_error("FIELD_SYSTEM_COMPILE: field loot must never grant shelter scrap")
		quit(1)
		return
	if shelter_source.contains("GameState.scrap +="):
		push_error("FIELD_SYSTEM_COMPILE: shelter scrap must come from production, not merchant sales")
		quit(1)
		return
	if not main_source.contains("fatigue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)"):
		push_error("FIELD_SYSTEM_COMPILE: fatigue HUD must stay clear of mobile movement controls")
		quit(1)
		return
	for mission_type in ["stealth", "investigate", "stealth_reach"]:
		if not main_source.contains("\"type\": \"%s\"" % mission_type):
			push_error("FIELD_SYSTEM_COMPILE: missing survival mission type %s" % mission_type)
			quit(1)
			return
	if not main_source.contains(
		"bool(enemy.get(\"alerted\")) and bool(enemy.get(\"has_current_line_of_sight\"))"
	):
		push_error("FIELD_SYSTEM_COMPILE: stealth missions must use real enemy detection state")
		quit(1)
		return
	if not main_source.contains("var required_types: Array[String] = [\"stealth\", \"investigate\", \"stealth_reach\"]"):
		push_error("FIELD_SYSTEM_COMPILE: each raid must guarantee survival-oriented missions")
		quit(1)
		return
	if building_portal_source.contains("func _unhandled_input"):
		push_error("FIELD_SYSTEM_COMPILE: building entry must not bypass the shared hold interaction")
		quit(1)
		return
	if not building_portal_source.contains("call_deferred(\"change_scene_to_packed\""):
		push_error("FIELD_SYSTEM_COMPILE: building scene changes must be deferred out of the interaction frame")
		quit(1)
		return
	print("FIELD_SYSTEM_COMPILE: PASS")
	quit(0)
