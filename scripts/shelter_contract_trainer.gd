extends CharacterBody3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const SPRITE_ROOT := "res://assets/sprites/trainer_curated"
const FRAME_COUNT := 4
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
const WANDER_SPEED := 1.7
const WANDER_RADIUS := 5.2
const WANDER_MIN_WAIT := 2.4
const WANDER_MAX_WAIT := 6.5
const PLAYER_GREET_RANGE := 3.2

var trainer_sprite: AnimatedSprite3D
var home_position := Vector3.ZERO
var target_position := Vector3.ZERO
var facing := "sw"
var motion_state := "idle"
var wander_wait := 1.5
var wander_random := RandomNumberGenerator.new()
var player_target: Node3D


func _ready() -> void:
    name = "ShelterIronTrainer"
    add_to_group("shelter_iron_trainer")
    collision_layer = 1
    collision_mask = 1
    home_position = position
    target_position = position
    wander_random.seed = hash("iron_trainer")

    trainer_sprite = AnimatedSprite3D.new()
    trainer_sprite.name = "TrainerSprite"
    trainer_sprite.position = Vector3(0.0, 0.46, 0.0)
    trainer_sprite.pixel_size = 0.0144
    trainer_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    trainer_sprite.shaded = false
    trainer_sprite.transparent = true
    trainer_sprite.no_depth_test = true
    trainer_sprite.render_priority = 126
    trainer_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    trainer_sprite.sprite_frames = _build_sprite_frames()
    add_child(trainer_sprite)
    _play_animation()

    _add_label("철근", Vector3(0.0, 2.50, 0.0), 44, Color("#f4d778"))
    _add_label("특수 생존 훈련 교관", Vector3(0.0, 2.22, 0.0), 28, Color("#b9d8ca"))

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.2
    collision.shape = shape
    add_child(collision)


func set_player_target(next_player: Node3D) -> void:
    player_target = next_player


func _physics_process(delta: float) -> void:
    # 플레이어가 다가오면 멈춰 서서 마주 본다 — 대화하러 온 상대를 두고 걸어가지 않는다.
    if is_instance_valid(player_target):
        var to_player := player_target.global_position - global_position
        to_player.y = 0.0
        if to_player.length() <= PLAYER_GREET_RANGE:
            velocity = Vector3.ZERO
            target_position = position
            wander_wait = wander_random.randf_range(WANDER_MIN_WAIT, WANDER_MAX_WAIT)
            _set_facing_from_world_direction(to_player)
            _set_motion_state("idle")
            return
    var offset := target_position - position
    offset.y = 0.0
    if offset.length() > 0.2:
        var direction := offset.normalized()
        velocity = direction * WANDER_SPEED
        _set_facing_from_world_direction(direction)
        _set_motion_state("walk")
        move_and_slide()
        # 벽이나 기물에 막히면 그 자리를 목적지로 인정하고 쉰다.
        if get_slide_collision_count() > 0 and velocity.length() < WANDER_SPEED * 0.3:
            target_position = position
    else:
        velocity = Vector3.ZERO
        _set_motion_state("idle")
        wander_wait -= delta
        if wander_wait <= 0.0:
            _choose_wander_target()


func _choose_wander_target() -> void:
    var angle := wander_random.randf_range(0.0, TAU)
    var distance := wander_random.randf_range(1.4, WANDER_RADIUS)
    target_position = home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
    wander_wait = wander_random.randf_range(WANDER_MIN_WAIT, WANDER_MAX_WAIT)


func get_interaction_prompt() -> String:
    var state: Dictionary = GameState.get_iron_mission_state()
    match str(state.get("status", "available")):
        "active":
            return "철근에게 훈련 진행 보고"
        "complete":
            return "철근에게 시험 결과 보고"
        "finished":
            return "철근과 생존 훈련 이야기하기"
        _:
            return "철근의 특별 훈련 받기"


func get_interaction_radius() -> float:
    return 2.45


func get_portrait_texture() -> Texture2D:
    return load("%s/down_left_idle-frame-0.png" % SPRITE_ROOT) as Texture2D


func _set_facing_from_world_direction(world_direction: Vector3) -> void:
    if world_direction.length_squared() <= 0.01:
        return
    var screen_direction := Vector2(
        world_direction.x - world_direction.z,
        world_direction.x + world_direction.z
    ).normalized()
    var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
    var index := int(round(angle / 45.0)) % DIRECTION_NAMES.size()
    if DIRECTION_NAMES[index] != facing:
        facing = DIRECTION_NAMES[index]
        _play_animation()


func _set_motion_state(next_state: String) -> void:
    if motion_state == next_state:
        return
    motion_state = next_state
    _play_animation()


func _play_animation() -> void:
    if trainer_sprite:
        trainer_sprite.play("%s_%s" % [motion_state, facing])


func _add_label(text: String, label_position: Vector3, font_size: int, color: Color) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = label_position
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.render_priority = 127
    label.font = FONT
    label.font_size = font_size
    label.pixel_size = 0.0060 if font_size >= 40 else 0.0056
    label.modulate = color
    label.outline_modulate = Color(0.01, 0.016, 0.014, 0.96)
    label.outline_size = 13 if font_size >= 40 else 11
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(label)


func _build_sprite_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for direction_name in DIRECTION_NAMES:
        var state_prefix: String = DIRECTION_STATES[direction_name]
        for state in ["idle", "walk"]:
            var animation_name := "%s_%s" % [state, direction_name]
            frames.add_animation(animation_name)
            frames.set_animation_loop(animation_name, true)
            frames.set_animation_speed(animation_name, 3.0 if state == "idle" else 6.0)
            for frame_index in FRAME_COUNT:
                var path := "%s/%s_%s-frame-%d.png" % [SPRITE_ROOT, state_prefix, state, frame_index]
                var texture := load(path) as Texture2D
                if texture != null:
                    frames.add_frame(animation_name, texture)
    return frames
