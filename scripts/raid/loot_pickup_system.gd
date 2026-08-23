class_name LootPickupSystem
extends RefCounted

# 바닥 전리품 — 생성, 비주얼, 근접 수집, 가방 판정, 버리기.
# main.gd에서 19개 함수를 옮겼다. 아이템의 이름/아이콘/설명도 여기가 안다.


const AIM_REVEAL_BUILDING_ALPHA := 0.28
const AK_DROP_TEXTURE := preload("res://assets/weapons/ak47_drop.png")
const SFX := preload("res://scripts/sfx_bank.gd")
const SHELTER_REQUISITION := preload("res://scripts/shelter/requisition.gd")
const AMMO_762_TEXTURE := preload("res://assets/items/ammo_762.png")
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
const BASE_ENEMY_COUNT := 24
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const CHURU_TEXTURE := preload("res://assets/items/churu_rare.png")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const DEEP_NIGHT_HOUR := 22.0
const DIRECTION_VECTORS := {
	"n": Vector2(0, -1),
	"ne": Vector2(1, -1),
	"e": Vector2(1, 0),
	"se": Vector2(1, 1),
	"s": Vector2(0, 1),
	"sw": Vector2(-1, 1),
	"w": Vector2(-1, 0),
	"nw": Vector2(-1, -1),
}
const ENEMY_PAIR_SQUAD_CHANCE := 0.78
const ENEMY_VISIBILITY_FADE_IN_SPEED := 10.0
const ENEMY_VISIBILITY_FADE_OUT_SPEED := 3.2
const ENEMY_VISIBILITY_HOLD_SECONDS := 0.32
const FATIGUE_DAMAGE_PER_POINT := 0.045
const FATIGUE_LOOT_GAIN := 0.85
const FATIGUE_RELOAD_GAIN := 0.8
const FATIGUE_SHOT_GAIN := 0.28
const FIRST_STAGE_ZONE_ID := "jongno_outskirts"
const INTERACTION_TARGETING := preload("res://scripts/interaction_targeting.gd")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const MAP_CONTENT_SCALE := ProceduralCityMap.WORLD_SCALE
const MAX_NIGHT_ENEMY_COUNT := 44
const MOBILE_AIM_ASSIST_ANGLE_WEIGHT := 24.0
const MOBILE_AIM_ASSIST_DISTANCE_WEIGHT := 0.32
const MOBILE_AIM_ASSIST_HALF_ANGLE_DEG := 42.0
const MOBILE_AIM_ASSIST_MAX_DISTANCE := 34.0
const NIGHT_START_HOUR := 19.0
const OBJECTIVE_SCENT_GUIDANCE_SCRIPT := preload("res://scripts/objective_scent_guidance.gd")
const OCCLUSION_DEPTH_LIMIT := 14.0
const OCCLUSION_LATERAL_LIMIT := 5.1
const OVERLAY_DEPTH_SORT := preload("res://scripts/overlay_depth_sort.gd")
const PERCEPTION_SYSTEM_SCRIPT := preload("res://scripts/perception_system.gd")
const PICKUP_DISTANCE := 1.75
const RAID_EVENT_DIRECTOR := preload("res://scripts/raid_event_director.gd")
const RAID_ITEM_ECONOMY := preload("res://scripts/raid_item_economy.gd")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCENT_TRAIL_MANAGER_SCRIPT := preload("res://scripts/scent_trail_manager.gd")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const SECONDS_PER_GAME_HOUR := 36.0
const SILHOUETTE_COLOR := Color("#26343b")
const STEALTH_TAKEDOWN_PROMPT_SIZE := Vector2(196.0, 54.0)
const STRUCTURE_REVEAL_BUILDING_ALPHA := 0.46
const STRUCTURE_REVEAL_HALF_ANGLE_DEG := 52.5
const STRUCTURE_REVEAL_RADIUS := 9.5
const STRUCTURE_REVEAL_VEHICLE_ALPHA := 0.58
const SUBWAY_SEALED_CARGO_TEXTURE := preload("res://assets/events/subway_sealed_cargo_v2.png")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const UI_SAFE_AREA := preload("res://scripts/ui_safe_area.gd")
const WEAPON_FLOAT_DISTANCE := 0.72
const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")
const WEAPON_MUZZLE_FORWARD_DISTANCE := 0.64
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")

var host: Node
var spawn_random: RandomNumberGenerator
var player: CharacterBody3D
var ammo_pickups: Array[Node3D] = []
var ammo_pickup_chain_total := 0
var ammo_pickup_chain_time := 0.0
var canned_food_texture: ImageTexture
var weapon_loot_texture_cache: Dictionary = {}


func attach(owner_node: Node) -> void:
	host = owner_node
	spawn_random = owner_node.spawn_random
	player = owner_node.player


func _create_loot_pickup(loot_type: String, world_position: Vector3, data: Dictionary = {}) -> Node3D:
	var pickup := Node3D.new()
	pickup.name = "Loot_%s_%d" % [loot_type, Time.get_ticks_usec()]
	host.add_child(pickup)
	pickup.global_position = Vector3(world_position.x, 0.34, world_position.z)
	pickup.set_meta("base_y", pickup.position.y)
	pickup.set_meta("loot_type", loot_type)
	for key in data:
		pickup.set_meta(str(key), data[key])

	var sprite := Sprite3D.new()
	sprite.name = "LootSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.render_priority = 88
	var highlight_color := Color("#f2d27a")
	match loot_type:
		"canned_food":
			sprite.texture = _get_canned_food_texture()
			sprite.pixel_size = 0.0062
			highlight_color = Color("#83c99a")
		"churu":
			sprite.texture = CHURU_TEXTURE
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 1.3794)
			highlight_color = Color("#f2bd55")
		"valuable":
			sprite.texture = UI_ICONS.get_icon("loot", 96, Color("#e6c979"))
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 0.58)
			highlight_color = Color("#e6c979")
		"medkit":
			sprite.texture = UI_ICONS.get_icon("medkit", 96, Color("#f4eee2"))
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 0.62)
			highlight_color = Color("#f2b16a")
		"mod_component":
			var component_id := str(data.get("component_id", "rubber_gasket"))
			sprite.texture = _get_mod_component_texture(component_id)
			sprite.pixel_size = _pickup_pixel_size(sprite.texture, 1.3167)
			highlight_color = _get_mod_component_color(component_id)
		"weapon_mod":
			sprite.texture = UI_ICONS.get_icon("mod", 96, Color("#dfc879"))
			sprite.pixel_size = 0.0062
			highlight_color = Color("#dfc879")
		"progression_item":
			var progression_item_id := str(data.get("progression_item_id", "rifle_blueprint"))
			var icon_name := "secure" if progression_item_id == "sealed_zone_keycard" else "craft"
			sprite.texture = UI_ICONS.get_icon(icon_name, 96, Color("#e7c96f"))
			sprite.pixel_size = 0.0062
			highlight_color = Color("#e7c96f")
		"weapon":
			var weapon_id := str(data.get("weapon_id", "ak47"))
			sprite.texture = _get_loot_weapon_texture(weapon_id)
			sprite.pixel_size = _loot_weapon_pixel_size(sprite.texture, weapon_id)
			highlight_color = Color("#df8f55")
		"armor":
			var equipment_id := str(data.get("equipment_id", "scav_vest"))
			var definition := GameState.get_equipment_definition(equipment_id)
			var slot := str(definition.get("slot", "body"))
			sprite.texture = _get_equipment_loot_texture(equipment_id)
			var target_long_edge := 0.7 if slot == "head" else 0.84
			var texture_long_edge := float(maxi(sprite.texture.get_width(), sprite.texture.get_height()))
			sprite.pixel_size = target_long_edge / maxf(texture_long_edge, 1.0)
			highlight_color = Color("#8bb9a4")
		_:
			sprite.texture = AMMO_762_TEXTURE
			sprite.pixel_size = 0.0032
	pickup.add_child(sprite)
	# 링 0.92는 화면에서 UI 버튼 크기로 보여 "깨진 버튼"으로 오해받았다.
	# 반쯤 줄이고 흐리게 — 월드의 물건은 월드의 물건처럼 보여야 한다.
	_add_loot_highlight(pickup, highlight_color, 0.52)
	ammo_pickups.append(pickup)
	return pickup


func _pickup_pixel_size(texture: Texture2D, target_world_size: float) -> float:
	# UI_ICONS.get_icon()은 커런시/아이템 아이콘에 대해 size 인자를 무시하고
	# 원본 해상도(예: 1254px)를 그대로 돌려준다. 고정 pixel_size를 쓰면
	# 아트 해상도에 따라 픽업이 건물만 해진다. 목표 월드 크기로 역산한다.
	if texture == null:
		return 0.0062
	var long_edge := float(maxi(texture.get_width(), texture.get_height()))
	return target_world_size / maxf(long_edge, 1.0)


func _loot_weapon_pixel_size(texture: Texture2D, weapon_id: String) -> float:
	if texture == null:
		return 0.001
	var target_long_edge := 1.25
	match weapon_id:
		"m1911":
			target_long_edge = 0.72
		"mp5":
			target_long_edge = 1.1
		"double_barrel", "pump_shotgun":
			target_long_edge = 1.3
	var texture_long_edge := float(maxi(texture.get_width(), texture.get_height()))
	return target_long_edge / maxf(texture_long_edge, 1.0)


func _get_canned_food_texture() -> ImageTexture:
	if canned_food_texture != null:
		return canned_food_texture
	var image := Image.create(72, 88, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(18, 12, 36, 64), Color("#26302d"))
	image.fill_rect(Rect2i(21, 15, 30, 58), Color("#71806d"))
	image.fill_rect(Rect2i(17, 12, 38, 8), Color("#b8b8aa"))
	image.fill_rect(Rect2i(17, 68, 38, 8), Color("#8b8d84"))
	image.fill_rect(Rect2i(23, 31, 26, 28), Color("#8e3f32"))
	image.fill_rect(Rect2i(27, 36, 18, 5), Color("#e0c77c"))
	image.fill_rect(Rect2i(27, 46, 18, 8), Color("#d5a953"))
	image.fill_rect(Rect2i(24, 18, 4, 47), Color(1.0, 1.0, 0.9, 0.2))
	canned_food_texture = ImageTexture.create_from_image(image)
	return canned_food_texture


func _get_loot_weapon_texture(weapon_id: String) -> Texture2D:
	var catalog_texture := WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
	if catalog_texture != null:
		return catalog_texture
	if weapon_loot_texture_cache.has(weapon_id):
		return weapon_loot_texture_cache[weapon_id]
	var image := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("#171b1c")
	match weapon_id:
		"m1911":
			image.fill_rect(Rect2i(26, 20, 77, 19), outline)
			image.fill_rect(Rect2i(31, 24, 68, 11), Color("#8f9895"))
			image.fill_rect(Rect2i(65, 35, 23, 25), outline)
			image.fill_rect(Rect2i(69, 37, 15, 19), Color("#76503d"))
		"mp5":
			image.fill_rect(Rect2i(16, 24, 101, 17), outline)
			image.fill_rect(Rect2i(22, 28, 88, 9), Color("#4d5654"))
			image.fill_rect(Rect2i(62, 38, 18, 24), outline)
			image.fill_rect(Rect2i(84, 38, 14, 17), outline)
		"double_barrel":
			image.fill_rect(Rect2i(47, 19, 75, 7), outline)
			image.fill_rect(Rect2i(47, 29, 75, 7), outline)
			image.fill_rect(Rect2i(51, 21, 68, 3), Color("#a3aaa4"))
			image.fill_rect(Rect2i(51, 31, 68, 3), Color("#7d8580"))
			image.fill_rect(Rect2i(10, 27, 43, 18), outline)
			image.fill_rect(Rect2i(15, 30, 34, 11), Color("#7d4e35"))
		_:
			return AK_DROP_TEXTURE
	var texture := ImageTexture.create_from_image(image)
	weapon_loot_texture_cache[weapon_id] = texture
	return texture


func _get_equipment_loot_texture(equipment_id: String) -> Texture2D:
	var definition := GameState.get_equipment_definition(equipment_id)
	var texture_path := str(definition.get("texture_path", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var texture := load(texture_path) as Texture2D
		if texture != null:
			return texture
	var slot := str(definition.get("slot", "body"))
	return UI_ICONS.get_icon(
		"helmet" if slot == "head" else "armor",
		96,
		Color("#b7c8bd")
	)


func _update_ammo_pickups(delta: float) -> void:
	host.ammo_notice_time = maxf(0.0, host.ammo_notice_time - delta)
	ammo_pickup_chain_time = maxf(0.0, ammo_pickup_chain_time - delta)
	if ammo_pickup_chain_time <= 0.0:
		ammo_pickup_chain_total = 0
	if host.hud.ammo_notice and host.ammo_notice_time <= 0.0 and host.hud.ammo_notice.visible:
		# 같은 리듬의 퇴장. 사라질 때도 툭 꺼지지 않는다.
		var fade := host.create_tween()
		var notice: Label = host.hud.ammo_notice
		fade.tween_property(notice, "modulate:a", 0.0, 0.18)
		fade.tween_callback(func() -> void:
			notice.visible = false
			notice.modulate.a = 1.0
		)
	var player_ground := Vector2(player.position.x, player.position.z)
	var nearest_distance := INF
	host.nearby_ammo_pickup = null
	for pickup in ammo_pickups.duplicate():
		if not is_instance_valid(pickup):
			ammo_pickups.erase(pickup)
			continue
		var base_y := float(pickup.get_meta("base_y", 0.3))
		pickup.position.y = base_y + sin(Time.get_ticks_msec() * 0.004 + pickup.position.x) * 0.04
		var pickup_ground := Vector2(pickup.position.x, pickup.position.z)
		var distance := player_ground.distance_to(pickup_ground)
		_update_loot_highlight(pickup, distance, delta)
		if distance <= PICKUP_DISTANCE and distance < nearest_distance:
			nearest_distance = distance
			host.nearby_ammo_pickup = pickup
	if host.hud.ammo_prompt_panel:
		host.hud.ammo_prompt_panel.visible = (
			is_instance_valid(host.nearby_ammo_pickup)
			and not is_instance_valid(host.nearby_field_interaction)
		)
	if host.hud.ammo_pickup_button and is_instance_valid(host.nearby_ammo_pickup):
		# 터치 기기에는 F키가 없다 — 있지도 않은 키를 안내하지 않는다.
		var pickup_name := str(host.nearby_ammo_pickup.get_meta("display_name", "Ammo"))
		host.hud.ammo_pickup_button.text = (
			pickup_name if DisplayServer.is_touchscreen_available() else "%s  [F]" % pickup_name
		)


func _collect_nearby_ammo() -> void:
	if not is_instance_valid(host.nearby_ammo_pickup):
		return
	var candidate := _build_pickup_candidate(host.nearby_ammo_pickup)
	if not GameState.can_add_raid_item(
		str(candidate.get("type", "")),
		str(candidate.get("id", "")),
		int(candidate.get("amount", 1))
	):
		_show_bag_full_notice()
		_open_loot_swap()
		return
	host._add_fatigue(FATIGUE_LOOT_GAIN)
	var loot_type := str(host.nearby_ammo_pickup.get_meta("loot_type", "ammo"))
	var amount := int(host.nearby_ammo_pickup.get_meta("amount", 1))
	# 획득 알림은 전부 토스트 스택으로 — 자동 장착(금색·길게)이 탄약 줍기에
	# 덮여 사라지던 문제를 스택이 해결한다.
	var toast_text := ""
	var toast_accent := HudStyle.GOLD
	var toast_seconds := 2.2
	match loot_type:
		"canned_food":
			GameState.canned_food += amount
			toast_text = "통조림 +%d   보유 %d" % [amount, GameState.canned_food]
			toast_accent = HudStyle.GREEN
		"churu":
			GameState.churu += amount
			toast_text = "희귀 츄르 +%d   보유 %d" % [amount, GameState.churu]
		"medkit":
			GameState.medkits += amount
			toast_text = "구급약 +%d   보유 %d" % [amount, GameState.medkits]
			toast_accent = HudStyle.GREEN
		"mod_component":
			var component_id := str(host.nearby_ammo_pickup.get_meta("component_id", "rubber_gasket"))
			GameState.add_mod_component(component_id, amount)
			host._advance_basic_mission("parts", amount)
			host._advance_contract_progress("parts", amount)
			# 처음 주운 부품에는 행선지를 붙인다. "팔 것"이 아니라 "개조 재료"라는
			# 걸 여기서 심어야 파밍이 계획이 된다. 본편 레슨은 쉘터의 사자가 잇는다.
			var component_hint := (
				""
				if GameState.workbench_lesson_seen or GameState.get_mod_component_count(component_id) > amount
				else "   → 쉘터 작업대에서 개조에 쓴다"
			)
			toast_text = "%s +%d   보유 %d%s" % [
				str(host.nearby_ammo_pickup.get_meta("display_name", "총기 부품")),
				amount,
				GameState.get_mod_component_count(component_id),
				component_hint,
			]
		"weapon_mod":
			var weapon_mod_id := str(host.nearby_ammo_pickup.get_meta("weapon_mod_id", "scope_2x"))
			GameState.add_weapon_mod(weapon_mod_id, amount)
			toast_text = "%s +%d" % [
				_raid_item_display_name("mod", weapon_mod_id),
				amount,
			]
		"progression_item":
			var progression_item_id := str(
				host.nearby_ammo_pickup.get_meta("progression_item_id", "rifle_blueprint")
			)
			GameState.add_progression_item(progression_item_id, amount)
			# 진행도 품목은 칸 0 — 가방이 꽉 차도 먹힌다는 걸 토스트에서 바로 말해 준다.
			var mission_tag := (
				"임무 품목 · " if bool(host.nearby_ammo_pickup.get_meta("mission_item", false)) else ""
			)
			toast_text = "%s 획득 · %s가방 칸 사용 안 함" % [
				str(host.nearby_ammo_pickup.get_meta("display_name", "진행도 아이템")),
				mission_tag,
			]
			# 설계도 조각은 "몇 조각 모였는지"가 곧 보상이다 — n/3을 붙이고 3/3이면 해금을 말한다.
			if progression_item_id.begins_with(LOOT_ECONOMY.BLUEPRINT_SHARD_PREFIX):
				var recipe_id := progression_item_id.trim_prefix(LOOT_ECONOMY.BLUEPRINT_SHARD_PREFIX)
				toast_text = "%s +%d · %s" % [
					str(host.nearby_ammo_pickup.get_meta("display_name", "설계도 조각")),
					amount,
					str(GameState.get_blueprint_progress_text(recipe_id)),
				]
				if GameState.is_blueprint_unlocked(recipe_id):
					toast_text += " → 작업대 제작 해금"
			toast_seconds = 3.2
		"weapon":
			var weapon_id := str(host.nearby_ammo_pickup.get_meta("weapon_id", "ak47"))
			GameState.add_weapon(weapon_id, amount)
			toast_text = "%s 보관 +%d" % [
				str(host.nearby_ammo_pickup.get_meta("display_name", "무기")),
				amount,
			]
			# 사다리 상위 무기를 처음 주웠다면 강화 이관을 한 줄 더 띄운다.
			var transfer_notice := GameState.take_weapon_enhancement_transfer_notice()
			if not transfer_notice.is_empty():
				host.hud.push_toast(transfer_notice, HudStyle.GOLD, 3.4)
		"valuable":
			# 엘리트 확정 드랍으로 귀중품이 바닥 픽업으로 흔해졌다. 이 match에
			# "valuable" 분기가 없어서 아래 탄약 분기로 떨어져 762탄이 지급되던
			# 잠복 버그를 함께 고친다 — 귀중품 원장(valuable_inventory)에 넣는다.
			var valuable_id := str(host.nearby_ammo_pickup.get_meta("item_id", "subway_token"))
			GameState.try_add_raid_item("valuable", valuable_id, amount)
			toast_text = "%s +%d   쉘터 복귀 시 고철로 환전" % [
				str(host.nearby_ammo_pickup.get_meta("display_name", "귀중품")),
				amount,
			]
		"armor":
			var equipment_id := str(host.nearby_ammo_pickup.get_meta("equipment_id", "scav_vest"))
			if GameState.add_equipment(equipment_id, amount):
				toast_text = _armor_pickup_notice(equipment_id)
				toast_seconds = 3.0
			else:
				toast_text = "장비 정보를 확인할 수 없습니다."
		_:
			var pickup_ammo_id := str(host.nearby_ammo_pickup.get_meta("ammo_id", "762_fmj"))
			var updated_ammo_count: int = GameState.get_ammo_count(pickup_ammo_id) + amount
			GameState.set_ammo_count(pickup_ammo_id, updated_ammo_count)
			if GameState.equipped_ammo_id == pickup_ammo_id:
				host.reserve_ammo = updated_ammo_count
			GameState.reserve_ammo = host.reserve_ammo
			if ammo_pickup_chain_time <= 0.0:
				ammo_pickup_chain_total = 0
			ammo_pickup_chain_total += amount
			ammo_pickup_chain_time = 2.4
			toast_text = "+%d %s   보유 %d" % [
				amount,
				str(host.nearby_ammo_pickup.get_meta("display_name", "탄약")),
				updated_ammo_count,
			]
	host.hud.push_toast(toast_text, toast_accent, toast_seconds)
	# 쉘터 다음 목표(티어 확장)에 필요한 품목이면 진행도를 한 줄 더 — 필드에서
	# "왜 줍나"가 쉘터 화면의 목표 줄과 같은 숫자로 이어진다.
	if loot_type == "churu":
		var goal_note: String = SHELTER_REQUISITION.describe_progress_after_pickup("churu")
		if not goal_note.is_empty():
			host.hud.push_toast(goal_note, HudStyle.GOLD, 2.6)
	SFX.play("pickup")
	host._update_equipment_ui()
	host._update_medkit_button()
	ammo_pickups.erase(host.nearby_ammo_pickup)
	host.nearby_ammo_pickup.queue_free()
	host.nearby_ammo_pickup = null
	host.hud.ammo_prompt_panel.visible = false


func _armor_pickup_notice(equipment_id: String) -> String:
	# 파밍의 결정적 순간. 주운 방어구가 더 좋으면 즉시 갈아 끼우고, 무엇이
	# 얼마나 좋아졌는지 그 자리에서 보여 준다. 이 피드백이 곧 손맛이다.
	var result := GameState.equip_if_upgrade(equipment_id)
	var display_name := str(result.get("display_name", "방어구"))
	var slot := str(result.get("slot", "body"))
	if not bool(result.get("equipped", false)):
		return "%s 획득 · 지금 장비가 더 낫다 (가방 보관)" % display_name
	if slot == "feet":
		return "▲ %s 장착! 발이 더 가벼워졌다" % display_name
	var new_pct := roundi(float(result.get("new_score", 0.0)))
	var previous_id := str(result.get("previous_id", ""))
	if previous_id.is_empty():
		return "▲ %s 장착! 방어 +%d%%" % [display_name, new_pct]
	var previous_pct := roundi(float(result.get("previous_score", 0.0)))
	return "▲ %s 장착! 방어 %d%% → %d%%" % [display_name, previous_pct, new_pct]


func _show_bag_full_notice() -> void:
	host.hud.push_toast("가방이 꽉 찼습니다", HudStyle.WARN, 2.2)
	# 처음 가방이 찬 순간이 이 게임의 핵심을 가르칠 유일한 자리다.
	# 조작이 아니라 "무엇을 버릴 것인가"를 가르쳐야 한다.
	if not GameState.bag_pressure_lesson_seen:
		GameState.bag_pressure_lesson_seen = true
		GameState.save_persistent_state()
		host._show_field_notice(
			"가방은 여기까지다.\n"
			+ "이제부터는 줍는 게 아니라 고르는 일이다. "
			+ "칸당 가치가 낮은 물건을 버리고 비싼 것을 실어라.\n"
			+ "살아서 나가야 내 것이 된다."
		)
	host._update_equipment_ui()


# ── 전리품 교체 UI ──────────────────────────────────────────────
# 완성된 채 배선이 빠져 한 번도 뜬 적 없던 LootSwapUI를 연결한다.
# 가방이 차면 토스트 한 줄 대신 "무엇을 버리고 무엇을 실을까"를 가치와
# 칸 수로 비교하는 교체 화면이 뜬다 — 이 게임 핵심 결정의 전용 UI.
var loot_swap: LootSwapUI


func _ensure_loot_swap_ui() -> void:
	if loot_swap != null and is_instance_valid(loot_swap):
		return
	# 전용 최상위 CanvasLayer — HUD 캔버스에 넣으면 시야 안개·다른 HUD 레이어가
	# 모달 위에 그려져 "묻힌" 화면이 됐다(스크린샷 실측). 일시정지 중에도
	# 동작해야 하므로 ALWAYS.
	var swap_layer := CanvasLayer.new()
	swap_layer.name = "LootSwapLayer"
	swap_layer.layer = 95
	swap_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(swap_layer)
	loot_swap = LootSwapUI.new()
	loot_swap.name = "LootSwapUI"
	swap_layer.add_child(loot_swap)
	loot_swap.setup(HudStyle.FONT)
	loot_swap.visible = false
	loot_swap.discard_requested.connect(_on_loot_swap_discard)
	loot_swap.claim_requested.connect(_on_loot_swap_claim)


func is_loot_swap_open() -> bool:
	# main의 수동 입력 라우터(근접 공격·조이스틱)가 모달 위 터치를 삼키지 않도록
	# 게이트에 쓰는 단일 판정.
	return loot_swap != null and is_instance_valid(loot_swap) and loot_swap.visible


func _open_loot_swap() -> void:
	if not is_instance_valid(host.nearby_ammo_pickup):
		return
	_ensure_loot_swap_ui()
	loot_swap.open(
		_build_pickup_candidate(host.nearby_ammo_pickup),
		_build_bag_swap_entries(),
		GameState.get_raid_bag_used_slots(),
		GameState.get_raid_bag_capacity()
	)


func _build_bag_swap_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_value in GameState.get_raid_bag_entries():
		var raw := raw_value as Dictionary
		var item_type := str(raw.get("type", ""))
		var item_id := str(raw.get("id", ""))
		var count := int(raw.get("count", 0))
		var drop_amount := int(raw.get("drop_amount", 1))
		var slot_cost := GameState.get_raid_item_slot_cost(item_type, item_id, count)
		var total_value := RAID_ITEM_ECONOMY.get_total_value(
			item_type, item_id, count, GameState.raid_special_cargo
		)
		var drop_value := RAID_ITEM_ECONOMY.get_total_value(
			item_type, item_id, drop_amount, GameState.raid_special_cargo
		)
		entries.append({
			"type": item_type,
			"id": item_id,
			"count": count,
			"drop_amount": drop_amount,
			"drop_value": drop_value,
			"slot_cost": slot_cost,
			"total_value": total_value,
			"value_per_slot": float(total_value) / float(maxi(1, slot_cost)),
			"title": _raid_item_display_name(item_type, item_id),
			"description": _raid_item_description(item_type, item_id),
			"texture": _raid_item_texture(item_type, item_id),
			"protected": RAID_ITEM_ECONOMY.is_protected(item_type, item_id),
		})
	return entries


func _on_loot_swap_discard(entry: Dictionary) -> void:
	var item_type := str(entry.get("type", ""))
	var item_id := str(entry.get("id", ""))
	var amount := int(entry.get("drop_amount", 1))
	var removed := GameState.remove_raid_bag_item(item_type, item_id, amount)
	if removed <= 0:
		loot_swap.show_feedback("버릴 수 없는 물품입니다.")
		return
	_spawn_discarded_raid_item(item_type, item_id, removed)
	host._update_equipment_ui()
	loot_swap.show_feedback("%s x%d을 내려놓았다" % [str(entry.get("title", "휴대품")), removed])
	# 최신 상태로 다시 그린다 — 자리가 났으면 '바로 획득'이 살아난다.
	if is_instance_valid(host.nearby_ammo_pickup):
		loot_swap.open(
			_build_pickup_candidate(host.nearby_ammo_pickup),
			_build_bag_swap_entries(),
			GameState.get_raid_bag_used_slots(),
			GameState.get_raid_bag_capacity()
		)
	else:
		loot_swap.close()


func _on_loot_swap_claim() -> void:
	loot_swap.close()
	if is_instance_valid(host.nearby_ammo_pickup):
		_collect_nearby_ammo()


func _build_pickup_candidate(pickup: Node3D) -> Dictionary:
	var loot_type := str(pickup.get_meta("loot_type", "ammo"))
	var amount := maxi(1, int(pickup.get_meta("amount", 1)))
	var item_type := "ammo"
	var item_id := str(pickup.get_meta("ammo_id", "762_fmj"))
	match loot_type:
		"canned_food":
			item_type = "food"
			item_id = "canned_food"
		"churu":
			item_type = "churu"
			item_id = "churu"
		"valuable":
			item_type = "valuable"
			item_id = str(pickup.get_meta("item_id", "subway_token"))
		"medkit":
			item_type = "medkit"
			item_id = "medkit"
		"mod_component":
			item_type = "component"
			item_id = str(pickup.get_meta("component_id", "rubber_gasket"))
		"weapon_mod":
			item_type = "mod"
			item_id = str(pickup.get_meta("weapon_mod_id", "scope_2x"))
		"progression_item":
			item_type = "progression"
			item_id = str(pickup.get_meta("progression_item_id", "rifle_blueprint"))
		"weapon":
			item_type = "weapon"
			item_id = str(pickup.get_meta("weapon_id", "ak47"))
		"armor":
			item_type = "equipment"
			item_id = str(pickup.get_meta("equipment_id", "scav_vest"))
	var required := GameState.get_raid_item_added_slot_delta(item_type, item_id, amount)
	var display_slots := maxi(1, required)
	var total_value := RAID_ITEM_ECONOMY.get_total_value(
		item_type,
		item_id,
		amount,
		GameState.raid_special_cargo
	)
	return {
		"type": item_type,
		"id": item_id,
		"amount": amount,
		"title": str(pickup.get_meta("display_name", _raid_item_display_name(item_type, item_id))),
		"description": _raid_item_description(item_type, item_id),
		"texture": _raid_item_texture(item_type, item_id),
		"required_slots": required,
		"display_slots": display_slots,
		"total_value": total_value,
		"value_per_slot": float(total_value) / float(display_slots),
		"protected": RAID_ITEM_ECONOMY.is_protected(item_type, item_id),
	}


func _spawn_discarded_raid_item(item_type: String, item_id: String, amount: int) -> void:
	var drop_position: Vector3 = player.global_position + host._get_current_facing_world_direction() * 1.25
	var loot_type := "ammo"
	var data := {
		"amount": amount,
		"display_name": _raid_item_display_name(item_type, item_id),
	}
	match item_type:
		"weapon":
			loot_type = "weapon"
			data["weapon_id"] = item_id
		"equipment":
			loot_type = "armor"
			data["equipment_id"] = item_id
		"ammo":
			data["ammo_id"] = item_id
		"component":
			loot_type = "mod_component"
			data["component_id"] = item_id
		"progression":
			loot_type = "progression_item"
			data["progression_item_id"] = item_id
		"medkit":
			loot_type = "medkit"
		"food":
			loot_type = "canned_food"
		"churu":
			loot_type = "churu"
		"valuable":
			loot_type = "valuable"
			data["item_id"] = item_id
		"mod":
			loot_type = "weapon_mod"
			data["weapon_mod_id"] = item_id
	_create_loot_pickup(loot_type, drop_position, data)


func _raid_item_display_name(item_type: String, item_id: String) -> String:
	if item_type == "special_cargo":
		return str(GameState.raid_special_cargo.get("title", "봉인된 지하철 화물"))
	if item_type == "weapon":
		return str(WEAPON_SYSTEM.get_weapon(item_id).get("display_name", item_id))
	if item_type == "equipment":
		return str(GameState.get_equipment_definition(item_id).get("display_name", item_id))
	if item_type == "mod":
		return str(WEAPON_SYSTEM.get_mod(item_id).get("display_name", item_id))
	if item_type == "valuable":
		# 귀중품은 종류가 많다. 이름은 카탈로그가 단일 진실 원천이다.
		return str(
			(LOOT_ECONOMY.ITEM_CATALOG.get(item_id, {}) as Dictionary).get("display_name", item_id)
		)
	var names := {
		"9mm_fmj": "9mm FMJ 탄환",
		"45_fmj": ".45 ACP FMJ 탄환",
		"762_fmj": "7.62mm FMJ 탄환",
		"12g_buckshot": "12게이지 벅샷",
		"9mm_ap": "9mm AP 탄환",
		"45_ap": ".45 ACP AP 탄환",
		"762_ap": "7.62mm AP 탄환",
		"12g_slug": "12게이지 슬러그",
		"rubber_gasket": "소음기용 고무 패킹",
		"scope_lens": "스코프 렌즈",
		"magazine_spring": "탄창 스프링",
		"canned_food": "통조림",
		"medkit": "구급약",
		"churu": "희귀 츄르",
		"precision_gear": "정밀 기어",
		"military_alloy": "군용 합금",
		"artisan_seal": "장인의 인장",
		"rifle_blueprint": "소총 제작 청사진",
		"shotgun_blueprint": "산탄총 제작 청사진",
		"akm_blueprint": "AKM 개조 청사진",
		"pump_blueprint": "펌프 산탄총 청사진",
		"sealed_zone_keycard": "봉인구역 키카드",
		"namdaemun_depot_plans": "남대문 창고 설계도",
		"euljiro_grid_schematic": "을지로 배전 도면",
		"yongsan_control_key": "용산 통제 키",
	}
	if names.has(item_id):
		return str(names[item_id])
	# 설계도 조각·신규 진행 아이템은 카탈로그가 이름을 안다.
	var catalog_name := str((LOOT_ECONOMY.ITEM_CATALOG.get(item_id, {}) as Dictionary).get("display_name", ""))
	return catalog_name if not catalog_name.is_empty() else item_id


func _raid_item_description(item_type: String, item_id: String) -> String:
	match item_type:
		"weapon":
			return "주무기로 장착하거나 쉘터에서 보관·판매할 수 있습니다."
		"equipment":
			return str(GameState.get_equipment_definition(item_id).get("description", "방어 장비입니다."))
		"ammo":
			return "구경이 맞는 총기에 사용하는 실탄입니다."
		"component", "mod":
			return "작업대 제작과 총기 개조에 사용하는 부품입니다."
		"progression":
			return "상위 제작과 봉인구역 진입에 필요한 희귀 물품입니다."
		"food":
			return "던져서 적을 유인하고, 귀환하면 쉘터 훈련 재고가 됩니다. 먹는 물건이 아닙니다."
		"churu":
			return "쉘터 확장에 쓰이는 희귀 재화입니다."
		"valuable":
			return "쓸 데는 없지만 값이 나갑니다. 쉘터에서 고철로 바꿉니다."
		"medkit":
			return "필드에서 체력을 회복하는 응급 치료품입니다."
	return "레이드에서 확보한 휴대품입니다."


func _raid_item_texture(item_type: String, item_id: String) -> Texture2D:
	match item_type:
		"weapon":
			return WEAPON_VISUAL_CATALOG.get_weapon_texture(item_id)
		"equipment":
			return _get_equipment_loot_texture(item_id)
		"component":
			return _get_mod_component_texture(item_id)
		"special_cargo":
			return SUBWAY_SEALED_CARGO_TEXTURE
		"food":
			return _get_canned_food_texture()
		"churu":
			return CHURU_TEXTURE
		"medkit":
			return UI_ICONS.get_icon("medkit", 96, Color("#f4eee2"))
		"valuable":
			return UI_ICONS.get_icon("loot", 96, Color("#e6c979"))
		"progression":
			return UI_ICONS.get_icon("secure", 96, Color("#e7c96f"))
		"mod":
			return UI_ICONS.get_icon("parts", 96, Color("#d6bf82"))
	return AMMO_762_TEXTURE


func _get_mod_component_texture(component_id: String) -> Texture2D:
	match component_id:
		"scope_lens": return SCOPE_LENS_TEXTURE
		"magazine_spring": return MAGAZINE_SPRING_TEXTURE
		# 희귀 부품 2종 — 전용 텍스처는 2단계 UI 몫. 지금은 식별 가능한 아이콘으로.
		"precision_gear": return UI_ICONS.get_icon("upgrade", 96, Color("#e8d27a"))
		"military_alloy": return UI_ICONS.get_icon("secure", 96, Color("#9fc3e0"))
		_: return RUBBER_GASKET_TEXTURE


func _get_mod_component_color(component_id: String) -> Color:
	match component_id:
		"scope_lens": return Color("#65c5d7")
		"magazine_spring": return Color("#b4b9ae")
		"precision_gear": return Color("#e8d27a")
		"military_alloy": return Color("#9fc3e0")
		_: return Color("#d1aa64")


func _add_loot_highlight(pickup: Node3D, color: Color, radius: float) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.2)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.1

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.9
	ring_mesh.outer_radius = radius
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	ring_mesh.material = material
	var ring := MeshInstance3D.new()
	ring.name = "LootRing"
	ring.position.y = -0.26
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pickup.add_child(ring)

	var marker := Sprite3D.new()
	marker.name = "LootMarker"
	marker.texture = host._get_loot_glow_texture()
	marker.position.y = 1.1
	marker.pixel_size = 0.006
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.transparent = true
	marker.no_depth_test = true
	marker.render_priority = 120
	marker.modulate = color
	pickup.add_child(marker)


func _update_loot_highlight(pickup: Node3D, distance: float, _delta: float) -> void:
	var ring := pickup.get_node_or_null("LootRing") as MeshInstance3D
	var marker := pickup.get_node_or_null("LootMarker") as Sprite3D
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 + pickup.position.x)
	var near_boost := 1.0 if distance > PICKUP_DISTANCE else 1.28
	if ring:
		var scale_value := near_boost * (1.0 + pulse * 0.16)
		ring.scale = Vector3(scale_value, scale_value, scale_value)
	if marker:
		marker.position.y = 1.05 + pulse * 0.18
		var color := marker.modulate
		color.a = 0.58 + pulse * 0.36
		marker.modulate = color


