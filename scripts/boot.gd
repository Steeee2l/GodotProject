extends Node

const OPENING_SCENE := "res://scenes/opening_sequence.tscn"
const SHELTER_SCENE := "res://scenes/shelter_interior.tscn"


func _ready() -> void:
	call_deferred("_route_to_start_scene")


func _route_to_start_scene() -> void:
	var next_scene := SHELTER_SCENE if GameState.opening_completed else OPENING_SCENE
	get_tree().change_scene_to_file(next_scene)
