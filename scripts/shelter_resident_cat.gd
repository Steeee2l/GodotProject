class_name ShelterResidentCat
extends CharacterBody3D

const ANIMATION_ROOT := "res://assets/characters/worker_cat"
const KNEADING_ANIMATION_ROOT := "res://assets/characters/worker_cat"
const DIRECTION_NAMES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const DIRECTION_STATES := {
	"n": "up",
	"ne": "up_right",
	"e": "right",
	"se": "down_right",
	"s": "down",
	"sw": "down_left",
	"w": "left",
	"nw": "up_left",
}
const FRAME_COUNT := 4
const KNEADING_FRAME_COUNT := 6
const WALK_SPEED := 3.8
const WANDER_SPEED := 2.15
const WANDER_MIN_WAIT := 1.0
const WANDER_MAX_WAIT := 3.2
const WANDER_RETARGET_TIME := 9.0
const PRODUCTION_POP_INTERVAL := 1.0
const PRODUCTION_POP_HEIGHT := 1.34
const PRODUCTION_POP_DURATION := 1.12
const PRODUCTION_POP_FONT_SIZE := 62
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var resident_id := ""
var assigned_to_scratcher := false
var assignment_kind := "waiting"
var target_position := Vector3.ZERO
var work_focus_position := Vector3.ZERO
var facing := "s"
var motion_state := "idle"
var sprite: AnimatedSprite3D
var work_indicator: Label3D
var work_phase := 0.0
var production_rate_per_second := 0.0
var production_pop_timer := 0.0
var production_pop_sequence := 0
var roam_bounds := Rect2(Vector2(-12.0, -4.0), Vector2(24.0, 12.0))
var wander_wait := 0.0
var wander_retarget_time := 0.0
var wander_random := RandomNumberGenerator.new()


func configure(next_resident_id: String, spawn_position: Vector3) -> void:
	resident_id = next_resident_id
	position = spawn_position
	target_position = spawn_position
	wander_random.seed = hash(resident_id)


func set_roam_bounds(next_bounds: Rect2) -> void:
	roam_bounds = next_bounds
	if assignment_kind == "waiting" and not roam_bounds.has_point(Vector2(target_position.x, target_position.z)):
		_choose_wander_target()


func _ready() -> void:
	add_to_group("shelter_resident")
	set_meta("resident_id", resident_id)
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 0.85
	collision.shape = shape
	add_child(collision)

	sprite = AnimatedSprite3D.new()
	sprite.name = "ResidentSprite"
	sprite.position = Vector3(0, 0.3, 0)
	sprite.sprite_frames = _create_sprite_frames()
	sprite.pixel_size = 0.0092
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = true
	sprite.render_priority = 124
	add_child(sprite)

	work_indicator = Label3D.new()
	work_indicator.name = "WorkIndicator"
	work_indicator.text = ""
	work_indicator.position = Vector3(0, 1.54, 0)
	work_indicator.font = FONT
	work_indicator.font_size = 28
	work_indicator.modulate = Color("#e6c978")
	work_indicator.outline_size = 6
	work_indicator.outline_modulate = Color(0.02, 0.025, 0.02, 0.96)
	work_indicator.no_depth_test = true
	work_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	work_indicator.render_priority = 127
	work_indicator.visible = false
	add_child(work_indicator)
	_play_animation()


func set_work_assignment(next_kind: String, next_target: Vector3, next_work_focus: Vector3, snap := false) -> void:
	var previous_kind := assignment_kind
	assignment_kind = next_kind
	assigned_to_scratcher = assignment_kind == "kneading"
	target_position = next_target
	work_focus_position = next_work_focus
	set_meta("assigned_to_scratcher", assigned_to_scratcher)
	set_meta("assignment_kind", assignment_kind)
	production_pop_timer = 0.18 + float(posmod(hash(resident_id), 5)) * 0.08
	if snap:
		position = target_position
	if assignment_kind == "waiting":
		wander_wait = wander_random.randf_range(WANDER_MIN_WAIT, WANDER_MAX_WAIT)
		wander_retarget_time = WANDER_RETARGET_TIME
		if snap or previous_kind != "waiting":
			_choose_wander_target()
	_play_animation()
	_update_work_indicator()


func _physics_process(delta: float) -> void:
	if assignment_kind == "waiting":
		wander_retarget_time -= delta
		var wander_distance := Vector2(position.x - target_position.x, position.z - target_position.z).length()
		if wander_distance <= 0.22:
			wander_wait -= delta
			if wander_wait <= 0.0:
				_choose_wander_target()
		elif wander_retarget_time <= 0.0:
			_choose_wander_target()
	var offset := target_position - position
	offset.y = 0.0
	if offset.length() > 0.18:
		var direction := offset.normalized()
		velocity = direction * (WANDER_SPEED if assignment_kind == "waiting" else WALK_SPEED)
		_set_facing_from_world_direction(direction)
		_set_motion_state("walk")
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		position.x = move_toward(position.x, target_position.x, delta * 2.8)
		position.z = move_toward(position.z, target_position.z, delta * 2.8)
		_set_motion_state("idle")
		if assignment_kind != "waiting":
			_set_facing_from_world_direction(work_focus_position - position)
	work_phase += delta
	if sprite:
		var work_bob := sin(work_phase * 7.0) * 0.025 if assignment_kind == "catnip" and offset.length() <= 0.18 else 0.0
		sprite.position.y = 0.3 + work_bob
	_update_production_pop(delta)
	_update_work_indicator()


func set_production_feedback(next_rate_per_second: float) -> void:
	production_rate_per_second = maxf(0.0, next_rate_per_second)
	set_meta("production_rate_per_second", production_rate_per_second)
	_update_work_indicator()


func emit_production_feedback_now() -> void:
	if assignment_kind == "waiting" or production_rate_per_second <= 0.0:
		return
	if position.distance_to(target_position) > 0.28:
		return
	_spawn_production_pop()
	production_pop_timer = PRODUCTION_POP_INTERVAL


func _update_production_pop(delta: float) -> void:
	if assignment_kind == "waiting" or production_rate_per_second <= 0.0:
		production_pop_timer = PRODUCTION_POP_INTERVAL
		return
	if position.distance_to(target_position) > 0.28:
		return
	production_pop_timer -= delta
	if production_pop_timer <= 0.0:
		_spawn_production_pop()
		production_pop_timer += PRODUCTION_POP_INTERVAL


func _spawn_production_pop() -> void:
	var is_catnip := assignment_kind == "catnip"
	var color := Color("#aeea78") if is_catnip else Color("#f1cf68")
	var label := Label3D.new()
	label.name = "ProductionGain"
	label.text = "+%s %s" % [
		_format_catnip_rate(production_rate_per_second)
		if is_catnip
		else _format_production_rate(production_rate_per_second),
		"캣닢" if is_catnip else "고철",
	]
	var side_direction := -1.0 if posmod(production_pop_sequence, 2) == 0 else 1.0
	production_pop_sequence += 1
	label.position = Vector3(side_direction * 0.06, 1.82, 0.0)
	label.font = FONT
	label.font_size = PRODUCTION_POP_FONT_SIZE
	label.pixel_size = 0.0056
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.outline_modulate = Color(0.015, 0.02, 0.016, 0.98)
	label.outline_size = 13
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 127
	label.scale = Vector3.ONE * 0.72
	label.set_meta("production_kind", assignment_kind)
	label.set_meta("production_rate", production_rate_per_second)
	label.set_meta("rise_height", PRODUCTION_POP_HEIGHT)
	add_child(label)

	var movement_tween := label.create_tween().set_parallel(true)
	movement_tween.tween_property(
		label,
		"position:y",
		label.position.y + PRODUCTION_POP_HEIGHT,
		PRODUCTION_POP_DURATION
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(
		label,
		"position:x",
		label.position.x + side_direction * 0.18,
		PRODUCTION_POP_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var scale_tween := label.create_tween()
	scale_tween.tween_property(
		label,
		"scale",
		Vector3.ONE * 1.42,
		0.16
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(
		label,
		"scale",
		Vector3.ONE * 1.08,
		0.17
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var visibility_tween := label.create_tween()
	visibility_tween.tween_property(
		label,
		"modulate:a",
		1.0,
		0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visibility_tween.tween_interval(0.48)
	visibility_tween.tween_property(
		label,
		"modulate:a",
		0.0,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	visibility_tween.tween_callback(label.queue_free)


func _format_production_rate(value: float) -> String:
	return GameState.format_compact_number(maxf(1.0, value))


func _format_catnip_rate(value: float) -> String:
	return GameState.format_compact_number(maxf(1.0, value))


func _choose_wander_target() -> void:
	var margin := 0.8
	var minimum := roam_bounds.position + Vector2(margin, margin)
	var maximum := roam_bounds.end - Vector2(margin, margin)
	if maximum.x <= minimum.x or maximum.y <= minimum.y:
		return
	target_position = Vector3(
		wander_random.randf_range(minimum.x, maximum.x),
		position.y,
		wander_random.randf_range(minimum.y, maximum.y)
	)
	wander_wait = wander_random.randf_range(WANDER_MIN_WAIT, WANDER_MAX_WAIT)
	wander_retarget_time = WANDER_RETARGET_TIME


func _update_work_indicator() -> void:
	if work_indicator:
		var arrived := position.distance_to(target_position) <= 0.28
		work_indicator.visible = assignment_kind != "waiting" and arrived
		if assignment_kind != "waiting":
			var resource_name := "캣닢" if assignment_kind == "catnip" else "고철"
			if production_rate_per_second > 0.0:
				work_indicator.text = "%s +%s/s" % [
					resource_name,
					_format_catnip_rate(production_rate_per_second)
					if assignment_kind == "catnip"
					else _format_production_rate(production_rate_per_second),
				]
				work_indicator.modulate = (
					Color("#aeea78") if assignment_kind == "catnip" else Color("#f1cf68")
				)
			else:
				work_indicator.text = "생산 중단 · 통조림 필요"
				work_indicator.modulate = Color("#e7836f")
		work_indicator.modulate.a = 0.72 + sin(work_phase * 4.2) * 0.18


func _set_facing_from_world_direction(world_direction: Vector3) -> void:
	if world_direction.length_squared() <= 0.01:
		return
	var screen_direction := Vector2(
		world_direction.x - world_direction.z,
		world_direction.x + world_direction.z
	).normalized()
	var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
	var index := int(round(angle / 45.0)) % DIRECTION_NAMES.size()
	_set_facing(DIRECTION_NAMES[index])


func _set_facing(next_facing: String) -> void:
	if facing == next_facing:
		return
	facing = next_facing
	_play_animation()


func _set_motion_state(next_state: String) -> void:
	if motion_state == next_state:
		return
	motion_state = next_state
	_play_animation()


func _play_animation() -> void:
	if sprite:
		sprite.flip_h = false
		sprite.rotation = Vector3.ZERO
		var arrived := position.distance_to(target_position) <= 0.28
		if assignment_kind == "kneading" and motion_state == "idle" and arrived:
			sprite.play("kneading_ne")
		else:
			sprite.play("%s_%s" % [motion_state, facing])


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in DIRECTION_NAMES:
		var state_prefix: String = DIRECTION_STATES[direction_name]
		for state in ["idle", "walk"]:
			var animation_name := "%s_%s" % [state, direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, true)
			frames.set_animation_speed(animation_name, 5.5 if state == "idle" else 8.0)
			for frame_index in FRAME_COUNT:
				var texture_path := "%s/%s_%s-frame-%d.png" % [
					ANIMATION_ROOT,
					state_prefix,
					state,
					frame_index,
				]
				var texture := load(texture_path) as Texture2D
				if texture:
					frames.add_frame(animation_name, texture)
				else:
					push_error("Missing shelter resident frame: %s" % texture_path)
	frames.add_animation("kneading_ne")
	frames.set_animation_loop("kneading_ne", true)
	frames.set_animation_speed("kneading_ne", 8.0)
	for frame_index in KNEADING_FRAME_COUNT:
		var texture_path := "%s/kneading_ne_%d.png" % [KNEADING_ANIMATION_ROOT, frame_index]
		var texture := load(texture_path) as Texture2D
		if texture:
			frames.add_frame("kneading_ne", texture)
		else:
			push_error("Missing worker kneading frame: %s" % texture_path)
	return frames
