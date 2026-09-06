extends SceneTree
## 설정 화면의 언어 전환 검증. 2026-09-06.
##  ① 시작 로케일은 ko이고 tr()이 한국어 원문을 그대로 돌려준다(기존 테스트 보호)
##  ② [English] 버튼을 누르면 로케일이 en으로 바뀌고 설정 화면이 영어로 다시 그려진다
##  ③ 노드 이름(SettingsAction_… )은 한국어 키 그대로다 — 다른 프로브가 그 이름으로 찾는다
##  ④ [한국어]로 되돌리면 원래대로 돌아온다
## 실행: godot --headless --path . --script res://tests/locale_settings_probe.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK %s" % label)
	else:
		failures += 1
		push_error("  FAIL %s" % label)


func _run() -> void:
	var settings := root.get_node_or_null("AccessibilitySettings")
	if settings == null:
		push_error("FAIL AccessibilitySettings 오토로드를 찾지 못했다")
		quit(1)
		return
	var original_language := str(settings.get("language"))

	_check(TranslationServer.get_locale() == "ko", "① 시작 로케일 ko (실제: %s)" % TranslationServer.get_locale())
	_check(tr("작업대") == "작업대", "① ko에서 tr()은 원문 그대로")
	settings.call("open")
	await process_frame
	_check(_find_label_text(settings, "표시 및 조작 설정"), "① 설정 헤더가 한국어")

	var english_button := _find_button(settings, "SettingsLanguage_en")
	_check(english_button != null, "② English 버튼 존재")
	if english_button == null:
		quit(1)
		return
	english_button.pressed.emit()
	await process_frame
	await process_frame
	_check(TranslationServer.get_locale() == "en", "② 로케일 en (실제: %s)" % TranslationServer.get_locale())
	_check(str(settings.get("language")) == "en", "② language 값 저장")
	_check(tr("작업대") == "Workbench", "② en에서 tr() 번역 (실제: %s)" % tr("작업대"))
	_check(_find_label_text(settings, "Display and Controls"), "② 설정 화면이 영어로 다시 그려짐")
	_check(_find_button(settings, "SettingsAction_안내 다시 보기") != null, "③ 노드 이름은 한국어 키 유지")

	var korean_button := _find_button(settings, "SettingsLanguage_ko")
	_check(korean_button != null, "④ 한국어 버튼 존재")
	if korean_button != null:
		korean_button.pressed.emit()
		await process_frame
		await process_frame
		_check(TranslationServer.get_locale() == "ko", "④ 로케일 ko 복귀")
		_check(_find_label_text(settings, "표시 및 조작 설정"), "④ 설정 화면 한국어 복귀")
	settings.call("close")

	# 원래 설정으로 되돌린다 — 프로브가 유저 설정을 바꿔 두면 안 된다.
	settings.set("language", original_language)
	settings.call("_apply_locale")
	settings.call("_save_settings")

	print("locale_settings_probe: %s (failures=%d)" % ["FAIL" if failures > 0 else "PASS", failures])
	quit(1 if failures > 0 else 0)


func _find_button(node: Node, target_name: String) -> Button:
	if node.name == target_name and node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, target_name)
		if found != null:
			return found
	return null


func _find_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _find_label_text(child, text):
			return true
	return false
