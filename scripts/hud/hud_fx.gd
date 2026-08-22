class_name HudFx
extends RefCounted

# HUD 셰이더 연출의 단일 출처(정적 헬퍼). 가방 모달에 먼저 깔고, 다음 단계에서
# 다른 모달(창고·작업대·상점)도 같은 API로 얹는다. 위젯 트리·레이아웃은 건드리지
# 않고 표면만 더한다 — 붙이는 노드는 전부 MOUSE_FILTER_IGNORE, 컨테이너 밖.
#
#  install_glass_backdrop(modal_root, dim)  뒤 화면 블러+비네트+스캔라인+그레인, 먼지 입자,
#                                           열릴 때 스캔 스윕(visibility_changed에 자동 연결)
#  attach_rim_pulse(control) / detach_rim_pulse(control)  선택 칸 골드 림라이트 펄스
#  play_glitch_out(control)                 칸을 0.34초 동안 찢어 없앤다(고스트로 떼어내 연출)
#  play_glitch_pulse(control, duration)     칸을 0.3초 동안 찢었다 되돌린다(슬라이스 오프셋만, 알파 컷 없음)
#  attach_text_glow(label, color) / set_text_glow_color(label, color)  라벨 뒤 은은한 글로우
#  attach_title_aberration(label)           7~9초마다 60ms R/B 색수차 깜빡임
#
# 접근성 AccessibilitySettings.ui_fx_enabled(기본 ON)가 OFF면 블러·노이즈·파티클·글리치를
# 끄고 단순 딤으로 폴백한다(저사양 폰). 림/글로우는 값싸서 그대로 둔다.
# 셰이더는 TIME 기반이라 트리를 멈추는 모달에서도 움직이고, 트윈/타이머는 항상 처리로 둔다.

const GLASS_SHADER := preload("res://scripts/shaders/ui_glass.gdshader")
const RIM_SHADER := preload("res://scripts/shaders/ui_rim_pulse.gdshader")
const GLITCH_SHADER := preload("res://scripts/shaders/ui_glitch_out.gdshader")
const GLITCH_PULSE_SHADER := preload("res://scripts/shaders/ui_glitch_pulse.gdshader")
const ABERRATION_SHADER := preload("res://scripts/shaders/ui_text_aberration.gdshader")

const GOLD := Color("#f0d77d")
const SWEEP_GREEN := Color(0.667, 0.886, 0.745, 0.16)
const SWEEP_DURATION := 1.1
const GLITCH_DURATION := 0.34
const GLITCH_PULSE_DURATION := 0.3
const DUST_AMOUNT := 48
const NOISE_TEXTURE_SIZE := 128

const META_DIM := "hud_fx_dim"
const META_MATERIAL := "hud_fx_material"
const META_PLAIN_COLOR := "hud_fx_plain_color"
const META_LAYER := "hud_fx_layer"
const META_SWEEP_TWEEN := "hud_fx_sweep_tween"
const META_GLOW_COLOR := "hud_fx_glow_color"

const RIM_NODE := "RimPulseFx"
const GLOW_TIGHT_NODE := "TextGlowTightFx"
const GLOW_WIDE_NODE := "TextGlowWideFx"
const LAYER_NODE := "HudFxLayer"
const DUST_NODE := "DustParticles"

static var _noise_texture: ImageTexture
static var _glow_texture: ImageTexture
static var _dust_texture: ImageTexture


static func fx_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true
	var settings := tree.root.get_node_or_null("AccessibilitySettings")
	if settings == null:
		return true
	var value = settings.get("ui_fx_enabled")
	return true if value == null else bool(value)


# ── 모달 배경: 유리(블러) + 비네트 + 스캔라인 + 그레인 + 먼지 + 스캔 스윕 ──────────

static func install_glass_backdrop(modal_root: Control, dim: ColorRect) -> void:
	if modal_root == null or dim == null or dim.has_meta(META_MATERIAL):
		return
	# 뒤 화면을 복사해 두는 노드 — dim보다 먼저 그려져야 한다.
	var copy := BackBufferCopy.new()
	copy.name = "GlassBackBuffer"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	modal_root.add_child(copy)
	modal_root.move_child(copy, dim.get_index())

	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	material.set_shader_parameter("noise_tex", _get_noise_texture())
	material.set_shader_parameter("noise_tex_size", float(NOISE_TEXTURE_SIZE))
	material.set_shader_parameter("sweep_y", -1.0)
	dim.set_meta(META_PLAIN_COLOR, dim.color)
	dim.set_meta(META_MATERIAL, material)
	modal_root.set_meta(META_DIM, dim)

	# 연출 전용 레이어(입력 통과) — 먼지 입자와 글리치 고스트가 여기 산다. 모달 맨 위.
	var layer := Control.new()
	layer.name = LAYER_NODE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_meta(META_LAYER, true)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	modal_root.add_child(layer)
	layer.add_child(_build_dust())
	layer.resized.connect(func() -> void: _fit_dust(layer))
	_fit_dust(layer)

	modal_root.visibility_changed.connect(func() -> void:
		if modal_root.is_visible_in_tree():
			_apply_glass_state(modal_root)
			play_scan_sweep(dim)
	)
	_apply_glass_state(modal_root)


static func _apply_glass_state(modal_root: Control) -> void:
	var dim := modal_root.get_meta(META_DIM) as ColorRect
	if dim == null:
		return
	var enabled := fx_enabled()
	var material := dim.get_meta(META_MATERIAL) as ShaderMaterial
	dim.material = material if enabled else null
	# OFF 폴백: 원래 딤 색 그대로(셰이더가 없으면 color가 그려진다).
	dim.color = dim.get_meta(META_PLAIN_COLOR) as Color
	var layer := modal_root.get_node_or_null(LAYER_NODE) as Control
	if layer != null:
		var dust := layer.get_node_or_null(DUST_NODE) as CPUParticles2D
		if dust != null:
			dust.emitting = enabled
			dust.visible = enabled
			if enabled:
				dust.restart()


static func play_scan_sweep(dim: ColorRect) -> void:
	if dim == null or not fx_enabled() or not dim.has_meta(META_MATERIAL):
		return
	var material := dim.get_meta(META_MATERIAL) as ShaderMaterial
	if dim.has_meta(META_SWEEP_TWEEN):
		var old := dim.get_meta(META_SWEEP_TWEEN) as Tween
		if old != null and old.is_valid():
			old.kill()
	material.set_shader_parameter("sweep_y", -0.2)
	var tween := dim.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(material, "shader_parameter/sweep_y", 1.2, SWEEP_DURATION) \
		.from(-0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: material.set_shader_parameter("sweep_y", -1.0))
	dim.set_meta(META_SWEEP_TWEEN, tween)


static func _build_dust() -> CPUParticles2D:
	# GPUParticles2D 대신 CPU — gl_compatibility/웹에서 확실하고, 48개면 CPU 비용은 없다시피 하다.
	var dust := CPUParticles2D.new()
	dust.name = DUST_NODE
	dust.amount = DUST_AMOUNT
	dust.lifetime = 9.0
	dust.preprocess = 8.0
	dust.speed_scale = 1.0
	dust.texture = _get_dust_texture()
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 28.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 5.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 0.45
	dust.scale_amount_max = 0.8
	dust.color = Color(0.88, 0.93, 0.88, 0.2)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0),
	])
	dust.color_ramp = ramp
	dust.process_mode = Node.PROCESS_MODE_ALWAYS
	return dust


static func _fit_dust(layer: Control) -> void:
	var dust := layer.get_node_or_null(DUST_NODE) as CPUParticles2D
	if dust == null:
		return
	var size := layer.size
	dust.position = size * 0.5
	dust.emission_rect_extents = size * 0.5 + Vector2(0.0, 24.0)


# ── 선택 칸 림라이트 펄스 ────────────────────────────────────────────────

static func attach_rim_pulse(control: Control, color: Color = GOLD, corner_radius := 7.0) -> void:
	if control == null or control.get_node_or_null(RIM_NODE) != null:
		return
	var rim := ColorRect.new()
	rim.name = RIM_NODE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = RIM_SHADER
	material.set_shader_parameter("rim_color", color)
	material.set_shader_parameter("corner_radius", corner_radius)
	material.set_shader_parameter("rect_size", control.size)
	rim.material = material
	rim.resized.connect(func() -> void: material.set_shader_parameter("rect_size", rim.size))
	control.add_child(rim)


static func detach_rim_pulse(control: Control) -> void:
	if control == null:
		return
	var rim := control.get_node_or_null(RIM_NODE)
	if rim != null:
		control.remove_child(rim)
		rim.queue_free()


# ── 버리기 글리치 디졸브 ─────────────────────────────────────────────────

# control을 부모에서 떼어 연출 레이어의 고스트(CanvasGroup)로 옮기고 0.34초 동안 찢어 없앤다.
# 호출자는 즉시 데이터/그리드를 갱신해도 된다 — 고스트는 새 그리드 위에서 사라진다.
# 연출을 못 하는 상황(연출 OFF·레이어 없음·안 보이는 칸)이면 false를 돌려주고 아무것도 안 한다.
static func play_glitch_out(control: Control, on_done: Callable = Callable(), duration := GLITCH_DURATION) -> bool:
	if control == null or not control.is_inside_tree() or not fx_enabled():
		return false
	var layer := _find_fx_layer(control)
	if layer == null or not control.is_visible_in_tree():
		return false
	# 스크롤로 대부분 가려진 칸은 고스트가 클리핑 밖으로 튀어나오므로 연출을 건너뛴다.
	var visible_rect := control.get_global_rect()
	var scroll := _find_ancestor_scroll(control)
	if scroll != null:
		var clipped := visible_rect.intersection(scroll.get_global_rect())
		if clipped.get_area() < visible_rect.get_area() * 0.6:
			return false
	var global_rect := control.get_global_rect()
	var parent := control.get_parent()
	if parent == null:
		return false
	var ghost := CanvasGroup.new()
	ghost.name = "GlitchGhost"
	ghost.fit_margin = 26.0
	ghost.clear_margin = 26.0
	ghost.use_mipmaps = false
	var material := ShaderMaterial.new()
	material.shader = GLITCH_SHADER
	material.set_shader_parameter("progress", 0.0)
	ghost.material = material
	ghost.position = global_rect.position - layer.get_global_rect().position
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(ghost)
	parent.remove_child(control)
	ghost.add_child(control)
	control.position = Vector2.ZERO
	control.size = global_rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control is BaseButton:
		(control as BaseButton).disabled = true
	var tween := ghost.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(material, "shader_parameter/progress", 1.0, duration).from(0.0)
	tween.tween_callback(func() -> void:
		if on_done.is_valid():
			on_done.call()
		ghost.queue_free()
	)
	return true


# ── 글리치 펄스(복원형) ───────────────────────────────────────────────────

# control 위에 화면 읽기 오버레이를 잠깐 얹어 가로 슬라이스를 찢었다 되돌린다. 트리·레이아웃은
# 건드리지 않고(떼어내지 않음) duration 뒤 오버레이만 제거한다 — 돌파 성공처럼 "카드는 남아야
# 하는" 강조에 쓴다. 연출 OFF·안 보이는 칸이면 false.
static func play_glitch_pulse(control: Control, duration := GLITCH_PULSE_DURATION) -> bool:
	if control == null or not control.is_inside_tree() or not fx_enabled():
		return false
	if not control.is_visible_in_tree():
		return false
	# 같은 캔버스 레이어에서 한 번 백버퍼를 복사하면(유리 배경의 BackBufferCopy) 그 뒤 화면 읽기
	# 머티리얼은 그 사본(모달 뒤 장면)을 재사용한다 — 오버레이 바로 앞에 복사 노드를 두어
	# '카드가 그려진 지금 화면'을 새로 뜬다. 0.3초짜리 전체 복사라 비용은 무시할 수준.
	var copy := BackBufferCopy.new()
	copy.name = "GlitchPulseBackBuffer"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	control.add_child(copy)
	var overlay := ColorRect.new()
	overlay.name = "GlitchPulseFx"
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = GLITCH_PULSE_SHADER
	material.set_shader_parameter("progress", 0.0)
	overlay.material = material
	control.add_child(overlay)
	# 컨테이너 부모(PanelContainer 등)는 자식을 제 크기로 맞춘다. 아닌 경우를 위해 직접도 덮는다.
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := overlay.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(material, "shader_parameter/progress", 1.0, maxf(0.05, duration)).from(0.0)
	tween.tween_callback(func() -> void:
		copy.queue_free()
		overlay.queue_free()
	)
	return true


static func _find_fx_layer(node: Node) -> Control:
	var current := node.get_parent()
	while current != null:
		if current is Control:
			var layer := (current as Control).get_node_or_null(LAYER_NODE) as Control
			if layer != null and layer.has_meta(META_LAYER):
				return layer
		current = current.get_parent()
	return null


static func _find_ancestor_scroll(node: Node) -> ScrollContainer:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null


# ── 라벨 글로우 ─────────────────────────────────────────────────────────

# 라벨 글자 뒤에 두 겹(좁고 진하게 + 넓고 옅게)의 부드러운 캡슐 글로우를 깐다.
# 라벨의 자식으로 붙고 show_behind_parent라 레이아웃에 전혀 영향이 없다.
static func attach_text_glow(label: Label, color: Color = GOLD, strength := 1.0) -> void:
	if label == null or label.get_node_or_null(GLOW_TIGHT_NODE) != null:
		return
	for spec in [
		{"name": GLOW_TIGHT_NODE, "pad": 7.0, "alpha": 0.34},
		{"name": GLOW_WIDE_NODE, "pad": 18.0, "alpha": 0.18},
	]:
		var glow := NinePatchRect.new()
		glow.name = str(spec["name"])
		glow.texture = _get_glow_texture()
		glow.patch_margin_left = 31
		glow.patch_margin_right = 31
		glow.patch_margin_top = 31
		glow.patch_margin_bottom = 31
		glow.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		glow.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.show_behind_parent = true
		glow.set_meta("pad", float(spec["pad"]))
		glow.set_meta("alpha", float(spec["alpha"]) * strength)
		label.add_child(glow)
	label.set_meta(META_GLOW_COLOR, color)
	label.resized.connect(func() -> void: refresh_text_glow(label))
	# 글자가 바뀌면 최소 크기가 바뀐다(autowrap 없는 라벨) — 그때 글로우 폭도 다시 맞춘다.
	label.minimum_size_changed.connect(func() -> void: refresh_text_glow(label))
	refresh_text_glow(label)


static func set_text_glow_color(label: Label, color: Color) -> void:
	if label == null or label.get_node_or_null(GLOW_TIGHT_NODE) == null:
		return
	label.set_meta(META_GLOW_COLOR, color)
	refresh_text_glow(label)


# 글로우를 글자 폭에 맞춘다(정렬 반영). 라벨 폭이 글자보다 넓어도 빈 곳은 빛나지 않는다.
static func refresh_text_glow(label: Label) -> void:
	if label == null:
		return
	var color: Color = label.get_meta(META_GLOW_COLOR, GOLD)
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_width := label.size.x
	if font != null and not label.text.is_empty():
		text_width = minf(label.size.x, font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var left := 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT:
			left = label.size.x - text_width
		HORIZONTAL_ALIGNMENT_CENTER:
			left = (label.size.x - text_width) * 0.5
		_:
			left = 0.0
	var hidden := label.text.strip_edges().is_empty()
	for node_name in [GLOW_TIGHT_NODE, GLOW_WIDE_NODE]:
		var glow := label.get_node_or_null(node_name) as NinePatchRect
		if glow == null:
			continue
		var pad := float(glow.get_meta("pad", 8.0))
		glow.visible = not hidden
		glow.position = Vector2(left - pad, -pad)
		glow.size = Vector2(text_width + pad * 2.0, label.size.y + pad * 2.0)
		glow.modulate = Color(color.r, color.g, color.b, float(glow.get_meta("alpha", 0.4)) * color.a)


# ── 타이틀 색수차 깜빡임 ─────────────────────────────────────────────────

static func attach_title_aberration(label: Label, min_interval := 7.0, max_interval := 9.0) -> void:
	if label == null or label.material != null:
		return
	var material := ShaderMaterial.new()
	material.shader = ABERRATION_SHADER
	material.set_shader_parameter("shift_px", 0.0)
	label.material = material
	_schedule_aberration(label, material, min_interval, max_interval)


static func _schedule_aberration(label: Label, material: ShaderMaterial, min_interval: float, max_interval: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var timer := tree.create_timer(randf_range(min_interval, max_interval), true)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(label):
			return
		if fx_enabled() and label.is_visible_in_tree():
			material.set_shader_parameter("shift_px", 1.0)
			var off := tree.create_timer(0.06, true)
			off.timeout.connect(func() -> void:
				if is_instance_valid(material):
					material.set_shader_parameter("shift_px", 0.0)
			)
		_schedule_aberration(label, material, min_interval, max_interval)
	)


# ── 코드 생성 텍스처(캐시) ──────────────────────────────────────────────

static func _get_noise_texture() -> ImageTexture:
	if _noise_texture != null:
		return _noise_texture
	var image := Image.create(NOISE_TEXTURE_SIZE, NOISE_TEXTURE_SIZE, false, Image.FORMAT_L8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260821
	for y in NOISE_TEXTURE_SIZE:
		for x in NOISE_TEXTURE_SIZE:
			var v := rng.randf()
			image.set_pixel(x, y, Color(v, v, v, 1.0))
	_noise_texture = ImageTexture.create_from_image(image)
	return _noise_texture


# 64x64 라디얼 — 중심 1 → 가장자리 0. 9패치 중앙 31px을 늘려 캡슐을 만든다.
static func _get_glow_texture() -> ImageTexture:
	if _glow_texture != null:
		return _glow_texture
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5 - 0.5, size * 0.5 - 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / (size * 0.5)
			var a := 1.0 - smoothstep(0.0, 1.0, d)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	_glow_texture = ImageTexture.create_from_image(image)
	return _glow_texture


static func _get_dust_texture() -> ImageTexture:
	if _dust_texture != null:
		return _dust_texture
	var size := 4
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5 - 0.5, size * 0.5 - 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / (size * 0.5)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - d, 0.0, 1.0)))
	_dust_texture = ImageTexture.create_from_image(image)
	return _dust_texture
