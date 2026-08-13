class_name ShelterUIComponents
extends RefCounted

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const UI_ICONS := preload("res://scripts/ui_icon_factory.gd")

const CURRENCY_NAMES := {
	"scrap": "고철",
	"catnip": "캣닢",
	"food": "통조림",
	"churu": "츄르",
}

const CURRENCY_COLORS := {
	"scrap": Color("#b9c4c2"),
	"catnip": Color("#91d46f"),
	"food": Color("#efbd66"),
	"churu": Color("#eba36d"),
}


static func make_currency_chip(
	currency_id: String,
	value_text: String,
	compact := false,
	show_name := true
) -> PanelContainer:
	return make_resource_chip(
		currency_id,
		str(CURRENCY_NAMES.get(currency_id, currency_id)),
		value_text,
		UI_ICONS.get_icon(currency_id, 42, get_currency_color(currency_id)),
		get_currency_color(currency_id),
		compact,
		show_name
	)


static func make_resource_chip(
	resource_id: String,
	display_name: String,
	value_text: String,
	texture: Texture2D,
	accent: Color,
	compact := false,
	show_name := true
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ResourceChip_%s" % resource_id
	# 컴팩트 72px는 "x80"에서 마지막 글자가 잘리는 한계선이었다.
	panel.custom_minimum_size = Vector2(86 if compact else 112, 36 if compact else 40)
	panel.tooltip_text = "%s %s" % [display_name, value_text]
	panel.add_theme_stylebox_override(
		"panel",
		_style(Color(0.035, 0.045, 0.042, 0.96), Color(accent, 0.58), 6)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "ResourceIcon_%s" % resource_id
	icon.custom_minimum_size = Vector2(25 if compact else 28, 25 if compact else 28)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	if show_name:
		var name_label := _label(display_name, 11 if compact else 12, Color("#91a39a"))
		name_label.name = "ResourceName_%s" % resource_id
		row.add_child(name_label)

	var value_label := _label("x%s" % value_text, 14 if compact else 16, accent)
	value_label.name = "ResourceValue_%s" % resource_id
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return panel


static func get_currency_color(currency_id: String) -> Color:
	return CURRENCY_COLORS.get(currency_id, Color("#d9e3dc")) as Color


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
