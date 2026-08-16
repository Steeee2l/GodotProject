extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const DIRECTION_STATES: Array[String] = [
    "down",
    "down_right",
    "right",
    "up_right",
    "up",
    "up_left",
    "left",
    "down_left",
]
const SCREEN_DIRECTION_STATES: Array[String] = [
    "up",
    "up_right",
    "right",
    "down_right",
    "down",
    "down_left",
    "left",
    "up_left",
]
const FRAME_COUNT := 4

var character_id := "story_character"
var display_name := "이름 없는 고양이"
var role_name := "쉘터 방문자"
var interaction_prompt := "대화하기"
var animation_root := ""
var facing_direction := "down_left"
var world_pixel_size := 0.0105
var player_target: Node3D
var sprite: AnimatedSprite3D
var nameplate: Label3D
var roleplate: Label3D
var _last_animation := ""
# 현재 재생 중인 동작. 방향이 바뀔 때마다 무조건 idle로 되돌리면 연출 중 걸어오는
# 도중에 사지가 얼어붙는다 — 방향만 갈아 끼우고 동작은 유지한다.
var _current_motion := "idle"
# 연출용 이동 중에는 플레이어 쪽을 쳐다보는 상시 로직을 끄고, 실제 진행 방향을 본다.
var _scripted_walk := false
var _scripted_previous_position := Vector3.ZERO


func configure(
    next_character_id: String,
    next_display_name: String,
    next_role_name: String,
    next_interaction_prompt: String,
    next_animation_root: String,
    next_facing_direction: String = "down_left",
    next_pixel_size: float = 0.0105
) -> void:
    character_id = next_character_id
    display_name = next_display_name
    role_name = next_role_name
    interaction_prompt = next_interaction_prompt
    animation_root = next_animation_root
    facing_direction = next_facing_direction
    world_pixel_size = next_pixel_size


func _ready() -> void:
    name = "%sStoryCharacter" % character_id.capitalize()
    add_to_group("shelter_story_character")
    if character_id == "saja":
        add_to_group("shelter_contract_agent")
    elif character_id == "juhong":
        add_to_group("shelter_story_visitor")
    set_meta("character_id", character_id)
    _build_visual()
    _build_collision()
    _play_animation("idle")


func _physics_process(_delta: float) -> void:
    if _scripted_walk:
        # 걸어오는 동안은 "가는 쪽"을 본다. 그래야 옆모습·뒷모습이 제대로 나온다.
        var step: Vector3 = global_position - _scripted_previous_position
        step.y = 0.0
        _scripted_previous_position = global_position
        if step.length_squared() > 0.000004:
            set_facing_from_world_direction(step)
        return
    if not is_instance_valid(player_target):
        return
    var offset: Vector3 = player_target.global_position - global_position
    offset.y = 0.0
    if offset.length_squared() <= 0.04 or offset.length() > 6.0:
        return
    set_facing_from_world_direction(offset)


func set_player_target(target: Node3D) -> void:
    player_target = target


func begin_scripted_walk() -> void:
    # 시네마틱이 global_position을 트윈으로 끌고 가는 동안 호출한다.
    _scripted_walk = true
    _scripted_previous_position = global_position
    play_motion("walk")


func end_scripted_walk() -> void:
    _scripted_walk = false
    play_motion("idle")


func play_motion(motion: String) -> void:
    _play_animation(motion)


func set_facing_from_world_direction(direction: Vector3) -> void:
    if direction.length_squared() <= 0.001:
        return
    var screen_direction := Vector2(
        direction.x - direction.z,
        direction.x + direction.z
    ).normalized()
    var angle := fposmod(rad_to_deg(atan2(screen_direction.x, -screen_direction.y)), 360.0)
    var index := int(round(angle / 45.0)) % 8
    var next_direction := SCREEN_DIRECTION_STATES[index]
    if next_direction == facing_direction:
        return
    facing_direction = next_direction
    _play_animation(_current_motion)


func get_interaction_prompt() -> String:
    return interaction_prompt


func get_interaction_radius() -> float:
    return 2.45


func get_portrait_texture() -> Texture2D:
    return load("%s/down_idle-frame-0.png" % animation_root) as Texture2D


func _build_visual() -> void:
    sprite = AnimatedSprite3D.new()
    sprite.name = "CharacterSprite"
    sprite.position = Vector3(0.0, 0.52, 0.0)
    sprite.pixel_size = world_pixel_size
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.shaded = false
    sprite.transparent = true
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
    sprite.no_depth_test = true
    sprite.render_priority = 126
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sprite.sprite_frames = _build_sprite_frames()
    add_child(sprite)

    # 주민 잡담 말풍선 확대(60pt)에 맞춰 소폭 상향 — 화면 전체 라벨 비율 유지.
    nameplate = _label3d(display_name, Vector3(0.0, 2.22, 0.0), 48, Color("#f0d27b"))
    nameplate.name = "CharacterName"
    add_child(nameplate)
    roleplate = _label3d(role_name, Vector3(0.0, 1.92, 0.0), 30, Color("#b7d8c8"))
    roleplate.name = "CharacterRole"
    add_child(roleplate)


func _build_collision() -> void:
    var body := StaticBody3D.new()
    body.name = "CharacterBody"
    body.collision_layer = 1
    body.collision_mask = 1
    add_child(body)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.42
    shape.height = 1.25
    collision.shape = shape
    body.add_child(collision)


func _build_sprite_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for direction in DIRECTION_STATES:
        for motion in ["idle", "walk"]:
            var animation_name := "%s_%s" % [motion, direction]
            frames.add_animation(animation_name)
            frames.set_animation_loop(animation_name, true)
            frames.set_animation_speed(animation_name, 3.0 if motion == "idle" else 7.0)
            for frame_index in range(FRAME_COUNT):
                var frame_path := "%s/%s_%s-frame-%d.png" % [
                    animation_root,
                    direction,
                    motion,
                    frame_index,
                ]
                var texture := load(frame_path) as Texture2D
                if texture != null:
                    frames.add_frame(animation_name, texture)
    return frames


func _play_animation(motion: String) -> void:
    _current_motion = motion
    if not is_instance_valid(sprite):
        return
    var animation_name := "%s_%s" % [motion, facing_direction]
    if animation_name == _last_animation:
        return
    if sprite.sprite_frames.has_animation(animation_name):
        _last_animation = animation_name
        sprite.play(animation_name)


func _label3d(text_value: String, local_position: Vector3, size: int, color: Color) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.position = local_position
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.render_priority = 127
    label.font = FONT
    label.font_size = size
    label.pixel_size = 0.0056
    label.modulate = color
    label.outline_modulate = Color(0.01, 0.016, 0.014, 0.96)
    label.outline_size = 11
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return label
