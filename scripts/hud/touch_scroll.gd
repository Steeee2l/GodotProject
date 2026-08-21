class_name TouchScroll
extends RefCounted

# 손가락 드래그(스와이프)로 스크롤되는 ScrollContainer의 단일 문법.
#
# 진범(4.5 엔진 소스 + 합성 터치 프로브로 확정):
#  ScrollContainer의 터치 드래그는 '에뮬레이트된 마우스' 이벤트(mb/mm)로 굴러가는데,
#  리스트 내용물이 전부 Button(MOUSE_FILTER_STOP)이라 누름이 버튼에서 끊겨
#  ScrollContainer가 드래그 시작을 영영 모른다. 버튼이 아닌 '틈'에서 시작한
#  드래그만 스크롤됐고, 유저는 결국 스크롤바를 더듬어야 했다.
#
# 해법: 스크롤 안의 STOP 컨트롤을 PASS로 낮춰 누름이 ScrollContainer까지 올라가게
#  한다. 그러면 엔진 내장 경로가 그대로 산다 — 데드존을 넘는 순간 자식에게
#  NOTIFICATION_SCROLL_BEGIN이 내려가 버튼 눌림이 취소되고(떼도 pressed 미발동),
#  관성 감속도 엔진 것을 쓴다. 데드존 안에서 떼면 평소 탭이다.
#  ScrollContainer 자신은 STOP으로 — 올라온 입력이 뒤쪽 HUD/_unhandled_input으로
#  새지 않게 여기서 끝낸다.
#
# 사용: HudStyle.make_scroll() 로 만들면 자동 적용. 기존 노드엔 TouchScroll.install(sc).

const META_KEY := &"touch_scroll_installed"
const META_ADOPTED := &"touch_scroll_adopted"
# 손가락 떨림은 탭으로 남긴다(안드로이드 touch slop 8dp에 준함). 엔진 기본 0은
# 1px만 흔들려도 스크롤로 보고 탭을 먹어 버린다.
const DEADZONE := 12


static func install(scroll: ScrollContainer) -> ScrollContainer:
	if scroll == null or scroll.has_meta(META_KEY):
		return scroll
	scroll.set_meta(META_KEY, true)
	scroll.scroll_deadzone = DEADZONE
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_adopt(scroll, scroll)
	return scroll


static func _adopt(node: Node, scroll: ScrollContainer) -> void:
	# 중첩 ScrollContainer는 제 손으로 관리한다(안쪽이 STOP이어야 안쪽만 굴러간다).
	if node != scroll and node is ScrollContainer:
		return
	if node.has_meta(META_ADOPTED):
		return
	node.set_meta(META_ADOPTED, true)
	if node is Control:
		_relax(node as Control, scroll)
	# 나중에 들어오는 자손(목록 재생성·행 추가)도 같은 규칙을 받는다.
	node.child_entered_tree.connect(func(child: Node) -> void: _on_child_entered(child, scroll))
	for child in node.get_children():
		_adopt(child, scroll)


static func _on_child_entered(child: Node, scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	_adopt(child, scroll)


static func _relax(control: Control, scroll: ScrollContainer) -> void:
	if control == scroll:
		return
	# 누르자마자 발동(BUTTON_PRESS)하는 버튼은 스와이프와 공존할 수 없다 — 손이
	# 닿는 순간 이미 눌려서 스크롤이 취소할 것이 없다. 목록 안에서는 '떼는 순간'
	# 발동으로 통일한다(모바일 목록의 표준 동작).
	if control is BaseButton and (control as BaseButton).action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS:
		(control as BaseButton).action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	if control.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	# 제 몸으로 드래그를 쓰는 컨트롤은 건드리지 않는다 — 슬라이더·스크롤바·
	# 텍스트 입력은 세로 드래그가 제 기능이라 스크롤에 뺏기면 안 된다.
	if (
		control is Range
		or control is LineEdit
		or control is TextEdit
		or control is ItemList
		or control is Tree
		or control is GraphEdit
	):
		return
	control.mouse_filter = Control.MOUSE_FILTER_PASS
