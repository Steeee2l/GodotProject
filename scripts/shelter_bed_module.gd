class_name ShelterBedModule
extends Node3D

signal interacted(module: ShelterBedModule)

@export var bed_index := 1
@export var interaction_radius := 1.8

@onready var sprite: Sprite3D = $BedSprite

var has_focus := false


func _ready() -> void:
	add_to_group("shelter_module")
	add_to_group("shelter_bed")
	set_meta("module_kind", "bed")
	set_meta("module_slot", bed_index)


func get_interaction_prompt() -> String:
	return "침대 %d에서 휴식" % bed_index


func get_interaction_radius() -> float:
	return interaction_radius


func interact() -> String:
	GameState.player_health = 100
	interacted.emit(self)
	return "침대 %d에서 휴식했습니다. 체력이 모두 회복되었습니다." % bed_index


func set_interaction_focus(value: bool) -> void:
	if has_focus == value:
		return
	has_focus = value
	if sprite:
		sprite.modulate = Color(1.18, 1.12, 0.86, 1.0) if has_focus else Color.WHITE
