extends SceneTree

# 초기화 프로브(2026-09-03): reset_all_progress_for_opening이 진행 플래그를 전부
# 기본값으로 되돌리는지 — 주홍 해금·첫 만남·이름·생환 횟수가 남으면 안 된다.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("persistence_enabled", false)
	game_state.set("companion_unlocked", true)
	game_state.set("companion_enabled", false)
	game_state.set("juhong_intro_seen", true)
	game_state.set("survived_return_count", 7)
	game_state.set("shelter_return_serial", 9)
	game_state.set("player_name", "재갈")
	game_state.set("shelter_tier", 3)
	game_state.call("reset_all_progress_for_opening")
	var checks := {
		"companion_unlocked=false": game_state.get("companion_unlocked") == false,
		"companion_enabled=true": game_state.get("companion_enabled") == true,
		"juhong_intro_seen=false": game_state.get("juhong_intro_seen") == false,
		"survived_return_count=0": int(game_state.get("survived_return_count")) == 0,
		"shelter_return_serial=0": int(game_state.get("shelter_return_serial")) == 0,
		"player_name=먼지": str(game_state.get("player_name")) == "먼지",
		"shelter_tier=1": int(game_state.get("shelter_tier")) == 1,
		"opening_completed=false": game_state.get("opening_completed") == false,
		"persistence_enabled kept": game_state.get("persistence_enabled") == false,
	}
	var failed := 0
	for label in checks:
		print("RESET|%s|%s" % ["OK" if checks[label] else "NG", label])
		if not checks[label]:
			failed += 1
	if failed == 0:
		print("RESET_PROBE_OK")
		quit(0)
		return
	push_error("RESET_PROBE_FAIL %d" % failed)
	quit(1)
