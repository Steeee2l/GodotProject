class_name HudStyle
extends RefCounted

# HUD 패널 스타일의 단일 출처.
#
# 예전에는 main.gd의 _make_panel_style()을 66곳에서 불렀고, 다른 화면들은
# 각자 비슷한 함수를 따로 갖고 있었다. 같은 모양을 여러 곳에서 정의하면
# 톤이 조금씩 어긋난다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")


static func panel(background: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


static func raised_panel(
	background: Color, border: Color, radius: int = 8, shadow: float = 18.0
) -> StyleBoxFlat:
	# 모달처럼 배경 위로 떠 보여야 하는 패널.
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = roundi(shadow)
	return style


static func label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result
