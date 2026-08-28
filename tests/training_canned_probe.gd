extends SceneTree

# 훈련 = 통조림 소비 프로브 (유저 확정: "고철 투자해서 훈련 아니야 통조림
# 소비해야해. 그리고 통조림은 먹는거 아님")
#   헤드리스(검증만):  godot --headless --path . --script res://tests/training_canned_probe.gd
#   창 모드(스크린샷): godot --path . --script res://tests/training_canned_probe.gd
#
# ① 통조림 0에서 훈련 시도 → 실패 · 사유 canned_food
# ② 충분할 때 성공 · 재고 차감 · 랭크 상승
# ③ 고철은 한 톨도 안 줄어든다
# ④ 먹기 경로 부재(try_eat_canned_food / describe_canned_food_eat_failure)
# ⑤ 출정 중엔 가방에 있고(투척용), 귀환 정산에서 쉘터 훈련 재고로 귀속
# ⑥ 훈련장 UI 상단 지갑 칩 = 통조림 · 카드 비용 표기 = "통조림 xN 필요"

const OUTPUT_DIR := "res://test-output"

var game_state: Node
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _sleep(seconds: float) -> void:
	await create_timer(seconds, true).timeout
	await process_frame


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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_state = root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.call("unlock_all_shelter_facilities")

	print("[1] 통조림 0 → 훈련 실패")
	game_state.set("scrap", 2_000_000)
	game_state.set("shelter_canned_food", 0)
	var scrap_before := int(game_state.get("scrap"))
	var denied := game_state.call("try_upgrade_training", "vitality") as Dictionary
	_check(not bool(denied.get("ok", false)), "통조림 0에서는 훈련이 거절된다")
	_check(str(denied.get("reason", "")) == "canned_food", "사유 = canned_food (실제: %s)" % str(denied.get("reason", "")))
	_check(int(game_state.call("get_training_rank", "vitality")) == 0, "실패한 훈련은 랭크를 올리지 않는다")
	_check(int(game_state.get("scrap")) == scrap_before, "고철 200만이 있어도 훈련은 안 된다(고철은 훈련 화폐가 아니다)")

	print("[2] 통조림 충분 → 훈련 성공 · 차감 · 랭크 상승")
	var cost := int(game_state.call("get_training_cost", "vitality"))
	_check(cost > 0 and cost <= 40, "1랭크 비용이 통조림 수량 눈금이다 (실제: %d)" % cost)
	game_state.set("shelter_canned_food", cost + 5)
	var granted := game_state.call("try_upgrade_training", "vitality") as Dictionary
	_check(bool(granted.get("ok", false)), "재고가 충분하면 훈련이 성사된다")
	_check(int(granted.get("cost", 0)) == cost, "반환 비용 = 표기 비용")
	_check(int(game_state.get("shelter_canned_food")) == 5, "쉘터 재고에서 비용만큼 차감 (실제: %d)" % int(game_state.get("shelter_canned_food")))
	_check(int(game_state.call("get_training_rank", "vitality")) == 1, "랭크 1로 상승")
	_check(int(game_state.get("scrap")) == scrap_before, "③ 고철은 변하지 않는다 (실제: %d)" % int(game_state.get("scrap")))
	# 2랭크는 base + step만큼 오른다 — 계단이 실제로 존재하는지 본다.
	_check(int(game_state.call("get_training_cost", "vitality")) > cost, "다음 랭크 비용이 더 비싸다")

	print("[3] 먹기 경로 부재")
	_check(not game_state.has_method("try_eat_canned_food"), "④ try_eat_canned_food 없음")
	_check(not game_state.has_method("describe_canned_food_eat_failure"), "④ describe_canned_food_eat_failure 없음")
	_check(game_state.get("canned_food_eat_ready_msec") == null, "④ canned_food_eat_ready_msec 없음")
	var inventory_source := FileAccess.get_file_as_string("res://scripts/inventory_ui.gd")
	_check(not inventory_source.contains("item_use_requested"), "④ 가방 UI에 소모품 사용 시그널 없음")
	_check(not inventory_source.contains("\"먹기\""), "④ 가방 상세에 '먹기' 버튼 없음")

	print("[4] 출정 중엔 가방 · 귀환하면 쉘터 훈련 재고")
	game_state.set("shelter_canned_food", 3)
	game_state.set("canned_food", 0)
	_check(bool(game_state.call("try_add_raid_item", "food", "canned_food", 7)), "필드 루팅 7개 성공")
	_check(int(game_state.get("canned_food")) == 7, "필드 루팅은 가방으로 들어간다(던질 수 있어야 한다)")
	_check(int(game_state.call("get_backpack_storage_count", "food", "canned_food")) == 7, "가방 보유량 = 7")
	var storage_refusal := game_state.call("deposit_storage_item", "food", "canned_food", 7) as Dictionary
	_check(not bool(storage_refusal.get("ok", false)), "통조림은 창고에 안 들어간다")
	var settlement := game_state.call("settle_shelter_return_inventory") as Dictionary
	_check(int(settlement.get("food", 0)) == 7, "정산 영수증이 통조림 7개를 보고한다")
	_check(int(game_state.get("canned_food")) == 0, "⑤ 귀환하면 가방 통조림은 비워진다")
	_check(int(game_state.get("shelter_canned_food")) == 10, "⑤ 쉘터 훈련 재고로 귀속 (3 + 7, 실제: %d)" % int(game_state.get("shelter_canned_food")))

	print("[5] 훈련장 UI")
	game_state.set("shelter_canned_food", 120)
	var training_module: Node3D = load("res://scripts/shelter_training_module.gd").new()
	training_module.name = "ProbeTrainingModule"
	root.add_child(training_module)
	await process_frame
	training_module.call("interact")
	await _sleep(0.5)
	var panel := root.find_child("TrainingPanel", true, false) as PanelContainer
	_check(panel != null, "훈련장 모달이 열렸다")
	if panel != null:
		var chip := panel.find_child("ResourceChip_food", true, false)
		_check(chip != null, "⑥ 상단 지갑 칩이 통조림(ResourceChip_food)")
		_check(panel.find_child("ResourceChip_scrap", true, false) == null, "⑥ 고철 칩은 없다")
		var wallet := panel.find_child("TrainingResourceLabel", true, false) as Label
		_check(
			# 자원 칩 수치는 "x120" 꼴이다(make_resource_chip 규약).
			wallet != null and wallet.text.strip_edges() == "x120",
			"⑥ 지갑 수치 = 쉘터 통조림 재고 120 (실제: %s)" % (wallet.text if wallet != null else "<null>")
		)
		var card := panel.find_child("TrainingCard_magazine_drill", true, false) as Button
		_check(card != null, "탄창 숙련 카드 존재")
		if card != null:
			var action := card.find_child("Action", true, false) as Label
			# 재화 표기 규칙(유저 확정): 아이콘 옆에 재화 이름을 또 쓰지 않는다.
			# 카드 비용은 통조림 아이콘 + "x18"이고, 이름은 카드 툴팁이 말한다.
			var expected := "x%d" % int(game_state.call("get_training_cost", "magazine_drill"))
			_check(
				action != null and action.text == expected,
				"⑥ 카드 비용 표기 = '%s' (실제: %s)" % [expected, action.text if action != null else "<null>"]
			)
		await _capture("training_canned_facility")
	var layer := training_module.get("ui_layer") as CanvasLayer
	if is_instance_valid(layer):
		layer.queue_free()
	training_module.queue_free()
	await process_frame

	print("training_canned_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
