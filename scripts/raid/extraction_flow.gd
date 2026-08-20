class_name ExtractionFlow
extends RefCounted

# 탈출 — 비콘 생성, 발견, 봉쇄, 진입 연출, 정산까지의 전체 흐름.
# main.gd에서 11개 함수를 옮겼다.


const BROKEN_SENTRY_TEXTURE := preload("res://assets/props/broken_sentry_salvage.png")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const COWERING_RESIDENT_TEXTURE_PATHS := {
	"n": "res://assets/characters/cowering_resident/up_action-frame-0.png",
	"ne": "res://assets/characters/cowering_resident/up_right_action-frame-0.png",
	"e": "res://assets/characters/cowering_resident/right_action-frame-3.png",
	"se": "res://assets/characters/cowering_resident/down_right_action-frame-1.png",
	"s": "res://assets/characters/cowering_resident/down_action-frame-2.png",
	"sw": "res://assets/characters/cowering_resident/down_left_action-frame-2.png",
	"w": "res://assets/characters/cowering_resident/left_action-frame-3.png",
	"nw": "res://assets/characters/cowering_resident/up_left_action-frame-0.png",
}
const ESCORT_SPEED_PENALTY := 0.07
const EXTRACTION_BEACON_TEXTURE := preload("res://assets/extraction/extraction_beacon_generated_v1.png")
const FATIGUE_AIM_HOLD_RATE := 0.09
const FATIGUE_IDLE_RATE := 0.0
const FATIGUE_LOOT_GAIN := 0.85
const FATIGUE_MAX := 100.0
const FATIGUE_MOVING_RATE := 0.055
const FATIGUE_RESCUE_GAIN := 2.2
const FATIGUE_SALVAGE_GAIN := 3.5
const FATIGUE_SPEED_MIN := 0.58
const FIELD_INTERACTION_DISTANCE := 2.8
const FIELD_INTERACTION_FACING_WEIGHT := 1.35
const FIELD_INTERACTION_SIGHT_HEIGHT := 0.48
const FIELD_MISSION_CATALOG := preload("res://scripts/field_mission_catalog.gd")
const FIELD_MISSION_STEALTH_HOLD_RADIUS := 14.0
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const LORE_CLUE_COUNT := 6
const LORE_ENTRIES := preload("res://scripts/lore_catalog.gd").ENTRIES
const LORE_POSTER_TEXTURE := preload("res://assets/lore/forgotten_notice_board_v1.png")
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_EXTRACTION_POLICY := preload("res://scripts/raid_extraction_policy.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const RESCUED_CAT_FOLLOWER_SCRIPT := preload("res://scripts/rescued_cat_follower.gd")
const RESCUE_HOLD_DURATION := 1.8
const RESCUE_POINT_COUNT := 5
const SALVAGE_HOLD_DURATION := 2.4
const SALVAGE_MISC_POINT_COUNT := 4
const SALVAGE_VEHICLE_POINT_COUNT := 10
const SCREEN_DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const TACTICAL_MAP_SCRIPT := preload("res://scripts/tactical_map.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var extraction_position := Vector3.ZERO
var extraction_prompt: Control
var extraction_success_label: Label
var pending_extraction_xp_result: Dictionary = {}
var selected_extraction_index := 0
var selected_extraction_multiplier := 1.0
var selected_extraction_title := "안전 탈출로"


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player


func _seal_one_extraction_route() -> void:
	# 탈출로 하나를 실제로 잠근다. 계획이 무너지는 순간을 만드는 장치다.
	var sites := host.get_tree().get_nodes_in_group("field_extraction")
	var candidates: Array[Node3D] = []
	for site in sites:
		if not is_instance_valid(site):
			continue
		var node := site as Node3D
		if int(node.get_meta("extraction_index", 0)) == 0:
			continue  # 기본 귀환로는 남겨 둔다. 완전히 갇히면 좌절만 남는다.
		if bool(node.get_meta("extraction_sealed", false)):
			continue
		candidates.append(node)
	if candidates.is_empty():
		return
	var target := candidates[host.raid_event_random.randi_range(0, candidates.size() - 1)]
	target.set_meta("extraction_sealed", true)
	host.raid_sealed_extraction_index = int(target.get_meta("extraction_index", -1))
	target.remove_from_group("field_extraction")
	for child in target.get_children():
		if child is Sprite3D:
			(child as Sprite3D).modulate = Color(0.42, 0.36, 0.36, 0.85)
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	if is_instance_valid(host.tactical_map) and host.tactical_map.has_method("seal_extraction"):
		host.tactical_map.call("seal_extraction", host.raid_sealed_extraction_index)


func _find_random_extraction_position(
	world: ProceduralCityMap,
	random: RandomNumberGenerator,
	minimum_player_distance: float,
	occupied_positions: Array[Vector3]
) -> Vector3:
	var map_limit := world.get_map_limit() * 0.82
	var fallback := world.get_extraction_position()
	fallback.y = 0.08
	var fallback_separation := -1.0
	for _attempt in 160:
		var requested := Vector3(
			random.randf_range(-map_limit, map_limit),
			0.08,
			random.randf_range(-map_limit, map_limit)
		)
		var candidate := world.find_nearest_physically_open_position(
			requested,
			0.72,
			[player.get_rid()]
		)
		candidate.y = 0.08
		if candidate.distance_to(player.global_position) < minimum_player_distance:
			continue
		if world.is_position_in_safe_zone(candidate):
			continue
		var nearest_extraction_distance := INF
		for occupied_position in occupied_positions:
			nearest_extraction_distance = minf(
				nearest_extraction_distance,
				candidate.distance_to(occupied_position)
			)
		if occupied_positions.is_empty():
			nearest_extraction_distance = 32.0
		if nearest_extraction_distance > fallback_separation:
			fallback = candidate
			fallback_separation = nearest_extraction_distance
		if nearest_extraction_distance >= 32.0:
			return candidate
	return fallback


func _setup_extraction_site(world: ProceduralCityMap) -> void:
	host.extraction_sites.clear()
	host.discovered_extraction_indices.clear()
	var extraction_random := RandomNumberGenerator.new()
	extraction_random.seed = (
		int(GameState.map_seed)
		^ (int(GameState.raid_serial) * 982451653)
		^ 0x45584954
	)
	var positions: Array[Vector3] = []
	for index in 3:
		positions.append(_find_random_extraction_position(
			world,
			extraction_random,
			24.0 + float(index) * 3.0,
			positions
		))
	for index in positions.size():
		var site := _create_extraction_beacon(positions[index], index)
		host.extraction_sites.append(site)
		host.field_interactions.append(site)
		if index == 0:
			site.set_meta("map_discovered", true)
			host.discovered_extraction_indices[index] = true
	host.extraction_site = host.extraction_sites[0]
	extraction_position = host.extraction_site.global_position
	extraction_prompt = host.hud.field_interaction_panel

	host.extraction_fade = ColorRect.new()
	host.extraction_fade.name = "ExtractionFade"
	host.extraction_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.extraction_fade.color = Color(0, 0, 0, 0)
	host.extraction_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.extraction_fade.z_index = 500
	host.get_node("HUD").add_child(host.extraction_fade)
	extraction_success_label = Label.new()
	extraction_success_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	extraction_success_label.text = "탈출 성공"
	extraction_success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extraction_success_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extraction_success_label.add_theme_font_override("font", preload("res://assets/fonts/Pretendard-Regular.otf"))
	extraction_success_label.add_theme_font_size_override("font_size", 44)
	extraction_success_label.add_theme_color_override("font_color", Color("#e6dfc4"))
	extraction_success_label.modulate.a = 0.0
	extraction_success_label.z_index = 501
	host.get_node("HUD").add_child(extraction_success_label)
	host.hud.build_extraction_progress_ui()
	if host.hud.extraction_return_button != null:
		host.hud.extraction_return_button.pressed.connect(_on_extraction_return_pressed)
	# 성장 카드를 한 장 고를 때마다 남은 개수가 바뀐다(main._show_level_reward_choices가
	# 행을 새로 채운다). 안내 문구와 버튼 라벨이 그 숫자를 따라가게 묶어 둔다.
	if host.hud.extraction_level_choice_row != null:
		host.hud.extraction_level_choice_row.child_order_changed.connect(
			_refresh_extraction_return_state
		)
		host.hud.extraction_level_choice_row.visibility_changed.connect(
			_refresh_extraction_return_state
		)


func _show_extraction_result(rescued_count: int) -> void:
	host._refresh_pointer_mode()
	host._update_combat_overlay_visibility()
	# 정산 화면 위로 긴장도 패널·증원 배너·무기 카드가 그대로 겹쳐 그려지던 문제.
	host.hud.hide_field_combat_hud()
	# 지난 판에서 못 쓰고 나온 성장 포인트. add_raid_experience가 이번 판 몫을
	# 더하기 전에 읽어야 '지난 판 잔여'와 '이번 판 획득'이 안 섞인다.
	var carried_level_choices := maxi(0, GameState.pending_level_choices)
	var combat_xp := GameState.get_raid_experience_reward(host.run_kills, host.enemy_director.run_boss_kills)
	# 엘리트 킬은 일반의 ~3배 — run_kills에 이미 1회분(22)이 포함되므로 +44.
	# get_raid_experience_reward 시그니처는 건드리지 않고 여기서 얹는다.
	combat_xp += host.enemy_director.run_elite_kills * 44
	var cargo_result: Dictionary = host.main_mission.settle()
	var cargo_xp := int(cargo_result.get("xp", 0))
	var base_xp_reward: int = combat_xp + host.completed_mission_xp + cargo_xp
	var xp_reward := roundi(float(base_xp_reward) * selected_extraction_multiplier)
	var route_xp_bonus := maxi(0, xp_reward - base_xp_reward)
	var route_bonus := _grant_extraction_route_bonus()
	var route_definition := RAID_EXTRACTION_POLICY.get_route(selected_extraction_index)
	var route_color: Color = route_definition.get("color", Color("#d9b44a"))
	host.hud.extraction_route_icon.texture = UI_ICONS.get_icon("raid", 44, route_color)
	# "정산 배율 ×1.40"은 개발자 말이다. 플레이어가 아는 건 "위험한 길로
	# 나와서 더 받았다"뿐 — 그 문장으로 쓴다.
	var route_gain_percent := roundi((selected_extraction_multiplier - 1.0) * 100.0)
	var route_headline := selected_extraction_title
	if route_gain_percent > 0:
		route_headline += "  —  위험을 감수해 보상 +%d%%" % route_gain_percent
	else:
		route_headline += "  —  안전하게 빠져나왔습니다"
	var route_supply := str(route_bonus.get("summary", ""))
	host.hud.extraction_route_label.text = (
		route_headline
		if route_supply.is_empty() or route_supply.begins_with("경로 보급 보너스 없음")
		else "%s\n길에서 주운 것 · %s" % [route_headline, route_supply.replace("경로 보급 · ", "")]
	)
	host.hud.extraction_route_label.add_theme_color_override(
		"font_color",
		route_color.lightened(0.18)
	)
	var risk_payout := GameState.grant_extraction_risk_payout(
		host.run_kills, host.raid_pressure_level, selected_extraction_multiplier
	)
	# 잠입 보상 — 시스템은 잠입을 파는데 경제가 학살만 사면 안 된다.
	# 무발각 탈출(유령 침투)은 정산 +35%, 암살 처치는 킬 XP 가중.
	var stealth_xp: int = int(host.run_stealth_kills) * 18
	var ghost_xp := 0
	var ghost_scrap := 0
	if not host.run_player_detected:
		ghost_xp = 80
		ghost_scrap = maxi(400, roundi(float(risk_payout) * 0.35))
		GameState.scrap += ghost_scrap
	xp_reward += stealth_xp + ghost_xp
	pending_extraction_xp_result = GameState.add_raid_experience(xp_reward)
	# 제목은 아직 '이전 레벨'이다. 레벨업 숫자는 XP 바가 가득 찬 순간에 바뀐다.
	host.hud.extraction_result_title.text = "탈출 성공 · Lv.%d" % int(
		pending_extraction_xp_result.get("old_level", GameState.player_level)
	)
	var mission_summary := ""
	if not host.completed_mission_titles.is_empty():
		mission_summary = "현장에서 해낸 일 · %s" % ", ".join(host.completed_mission_titles)
	var cargo_summary := str(cargo_result.get("summary", "특별 화물 없음"))
	# 경로 이름·배율·보급 보너스는 바로 위 extraction_route_label이 이미 말한다.
	# 숫자는 타일/칩이, 문장은 아래 요약 라벨이 맡는다.
	host.hud.clear_result_visuals()
	host.hud.add_result_stat(
		"weapon",
		str(host.run_kills + host.enemy_director.run_boss_kills),
		"처치" if host.enemy_director.run_boss_kills == 0 else "처치 · 보스 %d" % host.enemy_director.run_boss_kills,
		HudStyle.DANGER
	)
	host.hud.add_result_stat("resident", str(rescued_count), "주민 후송", HudStyle.GREEN)
	host.hud.add_result_stat(
		"scrap",
		"+%s" % GameState.format_compact_number(risk_payout),
		"위험 정산금",
		HudStyle.GOLD
	)
	# 칩은 "왜 이만큼 벌었는지"의 근거 목록이다. 전문용어 대신 행동으로 쓴다.
	host.hud.add_result_reward_chip("upgrade", "경험치 +%d" % xp_reward, HudStyle.GREEN)
	# 성장 포인트는 이 화면에서만 쓸 수 있다. 지난 판에 못 쓰고 나왔다면
	# 조용히 잠긴 채로 두지 말고 "아직 %d개 남아 있다"고 매번 말해 준다.
	if carried_level_choices > 0:
		host.hud.add_result_reward_chip(
			"secure",
			"지난 판에서 안 고른 성장 %d개 · 아래에서 지금 고를 수 있습니다" % carried_level_choices,
			HudStyle.GOLD
		)
	if ghost_scrap > 0:
		host.hud.add_result_reward_chip(
			"secure",
			"끝까지 들키지 않음 · 고철 +%s · 경험치 +%d" % [
				GameState.format_compact_number(ghost_scrap), ghost_xp,
			],
			HudStyle.GOLD
		)
	if stealth_xp > 0:
		host.hud.add_result_reward_chip(
			"melee", "몰래 처치 %d회 · 경험치 +%d" % [host.run_stealth_kills, stealth_xp], HudStyle.GREEN
		)
	if route_xp_bonus > 0:
		host.hud.add_result_reward_chip(
			"raid", "위험한 탈출로 선택 · 경험치 +%d" % route_xp_bonus, HudStyle.GOLD
		)
	if host.completed_mission_xp > 0:
		host.hud.add_result_reward_chip(
			"check", "현장 임무 완료 · 경험치 +%d" % host.completed_mission_xp, HudStyle.GOLD
		)
	# 도시 의뢰(계약 완주 후 반복 목표) 달성 시 즉시 지급 + 칩으로 보여준다.
	var commission_payout: Dictionary = GameState.settle_city_commission(
		host.run_kills,
		host.raid_pressure_level,
		GameState.get_valuable_total_value()
	)
	if not commission_payout.is_empty():
		var commission_text := "사자의 의뢰 · 고철 +%s" % GameState.format_compact_number(
			int(commission_payout.get("scrap", 0))
		)
		if int(commission_payout.get("churu", 0)) > 0:
			commission_text += " · 츄르 +%d" % int(commission_payout.get("churu", 0))
		host.hud.add_result_reward_chip("churu", commission_text, HudStyle.GOLD)
	# 가방을 "시간"으로 환산한다. 통조림 12개는 아무 느낌도 없지만
	# "쉘터 가동 3시간 12분"은 다음 출정의 이유가 된다.
	var runtime_seconds := GameState.get_canned_food_runtime_seconds()
	if runtime_seconds > 0.0:
		host.hud.add_result_reward_chip(
			"time",
			"가져온 통조림으로 쉘터가 %s 더 돌아갑니다" % GameState.format_duration_korean(
				runtime_seconds
			),
			HudStyle.GREEN
		)
	# 이번 판에 실제로 들고 나온 것 — 숫자보다 이게 먼저 읽혀야 한다.
	# 종류별로 묶어 칩 하나씩, 쉘터 귀속 규칙(통조림→재화, 재료→창고)과 같은 순서.
	var haul_food := GameState.get_backpack_storage_count("food", "canned_food")
	if haul_food > 0:
		host.hud.add_result_reward_chip("food", "통조림 %d개" % haul_food, HudStyle.GREEN)
	var haul_components := 0
	var haul_gear := 0
	var haul_ammo := 0
	# 귀중품과 청사진(진행품)이 집계에서 통째로 빠져 있었다 — 이번 판에서 제일
	# 값나가는 것을 들고 나왔는데 '가져온 것'에 한 줄도 안 뜨던 문제.
	var haul_valuables := GameState.get_valuable_total_count()
	var haul_progression := 0
	for entry in GameState.get_raid_bag_entries():
		var entry_type := str(entry.get("type", ""))
		var entry_count := int(entry.get("count", 0))
		match entry_type:
			"component", "mod":
				haul_components += entry_count
			"weapon", "equipment":
				haul_gear += entry_count
			"ammo":
				haul_ammo += entry_count
			"progression":
				haul_progression += entry_count
	if haul_gear > 0:
		host.hud.add_result_reward_chip("weapon", "무기·방어구 %d점" % haul_gear, HudStyle.GOLD)
	if haul_components > 0:
		host.hud.add_result_reward_chip("parts", "부품 %d개" % haul_components, HudStyle.GOLD)
	if haul_valuables > 0:
		host.hud.add_result_reward_chip(
			"scrap",
			"귀중품 %d점 · 쉘터 도착 시 고철 +%s" % [
				haul_valuables,
				GameState.format_compact_number(GameState.get_valuable_total_value()),
			],
			HudStyle.GOLD
		)
	if haul_progression > 0:
		host.hud.add_result_reward_chip("secure", "청사진·열쇠 %d점" % haul_progression, HudStyle.GOLD)
	if haul_ammo > 0:
		host.hud.add_result_reward_chip("ammo", "탄약 %d발" % haul_ammo, HudStyle.TEXT_DIM)
	var lines: PackedStringArray = [mission_summary]
	if cargo_summary != "특별 화물 없음":
		lines.append(cargo_summary)
	# 끝난 것만 정리하지 말고 다음까지 남은 거리를 보여준다.
	var next_goal := GameState.get_active_contract_progress_text()
	if not next_goal.is_empty():
		lines.append(next_goal)
	# 귀속 규칙을 여기서 미리 말해 준다 — 쉘터에 도착해서야 알면 늦다.
	# 귀속 규칙 예고에 귀중품 환전을 빠뜨리면, 쉘터에서 귀중품이 사라진 걸
	# 보고 "털렸다"고 읽는다.
	lines.append("통조림은 쉘터 연료로, 재료와 여분 장비는 창고로, 귀중품은 고철로 바뀝니다.")
	# "탭하면 쉘터로 복귀"는 요약 라벨에서 뺐다 — 레벨업 선택 UI보다 위에 있어
	# 순서가 거꾸로였다. 안내와 버튼은 선택 UI 아래(hud.extraction_return_row)로.
	host.hud.extraction_result_summary.text = "\n".join(lines)
	_play_extraction_xp_bar()
	host.hud.extraction_result_panel.visible = true
	extraction_result_dismissable_msec = Time.get_ticks_msec() + 700
	host.hud.set_extraction_return_state(GameState.pending_level_choices)
	if not host.hud.extraction_result_panel.gui_input.is_connected(_on_extraction_result_input):
		host.hud.extraction_result_panel.gui_input.connect(_on_extraction_result_input)
	if GameState.pending_level_choices > 0:
		# 성장 선택이 남아 있으면 자동 복귀 폴백을 걸지 않는다. 8초 뒤 혼자
		# 쉘터로 넘어가면 이 화면에서만 쓸 수 있는 성장 포인트가 그대로 잠긴다.
		host._show_level_reward_choices()
	else:
		# 정산은 이번 판의 보상 순간이다. 읽는 속도는 사람마다 다르니 시간을
		# 강요하지 않는다: 탭/클릭/스페이스로 즉시 복귀, 무입력이면 8초 폴백.
		# 40판째 유저가 벽을 보며 4.5초씩 기다리던 마찰 제거.
		var wait_tween := host.create_tween()
		wait_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		wait_tween.tween_interval(8.0)
		wait_tween.tween_callback(_finish_extraction_to_shelter)


var extraction_result_dismissable_msec := 0
var extraction_result_finished := false


func build_extraction_xp_bar_plan() -> Array[Dictionary]:
	# 레벨업 정산에서 바가 거꾸로 줄어들던 문제(유저 신고).
	# 원인: 시작값은 old_xp/이전 레벨 요구량인데, 목표값은 new_xp/새 레벨 요구량을
	# 같은 분모(new_required)로 계산했다. 레벨이 오르면 요구량이 커지고 남은 XP는
	# 작아지니 90% → 13% 로 역주행했다.
	#
	# 고침: "채우고 → 터뜨리고 → 0에서 다시 채운다"를 레벨업 횟수만큼 반복한다.
	# 계획을 배열로 먼저 만들어 두면 연출과 검증(프로브)이 같은 숫자를 본다.
	var old_xp := int(pending_extraction_xp_result.get("old_xp", GameState.player_xp))
	var new_xp := int(pending_extraction_xp_result.get("new_xp", GameState.player_xp))
	var old_required := maxi(1, int(pending_extraction_xp_result.get("old_required", 1)))
	var new_required := maxi(1, int(pending_extraction_xp_result.get("new_required", 1)))
	var levels_gained := maxi(0, int(pending_extraction_xp_result.get("levels_gained", 0)))
	var plan: Array[Dictionary] = []
	var start_percent := clampf(float(old_xp) / float(old_required) * 100.0, 0.0, 100.0)
	plan.append({"kind": "set", "value": start_percent})
	if levels_gained <= 0:
		plan.append({
			"kind": "fill",
			"value": clampf(float(new_xp) / float(new_required) * 100.0, 0.0, 100.0),
			"duration": 0.9,
		})
		return plan
	# 레벨업이 여러 번이면 중간 레벨은 짧게 훑고 지나간다 — 마지막 한 칸만 천천히.
	for level_step in levels_gained:
		var last_step := level_step == levels_gained - 1
		plan.append({"kind": "fill", "value": 100.0, "duration": 0.55 if last_step else 0.22})
		plan.append({"kind": "levelup", "level": int(
			pending_extraction_xp_result.get("old_level", GameState.player_level)
		) + level_step + 1})
		plan.append({"kind": "set", "value": 0.0})
	plan.append({
		"kind": "fill",
		"value": clampf(float(new_xp) / float(new_required) * 100.0, 0.0, 100.0),
		"duration": 0.75,
	})
	return plan


func _play_extraction_xp_bar() -> void:
	var new_xp := int(pending_extraction_xp_result.get("new_xp", GameState.player_xp))
	var new_required := maxi(
		1, int(pending_extraction_xp_result.get("new_required", GameState.get_xp_required()))
	)
	var plan := build_extraction_xp_bar_plan()
	var bar: ProgressBar = host.hud.extraction_xp_bar
	var label: Label = host.hud.extraction_xp_label
	label.text = "Lv.%d   %d / %d XP" % [
		int(pending_extraction_xp_result.get("old_level", GameState.player_level)),
		int(pending_extraction_xp_result.get("old_xp", new_xp)),
		maxi(1, int(pending_extraction_xp_result.get("old_required", new_required))),
	]
	bar.value = float((plan[0] as Dictionary).get("value", 0.0))
	var xp_tween := host.create_tween()
	xp_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	xp_tween.tween_interval(0.45)
	for step_index in range(1, plan.size()):
		var step := plan[step_index] as Dictionary
		match str(step.get("kind", "")):
			"set":
				xp_tween.tween_callback(func() -> void:
					bar.value = float(step.get("value", 0.0))
				)
			"fill":
				xp_tween.tween_property(
					bar, "value", float(step.get("value", 0.0)), float(step.get("duration", 0.6))
				).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			"levelup":
				# 바가 가득 찬 그 순간에만 레벨 숫자가 바뀐다 — 차오름과 숫자가 어긋나면
				# 플레이어는 "씹혔다"고 읽는다.
				xp_tween.tween_callback(func() -> void:
					label.text = "Lv.%d   레벨 업" % int(step.get("level", GameState.player_level))
					host.hud.extraction_result_title.text = "탈출 성공 · Lv.%d" % int(
						step.get("level", GameState.player_level)
					)
				)
				xp_tween.tween_property(bar, "modulate", Color("#fff3c4"), 0.12)
				xp_tween.tween_property(bar, "modulate", Color.WHITE, 0.18)
	xp_tween.tween_callback(func() -> void:
		label.text = "Lv.%d   %d / %d XP" % [GameState.player_level, new_xp, new_required]
	)


func _on_extraction_result_input(event: InputEvent) -> void:
	# 등장 직후 0.7초는 오탭 보호 — 탈출 홀드 중 남은 터치가 바로 닫아버리지 않게.
	if Time.get_ticks_msec() < extraction_result_dismissable_msec:
		return
	var confirmed: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (
			event is InputEventKey and event.pressed
			and (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER]
		)
	)
	if confirmed and not extraction_result_finished:
		if _block_return_for_level_choices():
			return
		extraction_result_finished = true
		_finish_extraction_to_shelter()


func _refresh_extraction_return_state() -> void:
	if host == null or host.hud == null:
		return
	host.hud.set_extraction_return_state(GameState.pending_level_choices)


func _on_extraction_return_pressed() -> void:
	if extraction_result_finished:
		return
	if _block_return_for_level_choices():
		return
	extraction_result_finished = true
	_finish_extraction_to_shelter()


func _block_return_for_level_choices() -> bool:
	# 성장 선택은 이 화면에서만 쓸 수 있다. 카드 밖 아무 데나 탭했다고 선택이
	# 통째로 삼켜지면, 다음 탈출까지 성장 포인트가 잠긴다. 막고, 이유를 말한다.
	if GameState.pending_level_choices <= 0:
		return false
	host.hud.set_extraction_return_state(GameState.pending_level_choices)
	host.hud.flash_extraction_return_warning(GameState.pending_level_choices)
	if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
		Input.vibrate_handheld(20)
	return true


func _finish_extraction_to_shelter() -> void:
	if GameState.pending_level_choices > 0 and not extraction_result_finished:
		# 자동 복귀 폴백/외부 호출이 선택을 건너뛰지 못하게 하는 마지막 방어선.
		_block_return_for_level_choices()
		return
	if extraction_result_finished and not host.get_tree().paused:
		return
	extraction_result_finished = true
	host.get_tree().paused = false
	GameState.returning_from_shelter = false
	GameState.register_shelter_return()
	SceneTransition.transition_to("res://scenes/shelter_interior.tscn")


func _grant_extraction_route_bonus() -> Dictionary:
	var bonus := RAID_EXTRACTION_POLICY.calculate_route_bonus(
		selected_extraction_index,
		host.raid_hotspots_opened,
		host.dynamic_incident_state == "claimed",
		host.run_kills,
		GameState.map_seed
	)
	GameState.canned_food += int(bonus.get("food", 0))
	GameState.medkits += int(bonus.get("medkits", 0))
	var component_id := str(bonus.get("component_id", ""))
	var component_count := int(bonus.get("component_count", 0))
	if not component_id.is_empty() and component_count > 0:
		GameState.add_mod_component(component_id, component_count)
	return bonus


func _create_extraction_beacon(world_position: Vector3, index: int) -> Node3D:
	var site := Node3D.new()
	var route_definition := RAID_EXTRACTION_POLICY.get_route(index)
	var route_color: Color = route_definition.get("color", Color("#d9b44a"))
	var route_title := str(route_definition.get("title", "안전 탈출로"))
	var reward_multiplier := float(route_definition.get("reward_multiplier", 1.0))
	site.name = "SewerExtraction_%02d" % (index + 1)
	host.add_child(site)
	site.global_position = Vector3(world_position.x, 0.08, world_position.z)
	site.set_meta("interaction_type", "extraction")
	site.set_meta(
		"display_name",
		"안전 탈출 하수구" if index == 0 else route_title
	)
	site.set_meta("hold_duration", 0.0)
	site.set_meta("interaction_distance", FIELD_INTERACTION_DISTANCE)
	site.set_meta("extraction_index", index)
	site.set_meta("map_discovered", false)
	site.set_meta("route_title", route_title)
	site.set_meta("reward_multiplier", reward_multiplier)
	site.set_meta("route_color", route_color)
	site.add_to_group("field_extraction")

	var sewer_sprite := Sprite3D.new()
	sewer_sprite.name = "SewerHatch"
	sewer_sprite.texture = EXTRACTION_BEACON_TEXTURE
	# The generated beacon is a taller freestanding prop than the old flat hatch.
	# Keep its footprint inside the extraction ring and lift the visual bottom to
	# the ground line instead of letting the transparent canvas sink below it.
	sewer_sprite.pixel_size = 0.0022
	sewer_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sewer_sprite.shaded = false
	sewer_sprite.transparent = true
	sewer_sprite.position.y = 0.92
	sewer_sprite.render_priority = 4
	site.add_child(sewer_sprite)

	host._add_interaction_marker(site, route_color, 1.55, true)
	var beam_material := StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(
		route_color.r,
		route_color.g,
		route_color.b,
		0.12
	)
	beam_material.emission_enabled = true
	beam_material.emission = route_color
	beam_material.emission_energy_multiplier = 1.8
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.28
	beam_mesh.bottom_radius = 1.25
	beam_mesh.height = 5.5
	beam_mesh.radial_segments = 24
	beam_mesh.material = beam_material
	var beam := MeshInstance3D.new()
	beam.name = "ExtractionBeacon"
	beam.position.y = 2.75
	beam.mesh = beam_mesh
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(beam)

	var light := OmniLight3D.new()
	light.name = "ExtractionLight"
	light.position.y = 1.15
	light.light_color = route_color
	light.light_energy = 3.2
	light.omni_range = 7.5
	light.shadow_enabled = false
	site.add_child(light)
	return site


func _update_extraction_discovery() -> void:
	for site in host.extraction_sites:
		if not is_instance_valid(site) or bool(site.get_meta("map_discovered", false)):
			continue
		if not _is_extraction_in_player_sight(site):
			continue
		var index := int(site.get_meta("extraction_index", -1))
		if index < 0:
			continue
		site.set_meta("map_discovered", true)
		host.discovered_extraction_indices[index] = true
		if is_instance_valid(host.tactical_map):
			host.tactical_map.call("discover_extraction", index)
		host._show_field_notice("탈출구 발견 · 전술 지도에 하수구 위치가 기록되었습니다.")


func _is_extraction_in_player_sight(site: Node3D) -> bool:
	var offset := site.global_position - player.global_position
	offset.y = 0.0
	var distance := offset.length()
	var in_visibility_shape := distance <= 10.5
	if not in_visibility_shape and host.laser_aim_held and distance <= 32.0:
		var aim_direction: Vector3 = host._get_perception_aim_direction()
		aim_direction.y = 0.0
		in_visibility_shape = aim_direction.normalized().dot(offset.normalized()) >= cos(deg_to_rad(58.0))
	if not in_visibility_shape:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.55, 0),
		site.global_position + Vector3(0, 0.55, 0),
		COLLISION_PROFILES.WORLD_ONLY_SIGHT_MASK
	)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _begin_extraction() -> void:
	if host.extraction_transition_active or host.player_death_sequence_active or host.player_health <= 0:
		return
	if is_instance_valid(host.nearby_field_interaction):
		selected_extraction_index = int(
			host.nearby_field_interaction.get_meta("extraction_index", 0)
		)
		selected_extraction_multiplier = float(
			host.nearby_field_interaction.get_meta("reward_multiplier", 1.0)
		)
		selected_extraction_title = str(
			host.nearby_field_interaction.get_meta("route_title", "안전 탈출로")
		)
	else:
		selected_extraction_index = 0
		selected_extraction_multiplier = 1.0
		selected_extraction_title = "안전 탈출로"
	host.extraction_transition_active = true
	host._refresh_pointer_mode()
	host._update_combat_overlay_visibility()
	extraction_prompt.visible = false
	host.fire_button_held = false
	host.mouse_fire_held = false
	host.laser_aim_held = false
	host.field_interaction_keyboard_held = false
	host.hud.field_interaction_touch_held = false
	host.touch_vector = Vector2.ZERO
	player.velocity = Vector3.ZERO
	host.recoil_velocity = Vector3.ZERO
	if is_instance_valid(host.extraction_fade):
		host.extraction_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var rescued_count: int = host._commit_rescued_followers()
	extraction_success_label.text = "탈출 성공 · %s" % selected_extraction_title
	# 시체를 실제로 주웠을 때만 회수 시도를 종료한다(= 시체 기록 삭제).
	# 회수했다면 _recover_previous_corpse가 이미 pending을 비웠다. 비어 있지
	# 않다면 안 주운 것이므로 다음 판을 위해 남긴다.
	GameState.finish_corpse_recovery_attempt(GameState.pending_corpse_recovery.is_empty())
	host._save_run_state()
	host.get_tree().paused = true
	var tween := host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(host.extraction_fade, "color:a", 1.0, 0.65)
	tween.tween_property(extraction_success_label, "modulate:a", 1.0, 0.32)
	tween.tween_interval(0.55)
	tween.tween_property(extraction_success_label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_show_extraction_result.bind(rescued_count))

# ── 판 중 레벨업 확보 예고 ─────────────────────────────────────
# XP는 탈출해야 실제로 들어온다(죽으면 날아가는 판돈). 그 구조는 지키되,
# 쌓아둔 XP가 다음 레벨을 넘는 "순간"을 판 중에 보여준다.
# 도파민과 동시에 "지금 나갈까?"라는 압박을 만든다.
var banked_levels_announced := 0


func reset_banked_level_watch() -> void:
	banked_levels_announced = 0


func update_banked_level_watch() -> void:
	var banked_xp: int = (
		GameState.get_raid_experience_reward(host.run_kills, host.enemy_director.run_boss_kills)
		# 엘리트 보너스(+44/킬)도 예고에 반영 — 정산과 예고가 어긋나면 안 된다.
		+ host.enemy_director.run_elite_kills * 44
		+ host.completed_mission_xp
	)
	var projected_levels := 0
	var simulated_xp: int = GameState.player_xp + banked_xp
	var simulated_level: int = GameState.player_level
	while simulated_xp >= GameState.get_xp_required(simulated_level):
		simulated_xp -= GameState.get_xp_required(simulated_level)
		simulated_level += 1
		projected_levels += 1
	if projected_levels > banked_levels_announced:
		banked_levels_announced = projected_levels
		host._show_field_notice(
			"레벨업 확보 · 탈출하면 Lv.%d
지금 죽으면 이 경험은 시체와 함께 남는다."
			% simulated_level
		)
		if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
			Input.vibrate_handheld(30)
