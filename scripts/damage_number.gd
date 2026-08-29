extends Label3D

# 피해량 숫자 팝 — 명중 지점 위로 떠올라 상승+페이드.
#
# 연사 무기는 초당 수십 개를 띄우고 이 PC는 ~500fps로 돌아가므로, 수명이
# 끝난 라벨을 queue_free 하지 않고 정적 풀로 돌려 재사용한다(할당·해제
# 비용 절감). 풀 상한을 넘는 라벨만 실제로 해제해 노드 수가 무한히 늘지
# 않는다. 씬 전환으로 무효화된 항목은 acquire가 걸러낸다.

const DURATION := 0.64
const MAX_POOL_SIZE := 40

static var idle_pool: Array[Label3D] = []

var elapsed := 0.0
var start_position := Vector3.ZERO
var target_position := Vector3.ZERO
var start_scale := 0.58
var peak_scale := 1.12
var end_scale := 0.7
var base_color := Color.WHITE


static func acquire(parent: Node) -> Label3D:
	# 풀에서 유휴 라벨을 꺼내 필요하면 새 부모(다른 씬 포함)로 옮긴다.
	# 없으면 null — 호출자가 새로 만든다(생성은 자연히 동시 표시 수만큼).
	while not idle_pool.is_empty():
		# 씬 전환으로 이미 해제된 항목이 남아 있을 수 있다. 타입 있는 변수에 freed
		# 인스턴스를 대입하면 그 자체가 에러("previously freed instance")이므로
		# 타입 없는 Variant로 꺼내 유효성을 먼저 본다(TelegraphFx._acquire와 같은 규약).
		var raw = idle_pool.pop_back()
		if not is_instance_valid(raw) or (raw as Node).is_queued_for_deletion():
			continue
		var candidate := raw as Label3D
		if candidate.get_parent() != parent:
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			parent.add_child(candidate)
		else:
			# 재사용 라벨을 자식 목록 끝으로 — "마지막 자식 = 최신 팝" 순서를
			# 유지해 테스트·디버그의 최신 조회가 어긋나지 않게 한다.
			parent.move_child(candidate, parent.get_child_count() - 1)
		candidate.visible = true
		candidate.set_process(true)
		return candidate
	return null


static func get_idle_pool_count() -> int:
	return idle_pool.size()


func setup(
	damage: int,
	is_critical: bool,
	damage_font: Font,
	world_position: Vector3,
	hit_direction: Vector3,
	side_amount: float,
	hit_grade: String = "normal",
	elite_target: bool = false,
	killing_blow: bool = false
) -> void:
	name = "DamageNumber"
	elapsed = 0.0
	text = str(maxi(0, damage))
	font = damage_font
	# 오토로드 식별자 직접 참조는 --script 콜드 스타트에서 컴파일이 깨질 수
	# 있어(정적 멤버가 있는 스크립트) 트리 루트에서 노드로 찾는다.
	var text_scale := 1.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var accessibility := tree.root.get_node_or_null("AccessibilitySettings")
		if accessibility != null:
			text_scale = clampf(float(accessibility.get("combat_text_scale")), 0.8, 1.4)
	# 명중 등급은 1.94배 데미지 차이인데 여태 아무 표시가 없었다. 정조준(center)은
	# 호박색으로 크게, 스침(graze)은 회청색으로 작게 — 조준 실력이 눈에 보이게 한다.
	var grade_size := 58
	base_color = Color("#f2f0e8")
	if hit_grade == "center":
		grade_size = 66
		base_color = Color("#ffb347")
	elif hit_grade == "graze":
		grade_size = 46
		base_color = Color("#9fb2c4")
	elif hit_grade == "head":
		# 헤드샷 — 주황. 정조준(호박색)보다 붉고 크리티컬(노랑)과도 구분된다.
		grade_size = 70
		base_color = Color("#ff8a2a")
	elif hit_grade == "hostile":
		# 내가 맞은 피해 — 붉은색. 적에게 주는 숫자와 색으로 즉시 구분된다.
		grade_size = 60
		base_color = Color("#ff5348")
	# 엘리트 표적은 금색 — 정예 토스트·확정 전리품과 같은 색으로
	# "가치 있는 표적을 때리고 있다"가 숫자만 봐도 읽히게 한다.
	if elite_target:
		base_color = Color("#f2bd55")
	if killing_blow:
		# 처치 마지막 타격 — 등급 크기 위에 한 단계 더 얹어 살짝 크게.
		grade_size = roundi(float(grade_size) * 1.22)
	font_size = roundi(float(78 if is_critical else grade_size) * text_scale)
	outline_size = roundi(float(18 if is_critical else 14) * text_scale)
	if is_critical:
		base_color = Color("#ffd84a")
	modulate = base_color
	outline_modulate = Color(0.16, 0.08, 0.01, 0.96) if is_critical else Color(0.02, 0.025, 0.025, 0.94)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 127
	var blow_scale := 1.12 if killing_blow else 1.0
	start_scale = 0.5 if is_critical else 0.58
	peak_scale = (1.42 if is_critical else 1.12) * blow_scale
	end_scale = (0.78 if is_critical else 0.7) * blow_scale
	scale = Vector3.ONE * start_scale
	set_meta("critical", is_critical)
	set_meta("damage", damage)
	global_position = world_position
	start_position = global_position
	var side_direction := Vector3(-hit_direction.z, 0.0, hit_direction.x)
	if side_direction.length_squared() <= 0.01:
		side_direction = Vector3.RIGHT
	target_position = start_position + Vector3(0, 1.15 if is_critical else 0.88, 0)
	target_position += side_direction.normalized() * side_amount


func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var flight_progress := 1.0 - pow(1.0 - progress, 4.0)
	global_position = start_position.lerp(target_position, flight_progress)
	if progress < 0.2:
		var pop_progress := progress / 0.2
		var pop_ease := 1.0 - pow(1.0 - pop_progress, 3.0) + sin(pop_progress * PI) * 0.12
		scale = Vector3.ONE * lerpf(start_scale, peak_scale, pop_ease)
	else:
		var settle_progress := smoothstep(0.2, 1.0, progress)
		scale = Vector3.ONE * lerpf(peak_scale, end_scale, settle_progress)
	var alpha := 1.0 - smoothstep(0.58, 1.0, progress)
	modulate = Color(base_color.r, base_color.g, base_color.b, alpha)
	if progress >= 1.0:
		_release_to_pool()


func _release_to_pool() -> void:
	# 풀 반환 — 숨겨서 세워 두고 다음 스폰에서 재사용한다. 상한 초과분만 해제.
	visible = false
	set_process(false)
	if idle_pool.size() < MAX_POOL_SIZE:
		idle_pool.append(self)
	else:
		queue_free()
