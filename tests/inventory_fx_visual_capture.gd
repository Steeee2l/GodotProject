extends SceneTree

# 가방 UI 셰이더 연출 시각 확인 프로브. 창 모드로만 돌린다(--headless 금지 — 화면 텍스처가 필요).
#   godot --path . --script res://tests/inventory_fx_visual_capture.gd
#
# 뽑는 컷(res://test-output):
#   1) inventory_fx_before          가방 열기 전 필드(블러 대조용)
#   2) inventory_fx_sweep_a/b       열린 직후 스캔 스윕 중(두 시점 — 띠 이동 확인)
#   3) inventory_fx_selected_a/b    안정 상태 + 칸 하나 선택(두 시점 — 림 펄스 변화 확인)
#   4) inventory_fx_glitch          버리기 글리치 디졸브 중
#   5) inventory_fx_shelter         쉘터에서 가방 열기
# 픽셀 검증 결과와 프레임 시간(열기 전/후)을 stdout에 찍는다.

const OUTPUT_DIR := "res://test-output"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	# 가방에 볼거리: 여분 MP5 + 구급약 + 탄약 + 조끼.
	game_state.call("add_weapon", "mp5", 1)
	game_state.set("medkits", 3)
	game_state.call("set_ammo_count", "762_fmj", 95)
	game_state.call("add_equipment", "scav_vest", 1)
	print("FX_PROBE renderer=%s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method")))
	print("FX_PROBE fx_enabled=%s" % str(HudFx.fx_enabled()))

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	for _frame in 30:
		await process_frame
	var chain: Object = main_scene.get("main_mission")
	if chain != null:
		var cine: Object = chain.get("cinematic")
		var guard := 0
		while cine != null and bool(cine.get("running")) and guard < 40:
			cine.call("skip")
			await _wait_seconds(0.2)
			guard += 1
	await _wait_seconds(0.8)
	var hud: Object = main_scene.get("hud")
	var inventory: Control = hud.get("inventory_ui")
	if inventory == null:
		push_error("inventory_ui 없음")
		quit(1)
		return

	# ── 프레임 시간(열기 전) ──
	var before_ms := await _measure_frame_ms(90)
	var before_img := await _capture("inventory_fx_before")

	# ── 열기 + 스윕 ──
	inventory.call("set_open", true)
	await _wait_seconds(0.25)
	var sweep_a := await _capture("inventory_fx_sweep_a")
	await _wait_seconds(0.3)
	var sweep_b := await _capture("inventory_fx_sweep_b")
	await _wait_seconds(1.2)

	# ── 안정 상태 + 칸 선택 ──
	var bag_grid: GridContainer = inventory.get("bag_grid")
	var medkit_tile := bag_grid.get_node_or_null("BagItem_medkit") as Button
	if medkit_tile != null:
		medkit_tile.pressed.emit()
	await _wait_seconds(0.15)
	var after_ms := await _measure_frame_ms(90)
	var selected_a := await _capture("inventory_fx_selected_a")
	await _wait_seconds(0.37)
	var selected_b := await _capture("inventory_fx_selected_b")
	var modal: Control = inventory.get("modal")
	var dim := modal.get_node_or_null("ModalDim") as ColorRect
	var rim := medkit_tile.get_node_or_null("RimPulseFx") if medkit_tile != null else null
	print("FX_PROBE dim_material=%s rim_attached=%s layer=%s dust=%s" % [
		str(dim != null and dim.material != null),
		str(rim != null),
		str(modal.get_node_or_null("HudFxLayer") != null),
		str(modal.get_node_or_null("HudFxLayer/DustParticles") != null),
	])

	# ── 픽셀 검증 ──
	# 블러: 패널 밖 왼쪽 띠(x 0~120, y 100~620)에서 열기 전/후를 비교한다.
	var region := Rect2i(0, 100, 120, 520)
	var same_ratio := _same_pixel_ratio(before_img, selected_a, region)
	var grad_before := _horizontal_gradient_energy(before_img, region)
	var grad_after := _horizontal_gradient_energy(selected_a, region)
	print("FX_PROBE blur_region same_pixel_ratio=%.4f hgrad_before=%.4f hgrad_after=%.4f (낮을수록 흐림)" % [
		same_ratio, grad_before, grad_after,
	])
	# 림 펄스: 선택 칸 영역의 두 시점 차이.
	if medkit_tile != null:
		var tile_rect := _to_image_rect(medkit_tile.get_global_rect(), selected_a)
		var rim_diff := _mean_abs_diff(selected_a, selected_b, tile_rect)
		print("FX_PROBE rim_pulse tile_rect=%s mean_abs_diff(a,b)=%.4f (0보다 커야 함)" % [str(tile_rect), rim_diff])
	# 스윕: 왼쪽 띠의 행별 초록 초과량 최대 행이 아래로 이동했는가.
	var sweep_row_a := _brightest_row(sweep_a, region)
	var sweep_row_b := _brightest_row(sweep_b, region)
	print("FX_PROBE sweep brightest_row a=%d b=%d (b > a 이어야 함)" % [sweep_row_a, sweep_row_b])
	# 스캔라인: 왼쪽 띠의 세로 방향 3px 주기 에너지.
	print("FX_PROBE scanline vgrad_before=%.4f vgrad_after=%.4f" % [
		_vertical_gradient_energy(before_img, region), _vertical_gradient_energy(selected_a, region),
	])

	# ── 버리기 글리치 ──
	if medkit_tile != null:
		var discard_button: Button = inventory.get("item_discard_button")
		discard_button.pressed.emit()  # 1탭: 무장
		await process_frame
		discard_button.pressed.emit()  # 2탭: 실행 → 글리치 고스트
		await _wait_seconds(0.12)
		var ghost := modal.get_node_or_null("HudFxLayer/GlitchGhost")
		print("FX_PROBE glitch_ghost_alive=%s" % str(ghost != null))
		await _capture("inventory_fx_glitch")
		await _wait_seconds(0.4)
		print("FX_PROBE glitch_ghost_after=%s medkits=%d" % [
			str(modal.get_node_or_null("HudFxLayer/GlitchGhost") != null),
			int(game_state.get("medkits")),
		])

	print("FX_PROBE frame_ms before_open=%.3f after_open=%.3f fps_now=%d" % [
		before_ms, after_ms, Engine.get_frames_per_second(),
	])
	inventory.call("set_open", false)
	await _wait_seconds(0.2)
	main_scene.queue_free()
	await process_frame
	await process_frame

	# ── 쉘터 ──
	var shelter: Node = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	for _frame in 30:
		await process_frame
	await _wait_seconds(0.8)
	var shelter_inventory: Control = shelter.get("inventory_ui")
	if shelter_inventory != null:
		shelter_inventory.call("set_open", true)
		await _wait_seconds(1.5)
		var shelter_grid: GridContainer = shelter_inventory.get("bag_grid")
		var first_tile: Button = null
		for child in shelter_grid.get_children():
			if child is Button and str(child.name).begins_with("BagItem_"):
				first_tile = child
				break
		if first_tile != null:
			first_tile.pressed.emit()
		await _wait_seconds(0.2)
		await _capture("inventory_fx_shelter")
		var shelter_modal: Control = shelter_inventory.get("modal")
		var shelter_dim := shelter_modal.get_node_or_null("ModalDim") as ColorRect
		print("FX_PROBE shelter dim_material=%s" % str(shelter_dim != null and shelter_dim.material != null))
	else:
		push_error("쉘터 inventory_ui 없음")
	print("FX_PROBE DONE")
	quit()


func _measure_frame_ms(frames: int) -> float:
	var start := Time.get_ticks_usec()
	for _frame in frames:
		await process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0 / float(frames)


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _capture(capture_name: String) -> Image:
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
	return image


func _to_image_rect(global_rect: Rect2, image: Image) -> Rect2i:
	# 창 크기 ≈ 캔버스 크기(1280x720 기본)라 1:1로 쓴다. 넘치면 잘라 낸다.
	var scale := float(image.get_width()) / float(root.get_visible_rect().size.x)
	var r := Rect2i(
		Vector2i(global_rect.position * scale), Vector2i(global_rect.size * scale)
	)
	return r.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))


func _same_pixel_ratio(a: Image, b: Image, region: Rect2i) -> float:
	var same := 0
	var total := 0
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			total += 1
			if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				same += 1
	return float(same) / float(maxi(total, 1))


func _horizontal_gradient_energy(image: Image, region: Rect2i) -> float:
	var total := 0.0
	var lum_total := 0.0
	var count := 0
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x - 1):
			var l0 := image.get_pixel(x, y).get_luminance()
			var l1 := image.get_pixel(x + 1, y).get_luminance()
			total += absf(l1 - l0)
			lum_total += l0
			count += 1
	return total / maxf(lum_total, 0.001)


func _vertical_gradient_energy(image: Image, region: Rect2i) -> float:
	var total := 0.0
	var lum_total := 0.0
	for x in range(region.position.x, region.end.x, 4):
		for y in range(region.position.y, region.end.y - 1):
			var l0 := image.get_pixel(x, y).get_luminance()
			var l1 := image.get_pixel(x, y + 1).get_luminance()
			total += absf(l1 - l0)
			lum_total += l0
	return total / maxf(lum_total, 0.001)


func _mean_abs_diff(a: Image, b: Image, region: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			count += 1
	return total / maxf(float(count), 1.0)


func _brightest_row(image: Image, region: Rect2i) -> int:
	var best_row := -1
	var best := -1.0
	for y in range(region.position.y, region.end.y):
		var sum := 0.0
		for x in range(region.position.x, region.end.x, 2):
			sum += image.get_pixel(x, y).g
		if sum > best:
			best = sum
			best_row = y
	return best_row
