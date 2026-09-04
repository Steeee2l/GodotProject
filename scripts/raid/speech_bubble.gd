extends RefCounted

# 필드 말풍선 — 적·동료·유인 반응이 전부 이 한 곳을 쓴다.
#
# 예전에는 can_throw(LureSpeech)와 companion(JuhongBark)이 각자 Label3D를
# 만들었고, 둘 다 배경 없는 맨 글자라 밝은 아스팔트 위에서는 외곽선만으로
# 버텨야 했다(유저 신고: "통조림 던져도 메시지가 작게 보인다").
# 여기서는 어두운 패널을 뒤에 깔고 글자를 키워, 직교 카메라 거리에서도
# 한눈에 읽히는 '말풍선'으로 만든다.
#
# 쓰는 쪽은 SPEECH_BUBBLE.show_line(대상, 대사, 색) 한 줄이면 된다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const BUBBLE_NAME := "FieldSpeechBubble"
# 직교 카메라(사이즈 28, 세로 ~780px)에서 1m ≈ 28px다. 0.0042는 글자 높이가
# 0.33m = 9px라 읽을 수가 없었다(유저 신고: "회색이라 잘 안 보이고 작다").
# 0.012면 0.94m ≈ 26px — 피해 숫자(0.84m)보다 한 뼘 크다.
# 0.012는 한 문장이 화면 폭을 다 먹었다(2026-09-03 유저: "머리 위 텍스트가 너무
# 크잖아"). 0.0085면 글자 높이 0.66m ≈ 19px — 피해 숫자보다 조금 작다.
const FONT_SIZE := 78
const PIXEL_SIZE := 0.0085
const OUTLINE_SIZE := 18
const DEFAULT_HOLD_SECONDS := 2.6
const FADE_SECONDS := 0.3
const DEFAULT_HEIGHT := 2.15
const BACKING_TEXTURE_SIZE := 48

# 말투 색 — 전부 흰색에 가깝게(유저: "흰색으로 잘 나와야"). 구분은 아주 옅은
# 기운으로만 두고, 가독성은 검은 외곽선 + 배경 판이 맡는다.
const TONE_ENEMY := Color("#ffffff")
const TONE_ENEMY_GOSSIP := Color("#fff1dc")
const TONE_ENEMY_SECRET := Color("#ece2ff")
const TONE_ALLY := Color("#e6fff8")


static func show_line(
	target: Node3D,
	line: String,
	tone: Color = TONE_ENEMY,
	hold_seconds: float = DEFAULT_HOLD_SECONDS,
	height: float = DEFAULT_HEIGHT
) -> Label3D:
	if not is_instance_valid(target) or line.is_empty():
		return null
	# 같은 대상이 새 말을 하면 이전 말풍선은 즉시 치운다 — 겹쳐 쌓이면
	# 둘 다 못 읽는다.
	var previous := target.get_node_or_null(BUBBLE_NAME)
	if previous != null:
		previous.name = "%s_fading" % BUBBLE_NAME
		previous.queue_free()
	var label := Label3D.new()
	label.name = BUBBLE_NAME
	label.text = line
	label.font = FONT
	label.font_size = FONT_SIZE
	label.pixel_size = PIXEL_SIZE
	label.modulate = tone
	label.outline_size = OUTLINE_SIZE
	label.outline_modulate = Color(0.02, 0.03, 0.03, 0.98)
	label.position = Vector3(0.0, height, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 122
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_child(label)
	var backing := _attach_backing_panel(label, line)
	# 살짝 튀어오르며 등장 — 정적으로 켜지면 언제 새 말이 나왔는지 모른다.
	label.scale = Vector3.ONE * 0.82
	var tree := label.get_tree()
	if tree == null:
		return label
	var tween := tree.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.2, hold_seconds))
	# 글자와 배경 판은 따로 그려지는 노드다 — 같이 사라지게 나란히 물린다.
	# (예전 구조 그대로 글자만 페이드하면 검은 판만 남아 더 눈에 띈다.)
	# 글자만 투명해지면 검은 외곽선이 그대로 남아 흰 글자가 '회색'으로 보였다
	# (유저: "처음엔 흰색이다가 회색빛으로 바뀐다"). 외곽선도 같이 뺀다.
	tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, FADE_SECONDS)
	if backing != null:
		tween.parallel().tween_property(backing, "modulate:a", 0.0, FADE_SECONDS)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)
	return label


static func _attach_backing_panel(label: Label3D, line: String) -> Sprite3D:
	# 글자 뒤에 까는 어두운 판. Label3D는 배경을 못 그리므로 Sprite3D 한 장을
	# 자식으로 깔고 렌더 우선순위를 한 단계 낮춰 글자가 위에 오게 한다.
	var panel := Sprite3D.new()
	panel.name = "BubbleBacking"
	panel.texture = _get_backing_texture()
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.shaded = false
	panel.transparent = true
	panel.no_depth_test = true
	panel.render_priority = 121
	panel.modulate = Color(1.0, 1.0, 1.0, 0.82)
	# 글자 길이에 맞춰 판을 늘린다 — 한 글자든 열 글자든 여백이 같게.
	var glyph_count := maxi(1, line.length())
	var width := float(glyph_count) * float(FONT_SIZE) * PIXEL_SIZE * 0.94 + 0.34
	var height := float(FONT_SIZE) * PIXEL_SIZE * 1.55
	# Sprite3D의 월드 크기 = 텍스처 픽셀 × pixel_size × scale.
	# pixel_size를 1/텍스처변으로 두면 scale이 그대로 월드 단위(m)가 된다.
	panel.pixel_size = 1.0 / float(BACKING_TEXTURE_SIZE)
	panel.scale = Vector3(width, height, 1.0)
	panel.position = Vector3(0.0, 0.0, -0.01)
	label.add_child(panel)
	return panel


static var _backing_texture: ImageTexture = null


static func _get_backing_texture() -> ImageTexture:
	# 1x1 짜리를 늘려 쓰면 모서리가 각져 '판때기'가 된다 — 모서리만 둥글게
	# 깎은 작은 텍스처를 한 번 만들어 전부가 공유한다.
	if _backing_texture != null:
		return _backing_texture
	var size := BACKING_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius := 11.0
	for y in size:
		for x in size:
			var dx := maxf(0.0, maxf(radius - float(x), float(x) - float(size - 1) + radius))
			var dy := maxf(0.0, maxf(radius - float(y), float(y) - float(size - 1) + radius))
			var corner_distance := sqrt(dx * dx + dy * dy)
			var alpha := 1.0 - smoothstep(radius - 1.6, radius, corner_distance)
			image.set_pixel(x, y, Color(0.035, 0.05, 0.055, alpha))
	_backing_texture = ImageTexture.create_from_image(image)
	return _backing_texture
