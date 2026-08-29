extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const SFX := preload("res://scripts/sfx_bank.gd")
const ROOM_MODULE_SCENE := preload("res://scenes/modules/building_room_module.tscn")
const TRANSITION_MODULE_SCENE := preload("res://scenes/modules/building_transition_module.tscn")
const LOOT_MODULE_SCENE := preload("res://scenes/modules/building_loot_module.tscn")
const LOOT_ECONOMY := preload("res://scripts/loot_economy.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const BULLET_SCRIPT := preload("res://scripts/bullet_projectile.gd")
const WEAPON_SYSTEM := preload("res://scripts/weapon_system.gd")
const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")
const AIM_RETICLE_SCRIPT := preload("res://scripts/aim_reticle.gd")
const INVENTORY_UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")
const WEAPON_VISUAL_CATALOG := preload("res://scripts/weapon_visual_catalog.gd")
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")
# 건물 내부 사망도 필드와 같은 경로를 탄다 — 게임오버 화면·시큐어 슬롯·사망 집계.
const GAME_OVER_SCREEN := preload("res://scripts/hud/game_over_screen.gd")
const RAID_LOSS_MANAGER := preload("res://scripts/raid_loss_manager.gd")
const AMMO_762_TEXTURE := preload("res://assets/items/ammo_762.png")
const RUBBER_GASKET_TEXTURE := preload("res://assets/items/mod_components/rubber_gasket.png")
const SCOPE_LENS_TEXTURE := preload("res://assets/items/mod_components/scope_lens.png")
const MAGAZINE_SPRING_TEXTURE := preload("res://assets/items/mod_components/magazine_spring.png")
const CAT_ANIMATION_ROOT := "res://assets/characters/cat_8way"
const CAT_ROLL_ANIMATION_ROOT := "res://assets/characters/cat_roll"
const CAT_MELEE_ANIMATION_ROOT := "res://assets/characters/cat_melee"
const BASEBALL_BAT_TEXTURE := preload("res://assets/weapons/catalog/generated/baseball_bat.png")
# raid_hud.gd는 GameState 식별자를 직접 쓰므로 preload하면 오토로드 등록 전에
# 컴파일되는 헤드리스 테스트에서 깨진다 — 런타임 load()로 늦게 붙인다.
const RAID_HUD_PATH := "res://scripts/hud/raid_hud.gd"
const CORRIDOR_TEXTURE_PATH := "res://assets/interiors/office_dungeon/corridor_floor_tile_v1.png"
const WALL_TEXTURE_PATH := "res://assets/interiors/office_dungeon/office_wall_panel_v1.png"
const CAT_DIRECTION_STATES := {
	"n": "up", "ne": "up_right", "e": "right", "se": "down_right",
	"s": "down", "sw": "down_left", "w": "left", "nw": "up_left",
}
const SCREEN_DIRECTIONS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ROOM_TYPES := ["open_office", "open_office", "meeting", "storage", "server", "executive"]
const MOVE_SPEED := 4.65
const ROOM_SIZE := Vector2(28.0, 22.0)
const ROOM_STEP := Vector2(38.0, 32.0)
const CORRIDOR_WIDTH := 3.2
const ROLL_DURATION := 0.42
const ROLL_STAMINA_MAX := 100.0
const ROLL_STAMINA_COST := 35.0
const ROLL_STAMINA_RECOVERY := 28.0
const ROLL_START_SPEED := 42.0
const ROLL_END_SPEED := 4.4
# 근접 전투 수치·연출은 필드(main.gd)와 완전 동일 — 건물 안이라고 배트가
# 짧아질 이유가 없다(유저: "건물 정보 제외 전부 필드와 동일해야").
const MELEE_ATTACK_RANGE := 2.2
const MELEE_ATTACK_DAMAGE := 38
const MELEE_ATTACK_COOLDOWN := 0.72
const MELEE_FRAME_COUNT := 4
const MELEE_ANIMATION_FPS := 8.0
const MELEE_WINDUP_DURATION := 0.18
const MELEE_ANIMATION_DURATION := 0.5
const MELEE_FAN_HALF_ANGLE_DEG := 56.0
const MELEE_FAN_SEGMENTS := 24
# 필드와 동일한 카메라 상수(main.gd BASE_CAMERA_SIZE / CAMERA_DIAGONAL_OFFSET).
const BASE_CAMERA_SIZE := 28.0
const CAMERA_DIAGONAL_OFFSET := 13.5
const MOBILE_AIM_ASSIST_MAX_DISTANCE := 30.0
const MOBILE_AIM_ASSIST_HALF_ANGLE_DEG := 55.0
const FATIGUE_MAX := 100.0
const FATIGUE_MOVING_RATE := 0.055
const FATIGUE_AIM_HOLD_RATE := 0.09
const FATIGUE_SHOT_GAIN := 0.28
const FATIGUE_MELEE_GAIN := 1.1
const FATIGUE_RELOAD_GAIN := 0.8
const FATIGUE_ROLL_GAIN := 0.45
const FATIGUE_SPEED_MIN := 0.58

var game_over_screen := GAME_OVER_SCREEN.new()
var player_death_sequence_active := false
var building_run_started_msec := Time.get_ticks_msec()
var building_run_kills := 0
var last_damage_source_name := "건물 내부의 무언가"
var floor_root: Node3D
var player: CharacterBody3D
var survivor: AnimatedSprite3D
var camera: Camera3D
var prompt_label: Label
var floor_label: Label
var health_bar: ProgressBar
var ammo_label: Label
var player_world_health_bar: Control
var player_world_health_fill: Panel
var player_health_fill_style: StyleBoxFlat
var equipment_panel: PanelContainer
var equipment_weapon_image: TextureRect
var equipment_label: Label
var equipment_ammo_label: Label
var equipment_reserve_ammo_label: Label
var equipment_condition_label: Label
var equipment_reload_bar: ProgressBar
var building_objective_panel: PanelContainer
var building_objective_label: Label
var floor_clear_banner: PanelContainer
var floor_clear_title: Label
var floor_clear_detail: Label
var floor_clear_tween: Tween
var floor_clear_announced := false
var fire_button: Button
var melee_button: Button
var dash_button: Button
var reload_button: Button
var flashlight_button: Button
var interact_button: Button
var medkit_button: Button
var current_interactable: Node3D
var enemies: Array[CharacterBody3D] = []
var floor_cells: Array[Vector2i] = []
var floor_connections: Array[Dictionary] = []
var facing := "s"
var motion_state := "idle"
var camera_focus := Vector3.ZERO
var fire_cooldown := 0.0
var loading_floor := false
var weapon_stats: Dictionary = {}
var weapon_reloading := false
# 무기 표시 규칙(조준할 때만) — scripts/raid/weapon_reveal.gd
var weapon_reveal := preload("res://scripts/raid/weapon_reveal.gd").new()
var reload_timer := 0.0
var mouse_fire_held := false
var fire_button_held := false
var aim_world_position := Vector3.ZERO
var laser_aim_held := false
var melee_attack_cooldown := 0.0
# 필드 melee 스윙 상태기 이식(main.gd) — 예비동작→타격 판정→마무리.
var melee_bat_sprite: Sprite3D
var melee_attack_active := false
var melee_attack_elapsed := 0.0
var melee_attack_direction := Vector3.ZERO
var melee_hit_resolved := false
var melee_arc_texture: ImageTexture
var melee_fan_indicator: MeshInstance3D
var melee_fan_fill_material: StandardMaterial3D
var melee_fan_rim_material: StandardMaterial3D
var melee_fan_tween: Tween
var camera_shake_time := 0.0
var camera_shake_strength := 0.0
var shake_random := RandomNumberGenerator.new()
# 필드 HUD 모듈(RaidHud) — 토스트 스택만 공유해 같은 위치·같은 스타일의
# 알림을 쓴다. (전체 공유 리팩터링 대신 구성 통일 우선. 타입은 위 컴파일
# 순서 문제로 동적으로 둔다.)
var hud
var aim_reticle: Control
var laser_glow_layers: Array[MeshInstance3D] = []
var laser_glow_meshes: Array[BoxMesh] = []
var laser_endpoint: MeshInstance3D
var visibility_material: ShaderMaterial
var building_info_label: Label
var elevator_menu: PanelContainer
var inventory_ui: Control
var weapon_sprite: Sprite3D
var roll_active := false
var roll_elapsed := 0.0
var roll_stamina := ROLL_STAMINA_MAX
var roll_direction := Vector3.ZERO
var touch_stick: Control
var touch_knob: Control
var touch_id := -1
var fire_touch_id := -1
var touch_origin := Vector2.ZERO
var touch_vector := Vector2.ZERO
var fatigue := 0.0
var fatigue_panel: PanelContainer
var fatigue_bar: ProgressBar
var fatigue_label: Label
var fatigue_fill_style: StyleBoxFlat
var collision_debug_enabled := false
var auto_paused_for_background := false
@onready var BuildingRunState: Node = get_node("/root/BuildingRunState")
@onready var GameState: Node = get_node("/root/GameState")
@onready var accessibility_settings: Node = get_node("/root/AccessibilitySettings")


func _ready() -> void:
	# 효과음을 미리 합성해 첫 총성에서 합성 루프가 프레임을 잡지 않게 한다.
	SFX.warm_up()
	if not BuildingRunState.active:
		BuildingRunState.begin_run(
			"editor_preview_tower",
			int(GameState.map_seed) ^ 0x424C4447,
			"res://scenes/main.tscn",
			Vector3.ZERO,
			5
		)
	_build_environment()
	_build_player()
	_setup_weapon()
	_setup_weapon_visual()
	_setup_melee_weapon()
	_setup_aim_laser()
	fatigue = clampf(float(GameState.fatigue), 0.0, FATIGUE_MAX)
	_build_interface()
	building_run_started_msec = Time.get_ticks_msec()
	game_over_screen.build(self)
	_build_visibility_fog()
	_load_floor(BuildingRunState.current_floor, "entry")
	if not get_viewport().size_changed.is_connected(_apply_mobile_safe_layout):
		get_viewport().size_changed.connect(_apply_mobile_safe_layout)
	_apply_mobile_safe_layout()


func _physics_process(delta: float) -> void:
	if player == null or loading_floor:
		return
	if player_death_sequence_active:
		player.velocity = Vector3.ZERO
		return
	if inventory_ui != null and bool(inventory_ui.call("is_open")):
		player.velocity = Vector3.ZERO
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	melee_attack_cooldown = maxf(0.0, melee_attack_cooldown - delta)
	camera_shake_time = maxf(0.0, camera_shake_time - delta)
	camera_shake_strength = move_toward(camera_shake_strength, 0.0, delta * 8.0)
	_update_melee_attack(delta)
	if melee_button != null:
		melee_button.disabled = melee_attack_cooldown > 0.0
	if dash_button != null:
		dash_button.disabled = roll_active or roll_stamina < ROLL_STAMINA_COST
	if reload_button != null:
		reload_button.disabled = weapon_reloading or _get_reserve_ammo() <= 0
	roll_stamina = minf(ROLL_STAMINA_MAX, roll_stamina + ROLL_STAMINA_RECOVERY * delta)
	if weapon_reloading:
		reload_timer = maxf(0.0, reload_timer - delta)
		if reload_timer <= 0.0:
			_finish_reload()
	if (mouse_fire_held or fire_button_held) and bool(weapon_stats.get("automatic", true)) and not weapon_reloading:
		if mouse_fire_held:
			_fire_toward_screen_point(get_viewport().get_mouse_position())
		else:
			_fire_at_nearest_enemy()
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	input_vector = input_vector.limit_length(1.0)
	if touch_vector.length_squared() > input_vector.length_squared():
		input_vector = touch_vector
	var direction := Vector3(input_vector.x + input_vector.y, 0.0, -input_vector.x + input_vector.y)
	_update_fatigue(delta, direction.length_squared() > 0.01)
	if roll_active:
		_update_roll(delta)
	elif melee_attack_active:
		# 필드와 동일: 스윙 중에는 이동해도 방향·모션은 melee가 유지된다.
		player.velocity = Vector3.ZERO
	elif direction.length_squared() > 0.01:
		var movement_speed := MOVE_SPEED * _get_fatigue_speed_multiplier()
		if weapon_reloading:
			movement_speed *= 0.55
		player.velocity = direction.normalized() * movement_speed
		_update_facing(input_vector)
		_set_motion_state("walk")
	else:
		player.velocity = Vector3.ZERO
		_set_motion_state("idle")
	player.move_and_slide()
	_update_weapon_reveal(delta)
	_update_aim_laser()
	_update_camera(delta)
	_update_player_world_health_bar()
	_update_nearby_interactable()
	_update_aim_reticle()
	_update_visibility_fog()
	_update_enemy_visibility()


func _input(event: InputEvent) -> void:
	if player_death_sequence_active:
		# 사망 화면은 아무 입력이나 한 번으로 넘어간다(필드와 동일).
		var continue_requested: bool = (
			(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
			or (
				event is InputEventKey
				and (event as InputEventKey).pressed
				and not (event as InputEventKey).echo
			)
		)
		if continue_requested:
			_continue_after_death()
			get_viewport().set_input_as_handled()
		return
	if inventory_ui != null and bool(inventory_ui.call("is_open")):
		if (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode in [KEY_ESCAPE, KEY_E, KEY_I, KEY_B]
		):
			inventory_ui.call("toggle")
		return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_F8 and event.pressed and OS.is_debug_build():
			# 디버그 전용 — 출시 빌드에서는 작동하지 않는다.
			_toggle_collision_debug()
		elif event.keycode == KEY_F and event.pressed:
			_interact()
		elif event.keycode == KEY_SPACE and event.pressed:
			_try_start_roll()
		elif event.keycode == KEY_R and event.pressed:
			_start_reload()
		elif event.keycode == KEY_SHIFT and event.pressed:
			_use_quick_medkit()
		elif event.keycode in [KEY_E, KEY_I, KEY_B] and event.pressed and inventory_ui != null:
			inventory_ui.call("toggle")
		elif event.keycode == KEY_ESCAPE and event.pressed and BuildingRunState.current_floor == 1:
			_show_status("1층 출구에서 나갈 수 있습니다.")
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			DisplayServer.is_touchscreen_available()
			and mouse_event.device == InputEvent.DEVICE_ID_EMULATION
		):
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if laser_aim_held:
					mouse_fire_held = true
					_fire_toward_screen_point(mouse_event.position)
				else:
					mouse_fire_held = false
					_try_melee_attack(mouse_event.position)
			else:
				mouse_fire_held = false
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			laser_aim_held = mouse_event.pressed and _has_equipped_firearm()
			if not mouse_event.pressed:
				mouse_fire_held = false
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _is_inventory_button_at(touch.position):
			inventory_ui.call("toggle")
			get_viewport().set_input_as_handled()
			return
		if _handle_mobile_action_touch(touch):
			get_viewport().set_input_as_handled()
			return
		if touch.pressed and touch.position.x < get_viewport().get_visible_rect().size.x * 0.5:
			if touch_id == -1:
				touch_id = touch.index
				touch_origin = touch.position
				touch_vector = Vector2.ZERO
				touch_stick.position = touch_origin - touch_stick.size * 0.5
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			touch_vector = Vector2.ZERO
			touch_knob.position = Vector2(40, 40)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == fire_touch_id:
			var drag := event as InputEventScreenDrag
			if not fire_button.get_global_rect().grow(28.0).has_point(drag.position):
				fire_touch_id = -1
				fire_button_held = false
			get_viewport().set_input_as_handled()
			return
		if event.index != touch_id:
			return
		var radius := touch_stick.size.x * 0.34
		var offset: Vector2 = (event.position - touch_origin).limit_length(radius)
		touch_vector = offset / radius
		touch_knob.position = Vector2(40, 40) + offset
		get_viewport().set_input_as_handled()


func _toggle_collision_debug() -> void:
	collision_debug_enabled = not collision_debug_enabled
	for node in get_tree().get_nodes_in_group("collision_debug_visual"):
		if node is VisualInstance3D:
			(node as VisualInstance3D).visible = collision_debug_enabled
	_show_status(
		"충돌 영역 표시 ON" if collision_debug_enabled else "충돌 영역 표시 OFF"
	)


func _mobile_button_contains(button: Button, screen_position: Vector2) -> bool:
	return (
		button != null
		and button.visible
		and not button.disabled
		and button.get_global_rect().has_point(screen_position)
	)


func _is_inventory_button_at(screen_position: Vector2) -> bool:
	if inventory_ui == null or bool(inventory_ui.call("is_open")):
		return false
	var button := inventory_ui.get_node_or_null("InventoryButton") as Button
	return button != null and button.visible and button.get_global_rect().has_point(screen_position)


func _release_mobile_held_actions() -> void:
	fire_touch_id = -1
	fire_button_held = false


func _handle_mobile_action_touch(touch: InputEventScreenTouch) -> bool:
	if not touch.pressed:
		if touch.index == fire_touch_id:
			fire_touch_id = -1
			fire_button_held = false
			return true
		return false
	if _mobile_button_contains(fire_button, touch.position):
		if fire_touch_id == -1:
			fire_touch_id = touch.index
			fire_button_held = true
			_fire_at_nearest_enemy()
		return true
	if _mobile_button_contains(melee_button, touch.position):
		_try_melee_forward()
		return true
	if _mobile_button_contains(dash_button, touch.position):
		_try_start_roll()
		return true
	if _mobile_button_contains(interact_button, touch.position):
		_interact()
		return true
	if _mobile_button_contains(reload_button, touch.position):
		_start_reload()
		return true
	if _mobile_button_contains(flashlight_button, touch.position):
		var enabled := not flashlight_button.button_pressed
		flashlight_button.set_pressed_no_signal(enabled)
		_on_flashlight_toggled(enabled)
		return true
	if _mobile_button_contains(medkit_button, touch.position):
		_use_quick_medkit()
		return true
	return false


func _on_inventory_open_state_changed(is_open: bool) -> void:
	if not is_open:
		return
	_release_mobile_held_actions()
	mouse_fire_held = false
	touch_vector = Vector2.ZERO
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mobile_held_actions()
		mouse_fire_held = false
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or (what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and DisplayServer.is_touchscreen_available())
	):
		if not get_tree().paused:
			auto_paused_for_background = true
			get_tree().paused = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		if auto_paused_for_background:
			auto_paused_for_background = false
			get_tree().paused = false


func take_damage(amount: int) -> void:
	if player_death_sequence_active:
		return
	var applied_damage := maxi(1, roundi(float(amount) * GameState.get_damage_taken_multiplier()))
	# 방어구 돌파 +50 — 필드(main.take_damage)와 같은 규칙(피격 후 1.5s 추가 피해 −20%).
	applied_damage = GameState.apply_post_hit_guard(applied_damage)
	GameState.player_health = maxi(0, GameState.player_health - applied_damage)
	_update_health()
	SFX.play("hit_player")
	# 내가 받은 피해 숫자 — 필드(main)와 같은 연출, 붉은색.
	if is_instance_valid(player):
		var number: Label3D = DAMAGE_NUMBER_SCRIPT_RUNTIME.acquire(self)
		if number == null:
			number = DAMAGE_NUMBER_SCRIPT_RUNTIME.new() as Label3D
			add_child(number)
		number.call(
			"setup", applied_damage, false, FONT,
			player.global_position + Vector3(0, 2.05, 0),
			Vector3.RIGHT, randf_range(-0.3, 0.3), "hostile"
		)
	# 필드(main.take_damage)와 같은 규칙 — 경직·히트스톱은 없고, 화면 흔들림과
	# 진동으로만 알린다. 흔들림 상한도 필드와 같은 0.24(조준이 죽지 않게).
	camera_shake_time = maxf(camera_shake_time, 0.2)
	var hit_feedback := clampf(float(accessibility_settings.hit_feedback_intensity), 0.0, 1.0)
	camera_shake_strength = maxf(
		camera_shake_strength,
		minf(0.24, (0.1 + float(applied_damage) * 0.006) * hit_feedback)
	)
	if DisplayServer.is_touchscreen_available() and bool(accessibility_settings.vibration_enabled):
		Input.vibrate_handheld(35)
	_show_status("피격 -%d · 체력 %d" % [applied_damage, GameState.player_health])
	if GameState.player_health <= 0:
		_begin_player_death_sequence()


# ── 건물 내부 사망 ────────────────────────────────────────────
# 예전에는 여기서 세 가지가 동시에 어긋나 있었다.
#   ① 게임오버 화면이 없어 죽은 사실도 잃은 것도 화면에 안 떴다.
#   ② store_carried_raid_loot_for_recovery를 써서 시큐어 슬롯이 통째로 무시됐다.
#   ③ register_shelter_return()을 인자 없이 불러 사망이 '생환'으로 집계됐다
#      (survived_return_count 증가 + 생환 전용 서사 해금).
# 이제 필드(main.gd)의 사망 시퀀스와 같은 경로를 탄다.
func _begin_player_death_sequence() -> void:
	if player_death_sequence_active:
		return
	player_death_sequence_active = true
	# 시체는 건물 좌표가 아니라 건물 입구(필드 복귀 지점)에 남긴다 —
	# 회수 판은 필드에서 열리고, 건물 내부 좌표는 다음 판에 재현되지 않는다.
	var corpse_loot: Dictionary = RAID_LOSS_MANAGER.store_death_corpse(
		BuildingRunState.return_position
	)
	_clear_carried_inventory_after_death()
	fire_button_held = false
	mouse_fire_held = false
	laser_aim_held = false
	touch_vector = Vector2.ZERO
	_release_mobile_held_actions()
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
	game_over_screen.present({
		"survival_time": _format_building_survival_time(),
		"kills": building_run_kills,
		"damage_text": "-",
		"source_name": last_damage_source_name,
		"weapon_name": "건물 내부 교전",
		"blocked": 0,
		"loss_value_text": GameState.format_compact_number(
			RAID_LOSS_MANAGER.get_total_value(corpse_loot)
		),
		"loot": corpse_loot,
		"lesson": _build_building_death_lesson(),
	})
	Engine.time_scale = 0.18
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(game_over_screen.panel, "modulate:a", 1.0, 0.55).set_delay(0.4)
	tween.tween_property(game_over_screen.fade, "color:a", 0.62, 0.85).set_delay(0.8)
	tween.set_parallel(false)
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void: game_over_screen.ready_to_continue = true)


func _clear_carried_inventory_after_death() -> void:
	GameState.clear_carried_raid_inventory_after_death()
	# 시큐어 슬롯이 지킨 것을 돌려준다 — 필드 사망과 동일하게.
	RAID_LOSS_MANAGER.restore_secure_items_after_death()
	GameState.fatigue = minf(fatigue + 18.0, FATIGUE_MAX)
	GameState.player_health = mini(82, GameState.get_max_health())
	GameState.returning_from_shelter = false
	GameState.world_time_hours = 9.0
	GameState.save_persistent_state()


func _format_building_survival_time() -> String:
	var elapsed_seconds := maxi(0, int((Time.get_ticks_msec() - building_run_started_msec) / 1000))
	return "%02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60]


func _build_building_death_lesson() -> String:
	if GameState.medkits > 0:
		return "치료 키트가 %d개 남아 있었습니다. 다음엔 더 일찍 쓰세요." % GameState.medkits
	if _get_reserve_ammo() <= 0:
		return "탄약이 바닥난 상태였습니다. 건물 안에서는 물러설 자리가 좁습니다."
	return "건물 안은 사방이 막혀 있습니다. 1층 출구까지의 거리를 항상 세어 두세요."


func _continue_after_death() -> void:
	if not game_over_screen.can_continue():
		return
	game_over_screen.mark_continue_started()
	BuildingRunState.active = false
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(game_over_screen.fade, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		Engine.time_scale = 1.0
		# 사망 귀환은 '살아 돌아온' 게 아니다 — 생환 전용 서사가 열리지 않게 한다.
		GameState.register_shelter_return(false)
		get_node("/root/SceneTransition").call(
			"transition_to",
			"res://scenes/shelter_interior.tscn"
		)
	)


func _build_environment() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#758087")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var outside_material := _material(Color.BLACK)
	outside_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_plane(self, "BlackOutside", Vector3(0, -0.2, 0), Vector2(180, 180), outside_material)
	camera = Camera3D.new()
	camera.name = "BuildingCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# 필드(main.gd)와 동일한 세팅 이식: 줌 배율(size 28)과 4배 후퇴 거리.
	# 직교 카메라는 거리와 무관하게 구도가 같고, 4배 뒤로 빼는 이유는 세로
	# 모드에서 화면 하단이 near 평면 뒤로 넘어가 검게 잘리는 것을 막기 위해서다.
	camera.size = BASE_CAMERA_SIZE
	camera.position = Vector3.ONE * (CAMERA_DIAGONAL_OFFSET * 4.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	# 카메라가 멀어지면 3D 오디오가 다 멀어진다 — 리스너는 예전 카메라 자리
	# (플레이어 근처)에 남겨 소리 거리감을 보존한다. 필드와 동일.
	var audio_listener := AudioListener3D.new()
	audio_listener.name = "InteriorAudioListener"
	camera.add_child(audio_listener)
	audio_listener.position = Vector3(
		0.0, 0.0, -(CAMERA_DIAGONAL_OFFSET * 3.0 * sqrt(3.0))
	)
	audio_listener.make_current()
	var light := DirectionalLight3D.new()
	light.name = "InteriorKeyLight"
	light.rotation_degrees = Vector3(-57, -42, 0)
	light.light_energy = 1.05
	light.shadow_enabled = true
	add_child(light)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "BuildingPlayer"
	player.add_to_group("player")
	player.position = Vector3(0, 0.78, 0)
	player.collision_layer = COLLISION_PROFILES.PLAYER_LAYER
	player.collision_mask = COLLISION_PROFILES.PLAYER_MOVEMENT_MASK
	add_child(player)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.3
	collision.shape = shape
	player.add_child(collision)
	survivor = AnimatedSprite3D.new()
	survivor.name = "Survivor"
	survivor.position = Vector3(0, 0.3, 0)
	survivor.pixel_size = 0.0098
	survivor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	survivor.shaded = false
	survivor.transparent = true
	survivor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	survivor.no_depth_test = true
	survivor.render_priority = 127
	survivor.sprite_frames = _create_cat_frames()
	player.add_child(survivor)
	_play_animation()


func _setup_weapon() -> void:
	var weapon_id := str(GameState.get("equipped_weapon_id"))
	if weapon_id.is_empty(): weapon_id = "ak47"
	var mods: Array[String] = []
	var stored_mods = GameState.get("equipped_weapon_mods")
	if stored_mods is Array:
		for mod_id in stored_mods:
			mods.append(str(mod_id))
	var enhancement_level := int(GameState.get("weapon_level")) if GameState.get("weapon_level") != null else 0
	# 필드 main과 같은 단일 지점 — 훈련(장탄·장전)이 건물 안에서도 똑같이 먹힌다.
	weapon_stats = GameState.call("build_player_weapon_stats", weapon_id, mods, enhancement_level)


func _setup_weapon_visual() -> void:
	if weapon_sprite != null and is_instance_valid(weapon_sprite):
		weapon_sprite.queue_free()
	weapon_sprite = Sprite3D.new()
	weapon_sprite.name = "EquippedWeapon"
	var weapon_id := str(GameState.get("equipped_weapon_id"))
	if weapon_id.is_empty():
		weapon_id = "ak47"
	weapon_sprite.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
	weapon_sprite.pixel_size = WEAPON_VISUAL_CATALOG.get_world_pixel_size(weapon_id, 0.0018)
	weapon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_sprite.shaded = false
	weapon_sprite.transparent = true
	weapon_sprite.no_depth_test = true
	weapon_sprite.offset = Vector2(0, -24)
	player.add_child(weapon_sprite)
	_update_weapon_visual()


func _weapon_reveal_requested() -> bool:
	# 조준·사격·재장전 중에만 총이 보인다(필드·오프닝과 같은 규칙).
	if melee_attack_active:
		return false
	return laser_aim_held or mouse_fire_held or fire_button_held or weapon_reloading


func _update_weapon_reveal(delta: float) -> void:
	var alpha := weapon_reveal.update(
		delta,
		_has_equipped_firearm() and _weapon_reveal_requested()
	)
	if weapon_sprite == null:
		return
	weapon_sprite.modulate.a = alpha
	_update_weapon_visual()


func _update_weapon_visual() -> void:
	if weapon_sprite == null:
		return
	weapon_sprite.visible = (
		_has_equipped_firearm()
		and weapon_sprite.texture != null
		and not roll_active
		and not melee_attack_active
		and weapon_reveal.is_drawn()
	)
	if not weapon_sprite.visible:
		return
	var screen_vectors := {
		"n": Vector2(0, -1), "ne": Vector2(1, -1), "e": Vector2(1, 0), "se": Vector2(1, 1),
		"s": Vector2(0, 1), "sw": Vector2(-1, 1), "w": Vector2(-1, 0), "nw": Vector2(-1, -1),
	}
	var screen_direction: Vector2 = screen_vectors.get(facing, Vector2.DOWN)
	weapon_sprite.flip_h = screen_direction.x < -0.01
	var source_angle := PI if weapon_sprite.flip_h else 0.0
	weapon_sprite.rotation.z = wrapf(screen_direction.angle() - source_angle, -PI, PI)
	weapon_sprite.position = _get_facing_world_direction() * 0.34 + Vector3(0, 0.38, 0)
	weapon_sprite.render_priority = 0 if facing in ["n", "ne", "nw"] else 2



func _build_interface() -> void:
	var touch_enabled := DisplayServer.is_touchscreen_available()
	var canvas := CanvasLayer.new()
	# 필드와 같은 이름 "HUD" — RaidHud 모듈(토스트 스택)이 이 이름으로 찾는다.
	canvas.name = "HUD"
	canvas.layer = 3
	add_child(canvas)
	# 필드 HUD의 토스트 스택을 그대로 공유 — 같은 위치·같은 스타일의 알림.
	var raid_hud_script := load(RAID_HUD_PATH) as GDScript
	if raid_hud_script != null and raid_hud_script.can_instantiate():
		hud = raid_hud_script.new()
		hud.attach(self)
		hud._build_toast_stack()
	aim_reticle = AIM_RETICLE_SCRIPT.new()
	aim_reticle.name = "AimReticle"
	canvas.add_child(aim_reticle)
	aim_reticle.visible = not DisplayServer.is_touchscreen_available()
	inventory_ui = INVENTORY_UI_SCRIPT.new()
	inventory_ui.name = "InventoryUI"
	canvas.add_child(inventory_ui)
	inventory_ui.call("setup", FONT, WEAPON_VISUAL_CATALOG.get_weapon_texture(str(GameState.equipped_weapon_id)), AMMO_762_TEXTURE, {
		"rubber_gasket": RUBBER_GASKET_TEXTURE,
		"scope_lens": SCOPE_LENS_TEXTURE,
		"magazine_spring": MAGAZINE_SPRING_TEXTURE,
	}, WEAPON_VISUAL_CATALOG.get_inventory_textures())
	inventory_ui.connect("weapon_mods_changed", _on_inventory_weapon_mods_changed)
	inventory_ui.connect("weapon_equipped", _on_inventory_weapon_equipped)
	inventory_ui.connect("weapon_unequipped", _on_inventory_weapon_unequipped)
	inventory_ui.connect("open_state_changed", _on_inventory_open_state_changed)
	var panel := PanelContainer.new()
	panel.name = "VitalsPanel"
	panel.position = Vector2(18, 18)
	panel.size = Vector2(332, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.022, 0.9)
	style.border_color = Color(0.42, 0.55, 0.52, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	floor_label = Label.new()
	floor_label.add_theme_font_override("font", FONT)
	floor_label.add_theme_font_size_override("font_size", 18)
	box.add_child(floor_label)
	floor_label.text = ""
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(290, 10)
	health_bar.max_value = 100
	health_bar.show_percentage = false
	box.add_child(health_bar)
	ammo_label = Label.new()
	ammo_label.add_theme_font_override("font", FONT)
	ammo_label.add_theme_font_size_override("font_size", 14)
	ammo_label.modulate = Color("#d6d2bd")
	box.add_child(ammo_label)
	var help := Label.new()
	help.text = "WASD 이동 · SPACE 대시 · 좌클릭 근접 · 우클릭 조준+좌클릭 사격 · R 재장전 · F 상호작용"
	help.add_theme_font_override("font", FONT)
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color("#aeb7b3")
	help.visible = false
	box.add_child(help)
	building_objective_panel = PanelContainer.new()
	building_objective_panel.position = Vector2(18, 18)
	building_objective_panel.size = Vector2(334, 72)
	building_objective_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.015, 0.02, 0.022, 0.9), Color(0.42, 0.55, 0.52, 0.65)))
	canvas.add_child(building_objective_panel)
	building_objective_label = Label.new()
	building_objective_label.text = "  건물 수색\n  · 적을 제압하고 물자를 회수한다"
	building_objective_label.add_theme_font_override("font", FONT)
	building_objective_label.add_theme_font_size_override("font_size", 15)
	building_objective_label.modulate = Color(0.92, 0.76, 0.32)
	building_objective_panel.add_child(building_objective_label)
	building_info_label = Label.new()
	building_info_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	building_info_label.position = Vector2(-330, 18)
	building_info_label.size = Vector2(308, 82)
	building_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	building_info_label.add_theme_font_override("font", FONT)
	building_info_label.add_theme_font_size_override("font_size", 15)
	building_info_label.modulate = Color("#d6d2bd")
	canvas.add_child(building_info_label)
	# 필드 유틸리티 버튼과 같은 원형 프리셋(HudStyle.style_mobile_action).
	medkit_button = Button.new()
	medkit_button.name = "MedkitButton"
	medkit_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	medkit_button.position = Vector2(22, -96)
	medkit_button.size = Vector2(98, 76)
	medkit_button.icon = UI_ICONS.get_icon("medkit", 26, Color("#dbe8df"))
	medkit_button.z_index = 90
	HudStyle.style_mobile_action(medkit_button, HudStyle.GREEN, 26)
	if not touch_enabled:
		medkit_button.pressed.connect(_use_quick_medkit)
	canvas.add_child(medkit_button)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-250, -82)
	prompt_label.size = Vector2(500, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", FONT)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.modulate = Color("#efe1a4")
	canvas.add_child(prompt_label)
	_build_shared_combat_hud(canvas)
	_build_floor_clear_banner(canvas)
	# 우하단 터치 버튼: 필드(raid_hud/main)와 같은 원형 프리셋·크기(80x80)·배치.
	fire_button = Button.new()
	fire_button.name = "FireButton"
	fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.position = Vector2(-108, -104)
	fire_button.size = Vector2(80, 80)
	fire_button.text = "발사"
	fire_button.icon = UI_ICONS.get_icon("weapon", 36, Color("#ffd29a"))
	fire_button.z_index = 90
	HudStyle.style_mobile_action(fire_button, Color("#e08a58"), 38, true, HudStyle.TYPE_HEADING)
	if not touch_enabled:
		fire_button.button_down.connect(func():
			fire_button_held = true
			_fire_at_nearest_enemy()
		)
		fire_button.button_up.connect(func(): fire_button_held = false)
	canvas.add_child(fire_button)
	_build_elevator_menu(canvas)
	melee_button = Button.new()
	melee_button.name = "MeleeButton"
	melee_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	melee_button.position = Vector2(-198, -104)
	melee_button.size = Vector2(80, 80)
	melee_button.text = "근접"
	melee_button.icon = UI_ICONS.get_icon("melee", 34, Color("#dbe9df"))
	melee_button.z_index = 90
	HudStyle.style_mobile_action(melee_button, HudStyle.LINE_FOCUS, 36, false, HudStyle.TYPE_BODY)
	if not touch_enabled:
		melee_button.pressed.connect(_try_melee_forward)
	canvas.add_child(melee_button)
	interact_button = Button.new()
	interact_button.name = "InteractButton"
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.position = Vector2(-378, -104)
	interact_button.size = Vector2(80, 80)
	interact_button.text = "상호작용"
	interact_button.icon = UI_ICONS.get_icon("interact", 26, Color("#c7e2d4"))
	interact_button.z_index = 90
	HudStyle.style_mobile_action(interact_button, HudStyle.LINE_FOCUS, 26)
	if not touch_enabled:
		interact_button.pressed.connect(_interact)
	canvas.add_child(interact_button)
	dash_button = Button.new()
	dash_button.name = "DashButton"
	dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_button.position = Vector2(-288, -104)
	dash_button.size = Vector2(80, 80)
	dash_button.text = "회피"
	dash_button.icon = UI_ICONS.get_icon("dash", 34, HudStyle.TEXT)
	dash_button.z_index = 90
	HudStyle.style_mobile_action(dash_button, Color("#82a8b8"), 36, false, HudStyle.TYPE_BODY)
	if not touch_enabled:
		dash_button.pressed.connect(_try_start_roll)
	canvas.add_child(dash_button)
	reload_button = Button.new()
	reload_button.name = "ReloadButton"
	reload_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_button.position = Vector2(-108, -194)
	reload_button.size = Vector2(80, 80)
	reload_button.text = "장전"
	reload_button.icon = UI_ICONS.get_icon("reload", 26, Color("#dbe8df"))
	reload_button.z_index = 90
	HudStyle.style_mobile_action(reload_button, HudStyle.LINE_FOCUS, 26)
	if not touch_enabled:
		reload_button.pressed.connect(_start_reload)
	canvas.add_child(reload_button)
	flashlight_button = Button.new()
	flashlight_button.name = "FlashlightButton"
	flashlight_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	flashlight_button.position = Vector2(-198, -194)
	flashlight_button.size = Vector2(80, 80)
	flashlight_button.text = "후레쉬"
	flashlight_button.icon = UI_ICONS.get_icon("flashlight", 26, Color("#e8df9f"))
	flashlight_button.toggle_mode = true
	flashlight_button.z_index = 90
	HudStyle.style_mobile_action(flashlight_button, HudStyle.LINE_FOCUS, 26)
	if not touch_enabled:
		flashlight_button.toggled.connect(_on_flashlight_toggled)
	canvas.add_child(flashlight_button)
	touch_stick = Panel.new()
	touch_stick.name = "TouchStick"
	touch_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	touch_stick.position = Vector2(34, -160)
	touch_stick.size = Vector2(120, 120)
	touch_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stick_style := StyleBoxFlat.new()
	stick_style.bg_color = Color(0.1, 0.13, 0.14, 0.38)
	stick_style.border_color = Color(0.5, 0.62, 0.6, 0.42)
	stick_style.set_border_width_all(2)
	stick_style.set_corner_radius_all(60)
	touch_stick.add_theme_stylebox_override("panel", stick_style)
	canvas.add_child(touch_stick)
	touch_knob = ColorRect.new()
	touch_knob.position = Vector2(40, 40)
	touch_knob.size = Vector2(40, 40)
	touch_knob.color = Color(0.72, 0.78, 0.75, 0.58)
	touch_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_stick.add_child(touch_knob)
	touch_stick.visible = touch_enabled
	for mobile_control: Control in [
		fire_button,
		melee_button,
		interact_button,
		dash_button,
		reload_button,
		flashlight_button,
	]:
		mobile_control.visible = touch_enabled
	_build_fatigue_panel(canvas)
	_update_health()
	_update_ammo_label()
	_update_fatigue_ui()
	_update_medkit_button()


const ROLL_COOLDOWN_INDICATOR_SCRIPT := preload("res://scripts/roll_cooldown_indicator.gd")
# damage_number는 오토로드 식별자를 안 쓰므로(런타임 조회) preload가 콜드스타트 안전.
const DAMAGE_NUMBER_SCRIPT_RUNTIME := preload("res://scripts/damage_number.gd")
var roll_cooldown_indicator: Control


func _build_shared_combat_hud(canvas: CanvasLayer) -> void:
	# 필드와 같은 스태미나 링 — 건물에서만 대시 게이지가 없어 감으로 굴러야 했다.
	roll_cooldown_indicator = ROLL_COOLDOWN_INDICATOR_SCRIPT.new() as Control
	roll_cooldown_indicator.name = "BuildingRollCooldownIndicator"
	canvas.add_child(roll_cooldown_indicator)
	player_world_health_bar = Control.new()
	player_world_health_bar.name = "PlayerWorldHealthBar"
	player_world_health_bar.size = Vector2(48, 7)
	player_world_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_world_health_bar.z_index = 40
	var health_background_panel := Panel.new()
	health_background_panel.size = Vector2(48, 7)
	health_background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color(0.018, 0.022, 0.024, 0.84)
	health_background.border_color = Color(0.82, 0.86, 0.8, 0.38)
	health_background.set_border_width_all(1)
	health_background.set_corner_radius_all(4)
	health_background.anti_aliasing = true
	health_background_panel.add_theme_stylebox_override("panel", health_background)
	player_world_health_bar.add_child(health_background_panel)
	player_world_health_fill = Panel.new()
	player_world_health_fill.position = Vector2(1, 1)
	player_world_health_fill.size = Vector2(46, 5)
	player_world_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_health_fill_style = StyleBoxFlat.new()
	player_health_fill_style.bg_color = Color(0.28, 0.86, 0.48, 0.96)
	player_health_fill_style.set_corner_radius_all(3)
	player_health_fill_style.anti_aliasing = true
	player_world_health_fill.add_theme_stylebox_override("panel", player_health_fill_style)
	player_world_health_bar.add_child(player_world_health_fill)
	canvas.add_child(player_world_health_bar)

	# 필드(raid_hud.gd)의 컴팩트 무기 카드와 같은 수치·프리셋: 204x56,
	# 작은 총 그림 + [이름·탄약명 / 잔탄 통합 표기] 2줄. 내구도는 그림 색으로.
	equipment_panel = PanelContainer.new()
	equipment_panel.name = "EquipmentPanel"
	equipment_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	equipment_panel.offset_left = -224
	equipment_panel.offset_top = -180
	equipment_panel.offset_right = -20
	equipment_panel.offset_bottom = -124
	equipment_panel.z_index = 30
	equipment_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK, Color("#8da997"), 7)
	)
	canvas.add_child(equipment_panel)
	var equipment_margin := MarginContainer.new()
	equipment_margin.add_theme_constant_override("margin_left", 10)
	equipment_margin.add_theme_constant_override("margin_top", 6)
	equipment_margin.add_theme_constant_override("margin_right", 12)
	equipment_margin.add_theme_constant_override("margin_bottom", 6)
	equipment_panel.add_child(equipment_margin)
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 10)
	equipment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment_margin.add_child(equipment_row)
	equipment_weapon_image = TextureRect.new()
	equipment_weapon_image.custom_minimum_size = Vector2(52, 36)
	equipment_weapon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_weapon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_weapon_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equipment_row.add_child(equipment_weapon_image)
	var weapon_text_box := VBoxContainer.new()
	weapon_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weapon_text_box.add_theme_constant_override("separation", 1)
	equipment_row.add_child(weapon_text_box)
	# 1줄: 총 이름(왼쪽) + 탄약명(오른쪽, 흐리게) — 필드와 동일.
	var weapon_header := HBoxContainer.new()
	weapon_header.add_theme_constant_override("separation", 6)
	weapon_text_box.add_child(weapon_header)
	equipment_label = Label.new()
	equipment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_label.clip_text = true
	equipment_label.add_theme_font_override("font", FONT)
	equipment_label.add_theme_font_size_override("font_size", 12)
	equipment_label.add_theme_color_override("font_color", Color("#c6d4cb"))
	weapon_header.add_child(equipment_label)
	equipment_reserve_ammo_label = Label.new()
	equipment_reserve_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	equipment_reserve_ammo_label.add_theme_font_override("font", FONT)
	equipment_reserve_ammo_label.add_theme_font_size_override("font_size", 11)
	equipment_reserve_ammo_label.add_theme_color_override("font_color", Color("#8fa39a"))
	weapon_header.add_child(equipment_reserve_ammo_label)
	# 2줄: 잔탄/탄창 · 예비탄 통합 표기.
	equipment_ammo_label = Label.new()
	equipment_ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_ammo_label.add_theme_font_override("font", FONT)
	equipment_ammo_label.add_theme_font_size_override("font_size", 19)
	equipment_ammo_label.add_theme_color_override("font_color", HudStyle.GOLD_TEXT)
	weapon_text_box.add_child(equipment_ammo_label)
	equipment_condition_label = Label.new()
	equipment_condition_label.clip_text = true
	equipment_condition_label.add_theme_font_override("font", FONT)
	equipment_condition_label.add_theme_font_size_override("font_size", 11)
	equipment_condition_label.add_theme_color_override("font_color", Color("#9fb0a7"))
	weapon_text_box.add_child(equipment_condition_label)
	equipment_reload_bar = ProgressBar.new()
	equipment_reload_bar.custom_minimum_size = Vector2(0, 5)
	equipment_reload_bar.max_value = 1.0
	equipment_reload_bar.show_percentage = false
	equipment_reload_bar.add_theme_stylebox_override(
		"background",
		HudStyle.panel(Color("#171d1b"), Color("#3e4944"), 4)
	)
	equipment_reload_bar.add_theme_stylebox_override(
		"fill",
		HudStyle.panel(Color("#d6b653"), Color("#f0d77d"), 4)
	)
	weapon_text_box.add_child(equipment_reload_bar)


func _build_floor_clear_banner(canvas: CanvasLayer) -> void:
	floor_clear_banner = PanelContainer.new()
	floor_clear_banner.name = "FloorClearBanner"
	floor_clear_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	floor_clear_banner.offset_left = -260
	floor_clear_banner.offset_top = 82
	floor_clear_banner.offset_right = 260
	floor_clear_banner.offset_bottom = 160
	floor_clear_banner.z_index = 140
	floor_clear_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_clear_banner.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.012, 0.024, 0.021, 0.97), Color("#74d8b5"), 8)
	)
	floor_clear_banner.visible = false
	canvas.add_child(floor_clear_banner)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	floor_clear_banner.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.texture = UI_ICONS.get_icon("secure", 48, Color("#89e8c4"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	floor_clear_title = Label.new()
	floor_clear_title.add_theme_font_override("font", FONT)
	floor_clear_title.add_theme_font_size_override("font_size", 22)
	floor_clear_title.add_theme_color_override("font_color", Color("#f3d879"))
	text_box.add_child(floor_clear_title)
	floor_clear_detail = Label.new()
	floor_clear_detail.add_theme_font_override("font", FONT)
	floor_clear_detail.add_theme_font_size_override("font_size", 14)
	floor_clear_detail.add_theme_color_override("font_color", Color("#b9cec4"))
	text_box.add_child(floor_clear_detail)


func _build_fatigue_panel(canvas: CanvasLayer) -> void:
	# 필드(raid_hud.gd)의 피로도 패널과 같은 구성·수치: 좌상단, 아이콘 +
	# "피로도" 헤더 + 상태 퍼센트 + 190x7 바, HudStyle 색.
	fatigue_panel = PanelContainer.new()
	fatigue_panel.name = "FatiguePanel"
	fatigue_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fatigue_panel.offset_left = 18
	fatigue_panel.offset_top = 214
	fatigue_panel.offset_right = 280
	fatigue_panel.offset_bottom = 276
	fatigue_panel.add_theme_stylebox_override(
		"panel",
		HudStyle.panel(HudStyle.INK, Color("#60766a"), 7)
	)
	canvas.add_child(fatigue_panel)
	var fatigue_margin := MarginContainer.new()
	fatigue_margin.add_theme_constant_override("margin_left", 10)
	fatigue_margin.add_theme_constant_override("margin_top", 7)
	fatigue_margin.add_theme_constant_override("margin_right", 10)
	fatigue_margin.add_theme_constant_override("margin_bottom", 7)
	fatigue_panel.add_child(fatigue_margin)
	var fatigue_row := HBoxContainer.new()
	fatigue_row.add_theme_constant_override("separation", 9)
	fatigue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fatigue_margin.add_child(fatigue_row)
	var fatigue_icon := TextureRect.new()
	fatigue_icon.name = "FatigueIcon"
	fatigue_icon.custom_minimum_size = Vector2(28, 28)
	fatigue_icon.texture = UI_ICONS.get_icon("stamina", 32, Color("#e3c069"))
	fatigue_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fatigue_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fatigue_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fatigue_row.add_child(fatigue_icon)
	var fatigue_box := VBoxContainer.new()
	fatigue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fatigue_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fatigue_box.add_theme_constant_override("separation", 3)
	fatigue_row.add_child(fatigue_box)
	var fatigue_header := HBoxContainer.new()
	fatigue_header.add_theme_constant_override("separation", 6)
	fatigue_box.add_child(fatigue_header)
	var fatigue_name := Label.new()
	fatigue_name.text = "피로도"
	fatigue_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fatigue_name.add_theme_font_override("font", FONT)
	fatigue_name.add_theme_font_size_override("font_size", 12)
	fatigue_name.add_theme_color_override("font_color", Color("#9fb4a9"))
	fatigue_header.add_child(fatigue_name)
	fatigue_label = Label.new()
	fatigue_label.text = "0%"
	fatigue_label.add_theme_font_override("font", FONT)
	fatigue_label.add_theme_font_size_override("font_size", 12)
	fatigue_label.add_theme_color_override("font_color", Color("#8fc7a8"))
	fatigue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fatigue_header.add_child(fatigue_label)
	fatigue_bar = ProgressBar.new()
	fatigue_bar.custom_minimum_size = Vector2(190, 7)
	fatigue_bar.max_value = FATIGUE_MAX
	fatigue_bar.show_percentage = false
	fatigue_bar.add_theme_stylebox_override("background", HudStyle.panel(Color("#17201d"), Color("#32443c"), 4))
	fatigue_fill_style = HudStyle.panel(Color("#78b993"), Color("#a7d6b9"), 4)
	fatigue_bar.add_theme_stylebox_override("fill", fatigue_fill_style)
	fatigue_box.add_child(fatigue_bar)


func _make_panel_style(background: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _on_inventory_weapon_mods_changed() -> void:
	_setup_weapon()
	_setup_weapon_visual()
	_update_ammo_label()


func _on_inventory_weapon_equipped(weapon_id: String) -> void:
	if _has_equipped_firearm() and weapon_id == str(GameState.equipped_weapon_id):
		return
	var previous_ammo_id := str(GameState.equipped_ammo_id)
	if _has_equipped_firearm() and int(GameState.magazine_ammo) > 0 and not previous_ammo_id.is_empty():
		GameState.set_ammo_count(previous_ammo_id, GameState.get_ammo_count(previous_ammo_id) + int(GameState.magazine_ammo))
	if not GameState.equip_weapon(weapon_id):
		return
	_setup_weapon()
	_setup_weapon_visual()
	_update_ammo_label()
	GameState.save_persistent_state()


func _on_inventory_weapon_unequipped() -> void:
	if not _has_equipped_firearm():
		return
	var ammo_id := str(GameState.equipped_ammo_id)
	if int(GameState.magazine_ammo) > 0 and not ammo_id.is_empty():
		GameState.set_ammo_count(ammo_id, GameState.get_ammo_count(ammo_id) + int(GameState.magazine_ammo))
	GameState.magazine_ammo = 0
	GameState.reserve_ammo = GameState.get_ammo_count(ammo_id)
	GameState.unequip_weapon()
	weapon_reloading = false
	laser_aim_held = false
	_update_weapon_visual()
	_update_ammo_label()
	GameState.save_persistent_state()


func _build_elevator_menu(canvas: CanvasLayer) -> void:
	elevator_menu = PanelContainer.new()
	elevator_menu.name = "ElevatorFloorMenu"
	elevator_menu.set_anchors_preset(Control.PRESET_CENTER)
	elevator_menu.position = Vector2(-155, -120)
	elevator_menu.size = Vector2(310, 240)
	elevator_menu.add_theme_stylebox_override("panel", _make_panel_style(Color(0.012, 0.018, 0.02, 0.97), Color("#9b8a5d"), 6))
	elevator_menu.visible = false
	canvas.add_child(elevator_menu)


func _show_elevator_menu() -> void:
	if elevator_menu == null:
		return
	for child in elevator_menu.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	elevator_menu.add_child(box)
	var title := Label.new()
	title.text = "엘리베이터 · 이동할 층 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var current_floor := int(BuildingRunState.current_floor)
	if current_floor < int(BuildingRunState.max_floors):
		_add_elevator_floor_button(box, "윗층 · %d층" % (current_floor + 1), current_floor + 1)
	if current_floor > 1:
		_add_elevator_floor_button(box, "아랫층 · %d층" % (current_floor - 1), current_floor - 1)
	if current_floor > 2:
		_add_elevator_floor_button(box, "1층 로비", 1)
	var cancel := Button.new()
	cancel.text = "취소"
	cancel.icon = UI_ICONS.get_icon("close", 28, Color("#dce6df"))
	cancel.expand_icon = true
	cancel.add_theme_font_override("font", FONT)
	cancel.pressed.connect(func() -> void: elevator_menu.visible = false)
	box.add_child(cancel)
	elevator_menu.visible = true


func _add_elevator_floor_button(parent: VBoxContainer, label_text: String, target_floor: int) -> void:
	var button := Button.new()
	button.text = label_text
	button.icon = UI_ICONS.get_icon("up" if target_floor > int(BuildingRunState.current_floor) else "down", 30, Color("#d8e5de"))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(280, 42)
	button.add_theme_font_override("font", FONT)
	button.pressed.connect(func() -> void:
		elevator_menu.visible = false
		var arrival := "from_below" if target_floor > int(BuildingRunState.current_floor) else "from_above"
		_load_floor(target_floor, arrival)
	)
	parent.add_child(button)


func _build_visibility_fog() -> void:
	var fog_layer := CanvasLayer.new()
	fog_layer.name = "VisibilityFog"
	fog_layer.layer = 2
	add_child(fog_layer)
	var darkness := ColorRect.new()
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_layer.add_child(darkness)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 player_screen = vec2(640.0, 360.0);
uniform vec2 facing_screen_direction = vec2(0.0, -1.0);
uniform float inner_radius = 360.0;
uniform float outer_radius = 500.0;
uniform float near_radius = 100.0;
uniform float fan_cos = 0.16;
uniform float darkness = 0.91;
uniform float aim_expanded = 0.0;
uniform float circle_radius = 160.0;
void fragment() {
	vec2 pixel_position = UV * viewport_size;
	vec2 to_pixel = pixel_position - player_screen;
	float distance_from_player = length(to_pixel);
	vec2 pixel_direction = distance_from_player > 0.001 ? normalize(to_pixel) : facing_screen_direction;
	float alignment = dot(pixel_direction, normalize(facing_screen_direction));
	float near_visibility = 1.0 - smoothstep(near_radius * 0.72, near_radius, distance_from_player);
	float circle_visibility = 1.0 - smoothstep(circle_radius * 0.78, circle_radius, distance_from_player);
	float fan_visibility = smoothstep(fan_cos - 0.11, fan_cos + 0.08, alignment);
	float range_visibility = 1.0 - smoothstep(inner_radius, outer_radius, distance_from_player);
	float relaxed_visibility = max(near_visibility, circle_visibility);
	float aimed_visibility = max(relaxed_visibility, fan_visibility * range_visibility);
	float visibility = mix(relaxed_visibility, aimed_visibility, aim_expanded);
	float fog_alpha = mix(darkness, 0.035, visibility);
	COLOR = vec4(0.008, 0.012, 0.015, fog_alpha);
}
"""
	visibility_material = ShaderMaterial.new()
	visibility_material.shader = shader
	darkness.material = visibility_material


func _update_visibility_fog() -> void:
	if visibility_material == null or camera == null or player == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var player_screen := camera.unproject_position(player.global_position)
	var aim_direction := _get_facing_world_direction()
	if laser_aim_held:
		var mouse_world := _screen_point_to_world(get_viewport().get_mouse_position())
		if is_finite(mouse_world.x):
			aim_direction = (mouse_world - player.global_position).normalized()
	var facing_screen := camera.unproject_position(player.global_position + aim_direction * 5.0)
	var facing_screen_direction := (facing_screen - player_screen).normalized()
	visibility_material.set_shader_parameter("viewport_size", viewport_size)
	visibility_material.set_shader_parameter("player_screen", player_screen)
	visibility_material.set_shader_parameter("facing_screen_direction", facing_screen_direction)
	visibility_material.set_shader_parameter("inner_radius", 390.0)
	visibility_material.set_shader_parameter("outer_radius", 520.0)
	visibility_material.set_shader_parameter("near_radius", 96.0)
	visibility_material.set_shader_parameter("fan_cos", 0.16)
	visibility_material.set_shader_parameter("darkness", 0.91)
	visibility_material.set_shader_parameter("aim_expanded", 1.0 if laser_aim_held else 0.0)
	visibility_material.set_shader_parameter("circle_radius", 170.0)


func _update_enemy_visibility() -> void:
	if camera == null or player == null:
		return
	var player_screen := camera.unproject_position(player.global_position)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_screen := camera.unproject_position(enemy.global_position)
		var distance := player_screen.distance_to(enemy_screen)
		var visible_radius := 520.0 if laser_aim_held else 180.0
		enemy.visible = distance <= visible_radius


func _load_floor(floor_number: int, arrival: String) -> void:
	loading_floor = true
	floor_clear_announced = BuildingRunState.is_floor_cleared(floor_number)
	current_interactable = null
	prompt_label.text = ""
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	enemies.clear()
	if floor_root != null:
		floor_root.queue_free()
		await get_tree().process_frame
	floor_root = Node3D.new()
	floor_root.name = "Floor%02dModules" % floor_number
	floor_root.add_to_group("building_floor_root")
	floor_root.set_meta("floor_number", floor_number)
	floor_root.set_meta("floor_seed", BuildingRunState.get_floor_seed(floor_number))
	add_child(floor_root)
	BuildingRunState.current_floor = floor_number
	var random := RandomNumberGenerator.new()
	random.seed = BuildingRunState.get_floor_seed(floor_number)
	_generate_floor_layout(random)
	_build_room_modules(random)
	_build_corridors()
	_build_transitions()
	_spawn_floor_loot(random)
	_spawn_floor_enemies(random)
	player.position = _get_arrival_position(arrival)
	camera_focus = Vector3(player.position.x, 0, player.position.z)
	var building_name := _get_building_display_name()
	building_info_label.text = "%s · %d / %d층\n경계 중\n실내 수색 구역" % [building_name, floor_number, BuildingRunState.max_floors]
	if building_objective_label != null:
		building_objective_label.text = "  %s 수색\n  · 적을 제압하고 물자를 회수한다" % building_name
	_show_status("%d층 진입 · 배치 시드 %d" % [floor_number, BuildingRunState.get_floor_seed(floor_number)])
	loading_floor = false


func _generate_floor_layout(random: RandomNumberGenerator) -> void:
	floor_cells.clear()
	floor_connections.clear()
	floor_cells.append(Vector2i.ZERO)
	var target_count := clampi(7 + int(BuildingRunState.current_floor) / 2, 7, 10)
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var attempts := 0
	while floor_cells.size() < target_count and attempts < 300:
		attempts += 1
		var parent_index := random.randi_range(0, floor_cells.size() - 1)
		var direction: Vector2i = directions[random.randi_range(0, directions.size() - 1)]
		var candidate := floor_cells[parent_index] + direction
		if absi(candidate.x) > 3 or absi(candidate.y) > 3 or floor_cells.has(candidate):
			continue
		var child_index := floor_cells.size()
		floor_cells.append(candidate)
		floor_connections.append({"a": parent_index, "b": child_index})
	floor_root.set_meta("room_cells", floor_cells)
	floor_root.set_meta("room_connections", floor_connections)


func _build_room_modules(random: RandomNumberGenerator) -> void:
	var door_map: Dictionary = {}
	for index in floor_cells.size():
		door_map[index] = [] as Array[String]
	for connection in floor_connections:
		var a := int(connection["a"])
		var b := int(connection["b"])
		var delta: Vector2i = floor_cells[b] - floor_cells[a]
		(door_map[a] as Array[String]).append(_door_side_for_delta(delta))
		(door_map[b] as Array[String]).append(_door_side_for_delta(-delta))
	for index in floor_cells.size():
		var room := ROOM_MODULE_SCENE.instantiate() as Node3D
		var type_name: String = ROOM_TYPES[random.randi_range(0, ROOM_TYPES.size() - 1)]
		if index == 0: type_name = "open_office"
		room.call("configure", index, ROOM_SIZE, type_name, random.randi(), door_map[index])
		room.name = "OfficeZone%02d_%s" % [index + 1, type_name]
		room.position = _cell_to_world(floor_cells[index])
		floor_root.add_child(room)
		var label := Label3D.new()
		label.name = "ZoneLabel"
		label.position = Vector3(0, 2.95, 0)
		label.text = "%02d · %s" % [index + 1, _room_display_name(type_name)]
		label.font = FONT
		label.font_size = 28
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		room.add_child(label)


func _build_corridors() -> void:
	for index in floor_connections.size():
		var connection := floor_connections[index]
		var a := int(connection["a"])
		var b := int(connection["b"])
		var from := _cell_to_world(floor_cells[a])
		var to := _cell_to_world(floor_cells[b])
		var delta := floor_cells[b] - floor_cells[a]
		var center := (from + to) * 0.5
		if delta.x != 0:
			var length := absf(to.x - from.x) - ROOM_SIZE.x
			_build_horizontal_corridor(index, center, length)
		else:
			var length := absf(to.z - from.z) - ROOM_SIZE.y
			_build_vertical_corridor(index, center, length)


func _build_horizontal_corridor(index: int, center: Vector3, length: float) -> void:
	_build_corridor_floor_tiles(index, center, length + 0.35, true)
	var wall_material := _texture_material(WALL_TEXTURE_PATH, Vector3(maxf(1.0, length / 4.0), 1.0, 1.0))
	_add_static_box_material(floor_root, "CorridorH%dNorth" % index, center + Vector3(0, 1.4, -CORRIDOR_WIDTH * 0.5), Vector3(length + 0.3, 2.8, 0.24), wall_material)
	_add_static_box_material(floor_root, "CorridorH%dSouth" % index, center + Vector3(0, 0.36, CORRIDOR_WIDTH * 0.5), Vector3(length + 0.3, 0.72, 0.24), wall_material)


func _build_vertical_corridor(index: int, center: Vector3, length: float) -> void:
	_build_corridor_floor_tiles(index, center, length + 0.35, false)
	var wall_material := _texture_material(WALL_TEXTURE_PATH, Vector3(maxf(1.0, length / 4.0), 1.0, 1.0))
	_add_static_box_material(floor_root, "CorridorV%dWest" % index, center + Vector3(-CORRIDOR_WIDTH * 0.5, 1.4, 0), Vector3(0.24, 2.8, length + 0.3), wall_material)
	_add_static_box_material(floor_root, "CorridorV%dEast" % index, center + Vector3(CORRIDOR_WIDTH * 0.5, 0.36, 0), Vector3(0.24, 0.72, length + 0.3), wall_material)


func _build_corridor_floor_tiles(index: int, center: Vector3, length: float, horizontal: bool) -> void:
	var tile_length := 4.0
	var tile_count := ceili(length / tile_length)
	for tile_index in tile_count:
		var piece_length := minf(tile_length, length - float(tile_index) * tile_length)
		var axis_offset := -length * 0.5 + float(tile_index) * tile_length + piece_length * 0.5
		var position := center + (Vector3(axis_offset, 0.02, 0) if horizontal else Vector3(0, 0.02, axis_offset))
		var size := Vector2(piece_length, CORRIDOR_WIDTH) if horizontal else Vector2(CORRIDOR_WIDTH, piece_length)
		var material := _texture_material(CORRIDOR_TEXTURE_PATH, Vector3.ONE)
		var tile := _add_plane(floor_root, "Corridor%dTile%02d" % [index, tile_index], position, size, material)
		tile.add_to_group("building_floor_tile")
		tile.set_meta("corridor_index", index)
		tile.set_meta("tile_index", tile_index)


func _build_transitions() -> void:
	var floor_number: int = int(BuildingRunState.current_floor)
	var entry_room := _cell_to_world(floor_cells[0])
	var upper_room := _cell_to_world(floor_cells[floor_cells.size() - 1])
	if floor_number == 1:
		_add_transition("ExitToCity", entry_room + Vector3(-10.2, 0, 8.5), 0.0, "exit", 0, "도시로 나가기")
	_add_transition("FloorElevator", upper_room + Vector3(0, 0, -10.82), 0.0, "elevator_menu", 0, "엘리베이터 층 선택")


func _add_transition(node_name: String, position: Vector3, rotation_y: float, kind: String, target_floor: int, label_text: String) -> void:
	var transition := TRANSITION_MODULE_SCENE.instantiate() as Node3D
	transition.call("configure", kind, target_floor, label_text)
	transition.name = node_name
	transition.position = position
	transition.rotation_degrees.y = rotation_y
	transition.connect("activated", _on_transition_activated.bind(transition))
	floor_root.add_child(transition)


func _spawn_floor_loot(random: RandomNumberGenerator) -> void:
	var count: int = floor_cells.size() + int(BuildingRunState.current_floor)
	var stage_tier := LOOT_ECONOMY.get_stage_for_zone(GameState.get_raid_zone())
	var available_containers: Array[String] = [
		"street_cache",
		"ammo_case",
		"toolbox",
		"clothing_cache",
	]
	if stage_tier >= 2:
		available_containers.append("weapon_case")
	if stage_tier >= 3:
		available_containers.append("secure_cache")
	for index in count:
		var key := "f%02d_loot_%02d" % [BuildingRunState.current_floor, index]
		if BuildingRunState.is_loot_collected(BuildingRunState.current_floor, key):
			continue
		var room_index := index % floor_cells.size()
		var room_center := _cell_to_world(floor_cells[room_index])
		var position := room_center + Vector3(random.randf_range(-6.8, 6.8), 0, random.randf_range(-4.7, 4.7))
		var container_type := available_containers[
			random.randi_range(0, available_containers.size() - 1)
		]
		var loot := LOOT_MODULE_SCENE.instantiate() as Node3D
		loot.call(
			"configure_container",
			key,
			container_type,
			stage_tier,
			BuildingRunState.current_floor,
			random.randi()
		)
		loot.name = "Loot_%s" % key
		loot.position = position
		loot.connect("collected", _on_loot_collected)
		floor_root.add_child(loot)


func _spawn_floor_enemies(random: RandomNumberGenerator) -> void:
	# 층당 4~12마리는 방 수에 비해 휑했다(유저: 너무 단조로워) — 바닥을 6으로
	# 올리고 층수 가중을 2배로. 좁은 실내라 필드보다 조우 밀도가 높아야 긴장이 산다.
	var count: int = clampi(floor_cells.size() + 1 + int(BuildingRunState.current_floor) * 2, 6, 16)
	for index in count:
		var key := "f%02d_enemy_%02d" % [BuildingRunState.current_floor, index]
		if BuildingRunState.is_enemy_defeated(BuildingRunState.current_floor, key):
			continue
		var enemy := CharacterBody3D.new()
		enemy.name = key
		enemy.set_script(ENEMY_SCRIPT)
		var room_index := 1 + index % maxi(1, floor_cells.size() - 1)
		var room_center := _cell_to_world(floor_cells[room_index])
		enemy.position = room_center + Vector3(random.randf_range(-5.5, 5.5), 0.78, random.randf_range(-3.8, 3.8))
		var floor_number := int(BuildingRunState.current_floor)
		# 전부 총잡이면 교전이 전부 같은 리듬이다 — 1/3은 근접 돌격조로 섞어
		# 거리 관리(후퇴·구르기)를 강제한다.
		if index % 3 == 2:
			enemy.call("configure", "melee", player, {}, minf(1.0, 0.14 * floor_number), "")
		else:
			var weapon_pool: Array[String] = ["m1911", "m1911", "mp5", "double_barrel"]
			if floor_number >= 2:
				weapon_pool.append("mp5")
			if floor_number >= 3:
				weapon_pool.append("ak47")
			if floor_number >= 4:
				weapon_pool.append("ak47")
			var weapon := weapon_pool[random.randi_range(0, weapon_pool.size() - 1)]
			enemy.call("configure", "ranged", player, {}, minf(1.0, 0.12 * floor_number), weapon)
		enemy.connect("died", _on_enemy_died.bind(key))
		floor_root.add_child(enemy)
		enemies.append(enemy)


func _on_enemy_died(enemy: CharacterBody3D, enemy_key: String) -> void:
	BuildingRunState.mark_enemy_defeated(BuildingRunState.current_floor, enemy_key)
	enemies.erase(enemy)
	if enemies.is_empty():
		call_deferred("_handle_floor_cleared")
	GameState.raid_kills += 1
	building_run_kills += 1
	GameState.advance_contract("kills", 1)
	var reward_key := "%s_drop" % enemy_key
	if not BuildingRunState.is_loot_collected(BuildingRunState.current_floor, reward_key):
		var stage_tier := LOOT_ECONOMY.get_stage_for_zone(GameState.get_raid_zone())
		var drop_random := RandomNumberGenerator.new()
		drop_random.seed = BuildingRunState.get_floor_seed(BuildingRunState.current_floor) ^ enemy_key.hash()
		var definition: Dictionary = LOOT_ECONOMY.roll_enemy_drop(
			stage_tier,
			str(enemy.get("enemy_kind")),
			str(enemy.get("weapon_id")),
			drop_random,
			not GameState.has_ak
		)
		if (
			definition.is_empty()
			or not LOOT_ECONOMY.try_register_loot(
				GameState,
				definition,
				"enemy",
				stage_tier
			)
		):
			BuildingRunState.mark_loot_collected(BuildingRunState.current_floor, reward_key)
			return
		var loot := LOOT_MODULE_SCENE.instantiate() as Node3D
		loot.call(
			"configure_item",
			reward_key,
			definition,
			BuildingRunState.current_floor
		)
		loot.name = "Loot_%s" % reward_key
		loot.position = Vector3(enemy.position.x, 0, enemy.position.z)
		loot.connect("collected", _on_loot_collected)
		floor_root.add_child(loot)


func _on_loot_collected(_key: String, description: String) -> void:
	_show_status(description)


func _handle_floor_cleared() -> void:
	if floor_clear_announced or not enemies.is_empty():
		return
	floor_clear_announced = true
	var cleared_floor := int(BuildingRunState.current_floor)
	BuildingRunState.mark_floor_cleared(cleared_floor)
	var building_name := _get_building_display_name()
	var full_clear: bool = bool(BuildingRunState.is_building_cleared())
	var title := (
		"%s 탐색 완료" % building_name
		if full_clear
		else "%s %d층 확보" % [building_name, cleared_floor]
	)
	var detail := (
		"모든 층 제압 완료. 전리품을 챙기고 도시로 돌아간다."
		if full_clear
		else "현재 층의 위협을 모두 제거했습니다. 남은 층을 계속 수색할 수 있습니다."
	)
	_show_floor_clear_banner(title, detail)
	if building_objective_label != null:
		building_objective_label.text = (
			"  %s 탐색 완료\n  · 전리품을 챙기고 도시로 돌아간다" % building_name
			if full_clear
			else "  %s %d층 확보\n  · 남은 층을 마저 수색한다" % [building_name, cleared_floor]
		)


func _show_floor_clear_banner(title: String, detail: String) -> void:
	if floor_clear_banner == null:
		return
	if floor_clear_tween != null and floor_clear_tween.is_valid():
		floor_clear_tween.kill()
	floor_clear_title.text = title
	floor_clear_detail.text = detail
	floor_clear_banner.visible = true
	floor_clear_banner.modulate = Color(1, 1, 1, 0)
	floor_clear_tween = create_tween()
	floor_clear_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	floor_clear_tween.tween_property(floor_clear_banner, "modulate:a", 1.0, 0.18)
	floor_clear_tween.tween_interval(2.6)
	floor_clear_tween.tween_property(floor_clear_banner, "modulate:a", 0.0, 0.42)
	floor_clear_tween.tween_callback(func() -> void: floor_clear_banner.visible = false)


func _get_building_display_name() -> String:
	var identifier := str(BuildingRunState.building_id).to_lower()
	if "pharmacy" in identifier or "clinic" in identifier:
		return "약국"
	if "market" in identifier:
		return "시장 건물"
	if "metalworks" in identifier:
		return "을지로 공업소"
	if "checkpoint" in identifier or "depot" in identifier:
		return "봉쇄선 시설"
	if "tower" in identifier or "office" in identifier:
		return "오피스 타워"
	return "도시 건물"


func _on_transition_activated(_action: String, transition: Node3D) -> void:
	if loading_floor:
		return
	var kind := str(transition.get_meta("transition_kind", ""))
	var target_floor := int(transition.get_meta("target_floor", 0))
	if kind == "exit":
		BuildingRunState.leave_building()
		return
	if kind == "elevator_menu":
		_show_elevator_menu()
		return
	if target_floor < 1 or target_floor > BuildingRunState.max_floors:
		return
	var arrival := "from_below" if target_floor > BuildingRunState.current_floor else "from_above"
	_load_floor(target_floor, arrival)


func _update_nearby_interactable() -> void:
	var nearest: Node3D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("building_interactable"):
		if not candidate is Node3D or not is_ancestor_of(candidate):
			continue
		var node := candidate as Node3D
		var radius := float(node.call("get_interaction_radius")) if node.has_method("get_interaction_radius") else 1.5
		var distance := player.global_position.distance_to(node.global_position)
		if distance <= radius and distance < nearest_distance:
			nearest = node
			nearest_distance = distance
	current_interactable = nearest
	prompt_label.text = "" if nearest == null else "[F]  %s" % str(nearest.call("get_interaction_prompt"))


func _interact() -> void:
	if current_interactable == null or not is_instance_valid(current_interactable):
		return
	if current_interactable.has_method("interact"):
		var result := str(current_interactable.call("interact"))
		if not result.is_empty(): _show_status(result)


func _on_flashlight_toggled(enabled: bool) -> void:
	laser_aim_held = enabled and _has_equipped_firearm()
	if DisplayServer.is_touchscreen_available() and bool(accessibility_settings.vibration_enabled):
		Input.vibrate_handheld(12)


func _fire_at_nearest_enemy() -> void:
	var facing_direction := _get_facing_world_direction()
	var closest := _get_mobile_aim_assist_enemy(facing_direction)
	if closest != null:
		_fire_toward_world(closest.global_position)
	else:
		_fire_toward_world(player.global_position + facing_direction * MOBILE_AIM_ASSIST_MAX_DISTANCE)


func _get_mobile_aim_assist_enemy(facing_direction: Vector3) -> CharacterBody3D:
	var closest: CharacterBody3D
	var closest_distance := INF
	var assist_strength := clampf(float(accessibility_settings.aim_assist_strength), 0.0, 1.0)
	if assist_strength <= 0.01:
		return null
	var minimum_dot := cos(deg_to_rad(lerpf(12.0, MOBILE_AIM_ASSIST_HALF_ANGLE_DEG, assist_strength)))
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		if float(enemy.get("player_visibility_factor")) < 0.2:
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.05 or distance > MOBILE_AIM_ASSIST_MAX_DISTANCE:
			continue
		if facing_direction.dot(offset / distance) < minimum_dot:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0, 0.45, 0),
			enemy.global_position + Vector3(0, 0.45, 0),
			COLLISION_PROFILES.ENEMY_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
		)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") != enemy:
			continue
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	return closest


func _try_melee_forward() -> void:
	var target_world := player.global_position + _get_facing_world_direction() * MELEE_ATTACK_RANGE
	_try_melee_attack(camera.unproject_position(target_world))


func _fire_toward_screen_point(screen_point: Vector2) -> void:
	aim_world_position = _screen_point_to_world(screen_point)
	if not is_finite(aim_world_position.x):
		return
	_fire_toward_world(aim_world_position)


func _screen_point_to_world(screen_point: Vector2) -> Vector3:
	if camera == null:
		return Vector3(INF, INF, INF)
	var origin := camera.project_ray_origin(screen_point)
	var ray_direction := camera.project_ray_normal(screen_point)
	if absf(ray_direction.y) < 0.001:
		return Vector3(INF, INF, INF)
	var distance := (0.45 - origin.y) / ray_direction.y
	return origin + ray_direction * distance


func _try_melee_attack(screen_point: Vector2) -> void:
	# 필드(main.gd)와 동일한 스윙 상태기: 예비동작(팬 텔레그래프+배트 트윈) →
	# 윈드업 후 타격 판정(아크 이펙트+카메라 셰이크) → 마무리.
	if melee_attack_cooldown > 0.0 or melee_attack_active or roll_active:
		return
	melee_attack_cooldown = MELEE_ATTACK_COOLDOWN
	_add_fatigue(FATIGUE_MELEE_GAIN)
	var target := _screen_point_to_world(screen_point)
	var attack_direction := Vector3.ZERO
	if is_finite(target.x):
		attack_direction = target - player.global_position
		attack_direction.y = 0.0
	if attack_direction.length_squared() < 0.01:
		attack_direction = _get_facing_world_direction()
	attack_direction = attack_direction.normalized()
	_set_facing_from_world_direction(attack_direction)
	melee_attack_active = true
	melee_attack_elapsed = 0.0
	melee_attack_direction = attack_direction
	melee_hit_resolved = false
	motion_state = "melee"
	_play_animation()
	_show_melee_fan(attack_direction)
	_play_bat_swing(attack_direction)
	SFX.play("melee_swing")


func _update_melee_attack(delta: float) -> void:
	if not melee_attack_active:
		return
	melee_attack_elapsed += delta
	if not melee_hit_resolved and melee_attack_elapsed >= MELEE_WINDUP_DURATION:
		melee_hit_resolved = true
		_hide_melee_fan()
		_spawn_player_melee_arc(melee_attack_direction)
		_resolve_melee_hit(melee_attack_direction)
	if melee_attack_elapsed >= MELEE_ANIMATION_DURATION:
		_finish_melee_attack()


func _finish_melee_attack() -> void:
	if not melee_attack_active:
		return
	melee_attack_active = false
	melee_attack_elapsed = 0.0
	melee_hit_resolved = false
	_hide_melee_fan()
	motion_state = ""
	_set_motion_state("walk" if player.velocity.length_squared() > 0.1 else "idle")


func _resolve_melee_hit(direction: Vector3) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dying")):
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.05 or distance > MELEE_ATTACK_RANGE:
			continue
		if direction.dot(offset.normalized()) < cos(deg_to_rad(MELEE_FAN_HALF_ANGLE_DEG)):
			continue
		# 필드와 동일: 벽 너머 타격을 막는 시야 확인.
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0, 0.35, 0),
			enemy.global_position + Vector3(0, 0.35, 0),
			COLLISION_PROFILES.ENEMY_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
		)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") != enemy:
			continue
		var backstab := bool(enemy.call("is_backstab_from", player.global_position)) if enemy.has_method("is_backstab_from") else false
		var melee_damage := MELEE_ATTACK_DAMAGE
		if GameState.has_method("is_churu_buff_active") and bool(GameState.call("is_churu_buff_active", "sharp_claws")):
			melee_damage = roundi(float(melee_damage) * 1.4)
		enemy.call("take_melee_hit", melee_damage, direction, backstab)
		# 배트가 실제로 맞았을 때만 화면이 울린다 — 헛스윙과 명중의 손맛을 가른다.
		camera_shake_time = maxf(camera_shake_time, 0.12)
		camera_shake_strength = maxf(camera_shake_strength, 0.22 if backstab else 0.16)
		SFX.play("melee_hit")


func _setup_melee_weapon() -> void:
	melee_bat_sprite = Sprite3D.new()
	melee_bat_sprite.name = "TemporaryBaseballBat"
	melee_bat_sprite.texture = BASEBALL_BAT_TEXTURE
	melee_bat_sprite.pixel_size = WEAPON_VISUAL_CATALOG.get_world_pixel_size("baseball_bat", 0.00058)
	melee_bat_sprite.centered = true
	melee_bat_sprite.offset = Vector2.ZERO
	melee_bat_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	melee_bat_sprite.shaded = false
	melee_bat_sprite.transparent = true
	melee_bat_sprite.no_depth_test = true
	melee_bat_sprite.render_priority = 126
	melee_bat_sprite.visible = false
	player.add_child(melee_bat_sprite)
	_setup_melee_fan_indicator()


func _setup_melee_fan_indicator() -> void:
	melee_fan_fill_material = StandardMaterial3D.new()
	melee_fan_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	melee_fan_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	melee_fan_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	melee_fan_fill_material.no_depth_test = true
	melee_fan_fill_material.albedo_color = Color(1.0, 0.46, 0.08, 0.3)
	melee_fan_fill_material.render_priority = 1

	melee_fan_rim_material = StandardMaterial3D.new()
	melee_fan_rim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	melee_fan_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	melee_fan_rim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	melee_fan_rim_material.no_depth_test = true
	melee_fan_rim_material.albedo_color = Color(1.0, 0.78, 0.22, 0.88)
	melee_fan_rim_material.render_priority = 2

	melee_fan_indicator = MeshInstance3D.new()
	melee_fan_indicator.name = "MeleeFanTelegraph"
	melee_fan_indicator.mesh = _create_melee_fan_mesh()
	melee_fan_indicator.position = Vector3(0, -0.735, 0)
	melee_fan_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	melee_fan_indicator.visible = false
	player.add_child(melee_fan_indicator)


func _create_melee_fan_mesh() -> ArrayMesh:
	var fill_vertices := PackedVector3Array()
	var half_angle := deg_to_rad(MELEE_FAN_HALF_ANGLE_DEG)
	for segment in MELEE_FAN_SEGMENTS:
		var angle_a := lerpf(-half_angle, half_angle, float(segment) / MELEE_FAN_SEGMENTS)
		var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / MELEE_FAN_SEGMENTS)
		fill_vertices.append(Vector3.ZERO)
		fill_vertices.append(Vector3(sin(angle_a), 0, cos(angle_a)) * MELEE_ATTACK_RANGE)
		fill_vertices.append(Vector3(sin(angle_b), 0, cos(angle_b)) * MELEE_ATTACK_RANGE)
	var mesh := ArrayMesh.new()
	var fill_arrays := []
	fill_arrays.resize(Mesh.ARRAY_MAX)
	fill_arrays[Mesh.ARRAY_VERTEX] = fill_vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fill_arrays)
	mesh.surface_set_material(0, melee_fan_fill_material)
	var rim_vertices := PackedVector3Array()
	var inner_radius := MELEE_ATTACK_RANGE - 0.09
	for segment in MELEE_FAN_SEGMENTS:
		var angle_a := lerpf(-half_angle, half_angle, float(segment) / MELEE_FAN_SEGMENTS)
		var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / MELEE_FAN_SEGMENTS)
		var outer_a := Vector3(sin(angle_a), 0.004, cos(angle_a)) * MELEE_ATTACK_RANGE
		var outer_b := Vector3(sin(angle_b), 0.004, cos(angle_b)) * MELEE_ATTACK_RANGE
		var inner_a := Vector3(sin(angle_a), 0.004, cos(angle_a)) * inner_radius
		var inner_b := Vector3(sin(angle_b), 0.004, cos(angle_b)) * inner_radius
		rim_vertices.append(inner_a)
		rim_vertices.append(outer_a)
		rim_vertices.append(outer_b)
		rim_vertices.append(inner_a)
		rim_vertices.append(outer_b)
		rim_vertices.append(inner_b)
	var rim_arrays := []
	rim_arrays.resize(Mesh.ARRAY_MAX)
	rim_arrays[Mesh.ARRAY_VERTEX] = rim_vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rim_arrays)
	mesh.surface_set_material(1, melee_fan_rim_material)
	return mesh


func _show_melee_fan(direction: Vector3) -> void:
	if melee_fan_indicator == null:
		return
	if melee_fan_tween != null and melee_fan_tween.is_valid():
		melee_fan_tween.kill()
	melee_fan_indicator.rotation = Vector3(0, atan2(direction.x, direction.z), 0)
	melee_fan_indicator.scale = Vector3(0.84, 1.0, 0.84)
	melee_fan_indicator.transparency = 0.0
	melee_fan_indicator.visible = true
	melee_fan_tween = create_tween()
	melee_fan_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	melee_fan_tween.tween_property(
		melee_fan_indicator, "scale", Vector3.ONE, MELEE_WINDUP_DURATION
	)


func _hide_melee_fan() -> void:
	if melee_fan_indicator == null or not melee_fan_indicator.visible:
		return
	if melee_fan_tween != null and melee_fan_tween.is_valid():
		melee_fan_tween.kill()
	melee_fan_tween = create_tween()
	melee_fan_tween.tween_property(melee_fan_indicator, "transparency", 1.0, 0.08)
	melee_fan_tween.tween_callback(func() -> void:
		if is_instance_valid(melee_fan_indicator):
			melee_fan_indicator.visible = false
	)


func _play_bat_swing(direction: Vector3) -> void:
	# 필드의 Sprite3D 배트 스윙 트윈과 동일(2D 오버레이 경로는 필드 전용이라 제외).
	var player_screen := camera.unproject_position(player.global_position)
	var target_screen := camera.unproject_position(
		player.global_position + direction * MELEE_ATTACK_RANGE
	)
	var screen_direction := (target_screen - player_screen).normalized()
	var screen_angle := atan2(screen_direction.y, screen_direction.x)
	var aligned_angle := screen_angle + PI * 0.25
	var bat_texture_size := Vector2(
		BASEBALL_BAT_TEXTURE.get_width(),
		BASEBALL_BAT_TEXTURE.get_height()
	)
	var bat_texture_length := maxf(1.0, bat_texture_size.length())
	var bat_world_length := bat_texture_length * melee_bat_sprite.pixel_size * 0.9
	var bat_world_center := maxf(0.3, MELEE_ATTACK_RANGE - bat_world_length * 0.5)
	melee_bat_sprite.visible = true
	melee_bat_sprite.flip_h = false
	melee_bat_sprite.flip_v = false
	melee_bat_sprite.modulate = Color(1.18, 1.08, 0.92, 1.0)
	melee_bat_sprite.position = direction * 0.28 + Vector3(0, 0.43, 0)
	melee_bat_sprite.rotation.z = aligned_angle - deg_to_rad(96.0)
	melee_bat_sprite.scale = Vector3.ONE * 0.78
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(melee_bat_sprite, "rotation:z", aligned_angle + deg_to_rad(58.0), 0.21).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(melee_bat_sprite, "position", direction * bat_world_center + Vector3(0, 0.45, 0), 0.21)
	tween.tween_property(melee_bat_sprite, "scale", Vector3.ONE * 0.9, 0.21)
	tween.chain().tween_property(melee_bat_sprite, "modulate", Color(1.0, 0.82, 0.55, 0.0), 0.13)
	tween.chain().tween_callback(func() -> void:
		melee_bat_sprite.visible = false
	)


func _spawn_player_melee_arc(direction: Vector3) -> void:
	if melee_arc_texture == null:
		melee_arc_texture = _create_melee_arc_texture()
	var arc := Sprite3D.new()
	arc.name = "PlayerMeleeArc"
	arc.texture = melee_arc_texture
	arc.pixel_size = 0.012
	arc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arc.shaded = false
	arc.transparent = true
	arc.no_depth_test = true
	arc.render_priority = 125
	arc.position = player.position + direction * 0.95 + Vector3(0, 0.3, 0)
	add_child(arc)
	var player_screen := camera.unproject_position(player.global_position)
	var target_screen := camera.unproject_position(player.global_position + direction * 2.0)
	var screen_direction := (target_screen - player_screen).normalized()
	arc.rotation.z = atan2(screen_direction.y, screen_direction.x)
	arc.scale = Vector3.ONE * 0.72
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(arc, "scale", Vector3.ONE * 1.28, 0.18)
	tween.tween_property(arc, "modulate", Color(1.0, 0.52, 0.2, 0.0), 0.2)
	get_tree().create_timer(0.22).timeout.connect(arc.queue_free)


func _create_melee_arc_texture() -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(64, 64)
	for y in 128:
		for x in 128:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			var angle := rad_to_deg(atan2(offset.y, offset.x))
			if radius >= 40.0 and radius <= 57.0 and absf(angle) <= 68.0:
				var edge_alpha := 1.0 - absf(radius - 48.5) / 8.5
				image.set_pixel(x, y, Color(1.0, 0.7, 0.32, edge_alpha * 0.72))
	return ImageTexture.create_from_image(image)


func _update_aim_reticle() -> void:
	if aim_reticle == null:
		return
	aim_reticle.visible = not DisplayServer.is_touchscreen_available()
	if aim_reticle.visible:
		aim_reticle.call(
			"update_feedback",
			get_viewport().get_mouse_position(),
			float(weapon_stats.get("base_spread_deg", 2.4)),
			Vector2.ZERO,
			laser_aim_held
		)


func _setup_aim_laser() -> void:
	var widths := [0.072, 0.034, 0.010]
	var colors := [Color(1.0, 0.02, 0.08, 0.10), Color(1.0, 0.04, 0.09, 0.32), Color(1.0, 0.72, 0.72, 0.96)]
	var energies := [1.8, 3.8, 7.0]
	for layer_index in widths.size():
		var mesh := BoxMesh.new()
		mesh.size = Vector3(widths[layer_index], widths[layer_index], 1.0)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = colors[layer_index]
		material.emission_enabled = true
		material.emission = Color(1.0, 0.015, 0.055)
		material.emission_energy_multiplier = energies[layer_index]
		material.no_depth_test = true
		mesh.material = material
		var layer := MeshInstance3D.new()
		layer.name = "AimGuideLaserCore" if layer_index == 2 else "AimGuideLaserGlow%d" % layer_index
		layer.mesh = mesh
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.visible = false
		add_child(layer)
		laser_glow_layers.append(layer)
		laser_glow_meshes.append(mesh)
	var endpoint_mesh := SphereMesh.new()
	endpoint_mesh.radius = 0.065
	endpoint_mesh.height = 0.13
	endpoint_mesh.radial_segments = 12
	endpoint_mesh.rings = 6
	var endpoint_material := StandardMaterial3D.new()
	endpoint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	endpoint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	endpoint_material.albedo_color = Color(1.0, 0.18, 0.22, 0.82)
	endpoint_material.emission_enabled = true
	endpoint_material.emission = Color(1.0, 0.025, 0.06)
	endpoint_material.emission_energy_multiplier = 6.0
	endpoint_material.no_depth_test = true
	endpoint_mesh.material = endpoint_material
	laser_endpoint = MeshInstance3D.new()
	laser_endpoint.name = "AimGuideLaserEndpoint"
	laser_endpoint.mesh = endpoint_mesh
	laser_endpoint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser_endpoint.visible = false
	add_child(laser_endpoint)


func _update_aim_laser() -> void:
	var should_show := laser_aim_held and _has_equipped_firearm() and not roll_active
	for layer in laser_glow_layers:
		layer.visible = should_show
	if laser_endpoint != null:
		laser_endpoint.visible = should_show
	if not should_show or camera == null or player == null:
		return
	var direction := _get_facing_world_direction()
	if not DisplayServer.is_touchscreen_available():
		var target := _screen_point_to_world(get_viewport().get_mouse_position())
		if not is_finite(target.x):
			return
		direction = target - player.global_position
		direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return
	direction = direction.normalized()
	var start := player.global_position + direction * 0.46 + Vector3(0, 0.47, 0)
	var end := start + direction * 48.0
	var query := PhysicsRayQueryParameters3D.create(
		start,
		end,
		COLLISION_PROFILES.ENEMY_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.get("position")
	var distance := start.distance_to(end)
	if distance <= 0.02:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	var widths := [0.072, 0.034, 0.010]
	for layer_index in laser_glow_layers.size():
		var width_scale := 1.0 + pulse * (0.18 if layer_index == 0 else 0.06)
		laser_glow_meshes[layer_index].size = Vector3(widths[layer_index] * width_scale, widths[layer_index] * width_scale, distance)
		laser_glow_layers[layer_index].global_position = start.lerp(end, 0.5)
		laser_glow_layers[layer_index].look_at(end, Vector3.UP)
	if laser_endpoint != null:
		laser_endpoint.global_position = end
		laser_endpoint.scale = Vector3.ONE * lerpf(0.82, 1.28, pulse)


func _fire_toward_world(target_position: Vector3) -> void:
	if not _has_equipped_firearm() or roll_active or melee_attack_active or weapon_reloading or fire_cooldown > 0.0:
		return
	if int(GameState.magazine_ammo) <= 0:
		_start_reload()
		return
	var direction := target_position - player.global_position
	direction.y = 0
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()
	_set_facing_from_world_direction(direction)
	var pellet_count := int(weapon_stats.get("pellet_count", 1))
	var spread := float(weapon_stats.get("base_spread_deg", 2.4))
	for pellet_index in pellet_count:
		var shot_direction := direction.rotated(Vector3.UP, deg_to_rad(randf_range(-spread, spread))).normalized()
		var bullet := Area3D.new()
		bullet.name = "BuildingPlayerBullet%d" % pellet_index
		bullet.set_script(BULLET_SCRIPT)
		bullet.set("direction", shot_direction)
		bullet.set("source_body", player)
		bullet.set("damage", roundi(float(weapon_stats.get("damage", 24))))
		bullet.set("critical_chance", 0.12)
		bullet.set("penetrations_remaining", int(weapon_stats.get("penetration_count", 0)))
		bullet.position = player.global_position + shot_direction * 0.75 + Vector3(0, 0.35, 0)
		add_child(bullet)
	GameState.magazine_ammo = int(GameState.magazine_ammo) - 1
	# 건물 내부도 필드와 같은 뱅크의 구경별 총성.
	SFX.play_weapon_shot(str(GameState.equipped_weapon_id))
	_add_fatigue(FATIGUE_SHOT_GAIN)
	fire_cooldown = float(weapon_stats.get("fire_interval", 0.12))
	_update_ammo_label()


func _has_equipped_firearm() -> bool:
	var value = GameState.get("has_ak")
	return true if value == null else bool(value)


func _start_reload() -> void:
	if weapon_reloading:
		return
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	var reserve := _get_reserve_ammo()
	if int(GameState.magazine_ammo) >= magazine_size or reserve <= 0:
		if reserve <= 0:
			_show_status("예비 탄약이 없습니다.")
			SFX.play("dry_fire")
		return
	weapon_reloading = true
	SFX.play("reload_start")
	_add_fatigue(FATIGUE_RELOAD_GAIN)
	reload_timer = float(weapon_stats.get("reload_time", 2.15))
	fire_cooldown = reload_timer
	_show_status("재장전 중 · %.1f초" % reload_timer)
	_update_ammo_label()


func _finish_reload() -> void:
	weapon_reloading = false
	SFX.play("reload_end")
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	var reserve := _get_reserve_ammo()
	var needed := magazine_size - int(GameState.magazine_ammo)
	var loaded := mini(needed, reserve)
	GameState.magazine_ammo = int(GameState.magazine_ammo) + loaded
	_set_reserve_ammo(reserve - loaded)
	# 재장전 완료 토스트는 폐지(유저) — 탄창 수치·완료음이 이미 말한다.
	_update_ammo_label()


func _get_reserve_ammo() -> int:
	if GameState.has_method("get_ammo_count"):
		return int(GameState.call("get_ammo_count", str(GameState.equipped_ammo_id)))
	return int(GameState.get("reserve_ammo"))


func _set_reserve_ammo(value: int) -> void:
	if GameState.has_method("set_ammo_count"):
		GameState.call("set_ammo_count", str(GameState.equipped_ammo_id), value)
	GameState.set("reserve_ammo", value)


func _update_ammo_label() -> void:
	if ammo_label == null:
		return
	var magazine_size := int(weapon_stats.get("magazine_size", 30))
	var current_ammo := int(GameState.magazine_ammo)
	var reserve_ammo := _get_reserve_ammo()
	var ammo_name := str(
		WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id).get(
			"display_name",
			GameState.equipped_ammo_id
		)
	)
	var hud_state := WEAPON_HUD_PRESENTER.build_state(
		_has_equipped_firearm(),
		current_ammo,
		magazine_size,
		reserve_ammo,
		weapon_reloading,
		reload_timer,
		ammo_name
	)
	ammo_label.text = WEAPON_HUD_PRESENTER.build_interior_line(
		int(GameState.player_health),
		int(GameState.get_max_health()),
		hud_state
	)
	var ammo_color: Color = hud_state.get("ammo_color", Color("#d6d2bd"))
	ammo_label.add_theme_color_override("font_color", ammo_color)
	_update_shared_equipment_hud(hud_state)
	if inventory_ui != null:
		var mods: Array[String] = []
		var stored_mods = GameState.get("equipped_weapon_mods")
		if stored_mods is Array:
			for mod_id in stored_mods:
				mods.append(str(mod_id))
		var stored_weapon_count := 0
		for count in GameState.weapon_inventory.values():
			stored_weapon_count += int(count)
		if _has_equipped_firearm():
			stored_weapon_count = maxi(0, stored_weapon_count - 1)
		inventory_ui.call("update_state", _has_equipped_firearm(), int(GameState.magazine_ammo), _get_reserve_ammo(), str(weapon_stats.get("display_name", "AK-47")), int(weapon_stats.get("magazine_size", 30)), float(GameState.get("weapon_durability") if GameState.get("weapon_durability") != null else 100.0), mods, int(GameState.get("canned_food") if GameState.get("canned_food") != null else 0), stored_weapon_count, GameState.get("mod_component_inventory") if GameState.get("mod_component_inventory") is Dictionary else {}, 0, fatigue)


func _update_shared_equipment_hud(hud_state: Dictionary) -> void:
	# 필드 main._update_equipment_ui와 같은 매핑 — 이름+강화, 탄약명, 통합 잔탄,
	# 내구도는 그림 색, 상태줄은 정말 할 말이 있을 때만.
	if equipment_panel == null:
		return
	var has_weapon := _has_equipped_firearm()
	var weapon_id := str(GameState.equipped_weapon_id)
	var weapon_name := str(weapon_stats.get("display_name", "AK-47"))
	var enhancement_level: int = int(GameState.get_weapon_enhancement_level(weapon_id))
	var short_weapon_name := weapon_name.split("\"")[0].strip_edges()
	equipment_label.text = (
		"%s +%d" % [short_weapon_name, enhancement_level]
		if has_weapon and enhancement_level > 0
		else (short_weapon_name if has_weapon else "무기 없음")
	)
	equipment_label.visible = true
	equipment_weapon_image.texture = WEAPON_VISUAL_CATALOG.get_weapon_texture(weapon_id)
	equipment_weapon_image.visible = has_weapon
	equipment_weapon_image.modulate = _weapon_condition_tint()
	equipment_weapon_image.tooltip_text = (
		"%s +%d" % [weapon_name, enhancement_level] if has_weapon else "무기 없음"
	)
	var ammo_name := str(
		WEAPON_SYSTEM.get_ammo(GameState.equipped_ammo_id).get(
			"display_name",
			GameState.equipped_ammo_id
		)
	)
	equipment_reserve_ammo_label.text = ammo_name if has_weapon else ""
	equipment_reserve_ammo_label.visible = has_weapon
	equipment_ammo_label.text = str(hud_state.get("ammo_combined_text", "-- / --"))
	var ammo_color: Color = hud_state.get("ammo_color", Color("#f1ce70"))
	equipment_ammo_label.add_theme_color_override("font_color", ammo_color)
	equipment_condition_label.text = str(hud_state.get("condition_text", ""))
	equipment_condition_label.visible = bool(hud_state.get("condition_notable", true))
	var reload_duration := maxf(0.01, float(weapon_stats.get("reload_time", 2.15)))
	equipment_reload_bar.value = (
		1.0 - clampf(reload_timer / reload_duration, 0.0, 1.0)
		if weapon_reloading
		else 1.0
	)
	equipment_reload_bar.visible = weapon_reloading and has_weapon


func _weapon_condition_tint() -> Color:
	# 필드와 동일: 내구도를 무기 그림의 색으로 알린다.
	if not _has_equipped_firearm():
		return Color(1.0, 1.0, 1.0, 1.0)
	var durability_value = GameState.get("weapon_durability")
	var ratio := clampf(
		(float(durability_value) if durability_value != null else 100.0) / 100.0,
		0.0,
		1.0
	)
	if ratio >= 0.6:
		return Color(1.0, 1.0, 1.0, 1.0)
	if ratio >= 0.3:
		return Color(1.0, 0.86, 0.62, 1.0)
	return Color(1.0, 0.62, 0.55, 1.0)


func _try_start_roll() -> void:
	if roll_active or melee_attack_active or roll_stamina < ROLL_STAMINA_COST:
		return
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
	if touch_vector.length_squared() > input_vector.length_squared():
		input_vector = touch_vector
	if input_vector.length_squared() > 0.01:
		roll_direction = Vector3(input_vector.x + input_vector.y, 0, -input_vector.x + input_vector.y).normalized()
		_update_facing(input_vector)
	else:
		roll_direction = _get_facing_world_direction()
	roll_active = true
	roll_elapsed = 0.0
	roll_stamina -= ROLL_STAMINA_COST
	_add_fatigue(FATIGUE_ROLL_GAIN)
	motion_state = "roll"
	_play_animation()


func _update_roll(delta: float) -> void:
	roll_elapsed += delta
	var progress := clampf(roll_elapsed / ROLL_DURATION, 0.0, 1.0)
	var speed := lerpf(ROLL_END_SPEED, ROLL_START_SPEED, pow(1.0 - progress, 2.35))
	player.velocity = roll_direction * speed
	if roll_elapsed >= ROLL_DURATION:
		roll_active = false
		roll_elapsed = 0.0
		_set_motion_state("idle")


func _get_facing_world_direction() -> Vector3:
	var screen_vectors := {
		"n": Vector2(0, -1), "ne": Vector2(1, -1), "e": Vector2(1, 0), "se": Vector2(1, 1),
		"s": Vector2(0, 1), "sw": Vector2(-1, 1), "w": Vector2(-1, 0), "nw": Vector2(-1, -1),
	}
	var screen_direction: Vector2 = screen_vectors.get(facing, Vector2.DOWN)
	return Vector3(screen_direction.x + screen_direction.y, 0, -screen_direction.x + screen_direction.y).normalized()


func _update_fatigue(delta: float, is_moving: bool) -> void:
	var rate := FATIGUE_MOVING_RATE if is_moving else 0.0
	if laser_aim_held and _has_equipped_firearm():
		rate += FATIGUE_AIM_HOLD_RATE
	_add_fatigue(rate * delta)
	_update_fatigue_ui()


func _add_fatigue(amount: float) -> void:
	if amount <= 0.0:
		return
	fatigue = clampf(fatigue + amount, 0.0, FATIGUE_MAX)
	GameState.fatigue = fatigue
	_update_fatigue_ui()


func _update_fatigue_ui() -> void:
	# 필드 _refresh_fatigue_hud와 같은 단계·색: 35 피곤 / 65 과부하 / 90 탈진.
	if fatigue_bar != null:
		fatigue_bar.value = fatigue
	var status := "안정"
	var color := Color("#78b993")
	var warning_band := 0
	if fatigue >= 90.0:
		status = "탈진"
		color = Color("#e06c62")
		warning_band = 3
	elif fatigue >= 65.0:
		status = "과부하"
		color = Color("#e3ad61")
		warning_band = 2
	elif fatigue >= 35.0:
		status = "피곤"
		color = Color("#d5c16b")
		warning_band = 1
	if fatigue_label != null:
		fatigue_label.text = (
			"%d%%" % roundi(fatigue)
			if warning_band <= 0
			else "%d%% · %s" % [roundi(fatigue), status]
		)
		fatigue_label.add_theme_color_override("font_color", color)
	if fatigue_fill_style != null:
		fatigue_fill_style.bg_color = color
		fatigue_fill_style.border_color = color.lightened(0.2)


func _get_fatigue_speed_multiplier() -> float:
	if fatigue < 70.0:
		return 1.0
	return lerpf(1.0, FATIGUE_SPEED_MIN, inverse_lerp(70.0, FATIGUE_MAX, fatigue))


func _set_facing_from_world_direction(direction: Vector3) -> void:
	var screen_direction := Vector2(direction.x - direction.z, direction.x + direction.z)
	_update_facing(screen_direction)


func _update_camera(delta: float) -> void:
	var camera_target := Vector3(player.position.x, 0, player.position.z)
	# 필드와 동일: 배트가 맞았을 때만 화면이 짧게 울린다.
	if camera_shake_time > 0.0:
		var shake_scale := clampf(float(accessibility_settings.camera_shake_scale), 0.0, 1.0)
		camera_target += Vector3(
			shake_random.randf_range(-camera_shake_strength, camera_shake_strength) * shake_scale,
			0.0,
			shake_random.randf_range(-camera_shake_strength, camera_shake_strength) * shake_scale
		)
	camera_focus = camera_focus.lerp(camera_target, clampf(delta * 5.0, 0, 1))
	camera.position = camera_focus + Vector3.ONE * (CAMERA_DIAGONAL_OFFSET * 4.0)
	camera.look_at(camera_focus)
	# 세로 화면 보정 — 필드와 동일하게 매 프레임 강제한다. KEEP_WIDTH로 가로
	# 시야를 가로모드와 맞추고, 세로에서는 한 걸음 더 물러난다(x1.25).
	var camera_viewport := get_viewport().get_visible_rect().size
	var camera_portrait := camera_viewport.y > camera_viewport.x
	camera.keep_aspect = Camera3D.KEEP_WIDTH if camera_portrait else Camera3D.KEEP_HEIGHT
	var target_camera_size := BASE_CAMERA_SIZE * (1.25 if camera_portrait else 1.0)
	camera.size = lerpf(camera.size, target_camera_size, 1.0 - exp(-8.5 * delta))


func _update_facing(input_vector: Vector2) -> void:
	if input_vector.length_squared() < 0.01:
		return
	var angle := fposmod(rad_to_deg(atan2(input_vector.x, -input_vector.y)), 360.0)
	var next_facing: String = SCREEN_DIRECTIONS[int(round(angle / 45.0)) % 8]
	# 스윙 중에는 방향이 잠긴다 — 필드와 동일.
	if melee_attack_active and next_facing != facing:
		return
	if next_facing != facing:
		facing = next_facing
		_play_animation()


func _set_motion_state(state: String) -> void:
	# 스윙 애니메이션은 walk/idle로 덮이지 않는다 — 필드와 동일.
	if melee_attack_active and state != "melee":
		return
	if motion_state == state:
		return
	motion_state = state
	_play_animation()


func _play_animation() -> void:
	if survivor != null:
		survivor.play("%s_%s" % [motion_state, facing])


func _create_cat_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in SCREEN_DIRECTIONS:
		var state_prefix: String = CAT_DIRECTION_STATES[direction_name]
		for state in ["idle", "walk"]:
			var animation_name := "%s_%s" % [state, direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, true)
			frames.set_animation_speed(animation_name, 4.0 if state == "idle" else 8.0)
			for frame_index in 4:
				var path := "%s/%s_%s_%d.png" % [CAT_ANIMATION_ROOT, state_prefix, state, frame_index]
				if ResourceLoader.exists(path): frames.add_frame(animation_name, load(path) as Texture2D)
		var roll_animation := "roll_%s" % direction_name
		frames.add_animation(roll_animation)
		frames.set_animation_loop(roll_animation, false)
		frames.set_animation_speed(roll_animation, 10.0)
		for frame_index in 4:
			var roll_path := "%s/%s_action-frame-%d.png" % [CAT_ROLL_ANIMATION_ROOT, state_prefix, frame_index]
			if ResourceLoader.exists(roll_path): frames.add_frame(roll_animation, load(roll_path) as Texture2D)
		# 필드와 동일한 배트 스윙 애니메이션.
		var melee_animation := "melee_%s" % direction_name
		frames.add_animation(melee_animation)
		frames.set_animation_loop(melee_animation, false)
		frames.set_animation_speed(melee_animation, MELEE_ANIMATION_FPS)
		for frame_index in MELEE_FRAME_COUNT:
			var melee_path := "%s/%s_action_%d.png" % [CAT_MELEE_ANIMATION_ROOT, state_prefix, frame_index]
			if ResourceLoader.exists(melee_path): frames.add_frame(melee_animation, load(melee_path) as Texture2D)
	return frames


func _room_display_name(type_name: String) -> String:
	match type_name:
		"meeting": return "회의실"
		"storage": return "창고"
		"server": return "서버실"
		"executive": return "임원실"
	return "사무실"


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * ROOM_STEP.x, 0, float(cell.y) * ROOM_STEP.y)


func _door_side_for_delta(delta: Vector2i) -> String:
	if delta.x > 0: return "east"
	if delta.x < 0: return "west"
	if delta.y > 0: return "south"
	return "north"


func _get_arrival_position(arrival: String) -> Vector3:
	if arrival == "from_below" and not floor_cells.is_empty():
		return _cell_to_world(floor_cells[floor_cells.size() - 1]) + Vector3(0, 0.78, 3.8)
	if arrival == "from_above" and floor_cells.size() >= 2:
		return _cell_to_world(floor_cells[floor_cells.size() - 2]) + Vector3(3.8, 0.78, 0)
	return _cell_to_world(floor_cells[0]) + Vector3(0, 0.78, 0)


func _update_health() -> void:
	if health_bar != null:
		health_bar.value = GameState.player_health
	if ammo_label != null:
		_update_ammo_label()
	_update_player_world_health_bar()
	_update_medkit_button()


func _update_player_world_health_bar() -> void:
	if player_world_health_bar == null or camera == null or player == null:
		return
	var max_health := maxi(1, int(GameState.get_max_health()))
	var health_ratio := clampf(float(GameState.player_health) / float(max_health), 0.0, 1.0)
	player_world_health_fill.size.x = 46.0 * health_ratio
	player_health_fill_style.bg_color = (
		Color(0.88, 0.18, 0.12, 0.98)
		if health_ratio <= 0.3
		else Color(0.94, 0.66, 0.16, 0.98)
		if health_ratio <= 0.6
		else Color(0.28, 0.86, 0.48, 0.96)
	)
	var head_position := camera.unproject_position(player.global_position + Vector3(0, 2.15, 0))
	player_world_health_bar.position = head_position - Vector2(24.0, 3.0)
	player_world_health_bar.visible = not camera.is_position_behind(player.global_position)
	if roll_cooldown_indicator != null:
		# 필드(main.gd)와 같은 문법: 머리 오른쪽 스태미나 링, 가득 차면 숨김.
		var stamina_ratio := clampf(roll_stamina / ROLL_STAMINA_MAX, 0.0, 1.0)
		roll_cooldown_indicator.position = head_position + Vector2(28.0, -8.5)
		roll_cooldown_indicator.call(
			"set_cooldown_progress",
			stamina_ratio,
			roll_active or stamina_ratio < 0.999
		)


func _use_quick_medkit() -> void:
	if int(GameState.medkits) <= 0:
		_show_status("구급약이 없습니다.")
		return
	var max_health := int(GameState.get_max_health())
	if int(GameState.player_health) >= max_health:
		_show_status("체력이 이미 가득 찼습니다.")
		return
	GameState.medkits = maxi(0, int(GameState.medkits) - 1)
	GameState.player_health = mini(max_health, int(GameState.player_health) + 36)
	GameState.save_persistent_state()
	_update_health()
	_show_status("구급약 사용 · 체력 %d/%d" % [GameState.player_health, max_health])
	if DisplayServer.is_touchscreen_available() and bool(accessibility_settings.vibration_enabled):
		Input.vibrate_handheld(18)


func _update_medkit_button() -> void:
	if not is_instance_valid(medkit_button):
		return
	# 필드 _update_medkit_button과 같은 문구.
	medkit_button.text = (
		"구급약\nx%d" % int(GameState.medkits)
		if DisplayServer.is_touchscreen_available()
		else "SHIFT\n구급약 x%d" % int(GameState.medkits)
	)
	medkit_button.disabled = int(GameState.medkits) <= 0


func _apply_mobile_safe_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	game_over_screen.apply_layout(viewport_size)
	var safe := UISafeArea.get_margins(viewport_size)
	var vitals := get_node_or_null("HUD/VitalsPanel") as Control
	if vitals:
		vitals.position = Vector2(18.0 + safe.x, 18.0 + safe.y)
	if is_instance_valid(building_objective_panel):
		building_objective_panel.position = Vector2(18.0 + safe.x, 18.0 + safe.y)
	if is_instance_valid(touch_stick):
		touch_stick.position = Vector2(34.0 + safe.x, -160.0 - safe.w)
	if is_instance_valid(medkit_button):
		medkit_button.position = Vector2(22.0 + safe.x, -96.0 - safe.w)
	if is_instance_valid(equipment_panel):
		# 필드와 같은 204x56 컴팩트 카드. 터치에서는 버튼 두 줄 위로 올린다.
		equipment_panel.offset_right = -20.0 - safe.z
		equipment_panel.offset_left = equipment_panel.offset_right - 204.0
		equipment_panel.offset_bottom = (-292.0 if DisplayServer.is_touchscreen_available() else -124.0) - safe.w
		equipment_panel.offset_top = equipment_panel.offset_bottom - 56.0
	if is_instance_valid(floor_clear_banner):
		floor_clear_banner.offset_top = 82.0 + safe.y
		floor_clear_banner.offset_bottom = 160.0 + safe.y
	var right_positions: Array = [
		[fire_button, Vector2(-108, -104)],
		[melee_button, Vector2(-198, -104)],
		[interact_button, Vector2(-378, -104)],
		[dash_button, Vector2(-288, -104)],
		[reload_button, Vector2(-108, -194)],
		[flashlight_button, Vector2(-198, -194)],
	]
	for entry in right_positions:
		var button := entry[0] as Button
		if is_instance_valid(button):
			var base_position: Vector2 = entry[1]
			button.position = base_position - Vector2(safe.z, safe.w)


func _show_status(message: String) -> void:
	# 필드와 동일한 토스트 스택(RaidHud.push_toast) 경유 — 중앙 상단 한 줄
	# 라벨을 서로 덮어쓰던 방식은 폐지.
	if hud != null:
		hud.push_toast(message)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	return material


func _texture_material(path: String, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
	material.texture_repeat = true
	material.uv1_scale = uv_scale
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _add_plane(parent: Node, node_name: String, position: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_visual_box(parent: Node, node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	instance.mesh = mesh
	parent.add_child(instance)


func _add_static_box(parent: Node, node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	_add_visual_box(parent, "%sVisual" % node_name, position, size, color)
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.position = position
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _add_static_box_material(parent: Node, node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "%sVisual" % node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.position = position
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
