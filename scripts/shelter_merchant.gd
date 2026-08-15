extends Node3D

const MERCHANT_TEXTURE := preload("res://assets/characters/merchant_cat/merchant_down_left_idle.png")
const FRAME_COUNT := 4

var merchant_sprite: AnimatedSprite3D


func _ready() -> void:
	name = "ShelterMerchant"
	add_to_group("shelter_merchant")
	merchant_sprite = AnimatedSprite3D.new()
	merchant_sprite.name = "MerchantSprite"
	merchant_sprite.position = Vector3(0.0, 0.32, 0.0)
	merchant_sprite.pixel_size = 0.0095
	merchant_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	merchant_sprite.shaded = false
	merchant_sprite.transparent = true
	merchant_sprite.no_depth_test = true
	merchant_sprite.render_priority = 126
	merchant_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	merchant_sprite.sprite_frames = _build_idle_frames()
	add_child(merchant_sprite)
	merchant_sprite.play("idle_down_left")

	var body := StaticBody3D.new()
	body.name = "MerchantBody"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.35
	collision.shape = shape
	body.add_child(collision)


func get_interaction_prompt() -> String:
	return "행상인과 거래하기"


func get_interaction_radius() -> float:
	return 2.15


func _build_idle_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle_down_left")
	frames.set_animation_loop("idle_down_left", true)
	frames.set_animation_speed("idle_down_left", 2.8)
	var frame_width := float(MERCHANT_TEXTURE.get_width()) / float(FRAME_COUNT)
	for frame_index in FRAME_COUNT:
		frames.add_frame(
			"idle_down_left",
			_atlas_region(Rect2(frame_width * frame_index, 0.0, frame_width, MERCHANT_TEXTURE.get_height()))
		)
	return frames


func _atlas_region(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = MERCHANT_TEXTURE
	texture.region = region
	return texture
