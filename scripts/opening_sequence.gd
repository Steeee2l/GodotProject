extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const BULLET_PROJECTILE := preload("res://scripts/bullet_projectile.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
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
const DIALOGUE_LINES := [
	"여기라면 찾을 수 있겠지.",
	"끊어진 구조 신호는 한강 북쪽에서 왔어. 아직 누군가 살아 있다는 뜻이야.",
	"통조림도 탄약도 오래 버티지 못해. 오늘은 반드시 쉴 곳을 찾아야 해.",
	"철교를 먼저 차지했군. 저 순찰대를 지나야 북쪽으로 갈 수 있어.",
	"숨을 고르고, 시선을 들어. 좋아... 시작해 볼까.",
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

var phase := "intro_walk"
var dialogue_index := 0
var player: CharacterBody3D
var player_sprite: AnimatedSprite3D
var weapon_sprite: Sprite3D
var camera_rig: Node3D
var camera: Camera3D
var survivor_frames: SpriteFrames
var current_facing := "n"
var current_motion := "walk"
var current_aim_direction := Vector3(0, 0, -1)
var camera_tracks_player := true
var roll_active := false
var roll_elapsed := 0.0
var roll_direction := Vector3.ZERO
var movement_distance := 0.0
var aim_hold_duration := 0.0
var aim_held := false
var fire_held := false
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
var sewer_exit: Node3D
var sewer_arrow: Label3D
var objective_panel: PanelContainer
var objective_title: Label
var objective_detail: Label
var objective_progress: Label
var dialogue_panel: PanelContainer
var dialogue_text: Label
var continue_label: Label
var ammo_label: Label
var magazine_label: Label
var reserve_ammo_label: Label
var reload_bar: ProgressBar
var weapon_hud_panel: PanelContainer
var weapon_hud_image: TextureRect
var health_bar: ProgressBar
var health_label: Label
var interaction_panel: PanelContainer
var interaction_label: Label
var fade_rect: ColorRect
var letterbox_top: ColorRect
var letterbox_bottom: ColorRect
var aim_reticle: Control
var muzzle_flash: MeshInstance3D
var visibility_rect: ColorRect
var visibility_material: ShaderMaterial
var mobile_controls_root: Control
var mobile_joystick: Control
var mobile_dash_button: Button
var mobile_aim_button: Button
var mobile_fire_button: Button
var mobile_interact_button: Button


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	touch_enabled = _detect_touch_controls()
	_build_environment()
	_build_camera()
	_build_player()
	_build_extraction()
	_build_hud()
	_build_visibility_fog()
	_spawn_cinematic_enemies()
	_set_player_animation("walk", "n")
	_fade_from_black()


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
	_update_weapon_visual()
	_update_visibility_fog()
	_update_hud()


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
		if touch.pressed and mobile_joystick != null and mobile_joystick.get_global_rect().has_point(touch.position):
			mobile_joystick_touch = touch.index
			_update_mobile_joystick(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == mobile_joystick_touch:
			mobile_joystick_touch = -1
			mobile_move_vector = Vector2.ZERO
			mobile_joystick.queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == mobile_joystick_touch:
			_update_mobile_joystick(drag.position)
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
	_add_vehicle("res://assets/opening/opening_wrecked_taxi_v1.png", Vector3(-3.5, 0.84, 27.0), 0.0036, 12.0, Vector3(4.1, 1.1, 1.8))
	_add_vehicle("res://assets/opening/opening_wrecked_truck_v1.png", Vector3(2.4, 0.95, 2.0), 0.0040, -8.0, Vector3(5.0, 1.3, 2.1))
	_add_vehicle("res://assets/opening/opening_wrecked_taxi_v1.png", Vector3(3.7, 0.82, -19.0), 0.0032, -18.0, Vector3(3.7, 1.0, 1.7))
	_add_vehicle("res://assets/opening/opening_wrecked_bus_v1.png", Vector3(-1.8, 1.0, -35.0), 0.0044, 4.0, Vector3(5.8, 1.3, 2.2))
	_add_fire(Vector3(-3.2, 0.35, 26.7), 0.72)
	_add_fire(Vector3(2.9, 0.4, 1.8), 0.82)
	_add_fire(Vector3(-5.5, 0.3, -27.0), 0.62)


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
	texture_path: String,
	world_position: Vector3,
	pixel_size: float,
	screen_rotation: float,
	collision_size: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = "OpeningWreck"
	body.add_to_group("opening_wreck")
	body.position = world_position
	body.collision_layer = 2
	body.collision_mask = 0
	var sprite := Sprite3D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.rotation_degrees.z = screen_rotation
	sprite.position.y = maxf(0.9, float(sprite.texture.get_height()) * pixel_size * 0.32)
	body.add_child(sprite)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collision_size
	collision.shape = shape
	collision.position.y = -0.2
	body.add_child(collision)
	add_child(body)


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


func _add_mist() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.66, 0.72, 0.73, 0.11)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(3.8, 1.2)
	quad.material = material
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(7, 1.2, 34)
	process.direction = Vector3(0.5, 0, -0.08)
	process.spread = 12.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.22
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.8
	var mist := GPUParticles3D.new()
	mist.position = Vector3(0, 1.1, 0)
	mist.amount = 70
	mist.lifetime = 12.0
	mist.randomness = 1.0
	mist.visibility_aabb = AABB(Vector3(-10, -2, -40), Vector3(20, 8, 80))
	mist.process_material = process
	mist.draw_pass_1 = quad
	add_child(mist)


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
	weapon_sprite.pixel_size = 0.00115
	weapon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_sprite.shaded = false
	weapon_sprite.transparent = true
	weapon_sprite.no_depth_test = true
	weapon_sprite.render_priority = 121
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
	sprite.pixel_size = 0.0038
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


func _build_dialogue_ui(hud: CanvasLayer) -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.position = Vector2(-450, -192)
	dialogue_panel.size = Vector2(900, 126)
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
	var speaker := Label.new()
	speaker.text = "생존자"
	speaker.add_theme_font_override("font", FONT)
	speaker.add_theme_font_size_override("font_size", 18)
	speaker.add_theme_color_override("font_color", Color("#d7b765"))
	column.add_child(speaker)
	dialogue_text = Label.new()
	dialogue_text.add_theme_font_override("font", FONT)
	dialogue_text.add_theme_font_size_override("font_size", 24)
	dialogue_text.add_theme_color_override("font_color", Color("#edf2ef"))
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(dialogue_text)
	continue_label = Label.new()
	continue_label.text = "화면 터치" if touch_enabled else "클릭 또는 SPACE"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_font_override("font", FONT)
	continue_label.add_theme_font_size_override("font_size", 13)
	continue_label.add_theme_color_override("font_color", Color("#91a49d"))
	column.add_child(continue_label)
	dialogue_panel.visible = false


func _build_objective_ui(hud: CanvasLayer) -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "TutorialObjective"
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_panel.position = Vector2(-270, 78)
	objective_panel.size = Vector2(540, 116)
	objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.022, 0.023, 0.93), Color("#7ecbb0"), 2, 6))
	hud.add_child(objective_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 14)
	objective_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	objective_title = Label.new()
	objective_title.add_theme_font_override("font", FONT)
	objective_title.add_theme_font_size_override("font_size", 22)
	objective_title.add_theme_color_override("font_color", Color("#f1d37c"))
	column.add_child(objective_title)
	objective_detail = Label.new()
	objective_detail.add_theme_font_override("font", FONT)
	objective_detail.add_theme_font_size_override("font_size", 17)
	objective_detail.add_theme_color_override("font_color", Color("#d4ded9"))
	objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(objective_detail)
	objective_progress = Label.new()
	objective_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_progress.add_theme_font_override("font", FONT)
	objective_progress.add_theme_font_size_override("font_size", 15)
	objective_progress.add_theme_color_override("font_color", Color("#80e4bd"))
	column.add_child(objective_progress)
	objective_panel.visible = false


func _build_status_ui(hud: CanvasLayer) -> void:
	var health_panel := PanelContainer.new()
	health_panel.position = Vector2(30, 76)
	health_panel.size = Vector2(264, 76)
	health_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.02, 0.022, 0.86), Color(0.34, 0.48, 0.43, 0.7), 1, 5))
	hud.add_child(health_panel)
	var health_margin := MarginContainer.new()
	health_margin.add_theme_constant_override("margin_left", 14)
	health_margin.add_theme_constant_override("margin_right", 14)
	health_margin.add_theme_constant_override("margin_top", 9)
	health_margin.add_theme_constant_override("margin_bottom", 9)
	health_panel.add_child(health_margin)
	var health_column := VBoxContainer.new()
	health_column.add_theme_constant_override("separation", 5)
	health_margin.add_child(health_column)
	health_label = Label.new()
	health_label.add_theme_font_override("font", FONT)
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color("#dce8e1"))
	health_column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.max_value = PLAYER_MAX_HEALTH
	health_bar.value = player_health
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(236, 18)
	health_bar.add_theme_stylebox_override("background", _panel_style(Color("#182322"), Color("#445a55"), 1, 8))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color("#59cf8f"), Color("#a9f2c9"), 1, 8))
	health_column.add_child(health_bar)

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

	mobile_joystick = Control.new()
	mobile_joystick.name = "MovementJoystick"
	mobile_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mobile_joystick.offset_left = 24
	mobile_joystick.offset_top = -204
	mobile_joystick.offset_right = 204
	mobile_joystick.offset_bottom = -24
	mobile_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_joystick.draw.connect(func() -> void:
		var center := mobile_joystick.size * 0.5
		var radius := minf(mobile_joystick.size.x, mobile_joystick.size.y) * 0.38
		mobile_joystick.draw_circle(center, radius, Color(0.02, 0.04, 0.05, 0.68))
		mobile_joystick.draw_arc(center, radius, 0, TAU, 48, Color(0.48, 0.72, 0.64, 0.82), 3.0, true)
		var knob := center + mobile_move_vector * radius * 0.72
		mobile_joystick.draw_circle(knob, radius * 0.34, Color(0.55, 0.86, 0.73, 0.92))
	)
	mobile_controls_root.add_child(mobile_joystick)

	mobile_fire_button = _make_mobile_action_button("FireButton", "발사", "weapon", Color("#ffd29a"))
	mobile_fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_fire_button.offset_left = -116
	mobile_fire_button.offset_top = -116
	mobile_fire_button.offset_right = -24
	mobile_fire_button.offset_bottom = -24
	mobile_fire_button.button_down.connect(func() -> void:
		if not mobile_aim_active:
			mobile_aim_active = true
			mobile_aim_button.set_pressed_no_signal(true)
		aim_held = true
		fire_held = true
		_try_fire()
	)
	mobile_fire_button.button_up.connect(func() -> void: fire_held = false)
	mobile_controls_root.add_child(mobile_fire_button)

	mobile_aim_button = _make_mobile_action_button("AimButton", "조준", "flashlight", Color("#e8df9f"))
	mobile_aim_button.toggle_mode = true
	mobile_aim_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_aim_button.offset_left = -216
	mobile_aim_button.offset_top = -116
	mobile_aim_button.offset_right = -124
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
	mobile_dash_button.offset_left = -316
	mobile_dash_button.offset_top = -116
	mobile_dash_button.offset_right = -224
	mobile_dash_button.offset_bottom = -24
	mobile_dash_button.pressed.connect(_try_dash)
	mobile_controls_root.add_child(mobile_dash_button)

	mobile_interact_button = _make_mobile_action_button("InteractButton", "진입", "interact", Color("#b8f2d4"))
	mobile_interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_interact_button.offset_left = -116
	mobile_interact_button.offset_top = -216
	mobile_interact_button.offset_right = -24
	mobile_interact_button.offset_bottom = -124
	mobile_interact_button.pressed.connect(_try_enter_shelter)
	mobile_controls_root.add_child(mobile_interact_button)


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


func _update_mobile_joystick(screen_position: Vector2) -> void:
	if mobile_joystick == null:
		return
	var center := mobile_joystick.get_global_rect().get_center()
	var radius := minf(mobile_joystick.size.x, mobile_joystick.size.y) * 0.38
	mobile_move_vector = ((screen_position - center) / maxf(radius, 1.0)).limit_length(1.0)
	mobile_joystick.queue_redraw()


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
	player.velocity = Vector3(0, 0, -2.25)
	player.move_and_slide()
	_set_player_animation("walk", "n")
	if player.position.z <= INTRO_TARGET_Z:
		player.position.z = INTRO_TARGET_Z
		player.velocity = Vector3.ZERO
		phase = "intro_dialogue"
		dialogue_index = 0
		_set_player_animation("idle", "n")
		_show_dialogue()


func _show_dialogue() -> void:
	dialogue_text.text = DIALOGUE_LINES[dialogue_index]
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.18)


func _advance_dialogue() -> void:
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
		"첫걸음",
		"왼쪽 조이스틱으로 이동해 보세요." if touch_enabled else "WASD로 이동해 보세요.",
		"이동 거리 0 / 3m"
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
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -BRIDGE_HALF_WIDTH + 0.55, BRIDGE_HALF_WIDTH - 0.55)
	player.position.z = clampf(player.position.z, -BRIDGE_HALF_LENGTH + 1.0, BRIDGE_HALF_LENGTH - 1.0)
	if phase == "tutorial_move" and not tutorial_transitioning:
		movement_distance += previous_position.distance_to(player.position)
		objective_progress.text = "이동 거리 %.1f / 3m" % minf(movement_distance, 3.0)
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
		"위기 회피",
		"대시 버튼을 눌러 회피하세요." if touch_enabled else "SPACE를 눌러 대시하세요.",
		"입력 대기"
	)


func _start_tutorial_aim() -> void:
	phase = "tutorial_aim"
	tutorial_transitioning = false
	_show_objective(
		"시야 확보",
		"조준 버튼을 켜 시야와 사격 방향을 확보하세요." if touch_enabled else "마우스 오른쪽 버튼을 누른 채 조준하세요.",
		"조준 유지 0.5초"
	)


func _start_tutorial_combat() -> void:
	phase = "tutorial_combat"
	tutorial_transitioning = false
	aim_hold_duration = 0.0
	tutorial_enemies_activated = false
	_show_objective(
		"교량 돌파",
		"전진한 뒤 조준과 발사 버튼으로 적들을 소탕하세요." if touch_enabled else "전진한 뒤 오른쪽 버튼으로 조준하고 왼쪽 버튼으로 사격하세요.",
		"경계병에게 접근하세요 · 남은 적 %d" % enemies_remaining
	)


func _try_activate_tutorial_enemies() -> void:
	if tutorial_enemies_activated or enemies_remaining <= 0:
		return
	var nearest_distance := INF
	for enemy in enemies:
		if is_instance_valid(enemy):
			nearest_distance = minf(nearest_distance, player.global_position.distance_to(enemy.global_position))
	if nearest_distance > TUTORIAL_ENEMY_ACTIVATION_RANGE:
		objective_progress.text = "경계병까지 %.0fm · 남은 적 %d" % [nearest_distance, enemies_remaining]
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
	_show_objective(
		"첫 번째 쉘터",
		"화살표를 따라 하수구로 이동하세요.",
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
	objective_detail.text = "지하에서 희미한 발전기 소리가 들립니다."
	objective_progress.text = ""
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.9)
	await tween.finished
	GameState.complete_opening_and_prepare_shelter()
	get_tree().change_scene_to_file(SHELTER_SCENE)


func take_damage(amount: int) -> void:
	if restarting or amount <= 0 or player_health <= 0:
		return
	if phase == "tutorial_combat" and tutorial_transitioning:
		return
	if phase == "tutorial_combat":
		if Time.get_ticks_msec() < tutorial_damage_grace_until_msec:
			return
		if player_hit_lock > 0.0:
			return
		amount = maxi(1, roundi(float(amount) * 0.62))
	player_health = maxi(0, player_health - amount)
	player_hit_lock = 0.28
	player_sprite.modulate = Color(1.55, 0.45, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.16)
	if player_health <= 0:
		_restart_opening_after_death()


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
	death_label.text = "다시 숨을 고릅니다..."
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
	get_tree().change_scene_to_file(OPENING_SCENE)


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


func _update_weapon_visual() -> void:
	if not is_instance_valid(weapon_sprite):
		return
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
