extends SceneTree


const SCRIPTS := [
	"res://scripts/main.gd",
	"res://scripts/enemy.gd",
	"res://scripts/bullet_projectile.gd",
	"res://scripts/building_loot_module.gd",
	"res://scripts/rocket_boss.gd",
	"res://scripts/rocket_projectile.gd",
	"res://scripts/boss_mine.gd",
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
	"res://scripts/shelter/active_tutorial.gd",
	"res://scripts/tactical_map.gd",
	"res://scripts/field_mission_catalog.gd",
	"res://scripts/raid_extraction_policy.gd",
	"res://scripts/ui_safe_area.gd",
]


func _initialize() -> void:
	for script_path in SCRIPTS:
		var script_resource := load(script_path) as Script
		if script_resource == null or not script_resource.can_instantiate():
			push_error("FIELD_SYSTEM_COMPILE: failed to load %s" % script_path)
			quit(1)
			return
	# 소스 문자열 검사는 줄바꿈에 민감하다 — CRLF 체크아웃에서도 통과하도록 정규화.
	var enemy_source := _read_source("res://scripts/enemy.gd")
	var projectile_source := _read_source("res://scripts/bullet_projectile.gd")
	var building_loot_source := _read_source("res://scripts/building_loot_module.gd")
	var main_source := _read_source("res://scripts/main.gd")
	var shelter_source := _read_source("res://scripts/shelter_interior.gd")
	var building_portal_source := _read_source("res://scripts/building_entrance_portal.gd")
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
	# 상인 매입 대가는 고철이다(통조림이 플레이어 소모품이 되며 화폐에서 빠짐). 다만 UI가
	# 장부를 직접 쓰는 건 여전히 금지 — 입금은 GameState.settle_merchant_sale 한 곳에서만.
	if shelter_source.contains("GameState.scrap +="):
		push_error("FIELD_SYSTEM_COMPILE: shelter UI must not write scrap directly (use GameState.settle_merchant_sale)")
		quit(1)
		return
	if not shelter_source.contains("GameState.settle_merchant_sale(price)"):
		push_error("FIELD_SYSTEM_COMPILE: merchant sales must pay scrap through GameState.settle_merchant_sale")
		quit(1)
		return
	if not main_source.contains("fatigue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)"):
		push_error("FIELD_SYSTEM_COMPILE: fatigue HUD must stay clear of mobile movement controls")
		quit(1)
		return
	var mission_catalog_source := FileAccess.get_file_as_string(
		"res://scripts/field_mission_catalog.gd"
	)
	for mission_type in ["stealth", "investigate", "stealth_reach"]:
		if not mission_catalog_source.contains("\"type\": \"%s\"" % mission_type):
			push_error("FIELD_SYSTEM_COMPILE: missing survival mission type %s" % mission_type)
			quit(1)
			return
	# 모듈화로 은신 판정은 field_mission_controller로 이사했다.
	var mission_source := _read_source("res://scripts/raid/field_mission_controller.gd")
	if not mission_source.contains(
		"bool(enemy.get(\"alerted\")) and bool(enemy.get(\"has_current_line_of_sight\"))"
	):
		push_error("FIELD_SYSTEM_COMPILE: stealth missions must use real enemy detection state")
		quit(1)
		return
	if not main_source.contains(
		"const FIELD_MISSION_CATALOG := preload(\"res://scripts/field_mission_catalog.gd\")"
	):
		push_error("FIELD_SYSTEM_COMPILE: main must use the shared mission catalog")
		quit(1)
		return
	if not mission_catalog_source.contains("const REQUIRED_TYPES := ["):
		push_error("FIELD_SYSTEM_COMPILE: each raid must define guaranteed mission coverage")
		quit(1)
		return
	for mission_type in ["defense", "eliminate", "collect", "stealth", "investigate", "stealth_reach"]:
		if not mission_catalog_source.contains("\t\"%s\"," % mission_type):
			push_error("FIELD_SYSTEM_COMPILE: mission coverage is missing %s" % mission_type)
			quit(1)
			return
	if building_portal_source.contains("func _unhandled_input"):
		push_error("FIELD_SYSTEM_COMPILE: building entry must not bypass the shared hold interaction")
		quit(1)
		return
	# 씬 전환 소유권은 SceneTransition 오토로드로 이사했다(내부에서 지연 커밋).
	var transition_source := _read_source("res://scripts/scene_transition_guard.gd")
	if not building_portal_source.contains("/root/SceneTransition"):
		push_error("FIELD_SYSTEM_COMPILE: building entry must route through the SceneTransition autoload")
		quit(1)
		return
	if not transition_source.contains("call_deferred"):
		push_error("FIELD_SYSTEM_COMPILE: building scene changes must be deferred out of the interaction frame")
		quit(1)
		return
	print("FIELD_SYSTEM_COMPILE: PASS")
	quit(0)


func _read_source(path: String) -> String:
	# CR(캐리지 리턴)을 걷어내 CRLF 체크아웃에서도 줄바꿈 리터럴 매칭이 깨지지 않게 한다.
	return FileAccess.get_file_as_string(path).replace(char(13), "")
