extends Object
## 정적 함수용 번역 헬퍼.
## Object.tr()은 인스턴스 메서드라 `static func` 안에서는 부를 수 없다.
## 정적 UI 빌더(HudStyle·DebugGate 등)에서는 tr() 대신 LOC.t()를 쓴다.
##   const LOC := preload("res://scripts/hud/loc.gd")
## 키는 한국어 원문 그대로다 — ko 로케일에서는 원문이 그대로 돌아온다.


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))
