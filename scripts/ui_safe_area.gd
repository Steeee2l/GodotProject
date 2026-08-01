class_name UISafeArea
extends RefCounted


static func get_margins(viewport_size: Vector2) -> Vector4:
	# Desktop safe-area rectangles may use absolute multi-monitor coordinates.
	# They are not notches and must never move HUD controls across the viewport.
	if not DisplayServer.is_touchscreen_available():
		return Vector4.ZERO
	var fallback := 12.0
	var result := Vector4(fallback, fallback, fallback, fallback)
	var screen_index := DisplayServer.window_get_current_screen()
	if screen_index < 0:
		screen_index = 0
	var screen_size := Vector2(DisplayServer.screen_get_size(screen_index))
	var screen_position := Vector2(DisplayServer.screen_get_position(screen_index))
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 1.0 or screen_size.y <= 1.0 or safe_rect.size.x <= 1.0 or safe_rect.size.y <= 1.0:
		return result
	var local_safe_position := safe_rect.position - screen_position
	# Mobile/web backends can already report screen-local coordinates.
	if (
		local_safe_position.x < -1.0
		or local_safe_position.y < -1.0
		or local_safe_position.x > screen_size.x
		or local_safe_position.y > screen_size.y
	):
		local_safe_position = safe_rect.position
	var local_safe_end := local_safe_position + safe_rect.size
	var scale := viewport_size / screen_size
	result.x = maxf(result.x, local_safe_position.x * scale.x)
	result.y = maxf(result.y, local_safe_position.y * scale.y)
	result.z = maxf(result.z, (screen_size.x - local_safe_end.x) * scale.x)
	result.w = maxf(result.w, (screen_size.y - local_safe_end.y) * scale.y)
	result.x = clampf(result.x, fallback, viewport_size.x * 0.18)
	result.y = clampf(result.y, fallback, viewport_size.y * 0.18)
	result.z = clampf(result.z, fallback, viewport_size.x * 0.18)
	result.w = clampf(result.w, fallback, viewport_size.y * 0.18)
	return result
