extends Node3D

const ELEVATOR_TEXTURE_PATH := "res://assets/interiors/office_dungeon/modules/wall_elevator_front_v2.png"
const COLLISION_PROFILES := preload("res://scripts/collision_profile_catalog.gd")

signal activated(action: String)

var transition_kind := "elevator_up"
var target_floor := 2
var display_label := "엘리베이터"


func configure(kind: String, floor_number: int, label_text: String = "") -> void:
	transition_kind = kind
	target_floor = floor_number
	display_label = label_text if not label_text.is_empty() else kind
	set_meta("transition_kind", transition_kind)
	set_meta("target_floor", target_floor)


func _ready() -> void:
	add_to_group("building_interactable")
	add_to_group("building_transition_module")
	if transition_kind.begins_with("elevator"):
		add_to_group("building_elevator_module")
	_build_visual()


func get_interaction_radius() -> float:
	return 2.4


func get_interaction_prompt() -> String:
	return display_label


func interact() -> String:
	activated.emit(transition_kind)
	return display_label


func _build_visual() -> void:
	if transition_kind.begins_with("elevator"):
		_build_generated_elevator()
		return
	var accent := Color("#d3a84f")
	if transition_kind == "exit": accent = Color("#63c997")
	elif transition_kind.begins_with("stairs"): accent = Color("#91a9bc")
	_add_box("PortalFrame", Vector3(0, 1.35, 0), Vector3(2.7, 2.7, 0.42), Color("#343b3f"), true)
	_add_box("PortalInset", Vector3(0, 1.35, 0.24), Vector3(1.9, 2.15, 0.08), Color("#171d20"), false)
	_add_box("PortalAccent", Vector3(0, 2.25, 0.3), Vector3(1.25, 0.09, 0.05), accent, false)
	var marker := Label3D.new()
	marker.name = "TransitionLabel"
	marker.position = Vector3(0, 2.85, 0.15)
	marker.text = display_label
	marker.font_size = 34
	marker.modulate = Color("#e7e4d9")
	marker.outline_size = 8
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	add_child(marker)


func _build_generated_elevator() -> void:
	var sprite := Sprite3D.new()
	sprite.name = "GeneratedElevatorVisual"
	sprite.texture = load(ELEVATOR_TEXTURE_PATH) as Texture2D
	sprite.position = Vector3(0, 2.6, 0.12)
	sprite.pixel_size = 0.0034
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(sprite)
	var body := StaticBody3D.new()
	body.name = "ElevatorDoorCollision"
	body.position = Vector3(0, 1.45, 0)
	body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 2.9, 0.38)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var marker := Label3D.new()
	marker.name = "TransitionLabel"
	marker.position = Vector3(0, 3.75, 0.15)
	marker.text = display_label
	marker.font_size = 30
	marker.modulate = Color("#e7e4d9")
	marker.outline_size = 8
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	add_child(marker)


func _add_box(node_name: String, local_position: Vector3, size: Vector3, color: Color, collision_enabled: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material = material
	instance.mesh = mesh
	add_child(instance)
	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		body.position = local_position
		body.collision_layer = COLLISION_PROFILES.WORLD_MOVEMENT_LAYER | COLLISION_PROFILES.WORLD_PROJECTILE_LAYER
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
