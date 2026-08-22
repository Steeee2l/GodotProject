extends SceneTree

# 시큐어 슬롯 표기 프로브 — 가방 UI의 시큐어 버튼 툴팁·구매 피드백이 GameState.get_secure_slot_count()
# (츄르 칸 + 방어구 돌파 +90 보너스)를 기준으로 말하는지 본다.
#   godot --headless --path . --script res://tests/secure_slot_display_probe.gd
#
# ① 보너스 없음: 기본 1칸 — 툴팁 "현재 1칸 (츄르 1/3)"
# ② 몸 방어구 +90 돌파 기록 → get_secure_slot_count 2 — 툴팁 "현재 2칸 (츄르 1/3 + 방어구 돌파 1)"
# ③ 츄르로 칸 구매 → 피드백 "죽어도 3칸은 지킨다"(보너스 포함 수)
# ④ 돌파 기록 제거 → 보너스 사라짐(1칸 감소)

const INVENTORY_UI := preload("res://scripts/inventory_ui.gd")
const FONT := preload("res://assets/fonts/Pretendard-Regular.otf")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.call("reset_run")
	game_state.set("churu", 0)
	var holder := Node.new()
	holder.name = "SecureProbeHolder"
	root.add_child(holder)
	var ui := INVENTORY_UI.new()
	holder.add_child(ui)
	ui.call("setup", FONT, null, null, {})
	ui.call("set_open", true)
	await process_frame
	await process_frame
	var button := ui.get("secure_expand_button") as Button
	_check(button != null and button.visible, "시큐어 확장 버튼 존재·표시")

	# ① 보너스 없음
	print("[1] 보너스 없음")
	var base_count := int(game_state.call("get_secure_slot_count"))
	_check(base_count == int(game_state.get("secure_dog_slots")), "기본 슬롯 수 = secure_dog_slots (%d)" % base_count)
	ui.call("_refresh_contents")
	print("  tooltip=%s" % button.tooltip_text)
	_check(button.tooltip_text.contains("현재 %d칸 (츄르 %d/3)" % [base_count, base_count]) and not button.tooltip_text.contains("돌파"), "툴팁이 기본 수만 말한다")

	# ② 몸 방어구 +90 돌파 → +1
	print("[2] 방어구 돌파 +90 → 시큐어 +1")
	game_state.call("add_equipment", "riot_vest", 1)
	_check(bool(game_state.call("equip_equipment", "riot_vest")), "진압 조끼 장착")
	var armor_levels: Dictionary = game_state.get("armor_enhancement_levels")
	armor_levels["riot_vest"] = 90
	var breakthroughs: Dictionary = game_state.get("gear_breakthroughs")
	breakthroughs["armor:riot_vest"] = 90
	_check(bool(game_state.call("has_armor_breakthrough_perk", 90)), "+90 돌파 기록 → 방어구 퍽(시큐어 슬롯) 활성")
	var bonus_count := int(game_state.call("get_secure_slot_count"))
	_check(bonus_count == base_count + 1, "get_secure_slot_count +1 (%d → %d)" % [base_count, bonus_count])
	ui.call("_refresh_contents")
	print("  tooltip=%s" % button.tooltip_text)
	_check(button.tooltip_text.contains("현재 %d칸 (츄르 %d/3 + 방어구 돌파 1)" % [bonus_count, base_count]), "툴팁이 보너스 포함 수 + 출처를 말한다")

	# ③ 츄르 구매 피드백
	print("[3] 츄르로 칸 구매 → 피드백")
	game_state.set("churu", 999)
	ui.call("_refresh_contents")
	_check(not button.disabled, "츄르 충분 → 버튼 활성")
	button.pressed.emit()
	await process_frame
	var feedback := ui.get("inventory_feedback") as Label
	print("  feedback=%s" % (feedback.text if feedback else "<null>"))
	var after_buy := int(game_state.call("get_secure_slot_count"))
	_check(after_buy == bonus_count + 1, "구매 후 슬롯 수 %d" % after_buy)
	_check(feedback != null and feedback.text.contains("죽어도 %d칸은 지킨다" % after_buy), "피드백이 보너스 포함 수(%d칸)를 말한다" % after_buy)

	# ④ 돌파 기록 제거 → 보너스 사라짐
	print("[4] 돌파 기록 제거")
	breakthroughs.erase("armor:riot_vest")
	armor_levels["riot_vest"] = 89
	var without := int(game_state.call("get_secure_slot_count"))
	_check(without == after_buy - 1, "보너스 제거 → %d칸" % without)
	ui.call("_refresh_contents")
	_check(button.tooltip_text.contains("현재 %d칸 (츄르 %d/3)" % [without, without]) and not button.tooltip_text.contains("돌파"), "툴팁도 보너스 없이 복귀 (%s)" % button.tooltip_text)

	holder.queue_free()
	await process_frame
	print("secure_slot_display_probe: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
