extends SceneTree
## 로케일 파이프라인 프로브 — ko에서는 원문 그대로, en에서는 영어가 나와야 한다.

const SAMPLES := [
	"작업대", "고철", "통조림", "제작", "강화", "창고", "가방",
	"강화 불가 · ", "잠김 · %s 후 이용할 수 있습니다.",
	"%s\n비어 있음", "표시 및 조작 설정",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	if TranslationServer.get_locale() != "ko":
		print("FAIL 시작 로케일이 ko가 아니다: ", TranslationServer.get_locale())
		failed = true
	for sample in SAMPLES:
		if tr(sample) != sample:
			print("FAIL ko에서 원문이 바뀐다: ", sample, " -> ", tr(sample))
			failed = true
	TranslationServer.set_locale("en")
	for sample in SAMPLES:
		var translated := tr(sample)
		if translated == sample:
			print("FAIL en 번역 없음: ", sample)
			failed = true
	print("en 샘플: ", tr("작업대"), " / ", tr("고철"), " / ", tr("통조림"))
	print("en 서식: ", tr("잠김 · %s 후 이용할 수 있습니다.") % tr("사자의 계약"))
	print("en 줄바꿈: ", tr("%s\n비어 있음").replace("\n", "|"))
	TranslationServer.set_locale("ko")
	print("locale pipeline probe: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
