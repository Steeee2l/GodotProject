extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")
const VEHICLE_FOOTPRINT := preload("res://scripts/vehicle_footprint.gd")
const TOUCH_JOYSTICK := preload("res://scripts/hud/touch_joystick.gd")

const CAT_ROOT := "res://assets/characters/cat_8way"
const ROLL_ROOT := "res://assets/characters/cat_roll"
const SHELTER_SCENE := "res://scenes/shelter_interior.tscn"
const OPENING_SCENE := "res://scenes/opening_sequence.tscn"
const SCREEN_DIRECTIONS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const CAT_DIRECTION_STATES := {
	"n": "up",
	"ne": "up_right",
	"e": "right",
	"se": "down_right",
	"s": "down",
	"sw": "down_left",
	"w": "left",
	"nw": "up_left",
}
const GAMEPLAY_PHASES := [
	"tutorial_move",
	"tutorial_dash",
	"tutorial_aim",
	"tutorial_combat",
	"tutorial_extract",
]
# DIALOGUE_LINES 앞에서 몇 줄이 라디오(무전) 육성인가 — 화자 라벨이 이걸 본다.
const RADIO_LINE_COUNT := 1
const DIALOGUE_LINES := [
	# 첫 줄은 반드시 라디오 육성이다 — 설명 이전에 목소리부터 들려주는 훅.
	# 앞 3줄(리빌 전) = 지금 벌어진 일, 뒤 3줄(리빌 후) = 그래서 어디로 가는가.
	# 짧게, 현재형으로. "삼백 밤"·"밥은 식탁에" 같은 문어체 비유는 쓰지 않는다.
	"들리나. 들리면 강을 건너와. 다리 끝에 문이 있다.",
	"라디오가 방금 말을 했다. 사람들이 사라진 뒤로 이 라디오는 한 번도 켜진 적이 없다.",
	"그날 밤에 무슨 일이 있었는지 나는 모른다. 아침에 눈을 떴더니 도시에 사람이 한 명도 없었다.",
	"그런데 지금, 강 건너에서 누군가 나를 부르고 있다.",
	"사람일까. 사람이라면, 왜 하필 지금일까.",
	"총 한 자루와 통조림 두 개를 챙긴다. 가서 확인해 본다.",
]

const PLAYER_SPEED := 5.2
const ROLL_DURATION := 0.38
const ROLL_START_SPEED := 22.0
const ROLL_END_SPEED := 5.8
const FIRE_INTERVAL := 0.105
const PLAYER_MAX_HEALTH := 100
const BRIDGE_HALF_WIDTH := 6.2
const BRIDGE_HALF_LENGTH := 58.0
const PLAYER_START_Z := 48.0
const INTRO_TARGET_Z := 34.0
const SEWER_EXIT_Z := -49.0
const TUTORIAL_ENEMY_ACTIVATION_RANGE := 17.5
const CAMERA_TARGET_HEIGHT := 0.78
const INTRO_CAMERA_SIZE := 18.0
const REVEAL_CAMERA_SIZE := 28.0
const GAMEPLAY_CAMERA_SIZE := 23.5
const AIM_CAMERA_SIZE := 28.0
const AIM_VISIBILITY_INNER_FACTOR := 0.50
const AIM_VISIBILITY_OUTER_FACTOR := 0.80
const TUTORIAL_KILL_GRACE_MSEC := 900
const INTRO_WALK_DIRECTION := Vector3(0, 0, -1)
# 충돌 정합 검증이 끝나 기본값을 껐다(2026-08-28 유저 스크린샷으로 확인).
# 스모크 테스트가 디버그 판으로 정합을 재기 때문에 상수가 아니라 변수다 —
# 테스트는 _ready 전에 켠다.
var show_vehicle_collision_debug := false

var phase := "intro_walk"
var dialogue_index := 0
var dialogue_speaker_label: Label
var player: CharacterBody3D
var player_sprite: AnimatedSprite3D
var weapon_sprite: Sprite3D
var camera_rig: Node3D
var camera: Camera3D
var survivor_frames: SpriteFrames
var current_facing := "ne"
var current_motion := "walk"
var current_aim_direction := Vector3(0, 0, -1)
var camera_tracks_player := true
var roll_active := false
var roll_elapsed := 0.0
var roll_iframe_until_msec := 0
var roll_direction := Vector3.ZERO
var movement_distance := 0.0
var aim_hold_duration := 0.0
var aim_held := false
var fire_held := false
var opening_fire_touch := -1
var dialogue_advance_msec := 0
var fire_cooldown := 0.0
var reloading := false
var reload_remaining := 0.0
var magazine_ammo := 30
var reserve_ammo := 300
var player_health := PLAYER_MAX_HEALTH
var player_hit_lock := 0.0
var enemies: Array[CharacterBody3D] = []
var enemies_remaining := 0
var tutorial_transitioning := false
var restarting := false
var death_resolution_pending := false
var tutorial_damage_grace_until_msec := 0
var extraction_ready := false
var tutorial_enemies_activated := false
var enemy_watch_bucket := -1
var touch_enabled := false
var mobile_move_vector := Vector2.ZERO
var mobile_joystick_touch := -1
var mobile_aim_active := false
# 무기 표시 규칙(조준할 때만) — scripts/raid/weapon_reveal.gd
var weapon_reveal := preload("res://scripts/raid/weapon_reveal.gd").new()
var sewer_exit: Node3D
var signal_beacon: Node3D
var signal_beacon_light: OmniLight3D
var sewer_arrow: Label3D
var objective_panel: PanelContainer
var objective_title: Label
var objective_detail: Label
var objective_progress: Label
var dialogue_panel: PanelContainer
var dialogue_text: Label
var dialogue_typewriter: Typewriter
var aim_laser: MeshInstance3D
var continue_label: Label
var ammo_label: Label
var magazine_label: Label
var reserve_ammo_label: Label
var reload_bar: ProgressBar
var weapon_hud_panel: PanelContainer
var weapon_hud_image: TextureRect
var health_bar: ProgressBar
var health_label: Label
var opening_medkit_button: Button
var interaction_panel: PanelContainer
var interaction_label: Label
var fade_rect: ColorRect
var title_card: VBoxContainer
var letterbox_top: ColorRect
var letterbox_bottom: ColorRect
var aim_reticle: Control
var muzzle_flash: MeshInstance3D
var visibility_rect: ColorRect
var visibility_material: ShaderMaterial
var mobile_controls_root: Control
var mobile_joystick: TouchJoystick
var mobile_dash_button: Button
var mobile_aim_button: Button
var mobile_fire_button: Button
var mobile_interact_button: Button
var auto_paused_for_background := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	touch_enabled = _detect_touch_controls()
	_build_environment()
	_build_camera()
	_build_player()
	_build_extraction()
	_build_hud()
	get_viewport().size_changed.connect(_apply_mobile_safe_layout)
	_apply_mobile_safe_layout()
	_build_visibility_fog()
	_spawn_cinematic_enemies()
	_build_aim_laser()
	_set_facing_from_world_direction(INTRO_WALK_DIRECTION)
	_set_player_animation("walk", current_facing)
	_fade_from_black()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		mobile_joystick_touch = -1
		mobile_move_vector = Vector2.ZERO
		fire_held = false
		if mobile_joystick:
			mobile_joystick.queue_redraw()
		if touch_enabled and not get_tree().paused:
			auto_paused_for_background = true
			get_tree().paused = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		if auto_paused_for_background:
			auto_paused_for_background = false
			get_tree().paused = false


func _detect_touch_controls() -> bool:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		var navigator := JavaScriptBridge.get_interface("navigator")
		if navigator != null:
			return int(navigator.maxTouchPoints) > 0
	return false


func _physics_process(delta: float) -> void:
	if restarting:
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	player_hit_lock = maxf(0.0, player_hit_lock - delta)
	_update_reload(delta)
	_update_ambient_animation()
	if phase == "intro_walk":
		_update_intro_walk(delta)
	elif GAMEPLAY_PHASES.has(phase):
		_update_player_gameplay(delta)
	else:
		player.velocity = Vector3.ZERO
		player.move_and_slide()
	_update_camera(delta)
	_update_weapon_visual(delta)
	_update_visibility_fog()
	_update_hud()



func _opening_button_contains(button: Button, position: Vector2) -> bool:
	return (
		is_instance_valid(button)
		and button.visible
		and button.get_global_rect().has_point(position)
	)


func _handle_opening_action_touch(touch: InputEventScreenTouch) -> bool:
	# 손가락을 뗐을 때: 발사를 잡고 있던 인덱스면 반드시 해제한다.
	if not touch.pressed:
		if touch.index == opening_fire_touch:
			opening_fire_touch = -1
			fire_held = false
			return true
		return false
	if _opening_button_contains(mobile_fire_button, touch.position):
		if opening_fire_touch != -1:
			return true
		opening_fire_touch = touch.index
		if not mobile_aim_active:
			mobile_aim_active = true
			mobile_aim_button.set_pressed_no_signal(true)
		aim_held = true
		fire_held = true
		_try_fire()
		return true
	if _opening_button_contains(mobile_dash_button, touch.position):
		_try_dash()
		return true
	if _opening_button_contains(mobile_aim_button, touch.position):
		mobile_aim_active = not mobile_aim_active
		mobile_aim_button.set_pressed_no_signal(mobile_aim_active)
		aim_held = mobile_aim_active
		if mobile_aim_active:
			current_aim_direction = _get_facing_world_direction()
		return true
	if _opening_button_contains(mobile_interact_button, touch.position):
		if phase == "tutorial_extract":
			_try_enter_shelter()
		return true
	if _opening_button_contains(opening_medkit_button, touch.position):
		_use_opening_medkit()
		return true
	return false


func _input(event: InputEvent) -> void:
	if restarting:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if phase in ["intro_dialogue", "reveal_dialogue"] and touch.pressed:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
			return
		if not GAMEPLAY_PHASES.has(phase):
			return
		if mobile_joystick != null and mobile_joystick.handle_touch(touch):
			mobile_joystick_touch = mobile_joystick.touch_index
			get_viewport().set_input_as_handled()
		elif _handle_opening_action_touch(touch):
			# 버튼 시그널에 기대면 두 번째 손가락이 무시된다. Godot의 마우스
			# 에뮬레이션은 첫 터치 인덱스만 따라가기 때문이다. 그래서 조이스틱을
			# 잡은 채로는 대시가 눌리지 않았고, 발사 버튼에서 손을 떼도 해제
			# 이벤트가 사라져 총이 계속 나갔다. 인덱스를 직접 추적한다.
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if mobile_joystick != null and mobile_joystick.handle_drag(drag):
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if restarting:
		return
	if phase in ["intro_dialogue", "reveal_dialogue"]:
		if (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		) or (
			event is InputEventKey
			and (event as InputEventKey).pressed
			and not (event as InputEventKey).echo
			and (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER]
		):
			get_viewport().set_input_as_handled()
			_advance_dialogue()
		return
	if not GAMEPLAY_PHASES.has(phase):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			aim_held = mouse_event.pressed
			if aim_held:
				current_aim_direction = _get_mouse_world_direction()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			fire_held = mouse_event.pressed
			if fire_held:
				_try_fire()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_SPACE:
			_try_dash()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_SHIFT:
			_use_opening_medkit()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F and phase == "tutorial_extract":
			_try_enter_shelter()
			get_viewport().set_input_as_handled()


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "OpeningEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#02050a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#26364e")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = false
	environment_node.environment = environment
	add_child(environment_node)

	var moon_light := DirectionalLight3D.new()
	moon_light.rotation_degrees = Vector3(-54, -24, 0)
	moon_light.light_color = Color("#91a7c7")
	moon_light.light_energy = 0.48
	moon_light.shadow_enabled = true
	add_child(moon_light)

	_add_textured_ground(
		"BridgeDeck",
		Vector3(0, 0, 0),
		Vector2(12.4, BRIDGE_HALF_LENGTH * 2.0),
		"res://assets/opening/opening_bridge_deck_v1.png",
		Vector3(1.0, 10.0, 1.0),
		true
	)
	_add_textured_ground(
		"RiverWest",
		Vector3(-23.0, -0.18, 0),
		Vector2(33.0, BRIDGE_HALF_LENGTH * 2.0 + 10.0),
		"res://assets/opening/opening_han_river_v1.png",
		Vector3(3.0, 11.0, 1.0),
		false
	)
	_add_textured_ground(
		"RiverEast",
		Vector3(23.0, -0.18, 0),
		Vector2(33.0, BRIDGE_HALF_LENGTH * 2.0 + 10.0),
		"res://assets/opening/opening_han_river_v1.png",
		Vector3(3.0, 11.0, 1.0),
		false
	)
	_add_bridge_rail(-6.15)
	_add_bridge_rail(6.15)
	# 다리는 Z 축으로 뻗는다 — 잔해도 전부 다리 방향(along_z)으로 눕는다.
	# 크기·중심·충돌은 카탈로그의 접지 사각형이 결정한다(손으로 넣던 숫자 제거).
	_add_vehicle("opening_taxi", Vector3(-3.5, 0.0, 27.0))
	_add_vehicle("opening_truck", Vector3(2.4, 0.0, 2.0))
	_add_vehicle("opening_taxi", Vector3(3.7, 0.0, -19.0), true, 0.889)
	_add_vehicle("opening_bus", Vector3(-1.8, 0.0, -35.0))
	_add_fire(Vector3(-3.2, 0.35, 26.7), 0.72)
	_add_fire(Vector3(2.9, 0.4, 1.8), 0.82)
	_add_fire(Vector3(-5.5, 0.3, -27.0), 0.62)
	_build_signal_beacon()


func _build_signal_beacon() -> void:
	# 대사가 말하는 "강 건너 신호". 다리 북쪽 끝 너머에서 세 번 깜빡이고 쉰다.
	# 서사가 말하는 것을 눈으로 보게 만든다 — 플레이어가 나아갈 이유의 시각화.
	signal_beacon = Node3D.new()
	signal_beacon.name = "NorthSignalBeacon"
	signal_beacon.position = Vector3(0.0, 6.4, -74.0)
	add_child(signal_beacon)

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.emission_enabled = true
	glow_material.emission = Color("#ffd27a")
	glow_material.emission_energy_multiplier = 6.0
	glow_material.albedo_color = Color(1.0, 0.86, 0.55, 0.92)
	glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_material.no_depth_test = true
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.7
	glow_mesh.height = 1.4
	glow_mesh.material = glow_material
	var glow := MeshInstance3D.new()
	glow.name = "BeaconGlow"
	glow.mesh = glow_mesh
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	signal_beacon.add_child(glow)

	signal_beacon_light = OmniLight3D.new()
	signal_beacon_light.light_color = Color("#ffcf82")
	signal_beacon_light.light_energy = 0.0
	signal_beacon_light.omni_range = 46.0
	signal_beacon.add_child(signal_beacon_light)

	_pulse_signal_beacon()


func _pulse_signal_beacon() -> void:
	# 세 번, 쉬고, 다시 — 강 건너에서 부르는 신호의 호흡. 대사 4번째 줄의
	# "누군가 나를 부른다"를 눈으로 보여주는 장치다.
	if not is_instance_valid(signal_beacon):
		return
	var glow := signal_beacon.get_node_or_null("BeaconGlow") as MeshInstance3D
	if glow == null:
		return
	var tween := create_tween().set_loops()
	for _blink in 3:
		tween.tween_property(glow, "scale", Vector3.ONE * 1.35, 0.16).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(signal_beacon_light, "light_energy", 2.4, 0.16)
		tween.tween_property(glow, "scale", Vector3.ONE * 0.7, 0.30).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(signal_beacon_light, "light_energy", 0.0, 0.30)
	tween.tween_interval(1.6)


func _add_textured_ground(
	node_name: String,
	world_position: Vector3,
	size: Vector2,
	texture_path: String,
	uv_scale: Vector3,
	with_collision: bool
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path) as Texture2D
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.92
	material.uv1_scale = uv_scale
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = world_position
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	if not with_collision:
		return
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = world_position + Vector3(0, -0.12, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.2, size.y)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_bridge_rail(x_position: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#30383a")
	material.metallic = 0.72
	material.roughness = 0.48
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.28, 0.72, BRIDGE_HALF_LENGTH * 2.0)
	mesh.material = material
	var body := StaticBody3D.new()
	body.name = "BridgeRail"
	body.position = Vector3(x_position, 0.32, 0)
	body.collision_layer = 2
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_vehicle(
	vehicle_type: String,
	world_position: Vector3,
	along_z: bool = true,
	size_scale: float = 1.0
) -> void:
	# 오프닝 잔해도 필드 차량과 완전히 같은 규칙을 쓴다 — 카탈로그의 접지 사각형에서
	# 스프라이트 크기·중심·충돌 상자를 유도한다(scripts/vehicle_footprint.gd).
	# 예전에는 여기서만 world_width·screen_rotation·collision_offset 를 손으로
	# 넣었고, 그 숫자들이 그림과 어긋나 충돌 영역이 작고 아래로 치우쳐 보였다.
	var definition := VEHICLE_CATALOG.get_definition(vehicle_type)
	if definition.is_empty():
		return
	var texture := load(str(definition["texture_path"])) as Texture2D
	if texture == null:
		return
	var collision_size := VEHICLE_FOOTPRINT.world_collision_size(
		definition, along_z, size_scale
	)
	var body := StaticBody3D.new()
	body.name = "OpeningWreck"
	body.add_to_group("opening_wreck")
	body.position = Vector3(world_position.x, 0.0, world_position.z)
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("vehicle_type", vehicle_type)
	body.set_meta("vehicle_axis", "z" if along_z else "x")
	body.set_meta("collision_size", collision_size)
	add_child(body)

	var sprite := Sprite3D.new()
	sprite.name = "VehicleSprite"
	sprite.texture = texture
	body.add_child(sprite)
	VEHICLE_FOOTPRINT.apply_to_sprite(
		sprite,
		definition,
		collision_size,
		VEHICLE_FOOTPRINT.should_flip(definition, along_z),
		0.0
	)
	sprite.render_priority = 1

	var profile: Dictionary = COLLISION_PROFILES.get_profile(
		str(definition.get("collision_profile", "vehicle_standard")),
		collision_size
	)
	var movement_size: Vector3 = profile["movement_size"]
	var collision := CollisionShape3D.new()
	collision.name = "VehicleCollision"
	var shape := BoxShape3D.new()
	shape.size = movement_size
	collision.shape = shape
	# yaw 는 0 이다. 빌보드 스프라이트는 노드 회전이 화면에 반영되지 않으므로,
	# 방향은 회전이 아니라 x/z 크기 교환(along_z)으로만 정한다.
	collision.position = Vector3(0.0, movement_size.y * 0.5, 0.0)
	body.add_child(collision)
	if show_vehicle_collision_debug:
		_add_vehicle_collision_debug(body, movement_size)


func _add_vehicle_collision_debug(body: StaticBody3D, movement_size: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.045, 0.035, 0.38)
	material.no_depth_test = true
	material.render_priority = 126
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(movement_size.x, movement_size.z)
	mesh.material = material
	var marker := MeshInstance3D.new()
	marker.name = "VehicleCollisionDebug"
	marker.position = Vector3(0.0, 0.035, 0.0)
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_to_group("opening_vehicle_collision_debug")
	body.add_child(marker)


func _add_fire(world_position: Vector3, scale_multiplier: float) -> void:
	var root := Node3D.new()
	root.name = "BridgeFire"
	root.position = world_position
	add_child(root)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff7a21")
	light.light_energy = 2.4 * scale_multiplier
	light.omni_range = 5.5 * scale_multiplier
	light.shadow_enabled = false
	root.add_child(light)
	var fire_material := StandardMaterial3D.new()
	fire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_material.vertex_color_use_as_albedo = true
	fire_material.albedo_color = Color(1.0, 0.34, 0.05, 0.82)
	fire_material.emission_enabled = true
	fire_material.emission = Color("#ff5a16")
	fire_material.emission_energy_multiplier = 4.5
	fire_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var fire_quad := QuadMesh.new()
	fire_quad.size = Vector2(0.26, 0.44) * scale_multiplier
	fire_quad.material = fire_material
	var fire_process := ParticleProcessMaterial.new()
	fire_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_process.emission_sphere_radius = 0.32 * scale_multiplier
	fire_process.direction = Vector3(0, 1, 0)
	fire_process.spread = 18.0
	fire_process.initial_velocity_min = 0.7
	fire_process.initial_velocity_max = 1.7
	fire_process.gravity = Vector3(0, 0.45, 0)
	fire_process.scale_min = 0.45
	fire_process.scale_max = 1.35
	fire_process.color = Color(1.0, 0.48, 0.08, 0.9)
	var fire := GPUParticles3D.new()
	fire.amount = 42
	fire.lifetime = 0.72
	fire.randomness = 0.6
	fire.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	fire.process_material = fire_process
	fire.draw_pass_1 = fire_quad
	root.add_child(fire)

	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.albedo_color = Color(0.16, 0.17, 0.17, 0.38)
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.9, 0.9) * scale_multiplier
	smoke_quad.material = smoke_material
	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_process.emission_sphere_radius = 0.3
	smoke_process.direction = Vector3(0.08, 1, 0.04)
	smoke_process.spread = 28.0
	smoke_process.initial_velocity_min = 0.35
	smoke_process.initial_velocity_max = 0.9
	smoke_process.gravity = Vector3(0.05, 0.18, 0.02)
	smoke_process.scale_min = 0.5
	smoke_process.scale_max = 1.8
	smoke_process.color = Color(0.2, 0.22, 0.22, 0.32)
	var smoke := GPUParticles3D.new()
	smoke.amount = 28
	smoke.lifetime = 2.8
	smoke.randomness = 0.82
	smoke.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	smoke.process_material = smoke_process
	smoke.draw_pass_1 = smoke_quad
	root.add_child(smoke)


func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "OpeningCameraRig"
	camera_rig.position = Vector3(0, 0, PLAYER_START_Z)
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.name = "OpeningCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = INTRO_CAMERA_SIZE
	camera.near = 0.1
	camera.far = 300.0
	camera.position = Vector3(10.5, 12.5, 10.5)
	camera.current = true
	camera_rig.add_child(camera)
	camera.look_at(camera_rig.global_position + Vector3(0, CAMERA_TARGET_HEIGHT, 0))


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "OpeningPlayer"
	player.position = Vector3(0, 0.78, PLAYER_START_Z)
	player.collision_layer = 1
	player.collision_mask = 3
	player.add_to_group("player")
	add_child(player)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.3
	collision.shape = shape
	player.add_child(collision)
	_add_player_shadow()
	survivor_frames = _create_player_frames()
	player_sprite = AnimatedSprite3D.new()
	player_sprite.name = "Survivor"
	player_sprite.sprite_frames = survivor_frames
	player_sprite.position = Vector3(0, 0.3, 0)
	player_sprite.pixel_size = 0.0098
	player_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_sprite.shaded = false
	player_sprite.transparent = true
	player_sprite.no_depth_test = true
	player_sprite.render_priority = 120
	player.add_child(player_sprite)
	weapon_sprite = Sprite3D.new()
	weapon_sprite.name = "OpeningAK47"
	weapon_sprite.texture = load("res://assets/weapons/catalog/generated/ak47.png") as Texture2D
	# 월드 폭 1.90m 고정(텍스처 해상도 무관).
	weapon_sprite.pixel_size = 1.89865 / float(maxi(1, weapon_sprite.texture.get_width()))
	weapon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_sprite.shaded = false
	weapon_sprite.transparent = true
	weapon_sprite.no_depth_test = true
	weapon_sprite.render_priority = 119
	# 조준하기 전까지는 손에 아무것도 없다(_update_weapon_visual 이 매 프레임 결정).
	weapon_sprite.visible = false
	player.add_child(weapon_sprite)
	_build_muzzle_flash()


func _add_player_shadow() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0, 0, 0, 0.4)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.48
	mesh.height = 0.018
	mesh.radial_segments = 20
	mesh.material = material
	var shadow := MeshInstance3D.new()
	shadow.position.y = -0.7
	shadow.mesh = mesh
	player.add_child(shadow)


func _create_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in SCREEN_DIRECTIONS:
		var source_name: String = CAT_DIRECTION_STATES[direction_name]
		for state in ["idle", "walk"]:
			var animation_name := "%s_%s" % [state, direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, true)
			frames.set_animation_speed(animation_name, 4.0 if state == "idle" else 8.0)
			for frame_index in 4:
				var path := "%s/%s_%s_%d.png" % [CAT_ROOT, source_name, state, frame_index]
				var texture := load(path) as Texture2D
				if texture != null:
					frames.add_frame(animation_name, texture)
		var roll_name := "roll_%s" % direction_name
		frames.add_animation(roll_name)
		frames.set_animation_loop(roll_name, false)
		frames.set_animation_speed(roll_name, 10.0)
		for frame_index in 4:
			var roll_path := "%s/%s_action-frame-%d.png" % [ROLL_ROOT, source_name, frame_index]
			var roll_texture := load(roll_path) as Texture2D
			if roll_texture != null:
				frames.add_frame(roll_name, roll_texture)
	return frames


func _build_muzzle_flash() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#fff1a1")
	material.emission_enabled = true
	material.emission = Color("#ffb11f")
	material.emission_energy_multiplier = 7.0
	material.no_depth_test = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.mesh = mesh
	muzzle_flash.visible = false
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(muzzle_flash)


func _build_extraction() -> void:
	sewer_exit = Node3D.new()
	sewer_exit.name = "TutorialSewerExit"
	sewer_exit.position = Vector3(0, 0.08, SEWER_EXIT_Z)
	add_child(sewer_exit)
	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/opening/opening_sewer_exit_v2.png") as Texture2D
	# 월드 폭 4.77m 고정(텍스처 해상도 무관).
	sprite.pixel_size = 4.7652 / float(maxi(1, sprite.texture.get_width()))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.position.y = 0.38
	sewer_exit.add_child(sprite)
	var glow_material := StandardMaterial3D.new()
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = Color(0.34, 1.0, 0.72, 0.22)
	glow_material.emission_enabled = true
	glow_material.emission = Color("#70ffc1")
	glow_material.emission_energy_multiplier = 2.6
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.12
	ring.rings = 32
	ring.ring_segments = 8
	ring.material = glow_material
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.visible = false
	ring_mesh.set_meta("tutorial_extraction_visual", true)
	sewer_exit.add_child(ring_mesh)
	sewer_arrow = Label3D.new()
	sewer_arrow.text = "▼"
	sewer_arrow.font = FONT
	sewer_arrow.font_size = 96
	sewer_arrow.outline_size = 20
	sewer_arrow.modulate = Color("#8dffd0")
	sewer_arrow.outline_modulate = Color(0.01, 0.08, 0.06, 1.0)
	sewer_arrow.position = Vector3(0, 2.4, 0)
	sewer_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sewer_arrow.no_depth_test = true
	sewer_arrow.visible = false
	sewer_exit.add_child(sewer_arrow)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "OpeningHUD"
	hud.layer = 100
	add_child(hud)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.018, 0.035, 0.035)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dim)
	letterbox_top = ColorRect.new()
	letterbox_top.color = Color.BLACK
	letterbox_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	letterbox_top.offset_bottom = 54
	letterbox_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(letterbox_top)
	letterbox_bottom = ColorRect.new()
	letterbox_bottom.color = Color.BLACK
	letterbox_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	letterbox_bottom.offset_top = -58
	letterbox_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(letterbox_bottom)
	_build_title_card(hud)
	_build_dialogue_ui(hud)
	_build_objective_ui(hud)
	_build_status_ui(hud)
	_build_interaction_ui(hud)
	_build_mobile_controls(hud)
	aim_reticle = _create_aim_reticle()
	hud.add_child(aim_reticle)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.z_index = 200
	hud.add_child(fade_rect)


func _build_title_card(hud: CanvasLayer) -> void:
	title_card = VBoxContainer.new()
	title_card.name = "TitleCard"
	title_card.set_anchors_preset(Control.PRESET_CENTER)
	title_card.alignment = BoxContainer.ALIGNMENT_CENTER
	title_card.add_theme_constant_override("separation", 4)
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.modulate.a = 0.0
	# 앵커 프리셋만으로는 자식 크기만큼만 중앙에 놓이므로, 폭을 화면에 맞춰
	# 텍스트를 가운데 정렬한다.
	title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_card.offset_top = 96
	var title_half := minf(400.0, (get_viewport().get_visible_rect().size.x - 24.0) * 0.5)
	title_card.offset_left = -title_half
	title_card.offset_right = title_half
	hud.add_child(title_card)

	var title_label := Label.new()
	title_label.text = "그레이 던"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("#f3e6c4"))
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title_card.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "GREY DAWN · 서울 생존묘"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_override("font", FONT)
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color("#9db4c4"))
	title_card.add_child(subtitle_label)


func _reveal_title_card() -> void:
	if not is_instance_valid(title_card):
		return
	var tween := create_tween()
	tween.tween_property(title_card, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.9)
	tween.tween_property(title_card, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _build_dialogue_ui(hud: CanvasLayer) -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# 앵커 기준 오프셋으로만 잡는다. position 세터는 앵커가 걸린 컨트롤에서 부모
	# 좌표로 해석돼 패널이 화면 왼쪽 밖으로 반쯤 나가는 사고가 났다.
	var dialogue_width := minf(900.0, get_viewport().get_visible_rect().size.x - 24.0)
	dialogue_panel.offset_left = -dialogue_width * 0.5
	dialogue_panel.offset_right = dialogue_width * 0.5
	dialogue_panel.offset_top = -318
	dialogue_panel.offset_bottom = -192
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.025, 0.94), Color("#9fc7b8"), 2, 6))
	hud.add_child(dialogue_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	dialogue_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	dialogue_speaker_label = Label.new()
	dialogue_speaker_label.add_theme_font_override("font", FONT)
	dialogue_speaker_label.add_theme_font_size_override("font_size", 18)
	column.add_child(dialogue_speaker_label)
	_refresh_dialogue_speaker()
	dialogue_text = Label.new()
	dialogue_text.add_theme_font_override("font", FONT)
	dialogue_text.add_theme_font_size_override("font_size", 24)
	dialogue_text.add_theme_color_override("font_color", Color("#edf2ef"))
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(dialogue_text)
	# 먼지의 독백도 한 글자씩 소리와 함께 흐른다.
	dialogue_typewriter = Typewriter.new()
	add_child(dialogue_typewriter)
	dialogue_typewriter.attach(dialogue_text)
	continue_label = Label.new()
	continue_label.text = "화면 터치 ▸" if touch_enabled else "클릭 또는 SPACE ▸"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_font_override("font", FONT)
	continue_label.add_theme_font_size_override("font_size", 13)
	continue_label.add_theme_color_override("font_color", Color("#91a49d"))
	column.add_child(continue_label)
	# 은은한 맥동 — "여기 눌러도 된다"를 시선 끌지 않게 말한다.
	var pulse := continue_label.create_tween().set_loops()
	pulse.tween_property(continue_label, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(continue_label, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	dialogue_panel.visible = false


func _build_objective_ui(hud: CanvasLayer) -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "TutorialObjective"
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# 앵커 컨트롤에 position을 쓰면 부모 좌표로 해석돼 어긋난다. 오프셋으로 고정.
	var objective_half := minf(270.0, (get_viewport().get_visible_rect().size.x - 24.0) * 0.5)
	objective_panel.offset_left = -objective_half
	objective_panel.offset_right = objective_half
	# 컴팩트(2026-08-30 유저 신고: "상하 폭이 커서 화면을 가려"). 116px → 82px.
	# 여백·글자를 줄이고 카드는 내용 높이에 맞춰 스스로 줄어들게 둔다.
	objective_panel.offset_top = 62
	objective_panel.offset_bottom = 144
	objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.021, 0.022, 0.94), Color("#79a994"), 1, 7))
	hud.add_child(objective_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	objective_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)
	objective_title = Label.new()
	objective_title.add_theme_font_override("font", FONT)
	objective_title.add_theme_font_size_override("font_size", 18)
	objective_title.add_theme_color_override("font_color", Color("#f1d37c"))
	column.add_child(objective_title)
	objective_detail = Label.new()
	objective_detail.add_theme_font_override("font", FONT)
	objective_detail.add_theme_font_size_override("font_size", 14)
	objective_detail.add_theme_color_override("font_color", Color("#d4ded9"))
	objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(objective_detail)
	objective_progress = Label.new()
	objective_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_progress.add_theme_font_override("font", FONT)
	objective_progress.add_theme_font_size_override("font_size", 13)
	objective_progress.add_theme_color_override("font_color", Color("#80e4bd"))
	column.add_child(objective_progress)
	objective_panel.visible = false


func _build_status_ui(hud: CanvasLayer) -> void:
	# 오프닝은 무적이라 체력바·구급약이 의미가 없다(유저: 체력바 없애고 무적으로).
	# health_bar/health_label 은 null 로 남고, 쓰는 곳은 전부 null 가드가 있다.
	opening_medkit_button = Button.new()
	opening_medkit_button.name = "OpeningMedkitButton"
	opening_medkit_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var medkit_left := 214.0 if touch_enabled else 30.0
	opening_medkit_button.position = Vector2(medkit_left, -116)
	opening_medkit_button.size = Vector2(96, 92)
	opening_medkit_button.icon = UI_ICONS.get_icon("medkit", 38, Color("#f0eee4"))
	opening_medkit_button.expand_icon = true
	opening_medkit_button.add_theme_constant_override("icon_max_width", 38)
	opening_medkit_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_medkit_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	opening_medkit_button.focus_mode = Control.FOCUS_NONE
	opening_medkit_button.add_theme_font_override("font", FONT)
	opening_medkit_button.add_theme_font_size_override("font_size", 13)
	opening_medkit_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color(0.018, 0.025, 0.025, 0.94), Color("#718a7e"), 2, 7)
	)
	opening_medkit_button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color(0.055, 0.08, 0.07, 0.97), Color("#b9d1c4"), 2, 7)
	)
	opening_medkit_button.add_theme_stylebox_override(
		"pressed",
		_panel_style(Color(0.11, 0.17, 0.13, 0.98), Color("#dff0e5"), 2, 7)
	)
	opening_medkit_button.pressed.connect(_use_opening_medkit)
	opening_medkit_button.visible = false
	hud.add_child(opening_medkit_button)

	weapon_hud_panel = PanelContainer.new()
	weapon_hud_panel.name = "OpeningWeaponHUD"
	weapon_hud_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_hud_panel.position = Vector2(-356, -258) if touch_enabled else Vector2(-356, -154)
	weapon_hud_panel.size = Vector2(326, 118)
	weapon_hud_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.018, 0.019, 0.94), Color("#8da997"), 2, 7))
	hud.add_child(weapon_hud_panel)
	var ammo_margin := MarginContainer.new()
	ammo_margin.add_theme_constant_override("margin_left", 13)
	ammo_margin.add_theme_constant_override("margin_right", 13)
	ammo_margin.add_theme_constant_override("margin_top", 11)
	ammo_margin.add_theme_constant_override("margin_bottom", 10)
	weapon_hud_panel.add_child(ammo_margin)
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 12)
	ammo_margin.add_child(equipment_row)
	weapon_hud_image = TextureRect.new()
	weapon_hud_image.texture = load("res://assets/weapons/catalog/generated/ak47.png") as Texture2D
	weapon_hud_image.custom_minimum_size = Vector2(108, 82)
	weapon_hud_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_hud_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_row.add_child(weapon_hud_image)
	var ammo_column := VBoxContainer.new()
	ammo_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_column.add_theme_constant_override("separation", 2)
	equipment_row.add_child(ammo_column)
	ammo_label = Label.new()
	ammo_label.add_theme_font_override("font", FONT)
	ammo_label.add_theme_font_size_override("font_size", 16)
	ammo_label.add_theme_color_override("font_color", Color("#e7e3d2"))
	ammo_column.add_child(ammo_label)
	var ammo_row := HBoxContainer.new()
	ammo_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_row.add_theme_constant_override("separation", 8)
	ammo_column.add_child(ammo_row)
	magazine_label = Label.new()
	magazine_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	magazine_label.add_theme_font_override("font", FONT)
	magazine_label.add_theme_font_size_override("font_size", 23)
	magazine_label.add_theme_color_override("font_color", Color("#f1ce70"))
	ammo_row.add_child(magazine_label)
	reserve_ammo_label = Label.new()
	reserve_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reserve_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reserve_ammo_label.add_theme_font_override("font", FONT)
	reserve_ammo_label.add_theme_font_size_override("font_size", 13)
	reserve_ammo_label.add_theme_color_override("font_color", Color("#c5d0c9"))
	ammo_row.add_child(reserve_ammo_label)
	reload_bar = ProgressBar.new()
	reload_bar.custom_minimum_size = Vector2(0, 7)
	reload_bar.max_value = 1.0
	reload_bar.show_percentage = false
	reload_bar.add_theme_stylebox_override("background", _panel_style(Color("#171d1b"), Color("#3e4944"), 1, 4))
	reload_bar.add_theme_stylebox_override("fill", _panel_style(Color("#d6b653"), Color("#f0d77d"), 1, 4))
	ammo_column.add_child(reload_bar)


func _build_interaction_ui(hud: CanvasLayer) -> void:
	interaction_panel = PanelContainer.new()
	interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_panel.position = Vector2(-250, -150)
	interaction_panel.size = Vector2(500, 62)
	interaction_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.023, 0.024, 0.94), Color("#7de5bd"), 2, 6))
	hud.add_child(interaction_panel)
	interaction_label = Label.new()
	interaction_label.text = "하수구로 내려가기" if touch_enabled else "[F]  하수구로 내려가기"
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_override("font", FONT)
	interaction_label.add_theme_font_size_override("font_size", 22)
	interaction_label.add_theme_color_override("font_color", Color("#e5f8ef"))
	interaction_panel.add_child(interaction_label)
	interaction_panel.visible = false


func _build_mobile_controls(hud: CanvasLayer) -> void:
	mobile_controls_root = Control.new()
	mobile_controls_root.name = "OpeningMobileControls"
	mobile_controls_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls_root.visible = false
	mobile_controls_root.z_index = 90
	hud.add_child(mobile_controls_root)

	# 필드/쉘터와 같은 위젯을 쓴다. 화면마다 조작감이 다르면 안 된다.
	mobile_joystick = TOUCH_JOYSTICK.new()
	mobile_joystick.name = "MovementJoystick"
	mobile_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mobile_joystick.offset_left = 24
	mobile_joystick.offset_top = -236
	mobile_joystick.offset_right = 236
	mobile_joystick.offset_bottom = -24
	mobile_joystick.moved.connect(func(vector: Vector2) -> void: mobile_move_vector = vector)
	mobile_controls_root.add_child(mobile_joystick)

	mobile_fire_button = _make_mobile_action_button("FireButton", "발사", "weapon", Color("#ffd29a"))
	mobile_fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_fire_button.offset_left = -140
	mobile_fire_button.offset_top = -140
	mobile_fire_button.offset_right = -24
	mobile_fire_button.offset_bottom = -24
	# 터치는 _handle_opening_action_touch가 인덱스별로 직접 처리한다.
	# 여기 시그널은 마우스(데스크톱 미리보기)에서만 의미가 있고,
	# 터치에서 두 번 발동하지 않도록 진행 중이면 무시한다.
	mobile_fire_button.button_down.connect(func() -> void:
		if opening_fire_touch != -1:
			return
		if not mobile_aim_active:
			mobile_aim_active = true
			mobile_aim_button.set_pressed_no_signal(true)
		aim_held = true
		fire_held = true
		_try_fire()
	)
	mobile_fire_button.button_up.connect(func() -> void:
		if opening_fire_touch == -1:
			fire_held = false
	)
	mobile_controls_root.add_child(mobile_fire_button)

	mobile_aim_button = _make_mobile_action_button("AimButton", "조준", "flashlight", Color("#e8df9f"))
	mobile_aim_button.toggle_mode = true
	mobile_aim_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_aim_button.offset_left = -264
	mobile_aim_button.offset_top = -140
	mobile_aim_button.offset_right = -148
	mobile_aim_button.offset_bottom = -24
	mobile_aim_button.toggled.connect(func(enabled: bool) -> void:
		mobile_aim_active = enabled
		aim_held = enabled
		if enabled:
			current_aim_direction = _get_facing_world_direction()
	)
	mobile_controls_root.add_child(mobile_aim_button)

	mobile_dash_button = _make_mobile_action_button("DashButton", "대시", "dash", Color("#d8e5de"))
	mobile_dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_dash_button.offset_left = -388
	mobile_dash_button.offset_top = -140
	mobile_dash_button.offset_right = -272
	mobile_dash_button.offset_bottom = -24
	mobile_dash_button.pressed.connect(_try_dash)
	mobile_controls_root.add_child(mobile_dash_button)

	mobile_interact_button = _make_mobile_action_button("InteractButton", "진입", "interact", Color("#b8f2d4"))
	mobile_interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_interact_button.offset_left = -140
	mobile_interact_button.offset_top = -264
	mobile_interact_button.offset_right = -24
	mobile_interact_button.offset_bottom = -148
	mobile_interact_button.pressed.connect(_try_enter_shelter)
	mobile_controls_root.add_child(mobile_interact_button)
	_apply_mobile_safe_layout()


func _apply_mobile_safe_layout() -> void:
	# 회전(가로↔세로)에도 대사·타이틀이 화면 안에 머물게 한다. 이 둘은 터치
	# 여부와 무관하게 폭을 다시 맞춰야 하므로 조기 반환 앞에서 처리한다.
	var viewport_size := get_viewport().get_visible_rect().size
	_apply_portrait_camera_aspect(camera)
	if is_instance_valid(dialogue_panel):
		var dialogue_width := minf(900.0, viewport_size.x - 24.0)
		dialogue_panel.offset_left = -dialogue_width * 0.5
		dialogue_panel.offset_right = dialogue_width * 0.5
	if is_instance_valid(title_card):
		var title_half := minf(400.0, (viewport_size.x - 24.0) * 0.5)
		title_card.offset_left = -title_half
		title_card.offset_right = title_half
	if not touch_enabled or mobile_controls_root == null:
		return
	var safe := UISafeArea.get_margins(viewport_size)
	if mobile_joystick:
		mobile_joystick.offset_left = 24.0 + safe.x
		mobile_joystick.offset_top = -204.0 - safe.w
		mobile_joystick.offset_right = 204.0 + safe.x
		mobile_joystick.offset_bottom = -24.0 - safe.w
	var button_layout: Array = [
		[mobile_fire_button, Vector4(-116, -116, -24, -24)],
		[mobile_aim_button, Vector4(-216, -116, -124, -24)],
		[mobile_dash_button, Vector4(-388, -140, -272, -24)],
		[mobile_interact_button, Vector4(-116, -216, -24, -124)],
	]
	for entry in button_layout:
		var button := entry[0] as Button
		if not is_instance_valid(button):
			continue
		var offsets: Vector4 = entry[1]
		button.offset_left = offsets.x - safe.z
		button.offset_top = offsets.y - safe.w
		button.offset_right = offsets.z - safe.z
		button.offset_bottom = offsets.w - safe.w


func _make_mobile_action_button(
	node_name: String,
	button_text: String,
	icon_name: String,
	accent: Color
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = button_text
	button.icon = UI_ICONS.get_icon(icon_name, 34, accent)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.03, 0.035, 0.9), accent.darkened(0.35), 2, 42))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.04, 0.06, 0.065, 0.94), accent.darkened(0.18), 2, 42))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.12, 0.12, 0.97), accent, 3, 42))
	return button


func _build_visibility_fog() -> void:
	var visibility_layer := CanvasLayer.new()
	visibility_layer.name = "OpeningVisibility"
	visibility_layer.layer = 2
	add_child(visibility_layer)
	visibility_rect = ColorRect.new()
	visibility_rect.name = "NightVisionMask"
	visibility_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_layer.add_child(visibility_rect)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 player_screen = vec2(640.0, 360.0);
uniform vec2 facing_screen_direction = vec2(0.0, -1.0);
uniform float circle_radius = 150.0;
uniform float inner_radius = 360.0;
uniform float outer_radius = 520.0;
uniform float near_radius = 82.0;
uniform float fan_cos = 0.20;
uniform float darkness = 0.94;
uniform float aim_expanded = 0.0;

void fragment() {
	vec2 pixel_position = UV * viewport_size;
	vec2 to_pixel = pixel_position - player_screen;
	float distance_from_player = length(to_pixel);
	vec2 pixel_direction = distance_from_player > 0.001 ? normalize(to_pixel) : facing_screen_direction;
	float alignment = dot(pixel_direction, normalize(facing_screen_direction));
	float near_visibility = 1.0 - smoothstep(near_radius * 0.70, near_radius, distance_from_player);
	float circle_visibility = 1.0 - smoothstep(circle_radius * 0.78, circle_radius, distance_from_player);
	float fan_visibility = smoothstep(fan_cos - 0.11, fan_cos + 0.08, alignment);
	float range_visibility = 1.0 - smoothstep(inner_radius, outer_radius, distance_from_player);
	float relaxed_visibility = max(near_visibility, circle_visibility);
	float aimed_visibility = max(relaxed_visibility, fan_visibility * range_visibility);
	float visibility = mix(relaxed_visibility, aimed_visibility, aim_expanded);
	float fog_alpha = mix(darkness, 0.025, visibility);
	COLOR = vec4(0.004, 0.008, 0.018, fog_alpha);
}
"""
	visibility_material = ShaderMaterial.new()
	visibility_material.shader = shader
	visibility_rect.material = visibility_material
	visibility_rect.visible = false


func _update_visibility_fog() -> void:
	if visibility_material == null or visibility_rect == null or not is_instance_valid(camera):
		return
	visibility_rect.visible = GAMEPLAY_PHASES.has(phase)
	if not visibility_rect.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var short_side := minf(viewport_size.x, viewport_size.y)
	var player_screen := camera.unproject_position(player.global_position + Vector3(0, 0.2, 0))
	var facing_point := camera.unproject_position(player.global_position + current_aim_direction * 5.0 + Vector3(0, 0.2, 0))
	var facing_direction := (facing_point - player_screen).normalized()
	if facing_direction.length_squared() <= 0.001:
		facing_direction = Vector2.UP
	visibility_material.set_shader_parameter("viewport_size", viewport_size)
	visibility_material.set_shader_parameter("player_screen", player_screen)
	visibility_material.set_shader_parameter("facing_screen_direction", facing_direction)
	visibility_material.set_shader_parameter("circle_radius", short_side * 0.16)
	visibility_material.set_shader_parameter("near_radius", short_side * 0.085)
	visibility_material.set_shader_parameter(
		"inner_radius",
		short_side * AIM_VISIBILITY_INNER_FACTOR
	)
	visibility_material.set_shader_parameter(
		"outer_radius",
		short_side * AIM_VISIBILITY_OUTER_FACTOR
	)
	visibility_material.set_shader_parameter("fan_cos", 0.18)
	visibility_material.set_shader_parameter("darkness", 0.94)
	visibility_material.set_shader_parameter("aim_expanded", 1.0 if aim_held else 0.0)


func _create_aim_reticle() -> Control:
	var reticle := Control.new()
	reticle.name = "AimReticle"
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.size = Vector2(42, 42)
	reticle.visible = false
	reticle.draw.connect(func() -> void:
		var center := Vector2(21, 21)
		reticle.draw_arc(center, 11, 0, TAU, 28, Color("#f1ca69"), 2.0, true)
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			reticle.draw_line(center + direction * 14, center + direction * 19, Color("#f1ca69"), 2.0)
		reticle.draw_circle(center, 2.2, Color("#ffe8a2"))
	)
	return reticle


func _panel_style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _apply_portrait_camera_aspect(target_camera: Camera3D) -> void:
	# 세로 화면에서는 직교 카메라 size가 세로 기준(KEEP_HEIGHT)이라 가로 시야가
	# 절반 이하로 좁아진다. KEEP_WIDTH로 뒤집으면 size가 가로 기준이 되어,
	# 세로로 자동 줌아웃되고 가로 시야는 가로모드와 같아진다.
	if target_camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y > viewport_size.x
	target_camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT


func _build_aim_laser() -> void:
	# 필드와 같은 감각의 조준선. 오프닝에만 없어서 "조준했는데 아무 표시가 없다"는
	# 첫인상을 남겼다. 얇은 붉은 막대를 조준 방향으로 눕혀서 쓴다.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.22, 0.14, 0.55)
	material.emission_enabled = true
	material.emission = Color("#ff3d2a")
	material.emission_energy_multiplier = 2.4
	material.no_depth_test = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.02, 11.0)
	mesh.material = material
	aim_laser = MeshInstance3D.new()
	aim_laser.name = "OpeningAimLaser"
	aim_laser.mesh = mesh
	aim_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_laser.visible = false
	add_child(aim_laser)


func _update_aim_laser() -> void:
	if aim_laser == null:
		return
	aim_laser.visible = aim_held and phase in ["tutorial_aim", "tutorial_combat", "tutorial_extract"]
	if not aim_laser.visible:
		return
	var direction := current_aim_direction
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = _get_facing_world_direction()
	direction = direction.normalized()
	var origin := player.global_position + Vector3(0, 0.32, 0) + direction * 0.6
	var mid := origin + direction * 5.5
	aim_laser.look_at_from_position(mid, mid + direction, Vector3.UP)


func _spawn_cinematic_enemies() -> void:
	var setups := [
		{"position": Vector3(-2.3, 0.78, -3.0), "weapon": "m1911", "facing": "e"},
		{"position": Vector3(2.1, 0.78, -11.0), "weapon": "mp5", "facing": "w"},
	]
	for setup in setups:
		var enemy := CharacterBody3D.new()
		enemy.set_script(ENEMY_SCRIPT)
		enemy.call("configure", "pistol", player, {}, 0.0, str(setup["weapon"]))
		enemy.position = setup["position"]
		enemy.connect("died", Callable(self, "_on_tutorial_enemy_died"))
		add_child(enemy)
		enemy.call("set_detection_profile", 1.0, 58.0, 1.0)
		enemy.call("_set_facing", str(setup["facing"]))
		enemy.set_physics_process(false)
		enemies.append(enemy)
	enemies_remaining = enemies.size()


func _update_intro_walk(delta: float) -> void:
	player.velocity = INTRO_WALK_DIRECTION * 2.25
	player.move_and_slide()
	_set_facing_from_world_direction(INTRO_WALK_DIRECTION)
	_set_player_animation("walk", current_facing)
	if player.position.z <= INTRO_TARGET_Z:
		player.position.z = INTRO_TARGET_Z
		player.velocity = Vector3.ZERO
		phase = "intro_dialogue"
		dialogue_index = 0
		_set_player_animation("idle", current_facing)
		_show_dialogue()


func _show_dialogue() -> void:
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.18)
	_refresh_dialogue_speaker()
	if dialogue_typewriter != null:
		dialogue_typewriter.start(DIALOGUE_LINES[dialogue_index])
	else:
		dialogue_text.text = DIALOGUE_LINES[dialogue_index]


func _refresh_dialogue_speaker() -> void:
	# 첫 줄은 라디오 육성이다 — 화자 칸에 주인공 이름이 붙으면 주인공이 스스로
	# "강을 건너와"라고 말하는 꼴이 된다(유저 신고). 무전은 무전 색으로 갈라 둔다.
	if dialogue_speaker_label == null:
		return
	var is_radio := dialogue_index < RADIO_LINE_COUNT
	dialogue_speaker_label.text = "무전 · 잡음 섞인 목소리" if is_radio else "먼지"
	dialogue_speaker_label.add_theme_color_override(
		"font_color", Color("#9fb6c9") if is_radio else Color("#d7b765")
	)


func _advance_dialogue() -> void:
	# 모바일에서는 한 번의 탭이 InputEventScreenTouch와 에뮬레이트된
	# 마우스 클릭을 둘 다 만들어서 대사가 두세 줄씩 건너뛰었다.
	# 입력 경로를 늘리는 대신 짧은 디바운스로 막는다.
	var now := Time.get_ticks_msec()
	if now - dialogue_advance_msec < 260:
		return
	dialogue_advance_msec = now
	# 타이핑 중이면 첫 입력은 전부 즉시 표시. 다음 입력에서 다음 줄로.
	if dialogue_typewriter != null and dialogue_typewriter.is_typing():
		dialogue_typewriter.skip()
		return
	if phase == "intro_dialogue":
		dialogue_index += 1
		if dialogue_index < 3:
			_show_dialogue()
		else:
			_start_camera_reveal()
	elif phase == "reveal_dialogue":
		dialogue_index += 1
		if dialogue_index < DIALOGUE_LINES.size():
			_show_dialogue()
		else:
			_start_tutorial_move()


func _start_camera_reveal() -> void:
	phase = "camera_reveal"
	dialogue_panel.visible = false
	camera_tracks_player = false
	var camera_tween := create_tween()
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(camera_rig, "position", Vector3(0, 0, -7.0), 1.75)
	camera_tween.parallel().tween_property(camera, "size", REVEAL_CAMERA_SIZE, 1.75)
	_reveal_title_card()
	await camera_tween.finished
	await get_tree().create_timer(0.45).timeout
	phase = "reveal_dialogue"
	dialogue_index = 3
	_show_dialogue()


func _start_tutorial_move() -> void:
	phase = "tutorial_move"
	dialogue_panel.visible = false
	camera_tracks_player = true
	var camera_tween := create_tween()
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(camera, "size", GAMEPLAY_CAMERA_SIZE, 0.6)
	_show_objective(
		"먼저 걷는다",
		"왼쪽 스틱으로 움직인다. 다리를 따라 앞으로 간다." if touch_enabled else "W·A·S·D로 움직인다. 다리를 따라 앞으로 간다.",
		"이동 0 / 3m"
	)
	_set_letterbox(false)


func _update_player_gameplay(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	input_vector += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_vector += mobile_move_vector
	input_vector = input_vector.limit_length(1.0)
	var world_direction := Vector3(input_vector.x + input_vector.y, 0, -input_vector.x + input_vector.y)
	if world_direction.length_squared() > 0.01:
		world_direction = world_direction.normalized()
	if aim_held:
		if touch_enabled:
			if world_direction.length_squared() > 0.01:
				current_aim_direction = world_direction
			else:
				current_aim_direction = _get_facing_world_direction()
		else:
			current_aim_direction = _get_mouse_world_direction()
		aim_hold_duration += delta
		if phase == "tutorial_aim" and aim_hold_duration >= 0.45:
			_complete_tutorial_step("조준 완료", Callable(self, "_start_tutorial_combat"))
	else:
		aim_hold_duration = 0.0
	var previous_position := player.position
	if roll_active:
		roll_elapsed += delta
		var progress := clampf(roll_elapsed / ROLL_DURATION, 0.0, 1.0)
		var speed := lerpf(ROLL_START_SPEED, ROLL_END_SPEED, ease(progress, 2.2))
		player.velocity = roll_direction * speed
		if roll_elapsed >= ROLL_DURATION:
			roll_active = false
			roll_elapsed = 0.0
			roll_iframe_until_msec = Time.get_ticks_msec() + 120
	elif player_hit_lock > 0.0:
		player.velocity = player.velocity.move_toward(Vector3.ZERO, 12.0 * delta)
	elif world_direction.length_squared() > 0.01:
		player.velocity = world_direction * PLAYER_SPEED
		if not aim_held:
			_set_facing_from_world_direction(world_direction)
		_set_player_animation("walk", current_facing)
	else:
		player.velocity = Vector3.ZERO
		_set_player_animation("idle", current_facing)
	if aim_held:
		_set_facing_from_world_direction(current_aim_direction)
	_update_aim_laser()
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -BRIDGE_HALF_WIDTH + 0.55, BRIDGE_HALF_WIDTH - 0.55)
	player.position.z = clampf(player.position.z, -BRIDGE_HALF_LENGTH + 1.0, BRIDGE_HALF_LENGTH - 1.0)
	if phase == "tutorial_move" and not tutorial_transitioning:
		movement_distance += previous_position.distance_to(player.position)
		objective_progress.text = "이동 %.1f / 3m" % minf(movement_distance, 3.0)
		if movement_distance >= 3.0:
			_complete_tutorial_step("이동 완료", Callable(self, "_start_tutorial_dash"))
	if phase == "tutorial_combat":
		_try_activate_tutorial_enemies()
		if fire_held and aim_held:
			_try_fire()
	if phase == "tutorial_extract":
		var distance_to_exit := player.global_position.distance_to(sewer_exit.global_position)
		interaction_panel.visible = distance_to_exit <= 2.2
		extraction_ready = distance_to_exit <= 2.2
		objective_progress.text = "하수구까지 %.0fm" % distance_to_exit
	else:
		interaction_panel.visible = false


func _try_dash() -> void:
	if roll_active or tutorial_transitioning:
		return
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	input_vector += mobile_move_vector
	var direction := Vector3(input_vector.x + input_vector.y, 0, -input_vector.x + input_vector.y)
	if direction.length_squared() <= 0.01:
		direction = _get_facing_world_direction()
	roll_direction = direction.normalized()
	roll_active = true
	roll_elapsed = 0.0
	_set_facing_from_world_direction(roll_direction)
	player_sprite.play("roll_%s" % current_facing)
	_spawn_roll_afterimages()
	if phase == "tutorial_dash":
		_complete_tutorial_step("대시 완료", Callable(self, "_start_tutorial_aim"))


func _spawn_roll_afterimages() -> void:
	for delay in [0.05, 0.11, 0.17]:
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if (
				not is_instance_valid(player_sprite)
				or not player_sprite.is_inside_tree()
				or not is_inside_tree()
				or restarting
			):
				return
			var texture := player_sprite.sprite_frames.get_frame_texture(player_sprite.animation, player_sprite.frame)
			if texture == null:
				return
			var ghost := Sprite3D.new()
			ghost.texture = texture
			ghost.pixel_size = player_sprite.pixel_size
			ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			ghost.shaded = false
			ghost.no_depth_test = true
			ghost.modulate = Color(0.66, 0.82, 0.82, 0.3)
			var ghost_position := player_sprite.global_position
			add_child(ghost)
			ghost.global_position = ghost_position
			var tween := ghost.create_tween().set_parallel(true)
			tween.tween_property(ghost, "modulate:a", 0.0, 0.24)
			tween.tween_property(ghost, "scale", Vector3.ONE * 1.08, 0.24)
			tween.finished.connect(ghost.queue_free)
		)


func _start_tutorial_dash() -> void:
	phase = "tutorial_dash"
	tutorial_transitioning = false
	_show_objective(
		"구르기",
		(
			"대시 버튼을 누르면 구른다. 구르는 동안에는 총알을 맞지 않는다."
			if touch_enabled
			else "SPACE를 누르면 구른다. 구르는 동안에는 총알을 맞지 않는다."
		),
		"입력 대기"
	)


func _start_tutorial_aim() -> void:
	phase = "tutorial_aim"
	tutorial_transitioning = false
	_show_objective(
		"조준",
		# 이 단계에서 총이 처음 손에 들린다 — 문구가 그 순간을 가리킨다.
		"조준 버튼을 누르고 있으면 총을 들고 멀리까지 본다." if touch_enabled else "우클릭을 누르고 있으면 총을 들고 멀리까지 본다.",
		"조준 유지 0.5초"
	)


func _start_tutorial_combat() -> void:
	phase = "tutorial_combat"
	tutorial_transitioning = false
	aim_hold_duration = 0.0
	tutorial_enemies_activated = false
	_show_objective(
		"다리를 건넌다",
		"앞에 경계병이 있다. 조준하고 쏴서 길을 연다." if touch_enabled else "앞에 경계병이 있다. 우클릭으로 조준하고 좌클릭으로 쏴서 길을 연다.",
		"경계병 %d — 접근한다" % enemies_remaining
	)


func _try_activate_tutorial_enemies() -> void:
	if tutorial_enemies_activated or enemies_remaining <= 0:
		return
	var nearest_distance := INF
	for enemy in enemies:
		if is_instance_valid(enemy):
			nearest_distance = minf(nearest_distance, player.global_position.distance_to(enemy.global_position))
	if nearest_distance > TUTORIAL_ENEMY_ACTIVATION_RANGE:
		objective_progress.text = "경계병까지 %.0fm · 남은 %d" % [nearest_distance, enemies_remaining]
		return
	tutorial_enemies_activated = true
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		enemy.set_physics_process(true)
		enemy.call("set_threat_level", 0.32)
		enemy.call("set_combat_target", player)
	objective_progress.text = "교전 중 · 남은 적 %d" % enemies_remaining


func _on_tutorial_enemy_died(enemy: CharacterBody3D) -> void:
	if enemies.has(enemy):
		enemies_remaining = maxi(0, enemies_remaining - 1)
	tutorial_damage_grace_until_msec = Time.get_ticks_msec() + TUTORIAL_KILL_GRACE_MSEC
	_clear_projectiles_from_enemy(enemy)
	if phase == "tutorial_combat":
		objective_progress.text = "남은 적 %d" % enemies_remaining
		if enemies_remaining <= 0:
			fire_held = false
			for remaining_enemy in enemies:
				if is_instance_valid(remaining_enemy):
					remaining_enemy.set_physics_process(false)
			_complete_tutorial_step("교량 확보", Callable(self, "_start_tutorial_extract"), 0.9)


func _clear_projectiles_from_enemy(enemy: CharacterBody3D) -> void:
	for projectile in get_tree().get_nodes_in_group("projectile"):
		if (
			is_instance_valid(projectile)
			and projectile.get("source_body") == enemy
		):
			projectile.queue_free()


func _start_tutorial_extract() -> void:
	phase = "tutorial_extract"
	tutorial_transitioning = false
	aim_held = false
	fire_held = false
	mobile_aim_active = false
	if mobile_aim_button:
		mobile_aim_button.set_pressed_no_signal(false)
	sewer_arrow.visible = true
	for child in sewer_exit.get_children():
		if child.has_meta("tutorial_extraction_visual"):
			child.visible = true
	# 신호는 여기서 죽는다 — 먼지가 쉘터를 '발견'하는 게 아니라, 신호가 끊긴
	# 자리에 쉘터가 있다. 사자의 "다들 그 소리를 듣고 왔다"로 이어지는 이음새.
	_show_objective(
		"무전이 끊겼다",
		"다리를 건넌 뒤로 라디오가 조용하다. 하수구 뚜껑 밑에서 불빛이 새어 나온다.",
		"하수구까지 %.0fm" % player.global_position.distance_to(sewer_exit.global_position)
	)


func _complete_tutorial_step(
	completion_text: String,
	next_step: Callable,
	delay: float = 0.65
) -> void:
	if tutorial_transitioning:
		return
	tutorial_transitioning = true
	objective_progress.text = "✓  %s" % completion_text
	objective_progress.add_theme_color_override("font_color", Color("#9dffd2"))
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if restarting:
			return
		next_step.call()
	)


func _show_objective(title: String, detail: String, progress: String) -> void:
	objective_title.text = title
	objective_detail.text = detail
	objective_progress.text = progress
	objective_progress.add_theme_color_override("font_color", Color("#80e4bd"))
	objective_panel.visible = true
	objective_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(objective_panel, "modulate:a", 1.0, 0.2)


func _try_fire() -> void:
	if phase != "tutorial_combat" or not aim_held or reloading or fire_cooldown > 0.0:
		return
	if magazine_ammo <= 0:
		if reserve_ammo > 0:
			_start_reload()
		return
	current_aim_direction = _get_mobile_aim_assisted_direction() if touch_enabled else _get_mouse_world_direction()
	_set_facing_from_world_direction(current_aim_direction)
	var bullet := Area3D.new()
	bullet.set_script(BULLET_PROJECTILE)
	bullet.direction = current_aim_direction.rotated(Vector3.UP, deg_to_rad(randf_range(-1.35, 1.35)))
	bullet.source_body = player
	bullet.damage = 58
	bullet.critical_chance = 0.08
	bullet.effective_range = 18.0
	bullet.maximum_range = 42.0
	bullet.position = player.global_position + current_aim_direction * 0.78 + Vector3(0, 0.18, 0)
	add_child(bullet)
	magazine_ammo -= 1
	fire_cooldown = FIRE_INTERVAL
	_flash_muzzle(bullet.position)
	if magazine_ammo <= 0 and reserve_ammo > 0:
		_start_reload()


func _start_reload() -> void:
	if reloading or reserve_ammo <= 0:
		return
	reloading = true
	reload_remaining = 1.25


func _update_reload(delta: float) -> void:
	if not reloading:
		return
	reload_remaining -= delta
	if reload_remaining > 0.0:
		return
	reloading = false
	var needed := 30 - magazine_ammo
	var loaded := mini(needed, reserve_ammo)
	magazine_ammo += loaded
	reserve_ammo -= loaded


func _flash_muzzle(world_position: Vector3) -> void:
	muzzle_flash.global_position = world_position
	muzzle_flash.visible = true
	muzzle_flash.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(muzzle_flash, "scale", Vector3.ONE * 2.4, 0.06)
	tween.tween_callback(func() -> void: muzzle_flash.visible = false)


func _try_enter_shelter() -> void:
	if not extraction_ready or restarting:
		return
	restarting = true
	player.velocity = Vector3.ZERO
	objective_title.text = "쉘터 진입"
	objective_detail.text = "쇠문 너머에서 발전기 소리가 난다. 누군가 아직 여기서 불을 켜 두고 있다."
	objective_progress.text = ""
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.9)
	await tween.finished
	GameState.complete_opening_and_prepare_shelter()
	if not SceneTransition.transition_to(SHELTER_SCENE, OPENING_SCENE):
		restarting = false


func take_damage(amount: int) -> void:
	if restarting or amount <= 0 or player_health <= 0:
		return
	# 구르는 동안 + 착지 직후 짧은 유예까지 무적. 회피 굴림이 아무것도 회피하지
	# 못하면 손맛이 죽는다. 대시 튜토리얼에서 특히, 굴러서 총알을 흘려보내는
	# 감각이 핵심이다. 굴림이 끝나는 프레임에 맞는 억울함도 유예로 막는다.
	if roll_active or Time.get_ticks_msec() < roll_iframe_until_msec:
		return
	if phase == "tutorial_combat" and tutorial_transitioning:
		return
	if phase == "tutorial_combat":
		if Time.get_ticks_msec() < tutorial_damage_grace_until_msec:
			return
		if player_hit_lock > 0.0:
			return
	# 오프닝은 무적 — 체력은 깎지 않고 피격 플래시만 남긴다. 첫 5분에 죽어서
	# 처음부터 다시 보는 경험을 만들지 않는다(사망 재시작 경로는 도달 불가).
	player_hit_lock = 0.28
	player_sprite.modulate = Color(1.55, 0.45, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.16)


func take_hit(amount: int, hit_direction: Vector3) -> void:
	take_damage(amount)
	if player_health > 0:
		hit_direction.y = 0.0
		if hit_direction.length_squared() > 0.01:
			player.velocity += hit_direction.normalized() * 1.8


func get_projectile_hit_center() -> Vector3:
	return player.global_position + Vector3(0, 0.2, 0)


func get_projectile_hit_radius() -> float:
	return 0.52


func get_faction_id() -> String:
	return "player"


func _restart_opening_after_death() -> void:
	if restarting or death_resolution_pending:
		return
	death_resolution_pending = true
	if phase == "tutorial_combat":
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		if enemies_remaining <= 0 or tutorial_transitioning:
			player_health = maxi(1, player_health)
			death_resolution_pending = false
			return
	death_resolution_pending = false
	restarting = true
	fire_held = false
	aim_held = false
	objective_panel.visible = false
	dialogue_panel.visible = false
	interaction_panel.visible = false
	var death_label := Label.new()
	death_label.text = "숨을 고른다. 다시 간다."
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.position = Vector2(-220, -24)
	death_label.size = Vector2(440, 48)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_override("font", FONT)
	death_label.add_theme_font_size_override("font_size", 26)
	death_label.add_theme_color_override("font_color", Color("#d7dfdc"))
	fade_rect.get_parent().add_child(death_label)
	death_label.z_index = 201
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.72)
	await tween.finished
	await get_tree().create_timer(0.55).timeout
	if not SceneTransition.transition_to(OPENING_SCENE, OPENING_SCENE):
		restarting = false


func _set_player_animation(state: String, direction: String) -> void:
	if roll_active:
		return
	current_motion = state
	if direction != current_facing:
		current_facing = direction
	var animation := "%s_%s" % [state, current_facing]
	if player_sprite.animation != animation:
		player_sprite.play(animation)


func _set_facing_from_world_direction(world_direction: Vector3) -> void:
	if world_direction.length_squared() <= 0.01:
		return
	var screen_direction := Vector2(
		world_direction.x - world_direction.z,
		world_direction.x + world_direction.z
	).normalized()
	var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
	var index := int(round(angle / 45.0)) % 8
	var next_facing: String = SCREEN_DIRECTIONS[index]
	if next_facing == current_facing:
		return
	current_facing = next_facing
	if not roll_active:
		_set_player_animation(current_motion, current_facing)


func _get_facing_world_direction() -> Vector3:
	var index := SCREEN_DIRECTIONS.find(current_facing)
	var angle := deg_to_rad(float(index) * 45.0)
	var screen := Vector2(sin(angle), -cos(angle))
	return Vector3(screen.x + screen.y, 0, -screen.x + screen.y).normalized()


func _get_mouse_world_direction() -> Vector3:
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return current_aim_direction
	var distance_to_plane := (player.global_position.y - ray_origin.y) / ray_direction.y
	var hit_position := ray_origin + ray_direction * distance_to_plane
	var direction := hit_position - player.global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.01 else current_aim_direction


func _get_mobile_aim_assisted_direction() -> Vector3:
	var base_direction := current_aim_direction
	base_direction.y = 0.0
	if base_direction.length_squared() <= 0.01:
		base_direction = _get_facing_world_direction()
	base_direction = base_direction.normalized()
	var best_direction := base_direction
	var best_score := -INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy := enemy.global_position - player.global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance <= 0.01 or distance > 28.0:
			continue
		var candidate := to_enemy / distance
		var alignment := base_direction.dot(candidate)
		if alignment < 0.45:
			continue
		var score := alignment * 2.0 - distance * 0.025
		if score > best_score:
			best_score = score
			best_direction = candidate
	return base_direction.lerp(best_direction, 0.72).normalized()


func _update_weapon_visual(delta: float = 0.0) -> void:
	if not is_instance_valid(weapon_sprite):
		return
	# 조준·사격·재장전 중에만 총이 보인다. 다리를 걸어 올라가는 인트로에서
	# 손에 총이 떠 있으면 이상하다 — 튜토리얼 '조준' 단계에서 총이 나타나는
	# 순간이 곧 연출이 된다. 규칙은 scripts/raid/weapon_reveal.gd.
	var reveal_alpha := weapon_reveal.update(
		delta,
		(aim_held or fire_held or reloading) and GAMEPLAY_PHASES.has(phase)
	)
	weapon_sprite.visible = weapon_reveal.is_drawn()
	weapon_sprite.modulate.a = reveal_alpha
	var direction := current_aim_direction if aim_held else _get_facing_world_direction()
	weapon_sprite.position = direction * 0.62 + Vector3(0, 0.27, 0)
	var screen_direction := Vector2(direction.x - direction.z, direction.x + direction.z).normalized()
	weapon_sprite.rotation.z = screen_direction.angle()
	weapon_sprite.flip_v = screen_direction.x < 0.0
	aim_reticle.visible = aim_held and GAMEPLAY_PHASES.has(phase)
	if aim_reticle.visible:
		var reticle_position := get_viewport().get_mouse_position()
		if touch_enabled:
			reticle_position = camera.unproject_position(
				player.global_position + current_aim_direction * 4.0 + Vector3(0, 0.2, 0)
			)
		aim_reticle.position = reticle_position - aim_reticle.size * 0.5


func _update_camera(delta: float) -> void:
	if camera_tracks_player and is_instance_valid(player):
		var target := Vector3(player.position.x, 0, player.position.z)
		camera_rig.position = target
	if GAMEPLAY_PHASES.has(phase) and is_instance_valid(camera):
		var target_size := AIM_CAMERA_SIZE if aim_held else GAMEPLAY_CAMERA_SIZE
		camera.size = lerpf(camera.size, target_size, 1.0 - exp(-6.5 * delta))


func _update_hud() -> void:
	if health_bar:
		health_bar.value = player_health
	if health_label:
		health_label.text = "체력  %d / %d" % [player_health, PLAYER_MAX_HEALTH]
	if opening_medkit_button:
		# 무적 오프닝에선 구급약을 쓸 일이 없다 — 늘 숨김(첫 사용법은 필드 튜토리얼이 맡는다).
		opening_medkit_button.visible = false
	if ammo_label:
		ammo_label.text = "AK-47  ·  7.62mm"
	if magazine_label:
		magazine_label.text = "%02d / 30" % magazine_ammo
	if reserve_ammo_label:
		reserve_ammo_label.text = "예비 %d발" % reserve_ammo
	if reload_bar:
		reload_bar.visible = reloading
		reload_bar.value = 1.0 - clampf(reload_remaining / 1.25, 0.0, 1.0) if reloading else 1.0
	if weapon_hud_panel:
		weapon_hud_panel.visible = GAMEPLAY_PHASES.has(phase)
	if mobile_controls_root:
		mobile_controls_root.visible = touch_enabled and GAMEPLAY_PHASES.has(phase)
	if mobile_fire_button:
		mobile_fire_button.visible = phase == "tutorial_combat"
	if mobile_aim_button:
		mobile_aim_button.visible = phase in ["tutorial_aim", "tutorial_combat"]
	if mobile_dash_button:
		mobile_dash_button.visible = GAMEPLAY_PHASES.has(phase)
	if mobile_interact_button:
		mobile_interact_button.visible = (
			phase == "tutorial_extract"
			and extraction_ready
		)


func _use_opening_medkit() -> void:
	if not GAMEPLAY_PHASES.has(phase):
		return
	if GameState.medkits <= 0 or player_health <= 0 or player_health >= PLAYER_MAX_HEALTH:
		return
	GameState.medkits -= 1
	player_health = mini(PLAYER_MAX_HEALTH, player_health + 38)
	_update_hud()


func _update_ambient_animation() -> void:
	if sewer_arrow and sewer_arrow.visible:
		var time := float(Time.get_ticks_msec()) * 0.001
		sewer_arrow.position.y = 2.4 + sin(time * 3.2) * 0.18
		sewer_arrow.modulate.a = 0.76 + sin(time * 4.4) * 0.2
	if continue_label and dialogue_panel.visible:
		continue_label.modulate.a = 0.55 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.35
	if not tutorial_enemies_activated and phase != "tutorial_extract":
		var watch_bucket := floori(float(Time.get_ticks_msec()) / 2200.0)
		if watch_bucket != enemy_watch_bucket:
			enemy_watch_bucket = watch_bucket
			var look_sets := [["e", "ne"], ["w", "nw"], ["se", "sw"]]
			var look_set: Array = look_sets[watch_bucket % look_sets.size()]
			for index in enemies.size():
				var enemy := enemies[index]
				if is_instance_valid(enemy):
					enemy.call("_set_facing", str(look_set[index % look_set.size()]))


func _set_letterbox(enabled: bool) -> void:
	var target_alpha := 1.0 if enabled else 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(letterbox_top, "modulate:a", target_alpha, 0.35)
	tween.tween_property(letterbox_bottom, "modulate:a", target_alpha, 0.35)


func _fade_from_black() -> void:
	fade_rect.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 1.2)
