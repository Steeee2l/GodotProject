extends SceneTree

# 액티브 튜토리얼 프로브 — 스텝 엔진·2단계 타깃·건너뛰기·세이브 왕복·리셋·세로/가로 레이아웃.
#   창 모드(스크린샷 3컷): godot --path . --script res://tests/active_tutorial_probe.gd
#   헤드리스(검증만):       godot --headless --path . --script res://tests/active_tutorial_probe.gd
#
# ① 첫 복귀 → 스텝1(쉘터 입문) 활성 · 운영 독 '생산' 버튼 림 펄스 · 카드 문구
# ② 주민 앉히기 → ✓ → 스텝2(다음 목표 읽기)
# ③ 통조림 재고 18 → 스텝3 훈련장 포인터 → 모달 열면 '탄창 숙련' 카드로 이동 → 구매 → 완료
# ④ 건너뛰기 → 해당 스텝만 완료 · 저장
# ⑤ 세이브 왕복
# ⑥ 설정 '안내 다시 보기' 리셋
# ⑦ 세로 720x1280 · 가로 1555x720에서 카드가 화면 안 · 대상과 겹침 없음(rect 로그)

const OUTPUT_DIR := "res://test-output"
const SAVE_PATH := "res://tmp/tutout/active_tutorial_probe_save.json"

var shelter: Node
var game_state: Node
var tutorial: RefCounted
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _wait(frames: int) -> void:
	for _index in frames:
		await process_frame


func _sleep(seconds: float) -> void:
	# 스텝 폴링(0.25s)·✓ 연출(0.4s)은 실시간 기준이다 — 헤드리스는 프레임이 빨라 시간을 기다린다.
	await create_timer(seconds).timeout
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/tutout"))
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("opening_completed", true)
	game_state.set("saja_intro_seen", true)
	game_state.set("saja_second_run_intro_seen", true)
	game_state.set("merchant_status", "away")
	# 첫 복귀: serial 1 · 생산기/훈련장 해금 · 주민 1명 · 통조림 재고 18(훈련 스텝 조건).
	game_state.call("register_shelter_return", true)
	game_state.call("unlock_shelter_facility", "scratcher_bank")
	game_state.call("unlock_shelter_facility", "training")
	game_state.call("try_add_rescued_workers", 1)
	game_state.call("consume_milestone_unlocks")
	game_state.set("scrap", 900)
	# 훈련 비용은 통조림이 됐다 — 탄창 숙련 1랭크 값(18개)만 딱 쥐여 준다.
	game_state.set("shelter_canned_food", int(game_state.call("get_training_cost", "magazine_drill")))
	game_state.set("catnip", 0)
	root.get_node("AccessibilitySettings").set("active_tutorial_enabled", true)

	shelter = load("res://scenes/shelter_interior.tscn").instantiate()
	root.add_child(shelter)
	await _wait(6)
	for _advance_index in 24:
		if not bool(shelter.get("contract_story_open")):
			break
		shelter.call("_advance_contract_story")
	await _wait(4)
	game_state.call("consume_milestone_unlocks")
	for layer_name in ["MilestoneUnlockLayer", "ReturnSettlementLayer"]:
		var stray := shelter.get_node_or_null(layer_name)
		if stray != null:
			stray.queue_free()
	# 첫 복귀엔 행상인이 찾아온다(판매 스텝 트리거). 이 프로브는 쉘터 스텝 순서를 보므로 돌려보낸다.
	game_state.set("merchant_status", "away")
	shelter.call("_set_merchant_notice_visible", false)
	tutorial = shelter.get("active_tutorial")
	_check(tutorial != null, "쉘터가 액티브 튜토리얼을 들고 있다")
	print("  viewport=%s" % str(root.get_visible_rect().size))
	await _sleep(0.7)

	# ① 스텝1 활성 + 대상 하이라이트 + 카드 문구
	print("[1] 첫 복귀 — 스텝1")
	_check(str(tutorial.call("get_active_step_id")) == "seat_worker", "활성 스텝 = seat_worker (실제: %s)" % str(tutorial.call("get_active_step_id")))
	var target := tutorial.call("get_active_target") as Control
	_check(target != null and target.name == "OpsButton_scratcher_bank", "대상 = 운영 독 '생산' 버튼 (실제: %s)" % (target.name if target else "<null>"))
	_check(target != null and target.get_node_or_null("RimPulseFx") != null, "대상에 림 펄스(RimPulseFx)가 붙었다")
	var layer := shelter.get_node_or_null("ActiveTutorialLayer") as CanvasLayer
	_check(layer != null and layer.visible, "튜토리얼 레이어가 보인다")
	var card_text := (layer.find_child("TutorialText", true, false) as Label).text if layer else ""
	_check(card_text.contains("주민을 좌석에"), "카드 문구: %s" % card_text)
	_log_rects("step1-landscape")
	await _capture("active_tutorial_step1_dock_pointer")

	# ② 주민 앉히기 → ✓ → 스텝2
	print("[2] 주민 앉히기")
	var ops = shelter.get("ops_console")
	ops.call("open_facility", "scratcher_bank")
	await _sleep(0.7)
	target = tutorial.call("get_active_target") as Control
	_check(target != null and str(target.name).begins_with("ResidentCard_"), "모달이 열리면 대상이 주민 카드로 이동 (실제: %s)" % (target.name if target else "<null>"))
	var resident_ids: Array = game_state.get("resident_cat_ids")
	_check(resident_ids.size() >= 1, "주민 1명 존재")
	if resident_ids.size() >= 1:
		(target as BaseButton).pressed.emit()
	await _sleep(0.35)
	_check(bool(game_state.call("is_tutorial_step_done", "seat_worker")), "seat_worker 완료 저장")
	var check_label := layer.find_child("TutorialCheck", true, false) as Control
	_check(check_label != null and check_label.visible, "✓ 체크 연출이 떴다")
	var modal := root.find_child("ScratcherBankUILayer", true, false)
	if modal != null:
		modal.queue_free()
	await _sleep(1.0)
	_check(str(tutorial.call("get_active_step_id")) == "read_goal", "다음 스텝 = read_goal (실제: %s)" % str(tutorial.call("get_active_step_id")))
	target = tutorial.call("get_active_target") as Control
	# 목표 줄은 카드로 재디자인됐다(ShelterGoalRow → ShelterGoalCard).
	_check(target != null and target.name == "ShelterGoalCard", "대상 = 스탯 패널 목표 카드")
	# 카드는 PanelContainer라 _rim_allowed()가 참 — 예전 HFlow 줄과 달리 림 펄스가 붙는다.
	_check(target != null and target.get_node_or_null("RimPulseFx") != null, "패널 대상은 림 펄스로 강조")
	_log_rects("step2-landscape")
	# 목표 카드 탭(터치 경로) → 완료
	var goal_center := target.get_global_rect().get_center()
	_check(bool(tutorial.call("handle_touch", goal_center)), "목표 카드 터치가 튜토리얼에 잡힌다")
	await _sleep(0.35)
	_check(bool(game_state.call("is_tutorial_step_done", "read_goal")), "read_goal 완료")
	await _sleep(1.0)

	# ③ 훈련장 스텝: 독 버튼 → 모달 카드 → 구매
	print("[3] 훈련장 — 탄약 운용")
	_check(str(tutorial.call("get_active_step_id")) == "train_magazine", "활성 스텝 = train_magazine (실제: %s)" % str(tutorial.call("get_active_step_id")))
	target = tutorial.call("get_active_target") as Control
	_check(target != null and target.name == "OpsButton_training", "대상 = 운영 독 '훈련' 버튼")
	ops.call("open_facility", "training")
	await _sleep(0.7)
	target = tutorial.call("get_active_target") as Control
	_check(target != null and target.name == "TrainingCard_magazine_drill", "모달 안 '탄창 숙련' 카드로 이동 (실제: %s)" % (target.name if target else "<null>"))
	_log_rects("step3-modal")
	await _capture("active_tutorial_step3_modal_pointer")
	var upgrade: Dictionary = game_state.call("try_upgrade_training", "magazine_drill")
	_check(bool(upgrade.get("ok", false)), "탄창 숙련 1랭크 구매")
	await _sleep(0.35)
	_check(bool(game_state.call("is_tutorial_step_done", "train_magazine")), "train_magazine 완료")
	var training_modal := root.find_child("TrainingFacilityUILayer", true, false)
	if training_modal != null:
		training_modal.queue_free()
	await _sleep(1.0)
	_check(str(tutorial.call("get_active_step_id")) == "", "통조림 0 → 남은 스텝 없음 (실제: %s)" % str(tutorial.call("get_active_step_id")))

	# ④ 건너뛰기 — 후속 훈련 스텝을 띄우고 건너뛴다.
	print("[4] 건너뛰기")
	game_state.set("shelter_canned_food", int(game_state.call("get_training_cost", "ammo_carry")))
	await _sleep(0.7)
	_check(str(tutorial.call("get_active_step_id")) == "train_supply", "후속 스텝 train_supply 활성 (실제: %s)" % str(tutorial.call("get_active_step_id")))
	var skip := layer.find_child("TutorialSkipButton", true, false) as Button
	_check(skip != null and skip.visible, "건너뛰기 버튼 보임")
	skip.pressed.emit()
	await _wait(4)
	var done: Array = game_state.get("tutorial_steps_done")
	_check(done.has("train_supply") and done.size() == 4, "train_supply만 추가 완료 · 총 4개: %s" % str(done))
	_check(str(tutorial.call("get_active_step_id")) == "", "건너뛴 뒤 활성 스텝 없음")

	# ⑤ 세이브 왕복
	print("[5] 세이브 왕복")
	game_state.set("persistence_enabled", true)
	game_state.set("persistence_path", SAVE_PATH)
	_check(bool(game_state.call("save_persistent_state")), "저장 성공")
	(game_state.get("tutorial_steps_done") as Array).clear()
	_check(bool(game_state.call("load_persistent_state")), "로드 성공")
	var loaded: Array = game_state.get("tutorial_steps_done")
	_check(loaded.size() == 4 and loaded.has("seat_worker") and loaded.has("train_supply"), "로드 후 스텝 4개 복원: %s" % str(loaded))
	game_state.set("persistence_enabled", false)

	# ⑥ 설정 '안내 다시 보기'
	print("[6] 설정 리셋")
	var settings := root.get_node("AccessibilitySettings")
	var reset_button := settings.find_child("SettingsAction_안내 다시 보기", true, false) as Button
	_check(reset_button != null, "설정에 '안내 다시 보기' 버튼 존재")
	reset_button.pressed.emit()
	_check((game_state.get("tutorial_steps_done") as Array).is_empty(), "리셋 후 완료 목록 비어 있음")
	var toggle_found := false
	for node in settings.find_children("*", "CheckButton", true, false):
		if str((node as CheckButton).text).contains("액티브 안내"):
			toggle_found = true
	_check(toggle_found, "설정에 '액티브 안내' 토글 존재")
	await _sleep(0.9)
	# 리셋 뒤 read_goal이 다시 뜬다(seat_worker는 이미 주민이 앉아 있어 트리거 안 됨).
	_check(str(tutorial.call("get_active_step_id")) == "read_goal", "리셋 후 read_goal 재활성 (실제: %s)" % str(tutorial.call("get_active_step_id")))
	# 토글 OFF → 숨김, ON → 복귀
	settings.set("active_tutorial_enabled", false)
	await _sleep(0.7)
	_check(str(tutorial.call("get_active_step_id")) == "" and not layer.visible, "토글 OFF → 스텝 해제·숨김")
	settings.set("active_tutorial_enabled", true)
	await _sleep(0.7)
	_check(str(tutorial.call("get_active_step_id")) == "read_goal", "토글 ON → 재활성")

	# ⑦ 세로/가로 레이아웃 — 독 탭바(하단)를 가리키는 train_supply로 확인
	print("[7] 세로 720x1280 / 가로 1555x720")
	game_state.call("mark_tutorial_step_done", "read_goal")
	var console_script := load("res://scripts/hud/shelter_ops_console.gd")
	console_script.set("force_touch_layout", true)
	await _resize(Vector2i(720, 1280))
	shelter.call("_apply_shelter_safe_layout")
	await _sleep(0.9)
	_check(str(tutorial.call("get_active_step_id")) == "train_supply", "세로: train_supply 활성 (실제: %s)" % str(tutorial.call("get_active_step_id")))
	_check_layout("portrait-720x1280")
	await _capture("active_tutorial_portrait")
	await _resize(Vector2i(1555, 720))
	shelter.call("_apply_shelter_safe_layout")
	await _sleep(0.9)
	_check_layout("landscape-1555x720")
	console_script.set("force_touch_layout", false)
	await _resize(Vector2i(1280, 720))
	await _wait(4)

	shelter.queue_free()
	await _wait(2)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("active_tutorial_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _resize(size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		root.size = size
	else:
		DisplayServer.window_set_size(size)
		root.size = size
	await process_frame
	await process_frame


func _check_layout(label: String) -> void:
	var viewport_size := root.get_visible_rect().size
	var card_rect: Rect2 = tutorial.call("get_card_rect")
	var arrow_rect: Rect2 = tutorial.call("get_arrow_rect")
	var target := tutorial.call("get_active_target") as Control
	var target_rect := target.get_global_rect() if target else Rect2()
	var screen := Rect2(Vector2.ZERO, viewport_size)
	print("  [%s] viewport=%s target=%s card=%s arrow=%s" % [label, viewport_size, target_rect, card_rect, arrow_rect])
	_check(screen.encloses(card_rect), "%s 카드가 화면 안" % label)
	_check(screen.encloses(arrow_rect), "%s 화살표가 화면 안" % label)
	_check(not card_rect.intersects(target_rect), "%s 카드와 대상이 겹치지 않음" % label)
	_check(not arrow_rect.intersects(target_rect.grow(-2.0)), "%s 화살표와 대상이 겹치지 않음" % label)
	var layer := shelter.get_node_or_null("ActiveTutorialLayer") as CanvasLayer
	_check(layer != null and layer.visible, "%s 레이어 보임" % label)


func _log_rects(label: String) -> void:
	var card_rect: Rect2 = tutorial.call("get_card_rect")
	var arrow_rect: Rect2 = tutorial.call("get_arrow_rect")
	var target := tutorial.call("get_active_target") as Control
	print("  [%s] viewport=%s target=%s card=%s arrow=%s" % [label, root.get_visible_rect().size, target.get_global_rect() if target else Rect2(), card_rect, arrow_rect])
	if target != null:
		_check(not card_rect.intersects(target.get_global_rect()), "%s 카드와 대상 겹침 없음" % label)
		_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(card_rect), "%s 카드 화면 안" % label)


func _capture(capture_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, capture_name]
	var error := image.save_png(path)
	if error == OK:
		print("  SHOT %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("캡처 실패: %s (%s)" % [capture_name, error_string(error)])
