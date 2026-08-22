class_name TelegraphFx
extends RefCounted

# 공격 예고(telegraph) 비주얼 — 적·보스가 공용으로 쓰는 정적 헬퍼.
#
# "긴장감은 있는데 실력이 늘어서 이기는 느낌이 약하다"에 대한 답의 절반.
# 피할 수 있는 공격이어야 피하는 게 실력이 된다. 여기 있는 건 전부 '읽을 거리'
# 이지 적을 약하게 만드는 장치가 아니다 — 예고 시간만큼 쿨다운을 줄여 적의
# 총 DPS는 그대로 둔다(enemy.gd 주석 참조).
#
# 종류
#   show_landing_circle  착탄 원(바닥 데칼, 반경 = 실제 폭발 반경) — 척탄병·보스 로켓
#   show_arc             붉은 포물선 예고선 — 척탄병 투척 궤적
#   show_aim_line        조준선 플래시(적→플레이어 얇은 선 깜빡임 + 총구 반짝) — 사수
#   show_dash_arrow      바닥 화살표 — 근접 돌진
#
# 렌더: gl_compatibility에서도 보이도록 unshaded + no_depth_test. 노드는 풀링한다
# (연사 예고가 초당 여러 개 떠도 생성/해제가 안 쌓이게). 수명은 실시간이 아닌
# 게임 시간(히트스톱 중엔 같이 멈춘다 — 예고는 게임 안의 사건이다).

const KIND_LANDING := "landing_circle"
const KIND_ARC := "arc"
const KIND_AIM_LINE := "aim_line"
const KIND_DASH_ARROW := "dash_arrow"
const MAX_POOL_PER_KIND := 24
const ARC_SEGMENTS := 18
# 예고 공용 색 — 착탄 원·포물선·돌진 화살표는 경고 붉은색, 조준선은 살짝 더 밝은 주황빛.
const DANGER_COLOR := Color("#ff3b1f")
const AIM_LINE_COLOR := Color("#ff6a3a")

static var idle_pool: Dictionary = {}
static var active_nodes: Array[Node3D] = []
static var spawn_count: Dictionary = {}


# ── 공개 API ───────────────────────────────────────────────────────

static func show_landing_circle(
	world_position: Vector3,
	radius: float,
	duration: float,
	parent: Node = null
) -> Node3D:
	# 착탄 원 — 반경은 호출자가 주는 '실제 폭발 반경'을 그대로 쓴다(속이지 않는다).
	var node := _acquire(KIND_LANDING, parent)
	if node == null:
		return null
	node.global_position = world_position + Vector3(0.0, 0.04, 0.0)
	node.scale = Vector3.ONE
	node.set_meta("radius", radius)
	var disc := node.get_node("Disc") as MeshInstance3D
	var ring := node.get_node("Ring") as MeshInstance3D
	(disc.mesh as CylinderMesh).top_radius = radius
	(disc.mesh as CylinderMesh).bottom_radius = radius
	(ring.mesh as TorusMesh).inner_radius = maxf(0.05, radius - 0.09)
	(ring.mesh as TorusMesh).outer_radius = radius
	disc.transparency = 0.0
	ring.transparency = 0.0
	_start_life(node, duration)
	# 맥동 — 원이 "살아 있다"는 느낌. 경고 색은 끝까지 유지(점점 진해진다).
	var pulse := node.create_tween().set_loops()
	pulse.tween_property(node, "scale", Vector3(1.04, 1.0, 1.04), 0.22).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(node, "scale", Vector3(0.97, 1.0, 0.97), 0.22).set_trans(Tween.TRANS_SINE)
	node.set_meta("pulse_tween", pulse)
	var fill := node.create_tween()
	fill.tween_property(disc, "transparency", 0.0, maxf(0.05, duration)).from(0.55)
	node.set_meta("fill_tween", fill)
	return node


static func show_arc(
	from: Vector3,
	to: Vector3,
	duration: float,
	parent: Node = null,
	apex_height: float = 2.4
) -> Node3D:
	# 붉은 포물선 — 투척 시작점에서 착탄점까지. 실제 수류탄 궤적과 같은 높이감.
	var node := _acquire(KIND_ARC, parent)
	if node == null:
		return null
	node.global_position = Vector3.ZERO
	node.scale = Vector3.ONE
	var mesh := node.get_node("Line") as MeshInstance3D
	var immediate := mesh.mesh as ImmediateMesh
	immediate.clear_surfaces()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for index in ARC_SEGMENTS + 1:
		var t := float(index) / float(ARC_SEGMENTS)
		var point := from.lerp(to, t)
		point.y += sin(t * PI) * apex_height
		immediate.surface_add_vertex(point)
	immediate.surface_end()
	# 굵기 보강 — 선 프리미티브는 1px라 멀면 안 읽힌다. 점선 구슬을 궤적 위에 얹는다.
	var beads := node.get_node("Beads") as Node3D
	for bead_index in beads.get_child_count():
		var bead := beads.get_child(bead_index) as MeshInstance3D
		var t := float(bead_index + 1) / float(beads.get_child_count() + 1)
		var point := from.lerp(to, t)
		point.y += sin(t * PI) * apex_height
		bead.global_position = point
		bead.visible = true
	_start_life(node, duration)
	var blink := node.create_tween().set_loops()
	blink.tween_method(func(value: float) -> void: _set_children_transparency(beads, value), 0.0, 0.55, 0.16)
	blink.tween_method(func(value: float) -> void: _set_children_transparency(beads, value), 0.55, 0.0, 0.16)
	node.set_meta("pulse_tween", blink)
	return node


static func _set_children_transparency(parent: Node, value: float) -> void:
	for child in parent.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).transparency = value


static func show_aim_line(
	from: Vector3,
	to: Vector3,
	duration: float,
	parent: Node = null
) -> Node3D:
	# 조준선 플래시 — 사수가 첫 발을 쏘기 직전 적→플레이어 얇은 선이 0.15초 주기로
	# 깜빡이고 총구가 반짝인다. 첫 발만 예고한다(연속 점사는 예고 없음 — 너무 쉬워지지 않게).
	var node := _acquire(KIND_AIM_LINE, parent)
	if node == null:
		return null
	var delta := to - from
	var length := maxf(0.2, delta.length())
	node.global_position = from
	node.scale = Vector3.ONE
	if delta.length_squared() > 0.0001:
		node.look_at(to, Vector3.UP)
	var beam := node.get_node("Beam") as MeshInstance3D
	beam.position = Vector3(0.0, 0.0, -length * 0.5)
	beam.scale = Vector3(1.0, 1.0, length)
	var glint := node.get_node("Glint") as MeshInstance3D
	glint.position = Vector3.ZERO
	glint.scale = Vector3.ONE
	beam.transparency = 0.0
	glint.transparency = 0.0
	_start_life(node, duration)
	# 0.15초 깜빡임 — 선이 점멸해야 '경고'로 읽힌다(상시 선은 레이저 조준 장비와 헷갈린다).
	var blink := node.create_tween().set_loops()
	blink.tween_property(beam, "transparency", 0.72, 0.075)
	blink.tween_property(beam, "transparency", 0.0, 0.075)
	node.set_meta("pulse_tween", blink)
	var glint_tween := node.create_tween().set_loops()
	glint_tween.tween_property(glint, "scale", Vector3.ONE * 1.7, 0.12)
	glint_tween.tween_property(glint, "scale", Vector3.ONE * 0.9, 0.12)
	node.set_meta("fill_tween", glint_tween)
	return node


static func show_dash_arrow(
	from: Vector3,
	direction: Vector3,
	duration: float = 0.5,
	parent: Node = null,
	length: float = 1.9
) -> Node3D:
	# 바닥 화살표 — 근접 적이 곧 돌진할 방향. 스프라이트 스케일 펀치(enemy.gd)와 짝.
	var node := _acquire(KIND_DASH_ARROW, parent)
	if node == null:
		return null
	var flat := direction
	flat.y = 0.0
	if flat.length_squared() <= 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	node.global_position = from + Vector3(0.0, 0.05, 0.0)
	node.look_at(node.global_position + flat, Vector3.UP)
	node.scale = Vector3(1.0, 1.0, length)
	_start_life(node, duration)
	var arrow := node.get_node("Arrow") as MeshInstance3D
	arrow.transparency = 0.0
	var blink := node.create_tween().set_loops()
	blink.tween_property(arrow, "transparency", 0.5, 0.12)
	blink.tween_property(arrow, "transparency", 0.0, 0.12)
	node.set_meta("pulse_tween", blink)
	return node


static func release(node: Node3D) -> void:
	# 예고를 일찍 거둔다(적이 죽거나 경직으로 공격이 끊겼을 때). 풀로 돌아간다.
	if node == null or not is_instance_valid(node):
		_prune_active()
		return
	_kill_meta_tween(node, "pulse_tween")
	_kill_meta_tween(node, "fill_tween")
	_kill_meta_tween(node, "life_tween")
	node.visible = false
	node.set_meta("telegraph_active", false)
	active_nodes.erase(node)
	var kind := str(node.get_meta("telegraph_kind", ""))
	var pool: Array = idle_pool.get(kind, [])
	if pool.size() >= MAX_POOL_PER_KIND:
		node.queue_free()
		return
	pool.append(node)
	idle_pool[kind] = pool


static func get_active_count(kind: String = "") -> int:
	# 프로브용 — 지금 떠 있는 예고 수(종류별 또는 전체).
	_prune_active()
	var count := 0
	for node in active_nodes:
		if not is_instance_valid(node) or not node.visible:
			continue
		if kind.is_empty() or str(node.get_meta("telegraph_kind", "")) == kind:
			count += 1
	return count


static func _prune_active() -> void:
	for index in range(active_nodes.size() - 1, -1, -1):
		if not is_instance_valid(active_nodes[index]):
			active_nodes.remove_at(index)


static func get_active_nodes(kind: String = "") -> Array[Node3D]:
	_prune_active()
	var result: Array[Node3D] = []
	for node in active_nodes:
		if not is_instance_valid(node) or not node.visible:
			continue
		if kind.is_empty() or str(node.get_meta("telegraph_kind", "")) == kind:
			result.append(node)
	return result


static func get_spawn_count(kind: String) -> int:
	return int(spawn_count.get(kind, 0))


static func reset_counters() -> void:
	spawn_count.clear()


# ── 내부 ───────────────────────────────────────────────────────────

static func _resolve_parent(parent: Node) -> Node:
	if parent != null and is_instance_valid(parent):
		return parent
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var host := tree.get_first_node_in_group("raid_host")
	if host != null:
		return host
	return tree.current_scene


static func _acquire(kind: String, parent: Node) -> Node3D:
	var resolved_parent := _resolve_parent(parent)
	if resolved_parent == null:
		return null
	spawn_count[kind] = int(spawn_count.get(kind, 0)) + 1
	var pool: Array = idle_pool.get(kind, [])
	while not pool.is_empty():
		# 풀 항목은 씬 전환·부모 해제로 이미 freed일 수 있다 — 타입 없는 Variant로 꺼내
		# 유효성을 먼저 본다(타입 변수에 freed 인스턴스를 넣으면 에러).
		var raw = pool.pop_back()
		if not is_instance_valid(raw) or (raw as Node).is_queued_for_deletion():
			continue
		var candidate := raw as Node3D
		if candidate.get_parent() != resolved_parent:
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			resolved_parent.add_child(candidate)
		candidate.visible = true
		candidate.set_meta("telegraph_active", true)
		idle_pool[kind] = pool
		active_nodes.append(candidate)
		return candidate
	idle_pool[kind] = pool
	var node := _build(kind)
	node.set_meta("telegraph_kind", kind)
	node.set_meta("telegraph_active", true)
	node.add_to_group("telegraph_fx")
	resolved_parent.add_child(node)
	active_nodes.append(node)
	return node


static func _start_life(node: Node3D, duration: float) -> void:
	_kill_meta_tween(node, "life_tween")
	var life := node.create_tween()
	life.tween_interval(maxf(0.02, duration))
	life.tween_callback(func() -> void: release(node))
	node.set_meta("life_tween", life)


static func _kill_meta_tween(node: Node, key: String) -> void:
	if not node.has_meta(key):
		return
	var tween := node.get_meta(key) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	node.remove_meta(key)


static func _make_material(color: Color, alpha: float, energy: float, depth_test: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.no_depth_test = not depth_test
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = false
	return material


static func _build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Telegraph_%s" % kind
	match kind:
		KIND_LANDING:
			var disc := MeshInstance3D.new()
			disc.name = "Disc"
			var disc_mesh := CylinderMesh.new()
			disc_mesh.height = 0.02
			disc_mesh.radial_segments = 48
			disc_mesh.material = _make_material(DANGER_COLOR, 0.2, 1.5, true)
			disc.mesh = disc_mesh
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(disc)
			var ring := MeshInstance3D.new()
			ring.name = "Ring"
			var ring_mesh := TorusMesh.new()
			ring_mesh.rings = 48
			ring_mesh.ring_segments = 8
			ring_mesh.material = _make_material(DANGER_COLOR, 0.92, 4.0)
			ring.mesh = ring_mesh
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ring)
		KIND_ARC:
			var line := MeshInstance3D.new()
			line.name = "Line"
			var immediate := ImmediateMesh.new()
			line.mesh = immediate
			line.material_override = _make_material(DANGER_COLOR, 0.9, 3.5)
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(line)
			var beads := Node3D.new()
			beads.name = "Beads"
			root.add_child(beads)
			var bead_material := _make_material(DANGER_COLOR, 0.95, 4.5)
			for bead_index in 9:
				var bead := MeshInstance3D.new()
				bead.name = "Bead%d" % bead_index
				var bead_mesh := SphereMesh.new()
				bead_mesh.radius = 0.07
				bead_mesh.height = 0.14
				bead_mesh.radial_segments = 8
				bead_mesh.rings = 4
				bead_mesh.material = bead_material
				bead.mesh = bead_mesh
				bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				beads.add_child(bead)
		KIND_AIM_LINE:
			var beam := MeshInstance3D.new()
			beam.name = "Beam"
			var beam_mesh := BoxMesh.new()
			beam_mesh.size = Vector3(0.03, 0.03, 1.0)
			beam_mesh.material = _make_material(AIM_LINE_COLOR, 0.8, 4.5)
			beam.mesh = beam_mesh
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(beam)
			var glint := MeshInstance3D.new()
			glint.name = "Glint"
			var glint_mesh := SphereMesh.new()
			glint_mesh.radius = 0.11
			glint_mesh.height = 0.22
			glint_mesh.radial_segments = 10
			glint_mesh.rings = 5
			glint_mesh.material = _make_material(Color("#ffd27a"), 0.95, 6.0)
			glint.mesh = glint_mesh
			glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(glint)
		KIND_DASH_ARROW:
			var arrow := MeshInstance3D.new()
			arrow.name = "Arrow"
			var immediate := ImmediateMesh.new()
			# 단위 길이(z: 0→-1) 화살표 — 루트의 scale.z로 길이를 준다.
			immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			# 샤프트
			immediate.surface_add_vertex(Vector3(-0.09, 0.0, 0.0))
			immediate.surface_add_vertex(Vector3(0.09, 0.0, 0.0))
			immediate.surface_add_vertex(Vector3(0.09, 0.0, -0.7))
			immediate.surface_add_vertex(Vector3(-0.09, 0.0, 0.0))
			immediate.surface_add_vertex(Vector3(0.09, 0.0, -0.7))
			immediate.surface_add_vertex(Vector3(-0.09, 0.0, -0.7))
			# 촉
			immediate.surface_add_vertex(Vector3(-0.28, 0.0, -0.66))
			immediate.surface_add_vertex(Vector3(0.28, 0.0, -0.66))
			immediate.surface_add_vertex(Vector3(0.0, 0.0, -1.0))
			immediate.surface_end()
			arrow.mesh = immediate
			arrow.material_override = _make_material(DANGER_COLOR, 0.78, 3.0)
			arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(arrow)
	return root
