extends SceneTree

const PATHS := [
	"res://scripts/hud/loc.gd",
	"res://scripts/hud/hud_style.gd", "res://scripts/hud/debug_gate.gd",
	"res://scripts/hud/debug_menu.gd", "res://scripts/hud/field_monologue.gd",
	"res://scripts/hud/game_over_screen.gd", "res://scripts/hud/lore_reader.gd",
	"res://scripts/hud/mission_tracker.gd", "res://scripts/hud/pause_menu.gd",
	"res://scripts/hud/raid_hud.gd", "res://scripts/hud/shelter_ops_console.gd",
	"res://scripts/hud/mission_celebration.gd",
	"res://scripts/tactical_map.gd", "res://scripts/character_naming.gd",
	"res://scripts/inventory_ui.gd", "res://scripts/shelter_workbench_module.gd",
	"res://scripts/shelter_storage_module.gd", "res://scripts/shelter_training_module.gd",
	"res://scripts/scratcher_bank_module.gd", "res://scripts/catnip_scraper_module.gd",
	"res://scripts/accessibility_settings.gd",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bad := 0
	for path in PATHS:
		var script := load(path)
		if script == null:
			print("FAIL load ", path)
			bad += 1
	print("compile probe done, failures=", bad)
	quit(1 if bad > 0 else 0)
