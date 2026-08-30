class_name CanThrowSystem
extends RefCounted

# 투척/배치 선택기 — 통조림(유인)과 중장비(지뢰·포탑·로켓)를 한 조준 UI로.
# 버튼을 누르면 사거리 링이 보이고, 링 안을 탭하면 그 지점으로 던진다/설치한다.
# 통조림: 착지 소리를 들은 비경계 적이 달려와 먹는 동안 지나가거나 암살한다.
#
# 조작(2026-08-29 중장비 1차):
#   데스크톱 — T로 조준을 열고, 조준 중 T를 짧게 다시 누르면 다음 품목으로 순환.
#             (보유 품목이 하나뿐이면 T는 예전처럼 취소로 동작한다.)
#   모바일  — 투척 버튼 탭 = 조준 토글, 길게(0.45s) 누르면 품목 순환.
#   발사    — 기존 그대로 링 안 클릭/탭. 포탑은 '배치'(사거리 5m), 로켓은 사거리 18m.
#
# 규칙: 이 파일은 "무엇을 어디로"만 안다. 통조림 유인은 enemy.gd의 lure_point가,
# 중장비의 전투 로직은 scripts/raid/deployables.gd가, 버튼 배치는
# main._apply_hud_layout이 맡는다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

const THROW_RANGE := 17.0
const NOISE_RADIUS := 13.0
const EAT_DURATION := 6.5
const AIM_TIMEOUT := 6.0
# 모바일 투척 버튼 길게 누름 = 품목 순환(기존 style_mobile_action 버튼 규약 유지).
const CYCLE_HOLD_SECONDS := 0.45

# 순환 순서 — 보유한 것만 돈다. 통조림 → 지뢰 → 포탑 → 로켓 → 드론 → 카트.
const THROW_KINDS := [
	"canned_food", "field_mine", "salvage_turret", "rocket_launcher",
	"escort_drone", "supply_cart", "strike_drone",
]
const KIND_INFO := {
	"canned_food": {
		"label": "던지기", "toast": "통조림", "icon": "food",
		"color": Color("#79b98d"), "range": THROW_RANGE,
	},
	"field_mine": {
		"label": "지뢰", "toast": "지뢰", "icon": "alert",
		"color": Color("#57d9c4"), "range": THROW_RANGE,
	},
	"salvage_turret": {
		"label": "포탑", "toast": "감시포탑", "icon": "parts",
		"color": Color("#57d9c4"), "range": 5.0,
	},
	"rocket_launcher": {
		"label": "로켓", "toast": "로켓 발사기", "icon": "raid",
		"color": Color("#e8b46a"), "range": 18.0,
	},
	# 드론·카트는 조준점이 필요 없다 — 링 안 아무 데나 탭하면 확정(소환 위치는
	# 드론=머리 위, 카트=플레이어 뒤). 링을 작게 줘서 "위치를 고르는 게 아니다"를 말한다.
	"escort_drone": {
		"label": "드론", "toast": "호위 드론", "icon": "dash",
		"color": Color("#57d9c4"), "range": 3.0,
	},
	"supply_cart": {
		"label": "카트", "toast": "보급 카트", "icon": "backpack",
		"color": Color("#d8b56a"), "range": 3.0,
	},
	# 타격 드론도 조준점 불필요 — 확정하면 즉시 락온 모드가 켜진다.
	"strike_drone": {
		"label": "타격", "toast": "타격 드론", "icon": "raid",
		"color": Color("#57d9c4"), "range": 3.0,
	},
}
const EATER_LINES := [
	"이게 웬 횡재냐",
	"아직 안 뜯었잖아?",
	"먹을 게 다 있네",
	"누가 이걸 흘렸어",
	"오늘 운 좋다",
	"뚜껑도 안 땄네",
]
# 착지 소리에 '반응하는 순간'의 대사 — 도착해 먹기 전, 던진 즉시 피드백이
# 있어야 유인이 먹혔는지 알 수 있다.
const REACT_LINES := [
	"응? 저 소리…",
	"밥 냄새다",
	"누가 통조림 흘렸나?",
	"저쪽에서 깡통 소리 났는데",
]

var host: Node
var player: Node3D
var camera: Camera3D

var throw_button: Button
var aiming := false
var aim_timeout_left := 0.0
var range_ring: MeshInstance3D

var active_can: Node3D
var can_gauge_bg: Sprite3D
var can_gauge_fill: Sprite3D
var eat_time_left := 0.0
var eating_started := false
var spoken_enemies: Array = []
var clank_player: AudioStreamPlayer3D

# ── 투척/배치 선택기 상태 ──
var selected_kind := "canned_food"
var button_icon_kind := ""
# 모바일 길게 누름 순환 추적 — 놓기 전까지는 토글하지 않는다.
var hold_touch_index := -1
var hold_elapsed := 0.0
var hold_cycled := false


func attach(owner_node: Node) -> void:
	host = owner_node
	player = host.get_node("Player")
	camera = host.get_node("CameraRig/Camera3D")
	_build_button()
	_build_range_ring()


func _build_button() -> void:
	throw_button = Button.new()
	throw_button.name = "CanThrowButton"
	throw_button.text = "던지기"
	throw_button.icon = UI_ICONS.get_icon("food", 34, Color("#a8d8b4"))
	throw_button.tooltip_text = "통조림 던지기 — 소리로 적을 유인한다"
	throw_button.z_index = 90
	HudStyle.style_mobile_action(throw_button, Color("#79b98d"), 36, false, HudStyle.TYPE_BODY)
	throw_button.visible = false
	if not DisplayServer.is_touchscreen_available():
		throw_button.pressed.connect(toggle_aim)
	host.get_node("HUD").add_child(throw_button)


func _build_range_ring() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.47, 0.72, 0.55, 0.28)
	material.emission_enabled = true
	material.emission = Color("#79b98d")
	material.emission_energy_multiplier = 1.1
	var torus := TorusMesh.new()
	torus.inner_radius = THROW_RANGE - 0.09
	torus.outer_radius = THROW_RANGE
	torus.rings = 48
	torus.ring_segments = 10
	torus.material = material
	range_ring = MeshInstance3D.new()
	range_ring.name = "CanThrowRangeRing"
	range_ring.mesh = torus
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_ring.visible = false
	host.add_child(range_ring)


func get_kind_count(kind: String) -> int:
	if kind == "canned_food":
		return maxi(0, int(GameState.canned_food))
	return GameState.get_heavy_gear_count(kind)


func get_available_kinds() -> Array:
	var available: Array = []
	for kind in THROW_KINDS:
		if get_kind_count(str(kind)) > 0:
			available.append(str(kind))
	return available


func has_any_throwable() -> bool:
	return not get_available_kinds().is_empty()


func get_selected_label() -> String:
	return str((KIND_INFO[selected_kind] as Dictionary).get("toast", "투척"))


func get_selected_count() -> int:
	return get_kind_count(selected_kind)


func _ensure_valid_selection() -> void:
	if get_kind_count(selected_kind) > 0:
		return
	var available := get_available_kinds()
	selected_kind = str(available[0]) if not available.is_empty() else "canned_food"
	_apply_ring_style()


func cycle_selection() -> void:
	# 보유한 것만 순환 — 다음 품목으로 넘어가며 토스트로 알린다.
	var available := get_available_kinds()
	if available.is_empty():
		return
	var index := available.find(selected_kind)
	selected_kind = str(available[(index + 1) % available.size()])
	_apply_ring_style()
	aim_timeout_left = AIM_TIMEOUT
	var info := KIND_INFO[selected_kind] as Dictionary
	host.hud.push_toast(
		"%s x%d 선택" % [str(info.get("toast", "")), get_kind_count(selected_kind)],
		info.get("color", Color("#79b98d")) as Color,
		1.4
	)
	if host.has_method("_update_medkit_button"):
		host.call("_update_medkit_button")


func on_throw_key() -> void:
	# 데스크톱 T — 닫혀 있으면 조준을 열고, 조준 중 짧게 다시 누르면 다음 품목.
	# 품목이 하나뿐이면 순환할 곳이 없으니 예전처럼 취소로 동작한다.
	if not aiming:
		toggle_aim()
		return
	if get_available_kinds().size() > 1:
		cycle_selection()
	else:
		_set_aiming(false)


func toggle_aim() -> void:
	if aiming:
		_set_aiming(false)
		return
	_ensure_valid_selection()
	if not has_any_throwable():
		return
	_set_aiming(true)
	# 모드에 들어왔음을 문장으로 말한다 — 링만으로는 "지금 탭하면 던진다"를
	# 모른다. (판당 처음 2회만, 이후엔 조용히)
	var hint_count := int(host.get_meta("can_throw_hint_count", 0))
	if hint_count < 2:
		host.set_meta("can_throw_hint_count", hint_count + 1)
		host.hud.push_toast("링 안을 탭하면 투척·배치 · T 짧게 = 품목 전환", Color("#79b98d"), 2.6)


func _selected_range() -> float:
	return float((KIND_INFO[selected_kind] as Dictionary).get("range", THROW_RANGE))


func _apply_ring_style() -> void:
	if range_ring == null:
		return
	# 링 반경은 품목 사거리(포탑 5m·로켓 18m), 색은 품목 식별색.
	range_ring.scale = Vector3.ONE * (_selected_range() / THROW_RANGE)
	var info := KIND_INFO[selected_kind] as Dictionary
	var accent := info.get("color", Color("#79b98d")) as Color
	var torus := range_ring.mesh as TorusMesh
	var material := torus.material as StandardMaterial3D if torus != null else null
	if material != null:
		material.albedo_color = Color(accent.r, accent.g, accent.b, 0.28)
		material.emission = accent


func _set_aiming(value: bool) -> void:
	aiming = value
	aim_timeout_left = AIM_TIMEOUT
	if value:
		_apply_ring_style()
	if range_ring != null:
		range_ring.visible = value


func is_aiming() -> bool:
	return aiming


func update(delta: float) -> void:
	_update_cycle_hold(delta)
	_refresh_button()
	if aiming:
		aim_timeout_left -= delta
		if get_selected_count() <= 0:
			# 마지막 하나를 쓴 품목 — 남은 게 있으면 자동으로 넘어간다.
			_ensure_valid_selection()
		if aim_timeout_left <= 0.0 or not has_any_throwable():
			_set_aiming(false)
		elif range_ring != null and is_instance_valid(player):
			range_ring.global_position = Vector3(
				player.global_position.x, 0.12, player.global_position.z
			)
	_update_active_can(delta)


func _update_cycle_hold(delta: float) -> void:
	if hold_touch_index == -1 or hold_cycled:
		return
	hold_elapsed += delta
	if hold_elapsed >= CYCLE_HOLD_SECONDS:
		hold_cycled = true
		if get_available_kinds().size() > 1:
			cycle_selection()
			if DisplayServer.is_touchscreen_available() and bool(AccessibilitySettings.vibration_enabled):
				Input.vibrate_handheld(18)


func _refresh_button() -> void:
	if throw_button == null:
		return
	_ensure_valid_selection()
	var info := KIND_INFO[selected_kind] as Dictionary
	var count := get_selected_count()
	# 조준 중엔 버튼이 취소+남은 시간 카운트다운으로 바뀐다.
	var next_text := (
		"취소 %d" % ceili(aim_timeout_left)
		if aiming
		else "%s\nx%d" % [str(info.get("label", "던지기")), count]
	)
	if throw_button.text != next_text:
		throw_button.text = next_text
	# 배지: 현재 품목 아이콘 — 품목이 바뀔 때만 다시 만든다.
	if button_icon_kind != selected_kind:
		button_icon_kind = selected_kind
		throw_button.icon = UI_ICONS.get_icon(
			str(info.get("icon", "food")), 34, info.get("color", Color("#a8d8b4")) as Color
		)
		throw_button.tooltip_text = (
			"%s 투척/배치 — 길게 누르면 품목 전환" % str(info.get("toast", ""))
		)
	throw_button.disabled = not has_any_throwable() and not aiming
	# 조준 중엔 버튼이 '취소'로 읽히도록 눌린 상태를 유지한다.
	throw_button.toggle_mode = true
	if throw_button.button_pressed != aiming:
		throw_button.set_pressed_no_signal(aiming)


func handle_touch(touch_position: Vector2, touch_index: int = -1) -> bool:
	# main의 터치 라우터가 부른다. true를 돌려주면 이벤트를 소비한 것.
	if throw_button != null and throw_button.visible and not throw_button.disabled \
		and throw_button.get_global_rect().has_point(touch_position):
		# 짧게 = 토글(놓을 때), 길게 = 품목 순환 — 판정은 release/update가 한다.
		hold_touch_index = touch_index
		hold_elapsed = 0.0
		hold_cycled = false
		return true
	if aiming:
		# 조준 모드가 화면 전체를 삼키면 안 된다: 조이스틱 영역과 다른 버튼
		# 위 터치는 통과시켜 이동·행동을 유지하고, 실수로 캔이 날아가는
		# 경로를 좁힌다. 착탄 지정은 "그 외의 화면"에서만.
		var viewport_size := host.get_viewport().get_visible_rect().size
		var in_joystick_zone: bool = (
			touch_position.x < viewport_size.x * 0.55
			and touch_position.y > viewport_size.y * 0.6
		)
		if in_joystick_zone or _touch_on_other_button(touch_position):
			return false
		throw_at_screen(touch_position)
		return true
	return false


func handle_touch_release(touch_index: int) -> bool:
	# 투척 버튼 위에서 시작한 터치의 release — 길게 눌러 순환했다면 토글하지 않는다.
	if hold_touch_index == -1 or touch_index != hold_touch_index:
		return false
	var cycled := hold_cycled
	hold_touch_index = -1
	hold_elapsed = 0.0
	hold_cycled = false
	if not cycled:
		toggle_aim()
	return true


func _touch_on_other_button(touch_position: Vector2) -> bool:
	for button_value in [
		host.hud.fire_button, host.hud.dash_button,
		host.mobile_medkit_button, host.mobile_reload_button,
		host.mobile_context_button, host.mobile_map_button,
	]:
		var button := button_value as Button
		if button != null and button.visible and button.get_global_rect().has_point(touch_position):
			return true
	return false


func throw_at_screen(screen_position: Vector2) -> void:
	_ensure_valid_selection()
	if get_selected_count() <= 0:
		_set_aiming(false)
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.001:
		return
	var distance_to_plane := (0.1 - ray_origin.y) / ray_direction.y
	var target := ray_origin + ray_direction * distance_to_plane
	var offset := target - player.global_position
	offset.y = 0.0
	var kind_range := _selected_range()
	if offset.length() > kind_range:
		target = player.global_position + offset.normalized() * kind_range
	target.y = 0.1
	_dispatch_selected(target)


func _dispatch_selected(target: Vector3) -> void:
	# 품목별 실행 — 통조림은 이 파일이, 중장비는 deployables가 맡는다.
	var deployables = host.get("deployables")
	match selected_kind:
		"canned_food":
			_set_aiming(false)
			_throw_to(target)
		"field_mine":
			if deployables != null and GameState.consume_heavy_gear("field_mine", 1):
				_set_aiming(false)
				deployables.call("throw_mine", target)
		"salvage_turret":
			if deployables != null and GameState.consume_heavy_gear("salvage_turret", 1):
				_set_aiming(false)
				deployables.call("place_turret", target)
		"rocket_launcher":
			# 발사기는 발수(판 로컬)로 소모된다 — 쿨다운 1.2s, 조준은 유지해
			# 연사 리듬을 지킨다. 3발 소진 시 deployables가 아이템을 버린다.
			if deployables != null and bool(deployables.call("fire_rocket", target)):
				if get_kind_count("rocket_launcher") <= 0:
					_set_aiming(false)
		"escort_drone":
			# 조준점 불필요 — 확정하면 플레이어 머리 위에서 소환된다(target 무시).
			if deployables != null and GameState.consume_heavy_gear("escort_drone", 1):
				_set_aiming(false)
				deployables.call("deploy_drone")
		"supply_cart":
			# 조준점 불필요 — 확정하면 플레이어 뒤에 소환돼 끌려온다(target 무시).
			if deployables != null and GameState.consume_heavy_gear("supply_cart", 1):
				_set_aiming(false)
				deployables.call("deploy_cart")
		"strike_drone":
			# 소모는 begin_strike_mode 안에서 — 이후 10초간 클릭이 일제 사격이 된다.
			if deployables != null and bool(deployables.call("begin_strike_mode")):
				_set_aiming(false)
	if host.has_method("_update_medkit_button"):
		host.call("_update_medkit_button")


func _throw_to(landing: Vector3) -> void:
	# 이전 캔이 살아 있으면 회수 — 유인은 한 번에 하나만.
	if is_instance_valid(active_can):
		active_can.queue_free()
		active_can = null
	GameState.canned_food = maxi(0, int(GameState.canned_food) - 1)
	if host.has_method("_refresh_resource_hud"):
		host.call("_refresh_resource_hud")
	# 액티브 튜토리얼 bag_throw 완료 판정 — "실제로 한 번 던졌다"가 조건이다.
	var tutorial = host.get("active_tutorial")
	if tutorial != null:
		tutorial.call("notify", "can_thrown")
	var can := Node3D.new()
	can.name = "ThrownCan"
	can.set_meta("can_lure", true)
	host.add_child(can)
	var start: Vector3 = player.global_position + Vector3(0, 0.5, 0)
	can.global_position = start
	var sprite := Sprite3D.new()
	sprite.name = "CanSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.render_priority = 90
	sprite.texture = host.loot_system._get_canned_food_texture()
	sprite.pixel_size = 0.0052
	can.add_child(sprite)
	# 포물선 비행: xz는 선형, y는 4t(1-t) 아치. 멀리 던질수록 오래·높게 난다.
	var flight_distance := Vector2(landing.x - start.x, landing.z - start.z).length()
	var flight_time := clampf(0.3 + flight_distance * 0.022, 0.34, 0.75)
	var arc_height := clampf(1.2 + flight_distance * 0.09, 1.4, 2.8)
	var tween := host.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(can):
				return
			var flat := start.lerp(Vector3(landing.x, start.y, landing.z), t)
			flat.y = lerpf(start.y, 0.34, t) + arc_height * 4.0 * t * (1.0 - t)
			can.global_position = flat,
		0.0,
		1.0,
		flight_time
	)
	tween.tween_callback(func() -> void:
		if is_instance_valid(can):
			_on_can_landed(can)
	)


func _on_can_landed(can: Node3D) -> void:
	active_can = can
	eating_started = false
	eat_time_left = EAT_DURATION
	spoken_enemies.clear()
	_play_clank(can.global_position)
	# 착지 소리: 반경 안의 비경계 적을 캔으로 끌어들인다.
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")) or bool(enemy.get("alerted")):
			continue
		var offset: Vector3 = enemy.global_position - can.global_position
		offset.y = 0.0
		if offset.length() <= NOISE_RADIUS and bool(enemy.call("set_lure_point", can)):
			# 반응한 순간 즉시 피드백 — 물음표 마커 + 반응 대사.
			_spawn_speech(enemy, REACT_LINES)
			_flash_reaction_marker(enemy)


func _update_active_can(delta: float) -> void:
	if not is_instance_valid(active_can):
		return
	var any_eating := false
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if enemy.get("lure_point") != active_can:
			continue
		if bool(enemy.call("is_lure_eating")):
			any_eating = true
			if not spoken_enemies.has(enemy):
				spoken_enemies.append(enemy)
				_spawn_speech(enemy)
	if any_eating:
		if not eating_started:
			eating_started = true
			_build_gauge(active_can)
		eat_time_left -= delta
		_update_gauge()
		if eat_time_left <= 0.0:
			active_can.queue_free()
			active_can = null


func _build_gauge(can: Node3D) -> void:
	var white := ImageTexture.create_from_image(Image.create_from_data(
		2, 2, false, Image.FORMAT_RGBA8,
		PackedByteArray([255, 255, 255, 255, 255, 255, 255, 255,
			255, 255, 255, 255, 255, 255, 255, 255])
	))
	can_gauge_bg = Sprite3D.new()
	can_gauge_bg.texture = white
	can_gauge_bg.modulate = Color(0.06, 0.09, 0.08, 0.85)
	can_gauge_bg.pixel_size = 0.01
	can_gauge_bg.scale = Vector3(52.0, 5.0, 1.0)
	can_gauge_bg.position = Vector3(0, 0.95, 0)
	can_gauge_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	can_gauge_bg.shaded = false
	can_gauge_bg.no_depth_test = true
	can_gauge_bg.render_priority = 118
	can.add_child(can_gauge_bg)
	can_gauge_fill = Sprite3D.new()
	can_gauge_fill.texture = white
	can_gauge_fill.modulate = Color("#8fd8a4")
	can_gauge_fill.pixel_size = 0.01
	can_gauge_fill.scale = Vector3(50.0, 3.4, 1.0)
	can_gauge_fill.position = Vector3(0, 0.95, 0.001)
	can_gauge_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	can_gauge_fill.shaded = false
	can_gauge_fill.no_depth_test = true
	can_gauge_fill.render_priority = 119
	can.add_child(can_gauge_fill)


func _update_gauge() -> void:
	if not is_instance_valid(can_gauge_fill):
		return
	var progress := clampf(eat_time_left / EAT_DURATION, 0.0, 1.0)
	can_gauge_fill.scale.x = 50.0 * progress


func _flash_reaction_marker(enemy: Node3D) -> void:
	# 머리 위 "?" — 적의 기존 threat_marker(Label3D)를 잠깐 빌려 쓴다.
	# 경계 연출(◆·★)과 충돌하지 않게, 숨길 때 "?" 상태 그대로인지 확인한다.
	var marker := enemy.get("threat_marker") as Label3D
	if marker == null or not is_instance_valid(marker) or bool(enemy.get("alerted")):
		return
	marker.text = "?"
	marker.modulate = Color("#ffb057")
	marker.visible = true
	var tween := host.create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(marker) or not is_instance_valid(enemy):
			return
		if marker.text == "?" and not bool(enemy.get("alerted")):
			marker.visible = false
	)


func _spawn_speech(enemy: Node3D, lines: Array = EATER_LINES) -> void:
	# 반응 대사가 남아 있을 때 먹기 대사가 겹치지 않게 이전 말풍선은 지운다.
	var previous := enemy.get_node_or_null("LureSpeech")
	if previous != null:
		previous.queue_free()
	var label := Label3D.new()
	label.name = "LureSpeech"
	label.text = lines[randi() % lines.size()]
	label.font = FONT
	# 26pt는 직교 카메라 거리에서 읽히지 않았다(유저 신고) — 두 배로.
	label.font_size = 56
	label.pixel_size = 0.0038
	label.modulate = Color("#efe3c0")
	label.outline_size = 16
	label.outline_modulate = Color(0.02, 0.03, 0.03, 0.92)
	label.position = Vector3(0, 1.86, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 120
	enemy.add_child(label)
	var tween := host.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)


func _play_clank(position: Vector3) -> void:
	if clank_player == null or not is_instance_valid(clank_player):
		clank_player = AudioStreamPlayer3D.new()
		clank_player.name = "CanClank"
		clank_player.bus = "SFX"
		clank_player.stream = _create_clank_stream()
		clank_player.unit_size = 6.0
		clank_player.max_distance = 30.0
		clank_player.volume_db = -4.0
		host.add_child(clank_player)
	clank_player.global_position = position
	clank_player.play()


func _create_clank_stream() -> AudioStreamWAV:
	# 짧은 금속성 '깡' — 두 개의 감쇠 사인파 + 노이즈 트랜지언트.
	var sample_rate := 22050
	var duration := 0.22
	var frame_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / float(sample_rate)
		var envelope := exp(-t * 26.0)
		var value := (
			sin(TAU * 1180.0 * t) * 0.55
			+ sin(TAU * 2790.0 * t) * 0.3
			+ (randf() * 2.0 - 1.0) * 0.35 * exp(-t * 90.0)
		) * envelope
		var sample := int(clampf(value, -1.0, 1.0) * 30000.0)
		data[frame * 2] = sample & 0xFF
		data[frame * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
