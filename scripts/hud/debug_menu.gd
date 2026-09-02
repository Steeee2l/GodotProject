extends CanvasLayer
class_name DebugMenu

# 개발자 디버그 메뉴(2026-08-30 유저 요청) — PC는 9키, 모바일은 좌하단 버튼.
#
# 테스트할 때마다 세이브를 손으로 고치거나 몇 시간을 파밍해야 하는 상황을
# 없애기 위한 도구다. 필드·쉘터 어디서든 뜨고, 누른 즉시 반영된다.
#
# 이 메뉴는 GameState의 공개 API만 쓴다. 여기서만 도는 특수 경로를 만들면
# "디버그로는 되는데 실제로는 안 되는" 상태가 생겨 도구가 거짓말을 한다.

const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")
const PANEL_WIDTH := 340.0
const CHEAT_AMOUNT := 9_999_999

var host: Node
var panel: PanelContainer
var button_column: VBoxContainer
var status_label: Label
var open_button: Button
var is_open := false


func setup(host_node: Node) -> void:
	host = host_node
	# 일시정지 중에도 눌려야 한다 — 멈춰 놓고 상태를 바꾸는 게 대부분이다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 140 — 일시정지(135)보다 위. 개발 도구는 무엇이 떠 있어도 눌려야 한다.
	layer = 140
	_build_open_button()
	_build_panel()
	set_open(false)


func _build_open_button() -> void:
	# 좌하단 상시 버튼 — 모바일에는 9키가 없다. 작고 흐릿하게 둬서 평소
	# 플레이에는 거슬리지 않게 한다.
	open_button = Button.new()
	open_button.name = "DebugOpenButton"
	open_button.text = "DEV"
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.add_theme_font_override("font", FONT)
	open_button.add_theme_font_size_override("font_size", 13)
	open_button.add_theme_color_override("font_color", Color("#8fe0c8"))
	open_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	open_button.offset_left = 14.0
	open_button.offset_top = -52.0
	open_button.offset_right = 74.0
	open_button.offset_bottom = -14.0
	open_button.modulate.a = 0.72
	open_button.pressed.connect(func() -> void: toggle())
	add_child(open_button)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "DebugPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.08, 0.96)
	style.border_color = Color("#41e0c9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	# 세로로 꽉 채운다 — 모바일에서 600px 고정이면 목록 끝(닫기 버튼)이
	# 화면 밖으로 밀려 "열고 나면 닫을 수가 없다"(유저 신고)가 된다.
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 16.0 + PANEL_WIDTH
	panel.offset_bottom = -16.0
	add_child(panel)

	# 헤더(제목 + 큰 닫기 버튼)는 스크롤 밖에 고정한다. 스크롤을 어디까지
	# 내렸든 닫기는 항상 같은 자리에 있어야 한다.
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 8)
	panel.add_child(root_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_column.add_child(header)
	var header_title := Label.new()
	header_title.text = "개발자 메뉴"
	header_title.add_theme_font_override("font", FONT)
	header_title.add_theme_font_size_override("font_size", 16)
	header_title.add_theme_color_override("font_color", Color("#41e0c9"))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(header_title)
	var close_button := Button.new()
	close_button.text = "✕ 닫기"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 15)
	# 손가락으로 누르는 버튼이다 — 44px 아래로 내리지 않는다.
	close_button.custom_minimum_size = Vector2(96.0, 44.0)
	close_button.pressed.connect(func() -> void: set_open(false))
	header.add_child(close_button)

	status_label = Label.new()
	status_label.add_theme_font_override("font", FONT)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#f0d78a"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 34.0
	root_column.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 터치 드래그로 굴린다 — 모바일에는 스크롤 휠이 없다(유저 신고: 스크롤 불편).
	scroll.follow_focus = false
	root_column.add_child(scroll)

	button_column = VBoxContainer.new()
	button_column.add_theme_constant_override("separation", 6)
	button_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(button_column)

	_add_title("재화")
	_add_action("고철 +999만", func() -> String:
		GameState.scrap += CHEAT_AMOUNT
		return "고철 %s" % GameState.format_compact_number(GameState.scrap)
	)
	_add_action("캣닢 · 츄르 · 통조림 +9999", func() -> String:
		GameState.catnip += 9999
		GameState.churu += 9999
		GameState.shelter_canned_food += 9999
		return "캣닢/츄르/통조림 충전"
	)
	_add_action("부품 전 종류 +999", func() -> String:
		for component_id in GameState.mod_component_inventory.keys():
			GameState.add_mod_component(str(component_id), 999)
		return "부품 전 종류 +999"
	)
	_add_action("탄약 · 구급약 보충", func() -> String:
		GameState.medkits += 20
		for ammo_id in GameState.ammo_inventory.keys():
			GameState.set_ammo_count(str(ammo_id), GameState.get_ammo_count(str(ammo_id)) + 2000)
		GameState.set_ammo_count(GameState.equipped_ammo_id, 2000)
		GameState.reserve_ammo = GameState.get_ammo_count(GameState.equipped_ammo_id)
		if host != null and host.has_method("_update_equipment_ui"):
			host.set("reserve_ammo", GameState.reserve_ammo)
			host.call("_update_equipment_ui")
		return "탄약 2000 · 구급약 +20"
	)

	_add_title("메타 해금")
	_add_action("모든 시설 해금", func() -> String:
		GameState.unlock_all_shelter_facilities()
		return "시설 전부 해금"
	)
	_add_action("쉘터 티어 최대 · 전 구역 개방", func() -> String:
		GameState.shelter_tier = int(GameState.SHELTER_CAPACITY_BY_TIER.keys().max())
		GameState.ensure_story_key_items()
		# 티어만 올리면 티어 4↑ 구역은 '봉인 구역 키카드'가 없어 계속 잠긴다
		# (유저 신고: "다 해금하니까 출정을 못 나가던데"). 키카드까지 쥐여 준다.
		if GameState.get_progression_item_count("sealed_zone_keycard") <= 0:
			GameState.add_progression_item("sealed_zone_keycard", 1)
		var open_zones := 0
		for zone_id in GameState.get_raid_zone_ids():
			if GameState.is_raid_zone_unlocked(str(zone_id)):
				open_zones += 1
		# 방 크기·생산기 위치·좌석이 전부 티어에서 나온다 — 쉘터에 있다면
		# 다시 지어야 넓어진 방이 실제로 보인다.
		if host != null and host.is_in_group("shelter_resident_host"):
			get_tree().call_deferred(
				"change_scene_to_file", "res://scenes/shelter_interior.tscn"
			)
		return "쉘터 티어 %d · 출정 가능 구역 %d곳" % [GameState.shelter_tier, open_zones]
	)
	_add_action("모든 무기 지급", func() -> String:
		var count := 0
		for weapon_id in WeaponSystem.WEAPONS.keys():
			GameState.add_weapon(str(weapon_id), 1)
			count += 1
		return "무기 %d종 지급" % count
	)
	# 정상 경로는 생환 3회 뒤(4번째 출정부터) 합류다 — 이건 그걸 건너뛰는 치트.
	_add_action("주홍 즉시 해금 (정상: 4번째 출정부터)", func() -> String:
		GameState.companion_unlocked = true
		GameState.companion_enabled = true
		return "주홍 동행 해금"
	)
	_add_action("주민 5명 영입", func() -> String:
		var accepted := int(GameState.try_add_rescued_workers(5))
		# 명단만 늘리면 화면에는 아무 일도 안 일어난다 — 쉘터에 다시 세우게 한다.
		GameState._ensure_resident_records()
		get_tree().call_group("shelter_resident_host", "refresh_shelter_residents", true)
		return "주민 +%d명(정원 여유만큼)" % accepted
	)

	_add_title("판 조작")
	_add_action("위험도 90%로", func() -> String:
		GameState.raid_danger = 0.9
		if host != null and host.has_method("_refresh_danger_hud"):
			host.set("raid_danger", 0.9)
			host.call("_refresh_danger_hud")
		return "위험도 90% — 곧 처형자가 온다"
	)
	_add_action("위험도 0%로", func() -> String:
		GameState.raid_danger = 0.0
		if host != null and host.has_method("_refresh_danger_hud"):
			host.set("raid_danger", 0.0)
			host.set("danger_overcap_seconds", 0.0)
			host.set("danger_enforcers_spawned", 0)
			host.call("_refresh_danger_hud")
		return "위험도 초기화"
	)
	_add_action("체력 회복", func() -> String:
		GameState.player_health = GameState.get_max_health()
		if host != null:
			host.set("player_health", GameState.player_health)
			# 필드 HUD의 체력바는 노드 경로로 직접 갱신한다(전용 갱신 함수 없음).
			var health_bar := host.get_node_or_null("HUD/TopLeft/Margin/VBox/Health") as ProgressBar
			if health_bar != null:
				health_bar.max_value = GameState.get_max_health()
				health_bar.value = GameState.player_health
		return "체력 %d" % GameState.player_health
	)
	_add_action("레벨 +5 (선택권 지급)", func() -> String:
		GameState.pending_level_choices += 5
		GameState.player_level += 5
		return "레벨 %d · 선택권 %d" % [GameState.player_level, GameState.pending_level_choices]
	)

	_add_title("초기화")
	_add_action("이번 판만 초기화(reset_run)", func() -> String:
		GameState.reset_run()
		return "판 상태 초기화 — 쉘터로 나갔다 오면 반영"
	)
	_add_action("세이브 파일 삭제 후 새로 시작", func() -> String:
		# 파일까지 지운다 — reset_run만으로는 다음 저장에 옛 값이 섞일 수 있다.
		var save_path := str(GameState.persistence_path)
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		GameState.reset_run()
		GameState.save_persistent_state()
		get_tree().change_scene_to_file("res://scenes/shelter_interior.tscn")
		return "세이브 삭제 — 쉘터에서 새로 시작"
	)

	# 목록 맨 아래 닫기는 없앴다 — 헤더의 고정 닫기 버튼이 그 역할을 한다.


func _add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#41e0c9"))
	label.custom_minimum_size.y = 22.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	button_column.add_child(label)


func _add_action(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 14)
	# 손가락 기준 최소 44px — 32px는 모바일에서 자꾸 빗나간다.
	button.custom_minimum_size.y = 44.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		var result: Variant = action.call()
		GameState.save_persistent_state()
		if status_label != null:
			status_label.text = str(result) if result != null else ""
	)
	button_column.add_child(button)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value
	if panel != null:
		panel.visible = value
	if open_button != null:
		# 패널이 떠 있는 동안에는 여는 버튼을 숨긴다 — 겹쳐서 잘못 누른다.
		open_button.visible = not value
	# 열려 있는 동안은 마우스가 보여야 버튼을 누른다.
	if value:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif host != null and host.has_method("_refresh_pointer_mode"):
		host.call("_refresh_pointer_mode")
