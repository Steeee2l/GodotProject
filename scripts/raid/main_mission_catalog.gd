class_name MainMissionCatalog
extends RefCounted

# 존별 메인 미션 체인 데이터 테이블.
#
# 구역마다 3단계짜리 체인이 있고, 세 단계를 끝낸 구역에서는 메인 미션이
# 더 이상 뜨지 않는다 — 흔적이 다음 구역으로 넘어간다.
#
# ── 이야기 뼈대(한 줄 요약) ───────────────────────────────────
#   사람은 도망친 게 아니다. 대피였고, 자리가 모자란다고 믿은 누가 문을 닫았다.
#   종로   신호의 정체    → 사람들은 걸어 나갔다(녹음 방송이 불렀다)
#   남대문 사료의 출처    → 반년째 새벽마다 채워 놓는 놈이 있다
#   을지로 마지막 운행    → 탑승 27, 잔여 9. 아홉은 셔터 밖에 남았다
#   용산   군의 협조      → 군은 알고도 도왔다. 주홍이 사자를 노리는 이유
#   남산   시스템 본체    → 사람들은 지하에 살아 있다. 끄거나, 깨우거나(선택)
#
# ── 문체 규칙(어기면 갈아엎기 전으로 돌아간다) ─────────────────
#   1) 한 장면에 새 고유명사는 1개까지. 이미 나온 것만 반복해 쓴다.
#   2) 모든 단계는 "무엇을 알아냈다"로 끝난다. 분위기로 끝내지 않는다.
#   3) 한 줄은 한 가지만 말한다. 은유로 두 겹 싸지 않는다.
#   4) 목소리 분리 — 먼지: 짧고 건조. 사자: 공무원 말투. 주홍: 거칠고 정직.
#      행상인: 수다스럽고 물건 얘기로 돌아감. 주민/생존자: 겁먹은 짧은 문장.
#   5) 정보는 구체적인 물건·숫자·목격담으로 준다(27에서 멈춘 번호, 신발 상자, 녹음, 발자국).
#
# ── 이 테이블만 고치면 새 미션이 생긴다 ──────────────────────
#
# CHAINS[zone_id] = [단계0, 단계1, 단계2]
#
# 단계(Dictionary):
#   id                  저장·회수 기록용 고유 id (recovered_story_cargo_ids 키)
#   title               배너/정산에 쓰는 미션 이름
#   type                "relay" | "defense" | "keyed"  — 표시용 분류
#   points              현장 지점 배열(아래 참조)
#   recovery            회수물 {id, title, description, label, map_label, prop, color, hold}
#   carry_title         회수 후 배너 제목
#   carry_detail        회수 후 배너 세부 문구
#   carry_notice        회수 순간의 필드 알림
#   carry_monologue     단계 완료 독백 2줄 — 반드시 "오늘 알아낸 것"으로 끝난다
#   reward              첫 회수 보상 {canned_food, churu, components:{}, progression_items:{}, xp, summary}
#                       progression_items = 쉘터 확장 키 등 0칸 서사 아이템(첫 회수에만, 재회수 없음)
#   repeat_reward       재회수 보상(축소판) — 반복 파밍 방지
#   lore                있으면 unlocked_contract_lore에 기록으로 남는다
#
# 지점(points 원소):
#   step_title          이 지점을 향할 때 배너 제목
#   detail              이 지점을 향할 때 배너 세부 문구
#   label               상호작용 표시명
#   map_label           전술 지도 마커 라벨
#   prop                프롭 텍스처 키(MainMissionChain.PROP_TEXTURES)
#   color               마커·비콘 색
#   hold                상호작용 홀드 시간(초)
#   distance            플레이어로부터 최소 거리
#   separation          다른 지점과 최소 간격
#   role                "" | "key" | "locked" | "defense"
#   alarm               true면 이 지점이 열릴 때 경보 웨이브가 시작된다
#   guards              이 지점 주변에 미리 깔아 둘 적 수(열쇠 지점 = 적 밀집지)
#   complete_notice     이 지점을 끝냈을 때의 필드 알림
#   complete_monologue  이 지점을 끝냈을 때의 독백(빈 배열이면 생략) — 분위기가 아니라 알아낸 사실
#   defense_duration    role == "defense"일 때 버텨야 하는 초
#   defense_waves       role == "defense"일 때 밀려오는 웨이브 수
#
# 신규 기믹은 만들지 않는다. relay(연쇄 상호작용) / defense(방어) /
# keyed(열쇠+거점) 세 골격의 조합으로만 짠다 — 유지보수 가능해야 한다.

const STAGES_PER_ZONE := 3

# 대사창 초상화 — 기존 캐릭터 스프라이트의 정면 대기 프레임을 그대로 쓴다.
# 시네마틱 모드 메타: 스텝 배열 첫머리의 {"mode": "bark"}는 "대사+카메라 눈길뿐인 장면"을
# 하단 바크(조작 유지)로 흘리라는 강제다(FieldCinematic.classify_mode). 배우·이미지 컷·
# 선택지가 있는 장면은 자동으로 event(세상 정지)로 간다. 바크 모드에서 focus는 건너뛰고
# flash/shake는 HUD·카메라 흔들림으로만 남는다 — 유저 신고 "대사 때마다 못 움직인다".
const PORTRAIT_NABI_PATH := "res://assets/characters/cat_8way/down_idle_0.png"
const PORTRAIT_WORKER_PATH := "res://assets/characters/worker_cat/down_idle-frame-0.png"
const PORTRAIT_JUHONG_PATH := "res://assets/characters/juhong/down_idle-frame-0.png"
const PORTRAIT_SAJA_PATH := "res://assets/characters/saja/down_idle-frame-0.png"

# 이야기가 흐르는 순서. 한 구역을 완주하면 이 순서의 다음 구역을 가리킨다.
const ZONE_ORDER: Array[String] = [
	"jongno_outskirts",
	"namdaemun_market",
	"euljiro_depths",
	"yongsan_blockade",
	"namsan_core",
]

const CHAINS := {
	# ── 종로 외곽 ────────────────────────────────────────────────
	# 이 구역에서 알아내는 것: 사람들은 끌려간 게 아니라 걸어 나갔다.
	"jongno_outskirts": [
		{
			"id": "seoul_line3_relief_core",
			"title": "신호를 보낸 것",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.4},
					{"type": "focus", "at": "site", "hold": 1.1},
					{"type": "flash", "color": "#62c9ca", "pulses": 2, "duration": 0.9},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "신호를 보낸 것",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"사자가 발전기 벨트를 구해 오라고 했다. 지하철엔 그런 게 있다고.",
							"종로역. 셔터가 내려와 있다.",
							"밖에서 잠근 게 아니다. 안에서 잠갔다.",
							"안에서 잠갔으면 잠근 놈이 안에 있었다는 소리다.",
							"옆문으로 들어간다. 역무실에 모니터가 아직 켜져 있다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_0": [
					{
						"type": "image_cut",
						"texture": "manifest_terminal",
						"title": "역무실 단말 · 화면",
						"lines": [
							"은행 번호표 같은 화면이다. 큰 숫자 하나.",
							"27.",
							"그 밑에 호명된 동호수가 줄줄이 떠 있다. 101동, 102동, 103동…",
							"27에서 멈췄다. 다음 번호를 부르는 버튼은 아직 안 눌렸다.",
							"승강장 스피커 선이 비상 발전기로 이어져 있다. 벨트도 저기 있을 거다.",
						],
					},
				],
				"point_1": [
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "runner",
						"root": "res://assets/characters/worker_cat",
						"display_name": "겁먹은 고양이",
						"role": "",
						"at": "player",
						"offset": Vector3(9.5, 0.0, 7.5),
					},
					{"type": "focus", "at": "player", "offset": Vector3(5.0, 0.0, 4.0), "hold": 0.5},
					{
						"type": "actor_walk",
						"key": "runner",
						"to_at": "player",
						"to_offset": Vector3(2.1, 0.0, 1.7),
						"duration": 1.5,
					},
					{"type": "shake", "strength": 0.3, "duration": 0.35},
					{"type": "actor_fall", "key": "runner", "hold": 0.6},
					{
						"type": "lines",
						"speaker": "겁먹은 고양이",
						"title": "그날 본 것",
						"portrait": PORTRAIT_WORKER_PATH,
						"lines": [
							"나, 나 그날 봤어.",
							"사람들이 줄을 서서 걸어 나갔어.",
							"끌려간 게 아니야. 다들 웃으면서 갔어.",
							"그, 그게 제일 무서웠어.",
						],
					},
					{
						"type": "choice",
						"id": "jongno_stage1_runner",
						"prompt": "쓰러진 고양이를 어떻게 할까.",
						"options": [
							{
								"id": "take",
								"label": "데려간다",
								"detail": "호송 · 이동이 느려진다",
								"effect": {
									"rescue": true,
									"notice": "생존자 호송 시작 · 이동 속도가 감소합니다",
									"monologue": [
										"업으면 느려진다. 느려지면 위험하다.",
										"…그래도 데려간다. 여기 두면 죽는다.",
									],
								},
							},
							{
								"id": "leave",
								"label": "두고 간다",
								"detail": "속도 유지 · 다음에 오겠다고 말한다",
								"effect": {
									"notice": "생존자를 두고 이동 · 좌표는 기억해 뒀다",
									"monologue": [
										"다시 오겠다고 했다. 안 믿는 눈치였다.",
										"들을 건 다 들었다. 오늘은 여기까지.",
									],
								},
							},
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "sealed_cargo",
						"title": "화물칸 · 개봉 전",
						"lines": [
							"방역 도장이 찍힌 화물칸이 승강장에 서 있다.",
							"봉인이 아직 안 뜯겼다. 반년 동안 아무도 못 열었다는 소리다.",
							"떼어서 들고 나간다.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 신호를 보낸 것 0/4",
					"detail": "TAB 지도 확인 → 지하철 역무실 단말을 조사한다",
					"label": "역무실 단말 조사",
					"map_label": "신호가 나온 단말",
					"prop": "manifest_terminal",
					"color": "#62c9ca",
					"hold": 1.6,
					"distance": 34.0,
					"separation": 22.0,
					"complete_notice": "호명 기록 확인 · 발전기 위치가 지도에 표시됩니다",
					"complete_monologue": [
						"대피 호명 번호가 27에서 멈춰 있다.",
						"다음 번호 버튼은 아직 안 눌렸다.",
						"스피커 선이 발전기로 이어진다. 저걸 살린다.",
					],
				},
				{
					"step_title": "발전기 복구 · 1/4",
					"detail": "역 안 스피커에 전기를 넣는다",
					"label": "역 발전기 복구",
					"map_label": "역 비상 발전기",
					"prop": "generator",
					"color": "#e7a847",
					"hold": 2.8,
					"distance": 42.0,
					"separation": 26.0,
					"complete_notice": "전력 복구 · 스피커가 녹음을 반복합니다 · 소리를 듣고 적이 옵니다",
					"complete_monologue": [
						"전기가 들어오자 스피커가 혼자 켜졌다.",
						"〈관리사무소에서 안내 말씀 드립니다. 101동부터 순서대로 내려오시기 바랍니다. 짐은 두고 오십시오.〉",
						"열두 초 쉬고 다시 튼다. 반년째 아무도 없는 승강장에 대고.",
						"소리를 듣고 놈들이 온다. 승강장 끝에 화물칸이 있다. 챙긴다.",
					],
				},
			],
			"recovery": {
				"id": "seoul_line3_relief_core",
				"title": "방역 도장이 찍힌 화물칸",
				"description": "역 승강장에 남아 있던 화물칸입니다. 방역 도장이 찍힌 채 반년째 봉인되어 있습니다. 탈출해야 열어 볼 수 있습니다.",
				"label": "화물칸 분리",
				"map_label": "경보 발생 · 봉인된 화물칸",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.2,
				"distance": 48.0,
				"separation": 30.0,
				"step_title": "화물칸 회수 · 2/4",
				"detail": "붉은 화물칸으로 이동한다 · 경보가 울린다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "화물칸 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "화물칸 확보 · 탈출하면 열어 볼 수 있습니다",
			"carry_monologue": [
				"사람들은 끌려간 게 아니다. 줄을 서서 걸어 내려갔다.",
				"번호를 부르는 방송이 있었고, 27번에서 멈췄다.",
				"그 방송을 아직도 틀고 있다.",
				"…누가 틀어 놨을까. 다음엔 그걸 본다.",
			],
			"reward": {
				"canned_food": 8,
				"churu": 1,
				"components": {"scope_lens": 1},
				"xp": 220,
				"summary": "화물칸 개봉 · 통조림 +8 · 츄르 +1 · 스코프 렌즈 +1 · XP +220\n새 기록 · ‘봉인된 화물칸’ 해금",
			},
			"repeat_reward": {
				"canned_food": 3,
				"churu": 1,
				"xp": 90,
				"summary": "남은 화물칸 개봉 · 통조림 +3 · 츄르 +1 · XP +90",
			},
			"lore": "봉인된 화물칸 · 종로역\n방역 도장이 찍힌 채 반년을 서 있던 화물칸. 안은 짐이었다. 가방, 신발, 지갑. 사람 옷 냄새가 났다.\n맨 위 가방에 세탁소 이름표가 붙어 있고, 뒷면에 볼펜으로 적혀 있다. 「금방 옴」",
		},
		{
			"id": "jongno_watermain_record",
			"title": "끊긴 수도관",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "끊긴 수도관",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"쉘터 정수기가 샌다. 사자가 아침부터 물통 얘기를 세 번 했다.",
							"도로 밑에서 물소리가 난다.",
							"수돗물은 그날 끊겼다. 반년 동안 안 나왔다. 그런데 지금 흐른다.",
							"배관 표지판에 밸브가 세 군데 적혀 있다.",
							"세 개를 순서대로 열면 마지막 밸브실이 열린다.",
							"1번부터.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_1": [
					{"mode": "bark"},
					{"type": "focus", "at": "site", "hold": 0.8},
					{"type": "flash", "color": "#6fb7d8", "pulses": 2, "duration": 0.8},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "도로 건너편",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"두 번째 밸브. 그러자 도로 건너편에 불이 켜졌다.",
							"가로등이 아니다. 손전등. 여덟 개.",
							"저쪽도 물소리를 들었다.",
							"몸을 낮춘다. 마지막 밸브실로.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "convoy_cache",
						"title": "배관도 · 손글씨",
						"lines": [
							"배관도가 벽에 걸려 있다.",
							"인쇄된 선 위에 누가 다른 잉크로 선을 하나 더 그었다.",
							"본선에서 갈라져 남쪽으로, 산 밑으로 내려가는 관이다.",
							"선을 따라 짧게 적어 놨다. 「살아 있음」 「살아 있음」 「여기부터 모름」",
							"…누가 여기까지 와서 확인하고 갔다. 뜯어서 들고 나간다.",
						],
					},
					{
						"type": "choice",
						"id": "jongno_stage2_valve",
						"prompt": "밸브를 열어 둘까, 다시 잠글까.",
						"options": [
							{
								"id": "shut",
								"label": "밸브를 다시 잠그고 나간다",
								"detail": "긴장도 하락 · 조용히 빠진다",
								"effect": {
									"pressure": -60.0,
									"notice": "밸브 폐쇄 · 도시가 다시 조용해진다",
									"monologue": [
										"열어 두면 다음에 오는 놈도 이 길을 본다.",
										"잠근다. 아직 나만 아는 길이다.",
									],
								},
							},
							{
								"id": "keep",
								"label": "열어 둔 채 더 뒤진다",
								"detail": "정산 보상 상승 · 증원 확률 상승",
								"effect": {
									"reward_multiplier": 0.15,
									"pressure": 45.0,
									"notice": "밸브 개방 유지 · 소음이 멀리 퍼진다",
									"monologue": [
										"물이 흐르면 소리가 난다. 소리가 나면 적이 온다.",
										"오라고 하자. 오는 놈들도 뭔가는 들고 있다.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 끊긴 수도관 0/4",
					"detail": "TAB 지도 확인 → 도로 건너편 1번 밸브를 연다",
					"label": "1번 밸브 개방",
					"map_label": "1번 밸브",
					"prop": "generator",
					"color": "#6fb7d8",
					"hold": 2.2,
					"distance": 40.0,
					"separation": 34.0,
					"complete_notice": "1번 밸브 개방 · 물이 2번 밸브 쪽으로 밀린다",
					"complete_monologue": [
						"밸브를 열었다. 물이 이쪽으로 안 온다.",
						"반대쪽으로 빨려 나간다. 어디선가 쓰고 있다는 소리다.",
						"…어디로 가는지 보자. 2번.",
					],
				},
				{
					"step_title": "2번 밸브 개방 · 1/4",
					"detail": "반대편 블록의 2번 밸브로 이동한다 · 도로에 오래 서 있지 않는다",
					"label": "2번 밸브 개방",
					"map_label": "2번 밸브",
					"prop": "generator",
					"color": "#6fb7d8",
					"hold": 2.2,
					"distance": 46.0,
					"separation": 38.0,
					"complete_notice": "2번 밸브 개방 · 마지막 밸브실 위치가 지도에 표시됩니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "jongno_watermain_record",
				"title": "남산으로 가는 관",
				"description": "마지막 밸브실 벽에 걸려 있던 배관도입니다. 인쇄된 선 위에 누가 다른 잉크로 관을 하나 더 그려 넣었습니다.",
				"label": "배관도 회수",
				"map_label": "마지막 밸브실 · 배관도",
				"prop": "convoy_cache",
				"color": "#e0a94f",
				"hold": 3.4,
				"distance": 52.0,
				"separation": 40.0,
				"step_title": "배관도 회수 · 2/4",
				"detail": "마지막 밸브실에서 배관도를 뜯어 온다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "배관도 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "배관도 확보 · 탈출하면 선이 어디로 가는지 읽을 수 있습니다",
			"carry_monologue": [
				"물이 남쪽으로 간다. 산 밑으로. 반년째.",
				"물을 쓴다는 건 저쪽에서 뭔가 아직 돌아간다는 소리다.",
				"…그리고 글씨 쓴 놈은 거기까지 가 봤다는 거고.",
			],
			"reward": {
				"canned_food": 11,
				"churu": 1,
				"components": {"rubber_gasket": 2},
				"xp": 320,
				"summary": "배관도 해독 · 통조림 +11 · 츄르 +1 · 고무 패킹 +2 · XP +320",
			},
			"repeat_reward": {
				"canned_food": 4,
				"xp": 110,
				"summary": "배관도 사본 회수 · 통조림 +4 · XP +110",
			},
		},
		{
			"id": "jongno_broadcast_log",
			"title": "잠긴 방송국",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e2c15f", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "잠긴 방송국",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"스피커가 아직 열두 초마다 같은 방송을 튼다.",
							"기계가 어디서 돌고 있다는 소리다.",
							"주조정실은 잠겨 있다.",
							"앞마당에 약탈대가 진을 쳤다. 방송국을 털었으면 열쇠도 그놈들 손에 있다.",
							"정리하고 뺏는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_0": [
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "juhong",
						"root": "res://assets/characters/juhong",
						"display_name": "주홍",
						"role": "떠도는 고양이",
						"at": "player",
						"offset": Vector3(8.0, 0.0, -6.5),
					},
					{"type": "focus", "at": "player", "offset": Vector3(4.0, 0.0, -3.0), "hold": 0.4},
					{
						"type": "actor_walk",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(2.0, 0.0, -1.6),
						"duration": 1.7,
					},
					{
						"type": "lines",
						"speaker": "주홍",
						"title": "같은 방송을 쫓는 것",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"손 내려. 나도 그 방송 듣고 왔어.",
							"열두 초마다 같은 잡음. 나는 그걸 여섯 동네에서 들었어.",
							"고장 나서 그러는 게 아니야. 누가 반복하라고 시켜 뒀지.",
							"안에 마지막 송출 기록이 있어. 뭘 읽었는지 거기 남아 있을 거야.",
							"나 주홍이야. 하수구에서 오래 혼자 살았어.",
							"그러니까 나한테 뭐 기대하지 마.",
							"들어가. 밖은 내가 볼게.",
						],
					},
					{
						"type": "actor_exit",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(11.0, 0.0, -9.0),
						"duration": 1.9,
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "manifest_terminal",
						"title": "마지막 송출 기록",
						"lines": [
							"대피 안내가 나온다. 우리가 아는 그거다. 101동부터, 짐은 두고.",
							"안내가 끝나고 마이크가 안 꺼졌다. 3분이 그대로 녹음돼 있다.",
							"종이 넘기는 소리. 의자 끄는 소리.",
							"그리고 사람 목소리. 방송용이 아니다. 혼잣말이다.",
							"「…이제 몇 명 남았지.」",
							"뜯어서 들고 나간다.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 잠긴 방송국 0/3",
					"detail": "TAB 지도 확인 → 약탈대가 낀 구역에서 주조정실 열쇠를 뺏는다",
					"label": "주조정실 열쇠 확보",
					"map_label": "주조정실 열쇠 · 약탈대 점거",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 2.6,
					"distance": 38.0,
					"separation": 30.0,
					"role": "key",
					"guards": 4,
					"complete_notice": "주조정실 열쇠 확보 · 방송국 문이 열립니다",
					"complete_monologue": [
						"열쇠. 이름은 없고 직책만 찍혀 있다. ‘야간 송출 담당’.",
						"마지막까지 마이크 앞에 앉아 있던 사람이 있었다.",
						"주조정실을 연다.",
					],
				},
			],
			"recovery": {
				"id": "jongno_broadcast_log",
				"title": "마이크가 안 꺼진 3분",
				"description": "주조정실 콘솔에서 뜯어낸 기록입니다. 마지막 방송의 원고와 녹음 날짜가 그대로 남아 있습니다.",
				"label": "송출 기록 회수",
				"map_label": "주조정실 · 잠김",
				"prop": "manifest_terminal",
				"color": "#e66a47",
				"hold": 4.0,
				"distance": 46.0,
				"separation": 34.0,
				"step_title": "주조정실 진입 · 1/3",
				"detail": "열쇠로 주조정실을 열고 송출 기록을 가져온다",
				"role": "locked",
				"locked_reason": "주조정실 열쇠가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "송출 기록 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "송출 기록 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"사람 목소리를 반년 만에 들었다.",
				"방송을 튼 사람은 마지막까지 저기 앉아 있었다. 그 사람도 세고 있었다.",
				"몇 명이 못 들어갔을까.",
				"…행상인이 남대문에 사료가 돈다고 했다. 다음은 거기.",
			],
			"reward": {
				"canned_food": 14,
				"churu": 2,
				"components": {"magazine_spring": 2},
				"xp": 460,
				"summary": "송출 기록 복원 · 통조림 +14 · 츄르 +2 · 탄창 스프링 +2 · XP +460\n새 기록 · ‘마이크가 안 꺼진 3분’ 해금",
			},
			"repeat_reward": {
				"canned_food": 5,
				"xp": 150,
				"summary": "송출 기록 사본 회수 · 통조림 +5 · XP +150",
			},
			"lore": "마이크가 안 꺼진 3분 · 종로 방송국\n마지막 송출 기록. 대피 안내가 끝나고도 마이크가 3분 동안 켜져 있었다.\n종이 넘기는 소리, 의자 소리, 그리고 혼잣말 한 마디. 「이제 몇 명 남았지.」",
		},
	],
	# ── 남대문 폐시장 ────────────────────────────────────────────
	# 이 구역에서 알아내는 것: 반년째 고양이 밥을 대는 놈이 창고 열쇠를 갖고 있다.
	"namdaemun_market": [
		{
			"id": "namdaemun_hidden_ration",
			"title": "몰래 채워 두는 밥",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "몰래 채워 두는 밥",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"행상인이 그랬다. 남대문에 사료가 돈다고.",
							"시장 한복판에 천막이 세 겹.",
							"바람 막으려고 친 게 아니다. 숨기려고.",
							"천막 쪽에서 냄새가 난다. 썩은 냄새가 아니다. 먹을 수 있는 냄새.",
							"좌판 밑으로 작은 발자국이 천막까지 이어진다.",
							"따라간다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_1": [
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "keeper",
						"root": "res://assets/characters/worker_cat",
						"display_name": "마른 고양이",
						"role": "",
						"at": "player",
						"offset": Vector3(4.5, 0.0, 4.0),
					},
					{"type": "focus", "at": "player", "offset": Vector3(2.5, 0.0, 2.0), "hold": 0.5},
					{
						"type": "lines",
						"speaker": "마른 고양이",
						"title": "손수레를 지키던 것",
						"portrait": PORTRAIT_WORKER_PATH,
						"lines": [
							"거, 거기 손대지 마.",
								"반년째 누가 채워 놔. 새벽마다 조금씩.",
							"채우는 걸 본 적은 없어.",
							"발자국만 남아. 고양이 발자국이야.",
						],
					},
					{
						"type": "actor_exit",
						"key": "keeper",
						"to_at": "player",
						"to_offset": Vector3(-9.0, 0.0, 8.0),
						"duration": 1.8,
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "pharmacy_cache",
						"title": "천막 밑 상자",
						"lines": [
							"상자를 열었다. 전부 사료다. 사람 음식은 없다.",
							"바닥에 배급표. 날짜가 오늘까지 찍혀 있다.",
							"사람들이 사라진 지 반년.",
							"그 반년 동안 누가 고양이들한테만 몰래 밥을 댔다.",
							"…왜 고양이한테만. 일단 이 상자를 어떻게 할지.",
						],
					},
					{
						"type": "choice",
						"id": "namdaemun_stage1_ration",
						"prompt": "이 배급을 어떻게 할까.",
						"options": [
							{
								"id": "take_all",
								"label": "전부 가져간다",
								"detail": "통조림 확보 · 정산 보상 상승",
								"effect": {
									"reward_multiplier": 0.12,
									"notice": "상자 전량 회수",
									"monologue": [
										"쉘터엔 오늘 밤 먹을 게 없는 애들이 여럿이다.",
										"전부 가져간다. 미안한 건 나중에.",
									],
								},
							},
							{
								"id": "leave_half",
								"label": "절반은 남겨 둔다",
								"detail": "고철 보상 · 미끼를 그대로 둔다",
								"effect": {
									"scrap": 2600,
									"notice": "절반 회수 · 나머지는 제자리에",
									"monologue": [
										"상자가 비면 채우던 놈이 눈치챈다.",
										"절반만. 나는 아직 그놈을 못 봤다.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 몰래 채워 두는 밥 0/4",
					"detail": "TAB 지도 확인 → 좌판 밑 발자국을 따라간다",
					"label": "좌판 밑 발자국 조사",
					"map_label": "좌판 밑 발자국",
					"prop": "convoy_cache",
					"color": "#d9b06a",
					"hold": 1.8,
					"distance": 30.0,
					"separation": 20.0,
					"complete_notice": "발자국 추적 · 다음 지점이 지도에 표시됩니다",
					"complete_monologue": [
						"좌판 밑 발자국. 사람이 아니다. 고양이.",
						"같은 발자국이 밤마다 여길 지나갔다.",
						"골목 안쪽으로.",
					],
				},
				{
					"step_title": "뒤집힌 손수레 · 1/4",
					"detail": "골목 안쪽의 뒤집힌 손수레를 살펴본다",
					"label": "뒤집힌 손수레 확인",
					"map_label": "뒤집힌 손수레",
					"prop": "convoy_cache",
					"color": "#d9b06a",
					"hold": 1.8,
					"distance": 34.0,
					"separation": 24.0,
					"complete_notice": "천막 밑 상자 위치 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namdaemun_hidden_ration",
				"title": "천막 밑 사료 상자",
				"description": "천막 세 겹 아래 숨겨져 있던 상자입니다. 안은 전부 사료고, 배급표 날짜가 오늘까지 찍혀 있습니다.",
				"label": "사료 상자 회수",
				"map_label": "천막 밑 사료 상자",
				"prop": "pharmacy_cache",
				"color": "#e66a47",
				"hold": 3.2,
				"distance": 38.0,
				"separation": 26.0,
				"step_title": "사료 상자 회수 · 2/4",
				"detail": "천막 안쪽의 사료 상자를 연다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "사료 상자 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "사료 상자 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"누가 반년째 고양이들 밥을 대고 있다. 우린 굶는데.",
				"사료만 있고 사람 음식은 없다. 고양이만 골라서 먹인다.",
				"반년치를 쌓아 두려면 창고가 있어야 한다.",
				"…시장에서 제일 큰 창고부터 본다.",
			],
			"reward": {
				"canned_food": 16,
				"churu": 2,
				"components": {"rubber_gasket": 2},
				"xp": 520,
				"summary": "사료 상자 개봉 · 통조림 +16 · 츄르 +2 · 고무 패킹 +2 · XP +520",
			},
			"repeat_reward": {
				"canned_food": 6,
				"xp": 170,
				"summary": "남은 사료 회수 · 통조림 +6 · XP +170",
			},
		},
		{
			"id": "namdaemun_warehouse_manifest",
			"title": "나간 짐이 없는 창고",
			"type": "defense",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e7a847", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "나간 짐이 없는 창고",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"반년치 밥을 대려면 쌓아 둘 데가 있어야 한다.",
							"시장에서 제일 큰 창고가 이거다.",
							"셔터에 붉은 등이 아직 켜져 있다. 배터리로는 반년을 못 버틴다. 누가 전기를 댄다.",
							"제어반을 누르면 셔터가 열린다.",
							"열리는 동안 온 동네가 듣는다.",
							"버틸 준비부터.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_0": [
					{"type": "shake", "strength": 0.28, "duration": 0.4},
					{
						"type": "image_cut",
						"texture": "military_cache",
						"title": "101동 302호 신발 상자",
						"lines": [
							"장부가 있다. 반입만 빼곡하고 반출은 한 줄도 없다.",
							"들어온 건 전부 짐이다. 가방, 신발, 지갑.",
							"신발 상자 하나에 매직으로 적혀 있다. 101동 302호.",
							"열어 본다. 신발 한 켤레. 아직 흙이 묻어 있다.",
							"…짐을 모아서 넣고 잠갔다. 왜.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 나간 짐이 없는 창고 0/3",
					"detail": "TAB 지도 확인 → 셔터 제어반을 누르고 버틴다",
					"label": "셔터 제어반 조작",
					"map_label": "창고 셔터",
					"prop": "generator",
					"color": "#e7a847",
					"hold": 2.4,
					"distance": 36.0,
					"separation": 28.0,
					"role": "defense",
					"defense_duration": 15.0,
					"defense_waves": 3,
					"complete_notice": "셔터 개방 시작 · 15초간 자리를 지켜라",
					"complete_monologue": [
						"셔터를 지키는 건 사람이 아니라 자동 경보였다. 아직 전기가 들어온다.",
						"누가 이 창고를 계속 잠가 두게 해 놨다.",
						"열릴 때까지 버틴다.",
					],
				},
			],
			"recovery": {
				"id": "namdaemun_warehouse_manifest",
				"title": "101동 302호 신발 상자",
				"description": "셔터 안쪽 창고에서 가져온 신발 상자입니다. 옆면에 매직으로 101동 302호라고 적혀 있고, 안에 신발 한 켤레가 들어 있습니다.",
				"label": "신발 상자 회수",
				"map_label": "101동 302호 상자",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.2,
				"step_title": "신발 상자 회수 · 2/3",
				"detail": "열린 창고 안쪽에서 신발 상자를 가져온다",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "신발 상자 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "신발 상자 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"사람들 짐은 전부 여기 있다. 가방, 신발, 지갑.",
				"방송이 그랬다. 짐은 두고 오라고. 정말 다 두고 갔다.",
				"여기 전기가 아직 들어온다. 반년 동안 누가 셔터를 잠가 뒀다.",
				"…열쇠 가진 놈이 있다. 그놈이 사료도 채운다.",
			],
			"reward": {
				"canned_food": 19,
				"churu": 2,
				"components": {"magazine_spring": 2},
				# 무기 사다리 — 상자 밑에 깔려 있던 펌프 산탄총 도면(설계도 조각 2/3). 첫 회수에만.
				# 통짜 청사진은 폐지 — 제작은 조각 3/3(나머지 1조각은 남대문 엘리트·봉인 상자).
				"progression_items": {"blueprint_shard_pump_shotgun": 2},
				"xp": 640,
				"summary": "신발 상자 확인 · 통조림 +19 · 츄르 +2 · 탄창 스프링 +2 · XP +640\n펌프 산탄총 청사진 획득 · 작업대에서 펌프 산탄총 제작 가능",
			},
			"repeat_reward": {
				"canned_food": 7,
				"xp": 210,
				"summary": "남은 상자 확인 · 통조림 +7 · XP +210",
			},
		},
		{
			"id": "namdaemun_guild_ledger",
			"title": "새벽에 오는 것",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "새벽에 오는 것",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"시장 사무실 금고가 아직 안 털렸다. 이 도시에서 그건 이상하다.",
							"안 턴 게 아니다. 못 연 거다. 인장이 없으면 안 열린다.",
							"인장은 사무실 주인이 갖고 있었다. 주인은 약탈대 거점 쪽에서 죽었다.",
							"인장은 그놈들 손에 있다.",
							"뺏는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_0": [
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "juhong",
						"root": "res://assets/characters/juhong",
						"display_name": "주홍",
						"role": "떠도는 고양이",
						"at": "player",
						"offset": Vector3(-7.5, 0.0, 6.0),
					},
					{"type": "focus", "at": "player", "offset": Vector3(-3.5, 0.0, 3.0), "hold": 0.4},
					{
						"type": "actor_walk",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(-2.0, 0.0, 1.6),
						"duration": 1.7,
					},
					{
						"type": "lines",
						"speaker": "주홍",
						"title": "새벽에 본 것",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"인장 찾았네. 그럼 하나 말해 줄게.",
							"나 어제 새벽에 여기 있었어. 사료 채우는 놈 봤어.",
							"안전모 쓰고 있더라. 창고 열쇠도 갖고 있고.",
							"누군지 알겠지.",
							"아직 나도 몰라. 밥 준다고 나쁜 놈은 아니니까.",
							"열어. 뒤는 내가 볼게.",
						],
					},
					{
						"type": "actor_exit",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(-10.0, 0.0, 8.5),
						"duration": 1.9,
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "sealed_cargo",
						"title": "금고 안 · 열쇠 한 벌",
						"lines": [
							"금고 안에 돈은 없다. 열쇠 한 벌이다.",
							"종로 집결지 셔터 열쇠. 꼬리표가 붙어 있다.",
							"세 개짜리 고리인데 하나가 비어 있다.",
							"…하나를 누가 가져갔다.",
							"이 열쇠를 어떻게 할지.",
						],
					},
					{
						"type": "choice",
						"id": "namdaemun_stage3_ledger",
						"prompt": "이 열쇠를 어떻게 할까.",
						"options": [
							{
								"id": "carry",
								"label": "그대로 들고 나간다",
								"detail": "기록 보관 · 정산 보상 상승",
								"effect": {
									"reward_multiplier": 0.1,
									"notice": "열쇠 원본 회수",
									"monologue": [
										"비어 있는 고리 하나. 그게 어디 있는지 알아야 한다.",
										"그대로 들고 나간다.",
									],
								},
							},
							{
								"id": "burn_copy",
								"label": "자물쇠째 부순다",
								"detail": "긴장도 하락 · 추적을 끊는다",
								"effect": {
									"pressure": -70.0,
									"notice": "원본 소각 · 사본만 회수",
									"monologue": [
										"열쇠 가진 놈이 다시 올 수도 있다.",
										"자물쇠를 부순다. 이제 아무나 연다.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 새벽에 오는 것 0/3",
					"detail": "TAB 지도 확인 → 약탈대가 낀 구역에서 금고 인장을 뺏는다",
					"label": "금고 인장 확보",
					"map_label": "금고 인장 · 약탈대 점거",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 2.6,
					"distance": 34.0,
					"separation": 26.0,
					"role": "key",
					"guards": 5,
					"complete_notice": "금고 인장 확보 · 사무실 금고가 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namdaemun_guild_ledger",
				"title": "종로 집결지 셔터 열쇠",
				"description": "금고에서 가져온 열쇠 한 벌입니다. 종로 집결지 셔터 열쇠이고, 세 개짜리 고리인데 하나가 비어 있습니다.",
				"label": "금고 개방",
				"map_label": "사무실 금고 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.4,
				"distance": 44.0,
				"separation": 32.0,
				"step_title": "금고 개방 · 1/3",
				"detail": "인장으로 금고를 열고 열쇠를 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "금고 인장이 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "열쇠 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "열쇠 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"종로 집결지 셔터 열쇠가 세 개였다. 하나가 없다.",
				"그날 밤 그 셔터를 내린 놈이 그 하나를 갖고 있다.",
				"새벽에 사료를 채우는 놈은 안전모를 썼다고 했다.",
				"…쉘터 등이 요즘 자꾸 나간다. 을지로 밑에서 전기를 당겨 쓴다더라.",
			],
			"reward": {
				"canned_food": 22,
				"churu": 3,
				"components": {"scope_lens": 2},
				# 쉘터 Tier 3 확장 키 — 금고 바닥에 깔려 있던 창고 설계도. 첫 회수에만.
				# + 장인의 인장 1(돌파 재료, 메인 미션 3단계 공통 보상).
				"progression_items": {"namdaemun_depot_plans": 1, "artisan_seal": 1},
				"xp": 820,
				"summary": "열쇠 확인 · 통조림 +22 · 츄르 +3 · 스코프 렌즈 +2 · XP +820\n새 기록 · ‘빈 고리 하나’ 해금",
			},
			"repeat_reward": {
				"canned_food": 8,
				"xp": 260,
				"summary": "여벌 열쇠 회수 · 통조림 +8 · XP +260",
			},
			"lore": "빈 고리 하나 · 남대문 시장 사무실\n금고 안에 돈은 없고 열쇠 한 벌이 있었다. 종로 집결지 셔터 열쇠.\n세 개짜리 고리인데 하나가 비어 있다. 그날 밤 셔터를 내린 손이 그 하나를 갖고 있다.",
		},
	],
	# ── 을지로 지하구역 ──────────────────────────────────────────
	# 이 구역에서 알아내는 것: 마지막 운행에 스물일곱이 탔고, 아홉이 셔터 밖에 남았다.
	"euljiro_depths": [
		{
			"id": "euljiro_grid_note",
			"title": "아직 들어오는 전기",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "아직 들어오는 전기",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"쉘터 등이 자꾸 나간다. 전기가 어디로 새는지.",
							"사람들이 걸어 내려간 길도 여기 어딘가다.",
							"이 동네만 전기가 들어온다. 지하상가 형광등이 아직 켜져 있다.",
							"누가 이 동네만 골라서 전기를 남겼다.",
							"골목마다 배전반. 셋 다 불이 들어온다.",
							"세 개를 열면 전기가 어디로 가는지 보인다. 1번부터.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 아직 들어오는 전기 0/4",
					"detail": "TAB 지도 확인 → 1번 배전반을 연다",
					"label": "1번 배전반 조사",
					"map_label": "1번 배전반",
					"prop": "generator",
					"color": "#7fd0c8",
					"hold": 2.2,
					"distance": 36.0,
					"separation": 30.0,
					"complete_notice": "1번 배전반 확인 · 다음 배전반 위치 확보",
					"complete_monologue": [
						"배전반에 쪽지. ‘3구역까지만 전기를 넣을 것’.",
						"3구역은 지상이 아니다. 지하.",
						"…누가 지하에 전기를 넣으라고 시켰다. 2번.",
					],
				},
				{
					"step_title": "2번 배전반 조사 · 1/4",
					"detail": "긴 통로 끝의 2번 배전반으로 이동한다",
					"label": "2번 배전반 조사",
					"map_label": "2번 배전반",
					"prop": "generator",
					"color": "#7fd0c8",
					"hold": 2.2,
					"distance": 42.0,
					"separation": 34.0,
					"complete_notice": "2번 배전반 확인 · 종단함 위치 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "euljiro_grid_note",
				"title": "배전 종단 기록",
				"description": "전기가 어디서 끝나는지 적힌 기록입니다. 남겨 둔 회로가 전부 한 방향으로 모입니다.",
				"label": "종단 기록 회수",
				"map_label": "배전 종단함",
				"prop": "convoy_cache",
				"color": "#e66a47",
				"hold": 3.6,
				"distance": 48.0,
				"separation": 36.0,
				"step_title": "종단 기록 회수 · 2/4",
				"detail": "종단함에서 기록을 뜯어 온다 · 경보 주의",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "종단 기록 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "종단 기록 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"남겨 둔 전기가 전부 지하 선로로 들어간다.",
				"사람 없는 도시에서 반년 넘게 누가 지하철 선로에 전기를 댔다.",
				"선로에 전기가 온다는 건, 그 위로 아직 뭔가 다닌다는 거다.",
				"…뭐가 다녔을까.",
			],
			"reward": {
				"canned_food": 24,
				"churu": 3,
				"components": {"rubber_gasket": 3},
				"xp": 900,
				"summary": "종단 기록 해독 · 통조림 +24 · 츄르 +3 · 고무 패킹 +3 · XP +900",
			},
			"repeat_reward": {
				"canned_food": 9,
				"xp": 300,
				"summary": "종단 기록 사본 회수 · 통조림 +9 · XP +300",
			},
		},
		{
			"id": "euljiro_workshop_cast",
			"title": "무엇을 실었나",
			"type": "defense",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "무엇을 실었나",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"선로 위로 뭔가 다녔다. 그게 뭔지.",
							"선로에서 바퀴 자국이 옆 공방까지 이어진다.",
							"공방 문은 안에서 잠겼다. 제어반을 누르면 열린다. 열리는 동안 시끄럽다.",
							"버틸 준비부터.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 무엇을 실었나 0/3",
					"detail": "TAB 지도 확인 → 공방 제어반을 누르고 버틴다",
					"label": "공방 제어반 조작",
					"map_label": "공방 제어반",
					"prop": "generator",
					"color": "#e7a847",
					"hold": 2.4,
					"distance": 38.0,
					"separation": 30.0,
					"role": "defense",
					"defense_duration": 15.0,
					"defense_waves": 3,
					"complete_notice": "봉쇄 해제 시작 · 15초간 자리를 지켜라",
					"complete_monologue": [
						"공방 바닥에 바퀴 자국이 여러 겹. 여기서 수레를 만들었다.",
						"자국이 크다. 사람을 실을 크기.",
						"열릴 때까지 버틴다.",
					],
				},
			],
			"recovery": {
				"id": "euljiro_workshop_cast",
				"title": "수레 도면 뭉치",
				"description": "공방에서 가져온 도면입니다. 걷지 못하는 사람을 눕혀서 싣는 크기로 그려져 있고, 옆에 손으로 「업고 내려올 것」이라고 적혀 있습니다.",
				"label": "수레 도면 회수",
				"map_label": "공방 수레 도면",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.4,
				"step_title": "수레 도면 회수 · 2/3",
				"detail": "열린 공방 안쪽에서 도면을 가져온다",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "도면 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "수레 도면 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"이 공방에서 사람을 실을 수레를 만들었다.",
				"사람들은 지하까지 제 발로 내려왔다. 여기서부터 수레에 실려 갔다.",
				"걷지 못하는 사람들이 있었다. 그 사람들이 마지막까지 남았다.",
				"…마지막 수레가 언제 갔는지 본다.",
			],
			"reward": {
				"canned_food": 27,
				"churu": 3,
				"components": {"magazine_spring": 3},
				# 무기 사다리 — 도면 뭉치 = AKM 설계도 조각 2/3. 첫 회수에만(나머지는 을지로 엘리트·봉인 보급함).
				"progression_items": {"blueprint_shard_akm": 2},
				"xp": 1080,
				"summary": "수레 도면 해독 · 통조림 +27 · 츄르 +3 · 탄창 스프링 +3 · XP +1080\nAKM 개조 청사진 획득 · 작업대에서 AKM 제작 가능",
			},
			"repeat_reward": {
				"canned_food": 10,
				"xp": 340,
				"summary": "도면 사본 회수 · 통조림 +10 · XP +340",
			},
		},
		{
			"id": "euljiro_control_log",
			"title": "마지막 운행",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "마지막 운행",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"수레가 다녔으면 마지막이 언제였는지 적혀 있을 거다.",
							"지하 관제실에 운행 일지가 통째로 남아 있다고 주홍이 그랬다.",
							"오늘은 숫자 하나만 알면 된다.",
							"관제실은 잠겨 있고 문 앞에 적들이 진을 쳤다. 열쇠는 그놈들한테.",
							"뺏는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "manifest_terminal",
						"title": "운행 일지 · 마지막 장",
						"lines": [
							"운행 일지. 열두 번. 전부 같은 선로.",
							"마지막 운행 시각이 적혀 있다. 그날 밤 열한 시 사십 분.",
							"그 밑에 손으로 눌러 쓴 한 줄.",
							"「탑승 27 · 잔여 9」",
							"…아홉 명이 못 탔다.",
							"역무실 번호는 27에서 멈춰 있었다. 그 뒤로 아홉이 더 있었다는 소리다.",
							"그 아홉은 셔터 앞에 서 있었다.",
							"…들고 나간다.",
						],
					},
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "juhong",
						"root": "res://assets/characters/juhong",
						"display_name": "주홍",
						"role": "떠도는 고양이",
						"at": "player",
						"offset": Vector3(7.5, 0.0, -6.0),
					},
					{"type": "focus", "at": "player", "offset": Vector3(3.5, 0.0, -2.5), "hold": 0.4},
					{
						"type": "actor_walk",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(2.0, 0.0, -1.6),
						"duration": 1.7,
					},
					{
						"type": "lines",
						"speaker": "주홍",
						"title": "아홉",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"봤지. 아홉.",
							"그 아홉이 왜 못 탔는지 알아? 셔터가 내려갔거든.",
							"누가 내렸는지는 아직 몰라. 아직은.",
							"용산 봉쇄선에 가면 그날 무전이 남아 있을 거야.",
								"군은 무전을 다 녹음해.",
							"먼저 가서 기다릴게.",
								"…나 요즘 쉘터 밥이 잘 안 넘어가.",
						],
					},
					{
						"type": "actor_exit",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(10.5, 0.0, -8.5),
						"duration": 1.9,
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 마지막 운행 0/3",
					"detail": "TAB 지도 확인 → 적이 몰린 구역에서 관제실 열쇠를 뺏는다",
					"label": "관제실 열쇠 확보",
					"map_label": "관제실 열쇠 · 적 밀집",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 2.8,
					"distance": 36.0,
					"separation": 28.0,
					"role": "key",
					"guards": 5,
					"complete_notice": "관제실 열쇠 확보 · 지하 관제실이 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "euljiro_control_log",
				"title": "지하 운행 일지",
				"description": "관제실 콘솔에서 통째로 뽑아낸 일지입니다. 마지막 운행 밑에 손으로 눌러 쓴 한 줄이 있습니다. 「탑승 27 · 잔여 9」",
				"label": "운행 일지 회수",
				"map_label": "지하 관제실 · 잠김",
				"prop": "manifest_terminal",
				"color": "#e66a47",
				"hold": 4.2,
				"distance": 46.0,
				"separation": 34.0,
				"step_title": "관제실 진입 · 1/3",
				"detail": "열쇠로 관제실을 열고 운행 일지를 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "관제실 열쇠가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "운행 일지 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "운행 일지 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"마지막 운행에 스물일곱이 탔고 아홉이 남았다.",
				"남은 아홉은 셔터 밖에 서 있었다.",
				"셔터를 내린 놈이 있다. 열쇠 고리에서 빠진 그 하나.",
				"…용산에 그날 무전이 남아 있다고 했다.",
			],
			"reward": {
				"canned_food": 30,
				"churu": 4,
				"components": {"scope_lens": 3},
				# 쉘터 Tier 4 확장 키 — 관제실 기록에 딸려 온 배전 도면. 첫 회수에만.
				"progression_items": {"euljiro_grid_schematic": 1, "artisan_seal": 1},
				"xp": 1350,
				"summary": "운행 일지 해독 · 통조림 +30 · 츄르 +4 · 스코프 렌즈 +3 · XP +1350\n새 기록 · ‘탑승 27 · 잔여 9’ 해금",
			},
			"repeat_reward": {
				"canned_food": 11,
				"xp": 420,
				"summary": "일지 사본 회수 · 통조림 +11 · XP +420",
			},
			"lore": "탑승 27 · 잔여 9 · 을지로 지하 관제실\n지하 선로 운행 일지. 마지막 운행은 그날 밤 열한 시 사십 분.\n그 밑에 손으로 눌러 쓴 한 줄이 있다. 「탑승 27 · 잔여 9」",
		},
	],
	# ── 용산 봉쇄선 ──────────────────────────────────────────────
	# 이 구역에서 알아내는 것: 군은 알고도 도왔고, 요청한 쪽은 사자다.
	"yongsan_blockade": [
		{
			"id": "yongsan_checkpoint_log",
			"title": "통과 인원 0",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "통과 인원 0",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"그날 아홉 명이 남았다. 그 아홉은 어디로 갔을까.",
							"봉쇄선이 그날 닫혔다. 군이 몰랐을 리 없다.",
							"검문소 두 곳에 단말이 아직 켜져 있다. 통과 기록이 남았을 거다.",
							"군이 사람들을 어느 쪽으로 보냈는지. 1번부터.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 통과 인원 0 0/4",
					"detail": "TAB 지도 확인 → 1번 검문소 단말을 조사한다",
					"label": "1번 검문소 단말 조사",
					"map_label": "1번 검문소 단말",
					"prop": "manifest_terminal",
					"color": "#c8d47a",
					"hold": 2.2,
					"distance": 40.0,
					"separation": 34.0,
					"complete_notice": "검문 기록 일부 복원 · 다음 검문소 위치 확보",
					"complete_monologue": [
						"검문 기록 마지막 줄. 통과 인원 0.",
						"봉쇄선은 사람이 밖으로 못 나가게 막고 있었다.",
						"…그럼 어디로. 2번.",
					],
				},
				{
					"step_title": "2번 검문소 단말 · 1/4",
					"detail": "봉쇄선 반대편의 2번 검문소로 이동한다 · 먼 거리 사선 주의",
					"label": "2번 검문소 단말 조사",
					"map_label": "2번 검문소 단말",
					"prop": "manifest_terminal",
					"color": "#c8d47a",
					"hold": 2.2,
					"distance": 48.0,
					"separation": 40.0,
					"complete_notice": "검문 기록 복원 · 기록함 위치 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "yongsan_checkpoint_log",
				"title": "검문소 기록함",
				"description": "검문 기록을 모아 둔 상자입니다. 사람들이 어느 문으로 들어갔는지가 시각까지 적혀 있습니다.",
				"label": "기록함 회수",
				"map_label": "검문소 기록함",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.8,
				"distance": 54.0,
				"separation": 42.0,
				"step_title": "기록함 회수 · 2/4",
				"detail": "보관소에서 기록함을 가져온다 · 경보 주의",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "기록함 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "검문 기록 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"통과 인원 0. 군은 아무도 밖으로 안 내보냈다.",
				"막기만 한 게 아니다. 도시 안쪽으로 몰았다. 지하 입구 쪽으로.",
				"군이 왜. 군대는 명령서 없이 안 움직인다.",
				"…명령서를 찾는다.",
			],
			"reward": {
				"canned_food": 34,
				"churu": 4,
				"components": {"rubber_gasket": 4},
				"xp": 1650,
				"summary": "검문 기록 해독 · 통조림 +34 · 츄르 +4 · 고무 패킹 +4 · XP +1650",
			},
			"repeat_reward": {
				"canned_food": 12,
				"xp": 520,
				"summary": "검문 기록 사본 회수 · 통조림 +12 · XP +520",
			},
		},
		{
			"id": "yongsan_magazine_order",
			"title": "총구의 방향",
			"type": "defense",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "총구의 방향",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"군은 사람들을 안쪽으로 몰았다. 그럼 총은 어디를 겨눴을까.",
							"검문 기록 끝에 경계 명령서 번호. 원본은 탄약고 금고.",
							"명령서를 보려면 탄약고 봉인부터 뜯어야 한다.",
							"뜯는 동안 시끄럽다. 버틸 준비부터.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 총구의 방향 0/3",
					"detail": "TAB 지도 확인 → 탄약고 봉인을 뜯고 버틴다",
					"label": "탄약고 봉인 해제",
					"map_label": "탄약고 봉인 장치",
					"prop": "generator",
					"color": "#e7a847",
					"hold": 2.6,
					"distance": 40.0,
					"separation": 32.0,
					"role": "defense",
					"defense_duration": 18.0,
					"defense_waves": 4,
					"complete_notice": "봉인 해제 시작 · 18초간 자리를 지켜라",
					"complete_monologue": [
						"탄약고를 지키라는 명령이 아직 안 취소됐다. 명령을 내린 사람은 이미 없는데.",
						"지키라고 한 게 탄약이 아니었던 모양이다.",
						"풀릴 때까지 버틴다.",
					],
				},
			],
			"recovery": {
				"id": "yongsan_magazine_order",
				"title": "경계 명령서",
				"description": "탄약고 금고에서 가져온 명령서입니다. 경계 대상이 무기가 아니라 도시 안쪽 주소로 적혀 있습니다.",
				"label": "명령서 회수",
				"map_label": "경계 명령서",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.6,
				"step_title": "명령서 회수 · 2/3",
				"detail": "열린 탄약고 안쪽에서 명령서를 가져온다",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "명령서 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "명령서 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"군의 경계 대상은 무기고가 아니었다. 도시 안쪽 주소들이었다.",
				"총구가 바깥이 아니라 안을 향해 있었다. 사람들이 도망 못 가게.",
				"그날 밤 무전이 사령부에 남아 있을 거다.",
				"…셔터를 누가 내렸는지 거기 있다.",
			],
			"reward": {
				"canned_food": 38,
				"churu": 5,
				"components": {"magazine_spring": 4},
				"xp": 1980,
				"summary": "명령서 해독 · 통조림 +38 · 츄르 +5 · 탄창 스프링 +4 · XP +1980",
			},
			"repeat_reward": {
				"canned_food": 14,
				"xp": 620,
				"summary": "명령서 사본 회수 · 통조림 +14 · XP +620",
			},
		},
		{
			"id": "yongsan_command_map",
			"title": "마지막 교신",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "마지막 교신",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"군은 그날 무전을 다 녹음했다.",
							"종로 집결지에서 온 마지막 교신이 사령부 금고에 있다.",
							"금고는 인증표가 있어야 열린다.",
							"인증표는 정예 병력이 지키는 구역에.",
							"뺏는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "sealed_cargo",
						"title": "금고 안 · 마지막 교신",
						"lines": [
							"금고 안에 무기는 없다. 녹음 하나다.",
							"그날 밤 열한 시 삼십팔 분. 종로 집결지.",
							"「종로 집결지입니다. 더는 수용이 안 됩니다.」",
							"「밖에 몇 명이나 남았습니까.」",
							"「…아직 있습니다.」",
							"「닫으세요.」",
							"셔터 내려가는 소리가 사십 초쯤 이어지고 녹음이 끊긴다.",
							"들고 나간다.",
						],
					},
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "juhong",
						"root": "res://assets/characters/juhong",
						"display_name": "주홍",
						"role": "떠도는 고양이",
						"at": "player",
						"offset": Vector3(-8.0, 0.0, 6.5),
					},
					{"type": "focus", "at": "player", "offset": Vector3(-3.5, 0.0, 3.0), "hold": 0.4},
					{
						"type": "actor_walk",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(-2.0, 0.0, 1.6),
						"duration": 1.7,
					},
					{
						"type": "lines",
						"speaker": "주홍",
						"title": "우리 집 사람",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"봤지. 이제 내가 왜 그놈을 쫓는지 말해 줄게.",
							"그 아홉 명 중에 우리 집 사람이 있어.",
							"나한테 밥 주던 사람. 나 안고 자던 사람이야.",
							"셔터 앞까지 갔는데 못 들어갔어.",
							"나는 그거 내린 놈 보러 간다. 너는 네 볼일 봐.",
						],
					},
					{
						"type": "actor_exit",
						"key": "juhong",
						"to_at": "player",
						"to_offset": Vector3(-11.0, 0.0, 9.0),
						"duration": 1.9,
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 마지막 교신 0/3",
					"detail": "TAB 지도 확인 → 정예 병력이 낀 구역에서 사령부 인증표를 뺏는다",
					"label": "사령부 인증표 확보",
					"map_label": "사령부 인증표 · 정예 경계",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 3.0,
					"distance": 38.0,
					"separation": 30.0,
					"role": "key",
					"guards": 6,
					"complete_notice": "사령부 인증표 확보 · 사령부 금고가 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "yongsan_command_map",
				"title": "그날 밤 마지막 교신",
				"description": "사령부 금고에 있던 녹음입니다. 그날 밤 종로 집결지에서 온 마지막 교신이, 사십 초짜리 셔터 소리와 함께 남아 있습니다.",
				"label": "사령부 금고 개방",
				"map_label": "사령부 금고 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.6,
				"distance": 48.0,
				"separation": 36.0,
				"step_title": "사령부 금고 개방 · 1/3",
				"detail": "인증표로 금고를 열고 녹음을 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "사령부 인증표가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "녹음 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "마지막 교신 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"누가 닫으라고 했고, 누가 닫았다.",
				"주홍은 그 아홉 중에 자기 사람이 있다고 했다.",
				"…101동 302호. 창고 신발 상자에 적혀 있던 그 주소도 그 아홉에 있었을까.",
				"그 사람들이 어디로 갔는지는 남산에 있다. 마지막이다.",
			],
			"reward": {
				"canned_food": 42,
				"churu": 6,
				"components": {"scope_lens": 4},
				# 쉘터 Tier 5 확장 키 — 사령부 금고의 통제 키. 첫 회수에만.
				"progression_items": {"yongsan_control_key": 1, "artisan_seal": 1},
				"xp": 2400,
				"summary": "마지막 교신 복원 · 통조림 +42 · 츄르 +6 · 스코프 렌즈 +4 · XP +2400\n새 기록 · ‘그날 밤 마지막 교신’ 해금",
			},
			"repeat_reward": {
				"canned_food": 15,
				"xp": 760,
				"summary": "교신 사본 회수 · 통조림 +15 · XP +760",
			},
			"lore": "마지막 교신 · 용산 사령부\n그날 밤 열한 시 삼십팔 분, 종로 집결지에서 온 무전.\n「종로 집결지입니다. 더는 수용이 안 됩니다.」 「밖에 몇 명이나 남았습니까.」\n「…아직 있습니다.」 「닫으세요.」\n셔터 내려가는 소리가 사십 초쯤 이어지고 녹음이 끊긴다.",
		},
	],
	# ── 남산 관제탑 ──────────────────────────────────────────────
	# 이 구역에서 알아내는 것: 지하엔 서른여섯이 자고 있다. 자리는 모자라지 않았다.
	"namsan_core": [
		{
			"id": "namsan_survey_data",
			"title": "거짓 수치",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "거짓 수치",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"종착지는 남산. 사람들은 이 산 어딘가로 들어갔다.",
							"지도에서 남산은 오염 구역이다. 그래서 아무도 안 올라온다.",
							"초입에 오염 관측기 세 개.",
							"세 개를 맞춰야 원본 수치가 읽힌다.",
							"그 숫자가 진짜인지부터.",
							"가짜면 여긴 오염 구역이 아니다. 뭘 숨긴 곳이다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 거짓 수치 0/4",
					"detail": "TAB 지도 확인 → 1번 관측기를 회수한다",
					"label": "1번 관측기 회수",
					"map_label": "1번 관측기",
					"prop": "convoy_cache",
					"color": "#a8d488",
					"hold": 2.2,
					"distance": 42.0,
					"separation": 36.0,
					"complete_notice": "1번 관측 자료 확보 · 다음 관측기 위치 확보",
					"complete_monologue": [
						"관측기 안에 수치가 두 벌. 표시용 하나, 실제 하나.",
						"실제 수치는 종로보다 낮다.",
						"…누가 숫자를 고쳤다. 2번.",
					],
				},
				{
					"step_title": "2번 관측기 회수 · 1/4",
					"detail": "개활지를 짧게 건너 2번 관측기로 간다",
					"label": "2번 관측기 회수",
					"map_label": "2번 관측기",
					"prop": "convoy_cache",
					"color": "#a8d488",
					"hold": 2.2,
					"distance": 50.0,
					"separation": 40.0,
					"complete_notice": "2번 관측 자료 확보 · 마지막 관측기 위치 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namsan_survey_data",
				"title": "관측 원본 자료",
				"description": "세 관측기를 맞춰야 읽히는 원본 자료입니다. 표시용 수치와 실제 수치가 나란히 남아 있습니다.",
				"label": "원본 자료 회수",
				"map_label": "3번 관측기 · 원본 자료",
				"prop": "pharmacy_cache",
				"color": "#e66a47",
				"hold": 3.8,
				"distance": 56.0,
				"separation": 44.0,
				"step_title": "원본 자료 회수 · 2/4",
				"detail": "마지막 관측기에서 원본 자료를 가져온다 · 경보 주의",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "원본 자료 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "원본 자료 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"남산 오염 수치는 조작이다. 실제로는 종로보다 깨끗하다.",
				"위험하다고 거짓말을 해서 아무도 못 올라오게 했다.",
				"관측기 밑에 빈 통조림 깡통이 굴러다닌다. 우리 쉘터에서 쓰는 거다.",
				"…누가 여기까지 몇 번을 왔다 갔다. 더 올라간다.",
			],
			"reward": {
				"canned_food": 46,
				"churu": 6,
				"components": {"rubber_gasket": 5},
				"xp": 2800,
				"summary": "원본 자료 해독 · 통조림 +46 · 츄르 +6 · 고무 패킹 +5 · XP +2800",
			},
			"repeat_reward": {
				"canned_food": 16,
				"xp": 880,
				"summary": "관측 자료 사본 회수 · 통조림 +16 · XP +880",
			},
		},
		{
			"id": "namsan_decon_key",
			"title": "아직 돌아가는 기계",
			"type": "defense",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "아직 돌아가는 기계",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"오염 수치는 가짜였다.",
							"관제탑 문이 잠겨 있다. 옆 표지에 제염 라인이 돌아야 열린다고 적혀 있다.",
							"제어반을 누르면 라인이 돈다.",
							"도는 동안 여기 서서 버틴다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 아직 돌아가는 기계 0/3",
					"detail": "TAB 지도 확인 → 제어반을 누르고 버틴다",
					"label": "제염 라인 제어반 조작",
					"map_label": "제염 라인 제어반",
					"prop": "generator",
					"color": "#e7a847",
					"hold": 2.8,
					"distance": 42.0,
					"separation": 34.0,
					"role": "defense",
					"defense_duration": 20.0,
					"defense_waves": 4,
					"complete_notice": "제염 라인 가동 시작 · 20초간 자리를 지켜라",
					"complete_monologue": [
						"기계가 돈다. 사람이 사라진 뒤로도 계속 예약이 걸려 있었다.",
						"누가 아직 이 기계를 쓸 생각이다.",
						"다 돌 때까지 버틴다.",
					],
				},
			],
			"recovery": {
				"id": "namsan_decon_key",
				"title": "관제탑 열쇠",
				"description": "라인이 돌아야 열리는 보관함에서 가져온 열쇠입니다. 관제탑 맨 위층 문을 엽니다.",
				"label": "관제탑 열쇠 회수",
				"map_label": "관제탑 열쇠",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.8,
				"step_title": "열쇠 회수 · 2/3",
				"detail": "돌아가는 기계 안쪽에서 열쇠를 가져온다",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "관제탑 열쇠 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "관제탑 열쇠 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"제염 라인이 아직 예약된 채로 돈다.",
				"예약표가 붙어 있다. 열세 번째 운행.",
				"인원 칸은 비어 있다.",
				"…아직 아홉 명을 기다리고 있다.",
			],
			"reward": {
				"canned_food": 52,
				"churu": 7,
				"components": {"magazine_spring": 5},
				"xp": 3400,
				"summary": "관제탑 열쇠 확보 · 통조림 +52 · 츄르 +7 · 탄창 스프링 +5 · XP +3400",
			},
			"repeat_reward": {
				"canned_food": 18,
				"xp": 1050,
				"summary": "예비 열쇠 회수 · 통조림 +18 · XP +1050",
			},
		},
		{
			"id": "namsan_final_record",
			"title": "문",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e2c15f", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "먼지",
						"title": "문",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"여기가 끝이다. 맨 위층에서 지하가 보인다고 했다.",
							"그 아홉 명이 어떻게 됐는지 거기서 안다.",
							"문은 코드로 잠겨 있다. 코드는 중무장한 놈들한테.",
							"뺏는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "manifest_terminal",
						"title": "관제탑 맨 위층",
						"lines": [
							"화면 하나에 지하 선로 전체가 떠 있다.",
							"열두 번의 운행이 전부 남산 아래 한 곳으로 들어갔다.",
							"인원이 떠 있다. 죽은 게 아니다. 살아서 자고 있다.",
							"숫자를 센다. 스물일곱이 아니다.",
							"서른여섯이다.",
							"못 탄 아홉도 안에 있다. 다른 입구로 들어갔다.",
							"자리는 모자라지 않았다.",
							"그날 밤 셔터를 내릴 필요가 없었다.",
							"…아무도 밖에 안 남았다. 셔터를 내린 놈만 빼고.",
						],
					},
					{
						"type": "choice",
						"id": "namsan_final_switch",
						"prompt": "사자한테 뭐라고 할까.",
						"options": [
							{
								"id": "shutdown",
								"label": "그대로 말한다",
								"detail": "돌아가서 다 말한다",
								"effect": {
									"pressure": -80.0,
									"notice": "그대로 전하기로 한다",
									"monologue": [
										"돌아가서 그대로 말한다.",
										"자리는 모자라지 않았다고. 아홉 명 다 안에 있다고.",
										"…믿든 안 믿든 그건 그다음 문제다.",
									],
								},
							},
							{
								"id": "wake",
								"label": "데리고 온다",
								"detail": "말은 안 하고 여기까지 끌고 온다 · 정산 보상 상승",
								"effect": {
									"reward_multiplier": 0.2,
									"pressure": 60.0,
									"notice": "지하 개방 · 사람들이 올라옵니다 · 기계는 계속 돌아갑니다",
									"monologue": [
										"말로는 안 믿을 거다. 반년을 그러고 살았는데.",
										"데리고 와서 이 화면을 보여 준다.",
										"…저 산을 끝까지 올라오게 하는 게 쉽진 않겠지만.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 문 0/3",
					"detail": "TAB 지도 확인 → 중무장 구역에서 맨 위층 코드를 뺏는다",
					"label": "맨 위층 진입 코드 확보",
					"map_label": "맨 위층 코드 · 중무장 경계",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 3.2,
					"distance": 40.0,
					"separation": 32.0,
					"role": "key",
					"guards": 7,
					"complete_notice": "진입 코드 확보 · 관제탑 맨 위층이 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namsan_final_record",
				"title": "서른여섯",
				"description": "맨 위층 콘솔에서 뽑아낸 기록입니다. 열두 번의 운행이 어디로 들어갔는지, 그리고 그 안에 서른여섯 명이 살아서 자고 있다는 것이 적혀 있습니다.",
				"label": "운영 기록 회수",
				"map_label": "관제탑 맨 위층 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 5.0,
				"distance": 50.0,
				"separation": 38.0,
				"step_title": "맨 위층 진입 · 1/3",
				"detail": "코드로 맨 위층을 열고 운영 기록을 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "맨 위층 진입 코드가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "운영 기록 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "운영 기록 확보 · 들고 나가면 사자에게 물어볼 차례입니다",
			"carry_monologue": [
				"사람들은 남산 지하에 살아 있다. 서른여섯 명 다.",
				"그날 밤 셔터를 내린 놈은 아홉 명을 죽였다고 믿고 반년을 살았다.",
				"…돌아가서 말해 준다. 아홉 명 다 살아 있다고.",
			],
			"reward": {
				"canned_food": 60,
				"churu": 9,
				"components": {"scope_lens": 5, "magazine_spring": 3},
				"xp": 4200,
				"summary": "운영 기록 해독 · 통조림 +60 · 츄르 +9 · 스코프 렌즈 +5 · 탄창 스프링 +3 · XP +4200\n새 기록 · ‘사람들은 아직 자고 있다’ 해금",
			},
			"repeat_reward": {
				"canned_food": 20,
				"xp": 1300,
				"summary": "운영 기록 사본 회수 · 통조림 +20 · XP +1300",
			},
			"lore": "서른여섯 · 남산 관제탑\n관제탑 화면에 지하가 떠 있다. 열두 번의 운행이 전부 남산 아래 한 곳으로 들어갔고, 그 안에 서른여섯 명이 자고 있다.\n그날 밤 셔터 앞에서 돌아선 아홉 명도 다른 입구로 들어갔다.\n자리는 모자라지 않았다.",
		},
	],
}


static func has_chain(zone_id: String) -> bool:
	return CHAINS.has(zone_id)


static func get_stage_count(zone_id: String) -> int:
	if not CHAINS.has(zone_id):
		return 0
	return (CHAINS[zone_id] as Array).size()


static func get_stage(zone_id: String, stage_index: int) -> Dictionary:
	# 범위를 벗어나면 빈 사전 — 호출부는 "이 구역엔 더 이상 메인 미션이 없다"로 읽는다.
	if not CHAINS.has(zone_id):
		return {}
	var stages := CHAINS[zone_id] as Array
	if stage_index < 0 or stage_index >= stages.size():
		return {}
	return (stages[stage_index] as Dictionary).duplicate(true)


static func get_stage_points(stage: Dictionary) -> Array:
	# 앞쪽 지점들 + 마지막 회수 지점을 하나의 순서로 펼친다.
	# recovery도 결국 "상호작용 지점"이라 같은 실행기가 다룬다.
	var points: Array = []
	for point in stage.get("points", []) as Array:
		points.append((point as Dictionary).duplicate(true))
	var recovery := stage.get("recovery", {}) as Dictionary
	if not recovery.is_empty():
		var recovery_point := recovery.duplicate(true)
		recovery_point["is_recovery"] = true
		points.append(recovery_point)
	return points


static func find_stage_by_recovery_id(recovery_id: String) -> Dictionary:
	# 세이브에서 돌아온 판은 "이 회수물이 어느 구역 몇 단계 것인지"부터 되찾아야 한다.
	if recovery_id.is_empty():
		return {}
	for chain_zone_id in CHAINS.keys():
		var stages := CHAINS[chain_zone_id] as Array
		for index in stages.size():
			var stage := stages[index] as Dictionary
			if str((stage.get("recovery", {}) as Dictionary).get("id", "")) != recovery_id:
				continue
			return {
				"zone_id": str(chain_zone_id),
				"stage_index": index,
				"stage": stage.duplicate(true),
			}
	return {}


static func get_next_zone(zone_id: String) -> String:
	var index := ZONE_ORDER.find(zone_id)
	if index < 0 or index + 1 >= ZONE_ORDER.size():
		return ""
	return ZONE_ORDER[index + 1]
