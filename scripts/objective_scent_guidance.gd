class_name ObjectiveScentGuidance
extends Node

const ROUTE_SPACING := 2.8
const ROUTE_REBUILD_DISTANCE := 7.0
const UPDATE_INTERVAL := 0.18
const DEFAULT_REVEAL_DISTANCE := 6.5
const GUIDED_VISUAL_NAMES := {
	"InteractionRing": true,
	"InteractionLight": true,
	"BasicMissionLabel": true,
	"MissionBoundary": true,
	"MissionMarkerLabel": true,
	"EvidenceSignal": true,
	"EvidenceLabel": true,
	"SafeRouteRing": true,
	"ReachTargetLabel": true,
	"MissionCollectibleSignal": true,
	"MissionCollectibleLabel": true,
}

var scent_system: Node3D
var player: Node3D
var world: Node3D
var registered_sites: Dictionary = {}
var current_target_id := ""
var current_target_position := Vector3.ZERO
var last_route_origin := Vector3(INF, INF, INF)
var update_accumulator := 0.0


func setup(scent_manager: Node3D, player_node: Node3D, world_node: Node3D) -> void:
	scent_system = scent_manager
	player = player_node
	world = world_node


func register_site(
	site: Node3D,
	role: String,
	kind: String = "objective",
	reveal_distance: float = DEFAULT_REVEAL_DISTANCE
) -> void:
	if not is_instance_valid(site):
		return
	registered_sites[site.get_instance_id()] = {
		"node_ref": weakref(site),
		"role": role,
		"kind": kind,
		"reveal_distance": maxf(2.0, reveal_distance),
	}
	_set_site_visuals(site, false)


func update_guidance(delta: float) -> void:
	if not is_instance_valid(scent_system) or not is_instance_valid(player):
		return
	update_accumulator += delta
	if update_accumulator < UPDATE_INTERVAL:
		return
	update_accumulator = 0.0
	_cleanup_sites()
	_update_site_visibility()
	var target := _select_target()
	if target.is_empty():
		clear_guidance()
		return
	var site := target.get("site") as Node3D
	if not is_instance_valid(site):
		clear_guidance()
		return
	var target_id := "objective_%d" % site.get_instance_id()
	var target_position := site.global_position
	var route_stale := (
		target_id != current_target_id
		or target_position.distance_to(current_target_position) > 0.75
		or player.global_position.distance_to(last_route_origin) >= ROUTE_REBUILD_DISTANCE
	)
	if not route_stale:
		return
	if not current_target_id.is_empty():
		scent_system.call("clear_guidance_trail", current_target_id)
	current_target_id = target_id
	current_target_position = target_position
	last_route_origin = player.global_position
	scent_system.call(
		"set_guidance_trail",
		current_target_id,
		_build_route_points(player.global_position, target_position),
		str(target.get("kind", "objective"))
	)


func clear_guidance() -> void:
	if not current_target_id.is_empty() and is_instance_valid(scent_system):
		scent_system.call("clear_guidance_trail", current_target_id)
	current_target_id = ""
	current_target_position = Vector3.ZERO
	last_route_origin = Vector3(INF, INF, INF)


func _select_target() -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for data_value in registered_sites.values():
		var data := data_value as Dictionary
		var site := _get_site(data)
		if not is_instance_valid(site) or bool(site.get_meta("completed", false)):
			continue
		var status := str(site.get_meta("status", "waiting"))
		if status in ["completed", "failed"]:
			continue
		var role := str(data.get("role", "mission"))
		var score := 0.0
		match role:
			"active_target":
				score = 400.0
			"primary":
				score = 260.0
			"rescue":
				score = 110.0
			_:
				score = 100.0
		if status in ["preparing", "active"]:
			score = 330.0
		score -= player.global_position.distance_to(site.global_position) * 0.04
		if score > best_score:
			best_score = score
			best = {
				"site": site,
				"kind": str(data.get("kind", "objective")),
			}
	return best


func _build_route_points(origin: Vector3, target: Vector3) -> Array[Vector3]:
	var flat_origin := Vector3(origin.x, 0.12, origin.z)
	var flat_target := Vector3(target.x, 0.12, target.z)
	var distance := flat_origin.distance_to(flat_target)
	var points: Array[Vector3] = []
	if distance <= 0.1:
		points.append(flat_target)
		return points
	var steps := maxi(1, ceili(distance / ROUTE_SPACING))
	for index in range(1, steps + 1):
		var ratio := float(index) / float(steps)
		var requested := flat_origin.lerp(flat_target, ratio)
		var point := requested
		if is_instance_valid(world) and world.has_method("find_nearest_physically_open_position"):
			var snapped: Variant = world.call(
				"find_nearest_physically_open_position",
				requested,
				0.34,
				[player.get_rid()]
			)
			if snapped is Vector3:
				point = snapped
		point.y = 0.12
		if points.is_empty() or points[-1].distance_to(point) >= 0.7:
			points.append(point)
	return points


func _update_site_visibility() -> void:
	for data_value in registered_sites.values():
		var data := data_value as Dictionary
		var site := _get_site(data)
		if not is_instance_valid(site):
			continue
		var status := str(site.get_meta("status", "waiting"))
		var reveal_distance := float(data.get("reveal_distance", DEFAULT_REVEAL_DISTANCE))
		var visible := (
			status in ["preparing", "active"]
			or player.global_position.distance_to(site.global_position) <= reveal_distance
		)
		_set_site_visuals(site, visible)


func _set_site_visuals(site: Node3D, visible: bool) -> void:
	for child in site.get_children():
		if not child is Node3D:
			continue
		var child_3d := child as Node3D
		if child_3d.name == "MissionPlayArea":
			child_3d.visible = str(site.get_meta("status", "waiting")) in ["preparing", "active"]
		elif GUIDED_VISUAL_NAMES.has(str(child_3d.name)):
			child_3d.visible = visible


func _cleanup_sites() -> void:
	for id in registered_sites.keys():
		var data := registered_sites[id] as Dictionary
		if not is_instance_valid(_get_site(data)):
			registered_sites.erase(id)


func _get_site(data: Dictionary) -> Node3D:
	var site_ref := data.get("node_ref") as WeakRef
	if site_ref == null:
		return null
	var site_value: Variant = site_ref.get_ref()
	return site_value as Node3D if is_instance_valid(site_value) else null
