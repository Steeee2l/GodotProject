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
# 앉아 쉬는 포즈. 새 아트를 그리지 않고 웅크린 주민 스프라이트를 재사용한다 —
# 털색이 작업 고양이와 같아서 "다른 캐릭터"로 안 읽히고 실루엣만 확 달라진다.
const REST_ANIMATION_ROOT := "res://assets/characters/cowering_resident"
const REST_TEXTURE_NAMES := {
	"n": "up_action-frame-0",
	"ne": "up_right_action-frame-0",
	"e": "right_action-frame-3",
	"se": "down_right_action-frame-1",
	"s": "down_action-frame-2",
	"sw": "down_left_action-frame-2",
	"w": "left_action-frame-3",
	"nw": "up_left_action-frame-0",
}
const WALK_SPEED := 3.8
const WANDER_SPEED := 2.15
const WANDER_MIN_WAIT := 1.0
const WANDER_MAX_WAIT := 3.2
const WANDER_RETARGET_TIME := 9.0
# 대기 주민이 자기 자리 주변에서만 서성이는 반경(m). 예전처럼 방 전체를
# 목적지로 삼으면 애써 만든 무리가 몇 초 만에 균일 분포로 풀어진다.
# 배치 최소 간격(0.42m)의 절반 아래로 잡아야 이웃과 겹쳐 서지 않는다.
const WAITING_HOME_RADIUS := 0.2
# 좌석에 "도착했다"고 볼 거리. 머리 위 생산 표시와 생산 팝업이 이걸 본다.
const WORK_ARRIVAL_RADIUS := 0.5
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
# 대기 무리가 잡아 준 "내 자리". 배회는 이 점 주변으로만 돈다.
var home_position := Vector3.ZERO
# 대기 포즈("stand" / "rest")와 대기 중 바라보는 방향. 호스트가 무리 배치와
# 함께 정해 준다(set_waiting_pose).
var waiting_pose := "stand"
var waiting_facing := "s"
# ── 개체 다양성(비용 0) ────────────────────────────────────
# 같은 프레임·같은 속도·같은 방향으로 서 있으면 120마리는 타일 무늬가 된다.
# 주민 id 해시로 시작 프레임·재생 속도·초기 방향만 흩어 준다.
var personal_speed_scale := 1.0
var animation_frame_offset := 0
var animation_phase_offset := 0.0
var current_animation := ""
# 꾹꾹이 작업조 전원이 같은 kneading_ne 한 장을 돌리면 100마리가 한 덩어리
# 무늬가 된다. 일부는 작업 구역을 바라보고 서 있게 해서 실루엣을 깬다.
var kneading_pose := true
# 캣닢 피버 동안 걸리는 체감 배속(이동·애니메이션·생산 팝업이 함께 빨라진다).
var fever_speed_scale := 1.0
# 생산 팝업(+고철) 허용 여부. 주민이 100명을 넘으면 똑같은 숫자가 100개 떠올라
# 화면이 읽히지 않을뿐더러, Label3D + 트윈 3개가 매초 100세트씩 생긴다.
# 호스트가 앞쪽 몇 명에게만 켜 준다(shelter_interior.PRODUCTION_POP_VISIBLE_LIMIT).
var production_pop_enabled := true
# 작업 라벨 문구 캐시. 매 물리 프레임 문자열을 다시 만들면 120명 규모에서
# 초당 7천 번 포맷이 돈다.
var work_indicator_cache := ""
# SpriteFrames는 주민마다 다시 만들 이유가 없다(70프레임 × 인원). 한 벌을
# 만들어 전원이 공유한다 — 재생 위치는 AnimatedSprite3D가 각자 들고 있다.
static var shared_sprite_frames: SpriteFrames


func configure(next_resident_id: String, spawn_position: Vector3) -> void:
	resident_id = next_resident_id
	position = spawn_position
	target_position = spawn_position
	home_position = spawn_position
	wander_random.seed = hash(resident_id)
	# 외형 난수는 배회 난수와 분리한다 — 같은 스트림을 쓰면 배회 한 번에
	# 외형 시드가 밀려서 재진입 때 다른 고양이가 된다.
	var look_random := RandomNumberGenerator.new()
	look_random.seed = hash("resident_look_%s" % resident_id)
	personal_speed_scale = look_random.randf_range(0.9, 1.1)
	animation_frame_offset = look_random.randi_range(0, FRAME_COUNT - 1)
	animation_phase_offset = look_random.randf()
	facing = DIRECTION_NAMES[look_random.randi_range(0, DIRECTION_NAMES.size() - 1)]
	waiting_facing = facing
	kneading_pose = look_random.randf() < 0.7


func set_waiting_pose(next_facing: String, rest: bool) -> void:
	# 무리 배치가 정해 준 "어디를 보고 있나 / 앉아 쉬고 있나". 대기 상태에서만 쓴다.
	if DIRECTION_STATES.has(next_facing):
		waiting_facing = next_facing
	waiting_pose = "rest" if rest else "stand"


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
		home_position = target_position
		facing = waiting_facing
		wander_wait = wander_random.randf_range(WANDER_MIN_WAIT, WANDER_MAX_WAIT)
		wander_retarget_time = WANDER_RETARGET_TIME
		if waiting_pose == "rest":
			# 앉아 쉬는 고양이는 자리를 뜨지 않는다 — 무리에 정지점이 있어야
			# 전체가 술렁이는 게 아니라 "모여서 쉬는 무리"로 읽힌다.
			target_position = home_position
		elif snap or previous_kind != "waiting":
			_choose_wander_target()
	_play_animation()
	_update_work_indicator()


func set_production_pop_enabled(value: bool) -> void:
	production_pop_enabled = value
	if not value:
		production_pop_timer = PRODUCTION_POP_INTERVAL


func set_fever_speed_scale(value: float) -> void:
	# 피버는 눈으로 먼저 읽혀야 한다 — 생산 수치보다 "다들 미쳐 날뛴다"가 먼저다.
	fever_speed_scale = clampf(value, 0.1, 6.0)
	if sprite != null:
		sprite.speed_scale = fever_speed_scale * personal_speed_scale


func _physics_process(raw_delta: float) -> void:
	var delta := raw_delta * fever_speed_scale
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
		velocity = (
			direction
			* (WANDER_SPEED if assignment_kind == "waiting" else WALK_SPEED)
			* fever_speed_scale
		)
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
	if not production_pop_enabled:
		return
	if assignment_kind == "waiting" or production_rate_per_second <= 0.0:
		return
	if position.distance_to(target_position) > WORK_ARRIVAL_RADIUS:
		return
	_spawn_production_pop()
	production_pop_timer = PRODUCTION_POP_INTERVAL


func _update_production_pop(delta: float) -> void:
	if not production_pop_enabled:
		return
	if assignment_kind == "waiting" or production_rate_per_second <= 0.0:
		production_pop_timer = PRODUCTION_POP_INTERVAL
		return
	if position.distance_to(target_position) > WORK_ARRIVAL_RADIUS:
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
	# 숫자가 클수록 팝도 커진다 — 자릿수(log10)당 +16%. 스탯 패널의 "+N 고철"
	# 표시를 없앤 대신 여기가 수입 성장의 체감을 전담한다(인크리멘탈의 심장).
	# 1/s ≈ x0.9, 100/s ≈ x1.2, 10K/s ≈ x1.5, 1M/s ≈ x1.9.
	var magnitude := clampf(
		log(maxf(production_rate_per_second, 1.0)) / log(10.0), 0.0, 6.0
	)
	var pop_scale := 0.9 + 0.16 * magnitude
	label.scale = Vector3.ONE * (pop_scale * 0.7)
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
		Vector3.ONE * (pop_scale * 1.35),
		0.16
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(
		label,
		"scale",
		Vector3.ONE * pop_scale,
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
	# 배회는 "내 자리 주변 한 걸음"이다. 방 전체를 목적지로 삼던 예전 코드는
	# 무리 배치를 몇 초 만에 균일 분포로 풀어 버렸다.
	wander_wait = wander_random.randf_range(WANDER_MIN_WAIT, WANDER_MAX_WAIT)
	wander_retarget_time = WANDER_RETARGET_TIME
	if waiting_pose == "rest":
		target_position = home_position
		return
	var margin := 0.8
	var minimum := roam_bounds.position + Vector2(margin, margin)
	var maximum := roam_bounds.end - Vector2(margin, margin)
	if maximum.x <= minimum.x or maximum.y <= minimum.y:
		return
	var angle := wander_random.randf() * TAU
	var radius := sqrt(wander_random.randf()) * WAITING_HOME_RADIUS
	target_position = Vector3(
		clampf(home_position.x + cos(angle) * radius, minimum.x, maximum.x),
		position.y,
		clampf(home_position.z + sin(angle) * radius, minimum.y, maximum.y)
	)


func _update_work_indicator() -> void:
	if work_indicator == null:
		return
	# 도착 판정 0.28 → 0.5. 좌석이 촘촘해지면서(0.66 간격) 마지막 한 뼘을
	# 좁히는 데 시간이 걸리는데, 그동안 머리 위 생산 표시가 통째로 사라져
	# "생산량이 안 보인다"(유저 신고)가 됐다. 자리 간격의 절반보다 작게 두면
	# 옆자리 고양이와 헷갈릴 일도 없다.
	var arrived := position.distance_to(target_position) <= WORK_ARRIVAL_RADIUS
	work_indicator.visible = assignment_kind != "waiting" and arrived
	if not work_indicator.visible:
		return
	var resource_name := "캣닢" if assignment_kind == "catnip" else "고철"
	var next_text := "생산 대기"
	var next_color := Color("#e7836f")
	if production_rate_per_second > 0.0:
		next_text = "%s +%s/s" % [
			resource_name,
			_format_catnip_rate(production_rate_per_second)
			if assignment_kind == "catnip"
			else _format_production_rate(production_rate_per_second),
		]
		next_color = Color("#aeea78") if assignment_kind == "catnip" else Color("#f1cf68")
	# 문구가 그대로면 텍스트를 다시 넣지 않는다(라벨 메시 재생성 방지).
	if next_text != work_indicator_cache:
		work_indicator_cache = next_text
		work_indicator.text = next_text
	# 알파 맥박은 앞줄(팝업이 켜진) 고양이에게만. 120마리가 매 프레임 Label3D
	# 머티리얼을 건드리면 그것만으로 물리 프레임이 밀린다.
	next_color.a = 0.72 + sin(work_phase * 4.2) * 0.18 if production_pop_enabled else 0.82
	if work_indicator.modulate != next_color:
		work_indicator.modulate = next_color


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
	if sprite == null:
		return
	sprite.flip_h = false
	sprite.rotation = Vector3.ZERO
	var arrived := position.distance_to(target_position) <= 0.28
	var next_animation := "%s_%s" % [motion_state, facing]
	if assignment_kind == "kneading" and motion_state == "idle" and arrived and kneading_pose:
		next_animation = "kneading_ne"
	elif assignment_kind == "waiting" and waiting_pose == "rest" and motion_state == "idle" and arrived:
		next_animation = "rest_%s" % facing
	if next_animation == current_animation:
		return
	current_animation = next_animation
	sprite.play(next_animation)
	# 같은 애니메이션을 100마리가 같은 프레임으로 돌리면 그건 무리가 아니라
	# 타일 무늬다. 시작 프레임·위상·재생 속도만 흩어도 "숨 쉬는 무리"가 된다.
	var frame_total := sprite.sprite_frames.get_frame_count(next_animation)
	if frame_total > 1:
		sprite.frame = animation_frame_offset % frame_total
		sprite.frame_progress = animation_phase_offset
	sprite.speed_scale = fever_speed_scale * personal_speed_scale


func _create_sprite_frames() -> SpriteFrames:
	if shared_sprite_frames != null:
		return shared_sprite_frames
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
		# 앉아 쉬는 포즈는 방향마다 한 장(정지)이면 충분하다.
		var rest_animation_name := "rest_%s" % direction_name
		frames.add_animation(rest_animation_name)
		frames.set_animation_loop(rest_animation_name, true)
		frames.set_animation_speed(rest_animation_name, 1.0)
		var rest_path := "%s/%s.png" % [REST_ANIMATION_ROOT, REST_TEXTURE_NAMES[direction_name]]
		var rest_texture := load(rest_path) as Texture2D
		if rest_texture:
			frames.add_frame(rest_animation_name, rest_texture)
		else:
			push_error("Missing shelter resident rest frame: %s" % rest_path)
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
	shared_sprite_frames = frames
	return frames
