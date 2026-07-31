extends Node3D

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const SPRITE_ROOT := "res://assets/generated/sprites/character-11/curated"
const IDLE_FRAME_COUNT := 4

var trainer_sprite: AnimatedSprite3D


func _ready() -> void:
	name = "ShelterContractTrainer"
	add_to_group("shelter_contract_agent")
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

	var nameplate := Label3D.new()
	nameplate.name = "ContractAgentName"
	nameplate.text = "훈련교관 철근"
	nameplate.position = Vector3(0.0, 2.50, 0.0)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.render_priority = 127
	nameplate.font = FONT
	nameplate.font_size = 44
	nameplate.pixel_size = 0.0060
	nameplate.modulate = Color("#f4d778")
	nameplate.outline_modulate = Color(0.01, 0.016, 0.014, 0.96)
	nameplate.outline_size = 13
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nameplate)

	var roleplate := Label3D.new()
	roleplate.name = "ContractAgentRole"
	roleplate.text = "현장 계약 담당"
	roleplate.position = Vector3(0.0, 2.22, 0.0)
	roleplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	roleplate.no_depth_test = true
	roleplate.render_priority = 127
	roleplate.font = FONT
	roleplate.font_size = 28
	roleplate.pixel_size = 0.0056
	roleplate.modulate = Color("#b9d8ca")
	roleplate.outline_modulate = Color(0.01, 0.016, 0.014, 0.96)
	roleplate.outline_size = 11
	roleplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(roleplate)

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
	var state := GameState.get_contract_state()
	match str(state.get("status", "available")):
		"active":
			return "철근에게 중간 보고"
		"complete":
			return "철근에게 결과 보고"
		"finished":
			return "철근과 해금된 기록 이야기"
		_:
			return "철근의 다음 계약 듣기"


func get_interaction_radius() -> float:
	return 2.35


func get_portrait_texture() -> Texture2D:
	return load("%s/down_left_idle-frame-0.png" % SPRITE_ROOT) as Texture2D


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
