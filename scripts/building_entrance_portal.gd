extends Area3D

const BUILDING_SCENE := preload("res://scenes/building_interior.tscn")

@export var building_id := "office_tower"
@export var seed_offset := 0
@export_range(2, 12, 1) var floor_count := 5
@export var return_offset := Vector3(0.0, 0.0, 2.2)

var nearby_player: Node3D
var portal_marker: MeshInstance3D
var prompt: Label3D
var transition_pending := false
@onready var BuildingRunState: Node = get_node("/root/BuildingRunState")
@onready var GameState: Node = get_node("/root/GameState")


func _ready() -> void:
	add_to_group("building_entrance_portal")
	add_to_group("field_interaction")
	set_meta("interaction_type", "building_portal")
	set_meta("display_name", "빌딩 진입")
	set_meta("hold_duration", 0.8)
	set_meta("interaction_distance", 3.2)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual_marker()


func _process(_delta: float) -> void:
	if portal_marker != null:
		var pulse := 0.88 + sin(Time.get_ticks_msec() * 0.004) * 0.12
		portal_marker.scale = Vector3(pulse, 1.0, pulse)
	if prompt != null:
		prompt.visible = nearby_player != null


func _build_visual_marker() -> void:
	portal_marker = MeshInstance3D.new()
	portal_marker.name = "EntranceMarker"
	portal_marker.position = Vector3(0, 0.045, 0)
	portal_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.82
	marker_mesh.bottom_radius = 0.82
	marker_mesh.height = 0.035
	marker_mesh.radial_segments = 32
	var marker_material := StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(0.22, 0.88, 0.72, 0.34)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.08, 0.78, 0.58)
	marker_material.emission_energy_multiplier = 2.2
	marker_material.no_depth_test = true
	marker_material.render_priority = 90
	marker_mesh.material = marker_material
	portal_marker.mesh = marker_mesh
	add_child(portal_marker)
	prompt = Label3D.new()
	prompt.name = "EntrancePrompt"
	prompt.text = "F  빌딩 진입"
	prompt.position = Vector3(0, 1.5, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.font_size = 42
	prompt.outline_size = 8
	prompt.modulate = Color("#d9fff3")
	prompt.no_depth_test = true
	prompt.visible = false
	add_child(prompt)


func enter_building(_player_body: Node3D) -> void:
	if transition_pending:
		return
	transition_pending = true
	set_meta("completed", true)
	monitoring = false
	set_process(false)
	if prompt != null:
		prompt.visible = false
	var current := get_tree().current_scene
	if current != null and current.has_method("_save_run_state"):
		current.call("_save_run_state")
	var source_path := current.scene_file_path if current != null else "res://scenes/main.tscn"
	var return_point := global_position + global_basis * return_offset
	BuildingRunState.begin_run(
		building_id,
		int(GameState.map_seed) ^ seed_offset ^ building_id.hash(),
		source_path,
		return_point,
		floor_count
	)
	get_tree().call_deferred("change_scene_to_packed", BUILDING_SCENE)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		nearby_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == nearby_player:
		nearby_player = null
