class_name ScentTrailManager
extends Node3D

signal focus_changed(active: bool)

const CELL_SIZE := 2.5
const MAX_TRAILS := 320
const BASE_DECAY_PER_SECOND := 2.2
const FOCUS_REVEAL_RADIUS := 18.0
const SCENT_COLORS := {
	"enemy": Color("#ff665f"),
	"rescue": Color("#75e39b"),
	"objective": Color("#f2c968"),
	"player": Color("#c8d0cf"),
}

var player: Node3D
var focus_active := false
var night_factor := 0.0
var tracked: Dictionary = {}
var trails: Dictionary = {}
var guidance_groups: Dictionary = {}
var update_accumulator := 0.0
var scent_texture: Texture2D


func setup(player_node: Node3D) -> void:
	player = player_node
	scent_texture = _build_scent_texture()
	register_mover(player_node, "player")
	_build_mobile_focus_button()


func register_mover(mover: Node3D, kind: String) -> void:
	if not is_instance_valid(mover):
		return
	tracked[mover.get_instance_id()] = {
		"node_ref": weakref(mover),
		"kind": kind,
		"last_cell": Vector2i(999999, 999999),
		"last_position": mover.global_position,
	}


func add_trace(world_position: Vector3, kind: String, strength: float = 100.0) -> void:
	var cell := _world_to_cell(world_position)
	var key := "%s:%d:%d" % [kind, cell.x, cell.y]
	if trails.has(key):
		var entry := trails[key] as Dictionary
		entry.strength = maxf(float(entry.strength), strength)
		entry.position = world_position
		return
	_create_trail(key, world_position, kind, strength, false, "")


func set_guidance_trail(
	trail_id: String,
	world_points: Array,
	kind: String = "objective"
) -> void:
	clear_guidance_trail(trail_id)
	var keys: Array[String] = []
	for index in world_points.size():
		var key := "guidance:%s:%d" % [trail_id, index]
		_create_trail(key, world_points[index], kind, 100.0, true, trail_id)
		keys.append(key)
	guidance_groups[trail_id] = keys


func clear_guidance_trail(trail_id: String) -> void:
	var keys := guidance_groups.get(trail_id, []) as Array
	for key_value in keys:
		_remove_trail(str(key_value))
	guidance_groups.erase(trail_id)


func _create_trail(
	key: String,
	world_position: Vector3,
	kind: String,
	strength: float,
	persistent: bool,
	source_id: String
) -> void:
	if trails.size() >= MAX_TRAILS:
		_remove_weakest_trail()
	var marker := Sprite3D.new()
	marker.name = "Scent_%s_%d" % [kind, trails.size()]
	marker.texture = scent_texture
	marker.pixel_size = 0.021 if kind in ["objective", "rescue"] else 0.018
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.shaded = false
	marker.transparent = true
	marker.no_depth_test = true
	marker.render_priority = 118
	marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	marker.position = Vector3(world_position.x, 0.16, world_position.z)
	marker.visible = false
	add_child(marker)
	trails[key] = {
		"kind": kind,
		"position": marker.position,
		"strength": clampf(strength, 0.0, 100.0),
		"marker": marker,
		"persistent": persistent,
		"source_id": source_id,
	}


func set_focus_active(active: bool) -> void:
	if focus_active == active:
		return
	focus_active = active
	focus_changed.emit(active)


func set_night_factor(value: float) -> void:
	night_factor = clampf(value, 0.0, 1.0)


func get_strength_near(world_position: Vector3, kind: String, radius: float = 5.0) -> float:
	var strongest := 0.0
	for entry_value in trails.values():
		var entry := entry_value as Dictionary
		if str(entry.kind) != kind:
			continue
		if (entry.position as Vector3).distance_to(world_position) <= radius:
			strongest = maxf(strongest, float(entry.strength))
	return strongest


func _process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator >= 0.18:
		_update_movers(update_accumulator)
		update_accumulator = 0.0
	var decay := BASE_DECAY_PER_SECOND * lerpf(1.0, 0.5, night_factor) * delta
	var now := Time.get_ticks_msec() * 0.001
	for key in trails.keys():
		var entry := trails[key] as Dictionary
		if not bool(entry.get("persistent", false)):
			entry.strength = maxf(0.0, float(entry.strength) - decay)
		var marker_value: Variant = entry.get("marker")
		if float(entry.strength) <= 0.0 or not is_instance_valid(marker_value):
			if is_instance_valid(marker_value):
				(marker_value as Sprite3D).queue_free()
			trails.erase(key)
			continue
		var marker := marker_value as Sprite3D
		if marker == null:
			trails.erase(key)
			continue
		var distance := INF if not is_instance_valid(player) else player.global_position.distance_to(entry.position)
		marker.visible = focus_active and distance <= FOCUS_REVEAL_RADIUS
		if marker.visible:
			var kind := str(entry.kind)
			var intensity := clampf(float(entry.strength) / 100.0, 0.08, 1.0)
			var color := SCENT_COLORS.get(kind, Color.WHITE) as Color
			var alpha := 0.2
			match kind:
				"objective":
					alpha = 0.82
				"rescue":
					alpha = 0.7
				"enemy":
					alpha = 0.58
			color.a = intensity * alpha
			marker.modulate = color
			var pulse := 0.94 + sin(now * 3.6 + marker.position.x * 0.11 + marker.position.z * 0.09) * 0.12
			marker.scale = Vector3.ONE * pulse
			marker.position.y = 0.16 + sin(now * 2.2 + marker.position.x * 0.07) * 0.035


func _update_movers(delta: float) -> void:
	for id in tracked.keys():
		var data := tracked[id] as Dictionary
		var mover_ref := data.get("node_ref") as WeakRef
		var mover_value: Variant = mover_ref.get_ref() if mover_ref != null else null
		if not is_instance_valid(mover_value):
			tracked.erase(id)
			continue
		var mover := mover_value as Node3D
		if mover == null:
			tracked.erase(id)
			continue
		var cell := _world_to_cell(mover.global_position)
		var kind := str(data.kind)
		var moved := mover.global_position.distance_to(data.last_position) > 0.08
		if kind == "player":
			add_trace(mover.global_position, kind, (2.0 if moved else 8.0) * delta)
			var key := "%s:%d:%d" % [kind, cell.x, cell.y]
			if trails.has(key):
				var entry := trails[key] as Dictionary
				entry.strength = minf(100.0, float(entry.strength) + (2.0 if moved else 8.0) * delta)
		elif cell != data.last_cell:
			add_trace(mover.global_position, kind, 100.0)
		data.last_cell = cell
		data.last_position = mover.global_position


func _world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.z / CELL_SIZE))


func _remove_weakest_trail() -> void:
	var weakest_key := ""
	var weakest_strength := INF
	for key in trails:
		if bool((trails[key] as Dictionary).get("persistent", false)):
			continue
		var strength := float((trails[key] as Dictionary).strength)
		if strength < weakest_strength:
			weakest_strength = strength
			weakest_key = str(key)
	if weakest_key.is_empty():
		return
	_remove_trail(weakest_key)


func _remove_trail(key: String) -> void:
	if not trails.has(key):
		return
	var marker_value: Variant = (trails[key] as Dictionary).get("marker")
	if is_instance_valid(marker_value):
		(marker_value as Sprite3D).queue_free()
	trails.erase(key)


func _build_scent_texture() -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(47.5, 47.5)
	for y in 96:
		for x in 96:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			var angle := atan2(offset.y, offset.x)
			var outer_wisp := absf(radius - 32.0) <= 2.2 and angle > -2.75 and angle < 0.55
			var inner_wisp := absf(radius - 21.0) <= 1.7 and angle > -2.35 and angle < 0.88
			var core_wisp := absf(radius - 10.5) <= 1.25 and angle > -1.9 and angle < 1.1
			var broken := sin(angle * 8.0 + radius * 0.19) > -0.38
			if (outer_wisp or inner_wisp or core_wisp) and broken:
				var alpha := 0.9 if outer_wisp else (0.68 if inner_wisp else 0.46)
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _build_mobile_focus_button() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	var layer := CanvasLayer.new()
	layer.layer = 145
	add_child(layer)
	var button := Button.new()
	button.name = "ScentFocusButton"
	button.text = "후각"
	button.tooltip_text = "누르는 동안 주변의 냄새 흔적을 확인합니다."
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -190
	button.offset_top = -112
	button.offset_right = -112
	button.offset_bottom = -34
	button.custom_minimum_size = Vector2(78, 78)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.035, 0.038, 0.86)
	normal.border_color = Color("#78b49a")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(39)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.16, 0.3, 0.25, 0.94)
	pressed.border_color = Color("#a9f2c5")
	button.add_theme_stylebox_override("pressed", pressed)
	button.button_down.connect(set_focus_active.bind(true))
	button.button_up.connect(set_focus_active.bind(false))
	layer.add_child(button)
