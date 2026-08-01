extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const SPRITE_ROOT := "res://assets/generated/sprites/character-11/curated"
const IDLE_FRAME_COUNT := 4

var trainer_sprite: AnimatedSprite3D


func _ready() -> void:
    name = "ShelterIronTrainer"
    add_to_group("shelter_iron_trainer")
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
    trainer_sprite.sprite_frames = _build_idle_frames()
    add_child(trainer_sprite)
    trainer_sprite.play("idle_down_left")

    _add_label("철근", Vector3(0.0, 2.50, 0.0), 44, Color("#f4d778"))
    _add_label("특수 생존 훈련 교관", Vector3(0.0, 2.22, 0.0), 28, Color("#b9d8ca"))

    var body := StaticBody3D.new()
    body.name = "TrainerBody"
    body.collision_layer = 1
    body.collision_mask = 1
    add_child(body)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.52
    shape.height = 1.7
    collision.shape = shape
    body.add_child(collision)


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


func _build_idle_frames() -> SpriteFrames:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    frames.add_animation("idle_down_left")
    frames.set_animation_loop("idle_down_left", true)
    frames.set_animation_speed("idle_down_left", 3.0)
    for frame_index in IDLE_FRAME_COUNT:
        var path := "%s/down_left_idle-frame-%d.png" % [SPRITE_ROOT, frame_index]
        var texture := load(path) as Texture2D
        if texture != null:
            frames.add_frame("idle_down_left", texture)
    return frames
