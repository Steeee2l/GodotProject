extends RefCounted

# 대화창 초상화(2026-08-30 유저: "초상화 크게, 상반신 크롭, 프레임보다 크게").
#
# 쉘터 계약 대화(shelter_interior)와 필드 시네마틱(field_cinematic)이 같이 쓴다.
# 패널 안의 작은 칸에 넣지 않고, 패널과 같은 부모에 별도 노드로 띄워 패널 위쪽
# 테두리 밖으로 삐져나오게 한다. 스프라이트(전신)는 확대해서 머리·상반신만
# 프레임에 담고 나머지는 클립한다.

# 초상화가 패널 위 테두리보다 얼마나 위로 솟는가.
const OVERHANG := 34.0
# 프레임 세로 = 폭 × 이 비율(상반신 세로 비율).
const HEIGHT_RATIO := 1.32
# 전신 스프라이트를 몇 배로 키워 상반신만 보이게 할지.
const ZOOM := 1.9


static func attach(
	parent: Node,
	panel: Control,
	texture: Texture2D,
	width: float,
	compact: bool,
	accent: Color
) -> Control:
	if texture == null or parent == null or panel == null:
		return null
	var frame := PanelContainer.new()
	frame.name = "DialoguePortrait"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.075, 0.07, 0.98)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 10
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	frame.add_theme_stylebox_override("panel", style)
	var frame_height := width * HEIGHT_RATIO
	frame.custom_minimum_size = Vector2(width, frame_height)
	frame.size = Vector2(width, frame_height)
	parent.add_child(frame)
	# 프레임 위치: 패널 왼쪽 여백 안쪽, 패널 위 테두리에서 OVERHANG만큼 위.
	# 패널은 앵커 기반이라 실제 rect는 한 프레임 뒤에 잡힌다 — deferred로 맞춘다.
	var place := func() -> void:
		if not is_instance_valid(frame) or not is_instance_valid(panel):
			return
		var panel_rect := panel.get_global_rect()
		frame.global_position = Vector2(
			panel_rect.position.x + (14.0 if compact else 18.0),
			panel_rect.position.y - OVERHANG
		)
	place.call_deferred()
	# 클립 컨테이너 — 확대한 스프라이트의 상반신만 보이게.
	var clip := Control.new()
	clip.name = "PortraitClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.custom_minimum_size = Vector2(width, frame_height)
	frame.add_child(clip)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 전신 스프라이트를 ZOOM배로 키우고, 머리가 프레임 위쪽 1/6 지점에 오도록
	# 위로 당긴다. 아래(다리)는 클립 밖으로 나가 잘린다.
	var texture_size := texture.get_size()
	var scale := (width * ZOOM) / maxf(1.0, texture_size.x)
	var drawn_size := texture_size * scale
	portrait.size = drawn_size
	portrait.position = Vector2(
		(width - drawn_size.x) * 0.5,
		frame_height * 0.16 - drawn_size.y * 0.12
	)
	clip.add_child(portrait)
	# 아래쪽을 어둡게 눌러 프레임 하단으로 자연스럽게 잠기게.
	var fade := ColorRect.new()
	fade.name = "PortraitFade"
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.05, 0.075, 0.07, 0.0)
	fade.size = Vector2(width, frame_height * 0.34)
	fade.position = Vector2(0.0, frame_height * 0.66)
	clip.add_child(fade)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.075, 0.07, 0.0))
	gradient.set_color(1, Color(0.05, 0.075, 0.07, 0.95))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(0.0, 1.0)
	var fade_rect := TextureRect.new()
	fade_rect.texture = gradient_texture
	fade_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.size = fade.size
	fade_rect.position = fade.position
	clip.add_child(fade_rect)
	fade.queue_free()
	# 살짝 떠오르며 등장.
	frame.modulate.a = 0.0
	var tree := frame.get_tree()
	if tree != null:
		var tween := tree.create_tween()
		tween.tween_property(frame, "modulate:a", 1.0, 0.22)
	return frame
