class_name CanThrowSystem
extends RefCounted

# 통조림 투척 — 소리로 적을 유인하는 잠입 도구.
# 버튼을 누르면 사거리 링이 보이고, 링 안을 탭하면 그 지점으로 던진다.
# 착지 소리를 들은 비경계 적이 달려와 먹는 동안(게이지) 지나가거나 암살한다.
#
# 규칙: 이 파일은 투척의 "무엇"만 안다. 적 AI는 enemy.gd의 lure_point가,
# 버튼 배치는 main._apply_hud_layout이 맡는다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

const THROW_RANGE := 17.0
const NOISE_RADIUS := 13.0
const EAT_DURATION := 6.5
const AIM_TIMEOUT := 6.0
const EATER_LINES := [
	"이게 웬 횡재냐",
	"아직 안 뜯었잖아?",
	"먹을 게 다 있네",
	"누가 흘렸어, 이걸",
	"오늘 운수 한번 좋군",
	"뚜껑도 안 땄다고?",
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


func toggle_aim() -> void:
	if aiming:
		_set_aiming(false)
		return
	if GameState.canned_food <= 0:
		return
	_set_aiming(true)
	# 모드에 들어왔음을 문장으로 말한다 — 링만으로는 "지금 탭하면 던진다"를
	# 모른다. (판당 처음 2회만, 이후엔 조용히)
	var hint_count := int(host.get_meta("can_throw_hint_count", 0))
	if hint_count < 2:
		host.set_meta("can_throw_hint_count", hint_count + 1)
		host.hud.push_toast("링 안을 탭하면 투척 · 던지기 버튼 = 취소", Color("#79b98d"), 2.6)


func _set_aiming(value: bool) -> void:
	aiming = value
	aim_timeout_left = AIM_TIMEOUT
	if range_ring != null:
		range_ring.visible = value


func is_aiming() -> bool:
	return aiming


func update(delta: float) -> void:
	_refresh_button()
	if aiming:
		aim_timeout_left -= delta
		if aim_timeout_left <= 0.0 or GameState.canned_food <= 0:
			_set_aiming(false)
		elif range_ring != null and is_instance_valid(player):
			range_ring.global_position = Vector3(
				player.global_position.x, 0.12, player.global_position.z
			)
	_update_active_can(delta)


func _refresh_button() -> void:
	if throw_button == null:
		return
	var count := int(GameState.canned_food)
	# 조준 중엔 버튼이 취소+남은 시간 카운트다운으로 바뀐다.
	var next_text := (
		"취소 %d" % ceili(aim_timeout_left)
		if aiming
		else "던지기\nx%d" % count
	)
	if throw_button.text != next_text:
		throw_button.text = next_text
	throw_button.disabled = count <= 0 and not aiming
	# 조준 중엔 버튼이 '취소'로 읽히도록 눌린 상태를 유지한다.
	throw_button.toggle_mode = true
	if throw_button.button_pressed != aiming:
		throw_button.set_pressed_no_signal(aiming)


func handle_touch(touch_position: Vector2) -> bool:
	# main의 터치 라우터가 부른다. true를 돌려주면 이벤트를 소비한 것.
	if throw_button != null and throw_button.visible and not throw_button.disabled \
		and throw_button.get_global_rect().has_point(touch_position):
		toggle_aim()
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
	if GameState.canned_food <= 0:
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
	if offset.length() > THROW_RANGE:
		target = player.global_position + offset.normalized() * THROW_RANGE
	target.y = 0.1
	_set_aiming(false)
	_throw_to(target)


func _throw_to(landing: Vector3) -> void:
	# 이전 캔이 살아 있으면 회수 — 유인은 한 번에 하나만.
	if is_instance_valid(active_can):
		active_can.queue_free()
		active_can = null
	GameState.canned_food = maxi(0, int(GameState.canned_food) - 1)
	if host.has_method("_refresh_resource_hud"):
		host.call("_refresh_resource_hud")
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
		if offset.length() <= NOISE_RADIUS:
			enemy.call("set_lure_point", can)


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


func _spawn_speech(enemy: Node3D) -> void:
	var label := Label3D.new()
	label.name = "LureSpeech"
	label.text = EATER_LINES[randi() % EATER_LINES.size()]
	label.font = FONT
	label.font_size = 26
	label.modulate = Color("#efe3c0")
	label.outline_size = 7
	label.position = Vector3(0, 1.62, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
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
