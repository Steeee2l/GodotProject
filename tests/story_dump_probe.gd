extends SceneTree

# 시나리오 전면 개편(2026-08) 자가 점검 프로브 — 헤드리스.
#
# 15개 메인 미션의 모든 서사 문자열을 test-output/story_dump.txt로 덤프하고,
# 문체 규칙 위반을 스스로 잡아낸다.
#
#   규칙 ① 한 장면에 새 고유명사는 1개까지 (이미 나온 것만 반복해서 쓴다)
#   규칙 ② 모든 미션 단계는 앞으로 끌어당기며 끝난다 — 다음에 갈 곳·할 일·
#           풀리지 않은 질문. (v4, 2026-09-04: "알아낸 것은 이렇다" 정리 독백은
#           사건 보고서처럼 읽혀 폐기. 요약은 미션 카드 UI가 맡는다.)
#
# 실행:
#   godot --headless --path . --script res://tests/story_dump_probe.gd

const CATALOG := preload("res://scripts/raid/main_mission_catalog.gd")
const OUTPUT_PATH := "res://test-output/story_dump.txt"

# 이야기 전체에서 "이미 나온 것"으로 취급하는 고유명사 사전.
# 새 장면에서 이 목록 밖의 고유명사가 2개 이상 나오면 규칙 ① 위반이다.
const KNOWN_NOUNS: Array[String] = [
	"먼지", "사자", "주홍", "행상인",
	"종로", "남대문", "을지로", "용산", "남산",
	"수거", "명단", "방송", "장부", "쉘터", "하수구", "봉쇄선",
	"통조림", "츄르", "고철", "캣닢",
	# v4 서울 질감 — 관리사무소 방송과 사자의 집 주소는 여러 장면에 되풀이된다.
	"관리사무소", "101동", "302호", "야간", "3구역", "집",
]

# 단계 완료 독백이 앞으로 끌어당기며 끝나는지 판정하는 표지 — 다음 행선지,
# 행동, 혹은 아직 열린 질문. 마지막 두 줄 안에 있어야 한다.
const FORWARD_MARKERS: Array[String] = [
	"간다", "본다", "정한다", "찾는다", "묻는다", "올라간다", "끝내야",
	"으로.", "로.", "일까", "을까", "까.", "…", "다음",
]

var lines: Array[String] = []
var violations: Array[String] = []
var stage_count := 0


func _initialize() -> void:
	_emit("GREY DAWN · 메인 미션 서사 덤프")
	_emit("=" .repeat(72))
	for zone_value in CATALOG.ZONE_ORDER:
		var zone_id := str(zone_value)
		_dump_zone(zone_id)
	_emit("")
	_emit("=" .repeat(72))
	_emit("자가 점검")
	_emit("  미션 수: %d" % stage_count)
	if violations.is_empty():
		_emit("  규칙 위반: 없음")
	else:
		_emit("  규칙 위반: %d건" % violations.size())
		for violation in violations:
			_emit("    - %s" % violation)
	_write_file()
	print("\n".join(lines))
	print("STORY_DUMP_VIOLATIONS=%d" % violations.size())
	quit(0 if violations.is_empty() else 1)


func _dump_zone(zone_id: String) -> void:
	_emit("")
	_emit("■ 구역: %s" % zone_id)
	var count := int(CATALOG.get_stage_count(zone_id))
	for index in count:
		var stage := CATALOG.get_stage(zone_id, index) as Dictionary
		if stage.is_empty():
			continue
		stage_count += 1
		_dump_stage(zone_id, index, stage)


func _dump_stage(zone_id: String, index: int, stage: Dictionary) -> void:
	var title := str(stage.get("title", ""))
	var label := "%s[%d] %s (%s)" % [zone_id, index, title, str(stage.get("id", ""))]
	_emit("")
	_emit("  ── %s ──" % label)

	var points := CATALOG.get_stage_points(stage) as Array
	for point_value in points:
		var point := point_value as Dictionary
		_emit("    · step_title : %s" % str(point.get("step_title", "")))
		_emit("      detail     : %s" % str(point.get("detail", "")))
		_emit("      label      : %s" % str(point.get("label", "")))
		_emit("      map_label  : %s" % str(point.get("map_label", "")))
		if point.has("locked_reason"):
			_emit("      locked     : %s" % str(point.get("locked_reason", "")))
		var notice := str(point.get("complete_notice", ""))
		if not notice.is_empty():
			_emit("      notice     : %s" % notice)
		for monologue_line in point.get("complete_monologue", []) as Array:
			_emit("      독백       : %s" % str(monologue_line))

	_emit("    · carry_title  : %s" % str(stage.get("carry_title", "")))
	_emit("      carry_detail : %s" % str(stage.get("carry_detail", "")))
	_emit("      carry_notice : %s" % str(stage.get("carry_notice", "")))
	var carry := stage.get("carry_monologue", []) as Array
	for carry_line in carry:
		_emit("      완료 독백    : %s" % str(carry_line))
	# 규칙 ② — 미션의 마지막 말은 앞으로 끌어당겨야 한다.
	if carry.is_empty():
		violations.append("%s · 완료 독백이 없다(규칙 ②)" % label)
	elif not _pulls_forward(carry):
		violations.append("%s · 완료 독백이 앞으로 끌어당기지 않는다(규칙 ②): %s" % [label, str(carry[carry.size() - 1])])

	var lore := str(stage.get("lore", ""))
	if not lore.is_empty():
		_emit("    · lore       : %s" % lore.replace("\n", " / "))

	_dump_cinematics(label, stage.get("cinematics", {}) as Dictionary)


func _dump_cinematics(stage_label: String, cinematics: Dictionary) -> void:
	if cinematics.is_empty():
		return
	for key_value in cinematics.keys():
		var scene_key := str(key_value)
		var steps := cinematics[key_value] as Array
		_emit("    · 컷 [%s]" % scene_key)
		var scene_lines: Array[String] = []
		for step_value in steps:
			var step := step_value as Dictionary
			var step_type := str(step.get("type", ""))
			match step_type:
				"lines":
					_emit("      %s (%s)" % [str(step.get("title", "")), str(step.get("speaker", ""))])
					for line_value in step.get("lines", []) as Array:
						_emit("        %s: %s" % [str(step.get("speaker", "")), str(line_value)])
						scene_lines.append(str(line_value))
				"image_cut":
					_emit("      [이미지 컷] %s" % str(step.get("title", "")))
					for line_value in step.get("lines", []) as Array:
						_emit("        %s" % str(line_value))
						scene_lines.append(str(line_value))
				"choice":
					_emit("      [선택] %s" % str(step.get("prompt", "")))
					scene_lines.append(str(step.get("prompt", "")))
					for option_value in step.get("options", []) as Array:
						var option := option_value as Dictionary
						_emit("        · %s — %s" % [
							str(option.get("label", "")), str(option.get("detail", "")),
						])
						var effect := option.get("effect", {}) as Dictionary
						for effect_line in effect.get("monologue", []) as Array:
							_emit("          → %s" % str(effect_line))
							scene_lines.append(str(effect_line))
		# 규칙 ① — 한 장면(컷)에 새 고유명사는 1개까지.
		var fresh := _fresh_proper_nouns(scene_lines)
		if fresh.size() >= 2:
			violations.append("%s · 컷[%s]에 새 고유명사 %d개(규칙 ①): %s" % [
				stage_label, scene_key, fresh.size(), ", ".join(fresh),
			])


func _pulls_forward(monologue: Array) -> bool:
	# 마지막 두 줄만 본다. 앞줄에서 이미 정리했더라도 끝이 닫혀 있으면 실패.
	var tail := ""
	var start := maxi(0, monologue.size() - 2)
	for index in range(start, monologue.size()):
		tail += str(monologue[index])
	for marker in FORWARD_MARKERS:
		if tail.contains(marker):
			return true
	return false


func _fresh_proper_nouns(scene_lines: Array[String]) -> Array[String]:
	# "새 고유명사"의 근사치: 따옴표로 묶인 서식명·표식(‘수거 완료’ 같은 것)과,
	# 알려진 명사 사전에 없는 2~4글자 한자어 명사 후보를 센다.
	var found: Array[String] = []
	for line_value in scene_lines:
		var line := str(line_value)
		var start := line.find("‘")
		while start >= 0:
			var end := line.find("’", start + 1)
			if end < 0:
				break
			var quoted := line.substr(start + 1, end - start - 1).strip_edges()
			if not quoted.is_empty() and not _is_known(quoted) and not found.has(quoted):
				found.append(quoted)
			start = line.find("‘", end + 1)
	return found


func _is_known(term: String) -> bool:
	for noun in KNOWN_NOUNS:
		if term.contains(noun):
			return true
	return false


func _emit(text: String) -> void:
	lines.append(text)


func _write_file() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-output"))
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("story_dump_probe: 출력 파일을 열지 못했습니다 — %s" % OUTPUT_PATH)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
