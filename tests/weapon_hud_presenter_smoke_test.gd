extends SceneTree

const WEAPON_HUD_PRESENTER := preload("res://scripts/weapon_hud_presenter.gd")


func _init() -> void:
	var ready := WEAPON_HUD_PRESENTER.build_state(true, 30, 30, 90, false, 0.0, "7.62mm 보통탄")
	assert(ready.get("ammo_text") == "30 / 30")
	assert(ready.get("status_text") == "사격 준비")
	var low := WEAPON_HUD_PRESENTER.build_state(true, 6, 30, 20, false, 0.0, "7.62mm 보통탄")
	assert(bool(low.get("is_low")))
	assert(low.get("status_text") == "탄창 부족")
	var empty := WEAPON_HUD_PRESENTER.build_state(true, 0, 30, 0, false, 0.0, "7.62mm 보통탄")
	assert(bool(empty.get("is_empty")))
	assert(empty.get("status_text") == "탄창 비움")
	var reloading := WEAPON_HUD_PRESENTER.build_state(true, 0, 30, 24, true, 1.2, "7.62mm 보통탄")
	assert(str(reloading.get("status_text")).contains("재장전"))
	print("weapon_hud_presenter_smoke_test: PASS")
	quit()
