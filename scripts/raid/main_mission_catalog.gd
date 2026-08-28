class_name MainMissionCatalog
extends RefCounted

# 존별 메인 미션 체인 데이터 테이블.
#
# 구역마다 3단계짜리 체인이 있고, 세 단계를 끝낸 구역에서는 메인 미션이
# 더 이상 뜨지 않는다 — 흔적이 다음 구역으로 넘어간다.
#
# ── 이야기 뼈대(한 줄 요약) ───────────────────────────────────
#   사람은 도망친 게 아니라 "수거"됐다. 나비는 그 수거를 지휘한 시스템을 찾아 끄러 간다.
#   종로   신호의 정체    → 사람들은 걸어 나갔다(녹음 방송이 불렀다)
#   남대문 명단의 출처    → 명단을 받아 적은 건 고양이 손이다
#   을지로 수거 방법      → 지하 수송로. 승인 서명은 "사자"
#   용산   군의 협조      → 군은 알고도 도왔다. 주홍이 사자를 노리는 이유
#   남산   시스템 본체    → 사람들은 지하에 살아 있다. 끄거나, 깨우거나(선택)
#
# ── 문체 규칙(어기면 갈아엎기 전으로 돌아간다) ─────────────────
#   1) 한 장면에 새 고유명사는 1개까지. 이미 나온 것만 반복해 쓴다.
#   2) 모든 단계는 "무엇을 알아냈다"로 끝난다. 분위기로 끝내지 않는다.
#   3) 한 줄은 한 가지만 말한다. 은유로 두 겹 싸지 않는다.
#   4) 목소리 분리 — 나비: 짧고 건조. 사자: 공무원 말투. 주홍: 거칠고 정직.
#      행상인: 수다스럽고 물건 얘기로 돌아감. 주민/생존자: 겁먹은 짧은 문장.
#   5) 정보는 구체적인 물건·숫자·목격담으로 준다(명단 27명, 도장, 녹음 방송, 발자국).
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
						"speaker": "나비",
						"title": "신호를 보낸 것",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"신호는 저 지하철역에서 나왔다.",
							"입구가 잠겨 있다. 밖이 아니라 안에서.",
							"오늘 알고 싶은 건 하나다. 사람들이 어디로 갔나.",
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
							"화면에 명단이 떠 있다. 이름 스물일곱.",
							"전부 이 동네 사람이다.",
							"맨 위에 도장이 찍혀 있다. ‘수거 완료.’",
							"— 수거. 사람한테 쓰는 말이 아닌데.",
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
							"나 그날 봤어.",
							"사람들이 줄을 서서 걸어 나갔어.",
							"끌려간 게 아니야. 웃으면서 갔어.",
							"그게 제일 무서웠어.",
						],
					},
					{
						"type": "choice",
						"id": "jongno_stage1_runner",
						"prompt": "쓰러진 고양이를 어떻게 할 것인가.",
						"options": [
							{
								"id": "take",
								"label": "데려간다",
								"detail": "호송 · 이동이 느려진다",
								"effect": {
									"rescue": true,
									"notice": "생존자 호송 시작 · 이동 속도가 감소합니다",
									"monologue": [
										"업고 가면 느려진다. 느려지면 죽는다.",
										"그래도 이 녀석은 그날을 본 눈이다. 데려간다.",
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
										"다시 오겠다고 말했다. 안 믿는 눈이었다.",
										"들은 건 다 들었다. 오늘은 그걸로 됐다.",
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
							"방역 도장이 찍힌 화물칸이다.",
							"안에서 두드리는 소리가 났다.",
							"— 사람은 아니다. 소리가 너무 작아.",
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
					"complete_notice": "명단 확인 · 발전기 위치가 지도에 표시됩니다",
					"complete_monologue": [
						"화면에 명단이 떠 있다. 이름 스물일곱, 전부 이 동네 사람이다.",
						"맨 위에 도장. ‘수거 완료.’",
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
					"complete_notice": "전력 복구 · 스피커가 녹음을 반복합니다 · 소리를 듣고 온다",
					"complete_monologue": [
						"전기가 들어오자 스피커가 저 혼자 떠들기 시작했다. 녹음된 여자 목소리다.",
						"〈주민 여러분, 대피 차량이 도착했습니다. 소지품은 두고 오십시오.〉",
						"같은 목소리다. 나한테 강을 건너오라던 — 라디오의 그 목소리.",
					],
				},
			],
			"recovery": {
				"id": "seoul_line3_relief_core",
				"title": "방역 도장이 찍힌 화물칸",
				"description": "역 승강장에 남아 있던 화물칸입니다. 방역 도장이 찍힌 채 봉인되어 있고, 안쪽에서 작은 소리가 납니다. 탈출해야 열어 볼 수 있습니다.",
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
				"오늘 알아낸 건 하나다. 사람들은 끌려간 게 아니라 걸어 나갔다.",
				"그럼 누가 오라고 했지?",
			],
			"reward": {
				"canned_food": 8,
				"churu": 1,
				"components": {"scope_lens": 1},
				"xp": 220,
				"summary": "화물칸 개봉 · 통조림 +8 · 츄르 +1 · 스코프 렌즈 +1 · XP +220\n새 기록 · ‘수거 완료 명단’ 해금",
			},
			"repeat_reward": {
				"canned_food": 3,
				"churu": 1,
				"xp": 90,
				"summary": "남은 화물칸 개봉 · 통조림 +3 · 츄르 +1 · XP +90",
			},
			"lore": "수거 완료 명단 · 종로 지하철역\n역무실 단말에 남아 있던 명단이다. 이름이 스물일곱 개, 전부 종로에 살던 사람들이다. 맨 위에 도장이 하나 찍혀 있다. ‘수거 완료.’ 날짜는 사람이 사라진 그날 밤이다.",
		},
		{
			"id": "jongno_watermain_record",
			"title": "끊긴 물길",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "끊긴 물길",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"사람들이 걸어 나갔다면, 어디로 걸어갔나.",
							"도로 밑에서 물소리가 난다. 수돗물은 사람들이 사라진 날 끊겼는데.",
							"밸브 셋을 순서대로 열면 마지막 방이 열린다.",
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
						"speaker": "나비",
						"title": "도로 건너편",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"두 번째 밸브를 여니까 도로 저쪽에 불빛이 켜졌다.",
							"가로등이 아니라 손전등이다. 여덟 개.",
							"저쪽도 물소리를 들었다. 몸을 낮춘다.",
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
							"배관도 위에 다른 잉크로 선이 하나 더 그어져 있다.",
							"본선에서 갈라져 지하로 내려가는 관이다.",
							"관 끝마다 같은 표시가 찍혀 있다. 신발 자국 모양이다.",
						],
					},
					{
						"type": "choice",
						"id": "jongno_stage2_valve",
						"prompt": "물길을 어떻게 두고 나갈 것인가.",
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
										"잠근다. 이 길은 아직 내 것이다.",
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
										"물이 흐르면 소리가 난다. 소리가 나면 온다.",
										"오라고 해. 오는 것들도 뭔가는 들고 있겠지.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 끊긴 물길 0/4",
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
						"밸브를 열었는데 물이 이쪽으로 안 온다. 저쪽으로 빨려 나간다.",
						"관 끝이 어딘가 아래로 이어져 있다.",
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
				"title": "종로 배관도",
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
				"알아낸 것. 사람들이 걸어간 길은 지하로 내려간다.",
				"물길이 아니었다. 사람 길이었다.",
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
						"speaker": "나비",
						"title": "잠긴 방송국",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"역에서 나온 그 여자 목소리. 어디서 틀었는지 알아야 한다.",
							"길가 스피커가 열두 초마다 같은 잡음을 낸다. 송출이 아직 돈다는 뜻이다.",
							"주조정실은 잠겼다. 열쇠부터 찾는다.",
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
							"손 내려. 나도 그 방송 듣고 왔다.",
							"열두 초마다 같은 잡음. 나는 그걸 여섯 동네에서 들었어.",
							"고장 난 게 아니야. 누가 반복하라고 시켜 뒀지.",
							"안에 마지막 송출 기록이 있다. 뭘 읽었는지 거기 남아.",
							"하나만 말해 둘게. 그 회색 고양이 말 믿지 마.",
							"걔 손이 깨끗한 적은 한 번도 없었어.",
							"…들어가. 나는 밖을 본다.",
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
							"마지막 방송은 안내가 아니었다.",
							"여자 목소리가 이름 스물일곱 개를 천천히 두 번 읽었다.",
							"녹음 날짜는 사람이 사라지기 사흘 전이다.",
							"— 명단이 먼저였다.",
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
						"열쇠에 이름이 없다. 직책만 찍혀 있다. ‘야간 송출 담당.’",
						"마지막까지 마이크 앞에 앉아 있던 사람이 있었다는 뜻이다.",
					],
				},
			],
			"recovery": {
				"id": "jongno_broadcast_log",
				"title": "방송국 마지막 송출 기록",
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
				"알아낸 것. 사람들을 부른 건 녹음된 방송이다.",
				"그리고 명단은 그 방송보다 사흘 먼저 만들어져 있었다.",
			],
			"reward": {
				"canned_food": 14,
				"churu": 2,
				"components": {"magazine_spring": 2},
				"xp": 460,
				"summary": "송출 기록 해독 · 통조림 +14 · 츄르 +2 · 탄창 스프링 +2 · XP +460\n새 기록 · ‘사흘 먼저 만든 명단’ 해금",
			},
			"repeat_reward": {
				"canned_food": 5,
				"xp": 150,
				"summary": "송출 기록 사본 회수 · 통조림 +5 · XP +150",
			},
			"lore": "사흘 먼저 만든 명단 · 종로 방송국\n마지막 방송의 원고는 대피 안내가 아니라 이름 스물일곱 개짜리 목록이었다. 녹음 날짜가 사람이 사라진 날보다 사흘 앞선다. 부르기 전에 누구를 부를지 이미 정해져 있었다는 뜻이다. 목록을 넘겨받은 곳은 남대문이다.",
		},
	],
	# ── 남대문 폐시장 ────────────────────────────────────────────
	# 이 구역에서 알아내는 것: 명단을 받아 적은 건 고양이 손이다.
	"namdaemun_market": [
		{
			"id": "namdaemun_hidden_ration",
			"title": "밥그릇을 채우는 손",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "밥그릇을 채우는 손",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"명단은 여기로 넘어왔다. 받아 적은 손을 찾는다.",
							"천막이 세 겹으로 겹쳐 있다. 바람 막으려고 친 게 아니다.",
							"냄새가 난다. 상한 냄새가 아니라 아직 먹을 수 있는 것의 냄새.",
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
							"거기 손대지 마. 반년째 누가 채워 놔.",
							"새벽마다 조금씩. 본 적은 없어.",
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
							"상자 안은 전부 사료다. 사람이 먹는 건 하나도 없다.",
							"바닥에 배급표가 깔려 있다. 날짜가 오늘까지 찍혀 있다.",
							"— 반년째 고양이한테만 밥을 주는 손이 있다.",
						],
					},
					{
						"type": "choice",
						"id": "namdaemun_stage1_ration",
						"prompt": "이 배급을 어떻게 할 것인가.",
						"options": [
							{
								"id": "take_all",
								"label": "전부 가져간다",
								"detail": "통조림 확보 · 정산 보상 상승",
								"effect": {
									"reward_multiplier": 0.12,
									"notice": "상자 전량 회수",
									"monologue": [
										"쉘터에는 오늘 밤 먹을 게 없는 입이 여럿이다.",
										"전부 가져간다. 미안한 건 나중에 하자.",
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
										"비어 있으면 채우던 손이 눈치챈다.",
										"절반만 가져간다. 나는 그 손을 아직 못 봤으니까.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 밥그릇을 채우는 손 0/4",
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
						"발자국이 이어진다. 사람 것이 아니라 고양이 것이다.",
						"같은 발자국이 밤마다 여기를 지나갔다.",
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
				"알아낸 것. 사람을 데려간 쪽이 고양이한테는 반년째 밥을 주고 있다.",
				"공짜 밥은 없다. 뭘 시켰지?",
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
			"title": "들어가기만 한 창고",
			"type": "defense",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e7a847", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "들어가기만 한 창고",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"셔터에 붉은 등이 아직 켜져 있다. 배터리로는 반년을 못 버틴다.",
							"제어반을 누르면 셔터가 열린다. 그리고 온 동네가 그 소리를 듣는다.",
							"열고, 버티고, 챙긴다. 순서를 바꾸면 죽는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_0": [
					{"type": "shake", "strength": 0.28, "duration": 0.4},
					{
						"type": "image_cut",
						"texture": "military_cache",
						"title": "창고 장부",
						"lines": [
							"반입 기록만 빼곡하다. 반출은 한 줄도 없다.",
							"들어온 건 짐이다. 가방, 신발, 지갑.",
							"마지막 반입일은 사람이 사라진 다음 날이다.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 들어가기만 한 창고 0/3",
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
						"셔터를 지키던 건 사람이 아니라 자동 경보다. 아직 전기가 살아 있다.",
						"누가 이 창고를 계속 잠가 두게 해 놨다.",
					],
				},
			],
			"recovery": {
				"id": "namdaemun_warehouse_manifest",
				"title": "창고 장부",
				"description": "셔터 안쪽 사무실에서 가져온 장부입니다. 반입만 적혀 있고 반출은 한 줄도 없습니다.",
				"label": "창고 장부 회수",
				"map_label": "창고 장부",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.2,
				"step_title": "창고 장부 회수 · 2/3",
				"detail": "열린 창고 안쪽에서 장부를 가져온다",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "장부 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "창고 장부 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"알아낸 것. 사람 짐은 전부 여기 남았다. 사람만 갔다.",
				"소지품은 두고 오십시오. 그 방송, 진짜였네.",
			],
			"reward": {
				"canned_food": 19,
				"churu": 2,
				"components": {"magazine_spring": 2},
				# 무기 사다리 — 장부 뒷장에 끼워 둔 펌프 산탄총 도면(설계도 조각 2/3). 첫 회수에만.
				# 통짜 청사진은 폐지 — 제작은 조각 3/3(나머지 1조각은 남대문 엘리트·봉인 상자).
				"progression_items": {"blueprint_shard_pump_shotgun": 2},
				"xp": 640,
				"summary": "창고 장부 해독 · 통조림 +19 · 츄르 +2 · 탄창 스프링 +2 · XP +640\n펌프 산탄총 청사진 획득 · 작업대에서 펌프 산탄총 제작 가능",
			},
			"repeat_reward": {
				"canned_food": 7,
				"xp": 210,
				"summary": "장부 사본 회수 · 통조림 +7 · XP +210",
			},
		},
		{
			"id": "namdaemun_guild_ledger",
			"title": "명단을 쓴 손",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "명단을 쓴 손",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"시장 사무실 금고는 아직 안 털렸다. 이 도시에서 그건 이상한 일이다.",
							"약탈대가 못 연 게 아니라 안 연 거다. 인장이 없으면 안 열리니까.",
							"인장은 사무실 주인이 들고 있었다. 어디 누웠는지는 저쪽이 안다.",
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
						"title": "글씨를 아는 것",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"인장 찾았구나. 그럼 말해 줄게.",
							"방송 명단, 창고 장부, 저 안의 장부. 셋 다 글씨가 같아.",
							"사람 글씨가 아니야. 사람은 그렇게 꾹꾹 눌러 안 써.",
							"명단을 받아 적은 건 고양이다. 우리 중 하나야.",
							"…누군지 짐작은 가. 확인하기 전엔 말 안 해.",
							"열어. 등은 내가 본다.",
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
						"title": "금고 안 장부 · 마지막 장",
						"lines": [
							"돈 계산은 사람이 사라지기 전날에서 끊긴다.",
							"그 다음 장부터는 이름과 주소뿐이다. 스물일곱 줄.",
							"글씨 옆에 눌린 자국이 있다. 앞발 자국이다.",
						],
					},
					{
						"type": "choice",
						"id": "namdaemun_stage3_ledger",
						"prompt": "장부를 어떻게 할 것인가.",
						"options": [
							{
								"id": "carry",
								"label": "그대로 들고 나간다",
								"detail": "기록 보관 · 정산 보상 상승",
								"effect": {
									"reward_multiplier": 0.1,
									"notice": "장부 원본 회수",
									"monologue": [
										"원본이 있어야 다음에 같은 글씨를 봤을 때 맞춰 볼 수 있다.",
										"들고 나간다.",
									],
								},
							},
							{
								"id": "burn_copy",
								"label": "베껴 적고 원본은 태운다",
								"detail": "긴장도 하락 · 추적을 끊는다",
								"effect": {
									"pressure": -70.0,
									"notice": "원본 소각 · 사본만 회수",
									"monologue": [
										"이 글씨의 주인이 여기 다시 올 수도 있다.",
										"태운다. 그놈은 재만 보게 될 거다.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 명단을 쓴 손 0/3",
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
				"title": "시장 사무실 장부",
				"description": "금고에서 가져온 장부입니다. 뒷장부터는 돈 대신 사람 이름 스물일곱 줄이 적혀 있고, 글씨 옆에 앞발 자국이 눌려 있습니다.",
				"label": "금고 개방",
				"map_label": "사무실 금고 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.4,
				"distance": 44.0,
				"separation": 32.0,
				"step_title": "금고 개방 · 1/3",
				"detail": "인장으로 금고를 열고 장부를 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "금고 인장이 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "장부 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "장부 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"알아낸 것. 사람 명단을 받아 적은 건 고양이 손이다.",
				"누가 시켰는지는 아직 모른다.",
			],
			"reward": {
				"canned_food": 22,
				"churu": 3,
				"components": {"scope_lens": 2},
				# 쉘터 Tier 3 확장 키 — 장부 마지막 장이 창고 설계도다. 첫 회수에만.
				# + 장인의 인장 1(돌파 재료, 메인 미션 3단계 공통 보상).
				"progression_items": {"namdaemun_depot_plans": 1, "artisan_seal": 1},
				"xp": 820,
				"summary": "장부 해독 · 통조림 +22 · 츄르 +3 · 스코프 렌즈 +2 · XP +820\n새 기록 · ‘앞발 자국이 찍힌 장부’ 해금",
			},
			"repeat_reward": {
				"canned_food": 8,
				"xp": 260,
				"summary": "장부 사본 회수 · 통조림 +8 · XP +260",
			},
			"lore": "앞발 자국이 찍힌 장부 · 남대문 시장 사무실\n장부 뒷장에는 사람 이름 스물일곱 줄이 적혀 있다. 글씨는 방송국 명단과 창고 장부의 것과 같고, 줄 옆마다 앞발 자국이 눌려 있다. 사람 명단을 받아 적은 손이 고양이 손이었다는 뜻이다. 장부의 다음 인수처는 을지로다.",
		},
	],
	# ── 을지로 지하구역 ──────────────────────────────────────────
	# 이 구역에서 알아내는 것: 사람들은 지하 수송로로 실려 갔고, 승인한 이름은 사자다.
	"euljiro_depths": [
		{
			"id": "euljiro_grid_note",
			"title": "살아 있는 전기",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "살아 있는 전기",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"사람들은 지하로 내려갔다. 그 아래에서 뭘 했는지 알아야 한다.",
							"이 동네만 아직 전기가 돈다. 누가 골라서 살려 뒀다는 뜻이다.",
							"배전반 셋을 열면 전기가 어디로 가는지 보인다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 살아 있는 전기 0/4",
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
						"배전반에 쪽지가 붙어 있다. ‘3구역까지만 살려 둘 것.’",
						"3구역은 지상이 아니다. 지하다.",
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
				"description": "전기가 어디서 끝나는지 적힌 기록입니다. 살려 둔 회로가 전부 한 방향으로 모입니다.",
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
				"알아낸 것. 살려 둔 전기는 전부 지하 선로로 간다.",
				"사람 없는 도시에서 아직도 뭔가가 그 아래를 굴러다닌다.",
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
						"speaker": "나비",
						"title": "무엇을 실었나",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"선로가 살아 있으면 그 위로 뭔가가 다녔다는 뜻이다.",
							"공방 문이 안에서 잠겼다. 제어반을 누르면 열린다.",
							"열리는 동안은 소리가 난다. 버틸 준비부터 한다.",
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
						"공방 바닥에 바퀴 자국이 층층이 남아 있다.",
						"수레를 만들던 곳이다. 사람을 실을 만큼 큰 걸로.",
					],
				},
			],
			"recovery": {
				"id": "euljiro_workshop_cast",
				"title": "수레 도면 뭉치",
				"description": "공방에서 가져온 도면입니다. 사람 스물일곱을 한 번에 싣는 크기로 그려져 있습니다.",
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
				"알아낸 것. 사람들은 걸어서 지하로 내려가 수레에 실렸다.",
				"걸어 들어가서, 실려 나갔다.",
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
			"title": "승인한 이름",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "승인한 이름",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"수레가 다녔으면 누가 그걸 굴리라고 했을 거다.",
							"지하 관제실에 수송 기록이 남아 있다.",
							"오늘은 이름 하나만 알아 가면 된다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "manifest_terminal",
						"title": "수송 기록 · 승인란",
						"lines": [
							"수송 기록이 통째로 남아 있다. 열두 회차, 전부 같은 선로.",
							"매 회차 승인란에 같은 서명이 찍혀 있다.",
							"이름 두 글자. ‘사자.’",
							"— 내 밥그릇을 채워 주는 그 사자.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 승인한 이름 0/3",
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
				"title": "지하 수송 기록",
				"description": "관제실 콘솔에서 통째로 뽑아낸 기록입니다. 수송 열두 회차의 승인란에 전부 같은 서명이 찍혀 있습니다.",
				"label": "수송 기록 회수",
				"map_label": "지하 관제실 · 잠김",
				"prop": "manifest_terminal",
				"color": "#e66a47",
				"hold": 4.2,
				"distance": 46.0,
				"separation": 34.0,
				"step_title": "관제실 진입 · 1/3",
				"detail": "열쇠로 관제실을 열고 수송 기록을 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "관제실 열쇠가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "수송 기록 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "수송 기록 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"알아낸 것. 수송을 승인한 이름은 사자다.",
				"오늘 밤에도 그 앞에 앉아서 밥을 먹어야 한다.",
			],
			"reward": {
				"canned_food": 30,
				"churu": 4,
				"components": {"scope_lens": 3},
				# 쉘터 Tier 4 확장 키 — 관제실 기록에 딸려 온 배전 도면. 첫 회수에만.
				"progression_items": {"euljiro_grid_schematic": 1, "artisan_seal": 1},
				"xp": 1350,
				"summary": "수송 기록 해독 · 통조림 +30 · 츄르 +4 · 스코프 렌즈 +3 · XP +1350\n새 기록 · ‘열두 회차 승인란’ 해금",
			},
			"repeat_reward": {
				"canned_food": 11,
				"xp": 420,
				"summary": "수송 기록 사본 회수 · 통조림 +11 · XP +420",
			},
			"lore": "열두 회차 승인란 · 을지로 지하 관제실\n지하 선로로 열두 번의 수송이 있었다. 회차마다 인원과 시각이 적혀 있고, 승인란에는 매번 같은 서명이 찍혀 있다. ‘사자.’ 마지막 회차 아래에는 다음 예정지가 한 줄 적혀 있다. 용산.",
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
						"speaker": "나비",
						"title": "통과 인원 0",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"수송이 여기까지 왔다. 그럼 군이 봤을 거다.",
							"검문소 단말이 두 개 남았다. 둘 다 읽으면 기록이 이어진다.",
							"군이 사람들을 어느 쪽으로 보냈는지, 그것만 본다.",
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
						"봉쇄선은 사람을 밖으로 못 나가게 막고 있었다.",
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
				"알아낸 것. 군은 사람을 내보낸 게 아니다. 안쪽으로 몰았다.",
				"지하로 내려가는 입구 쪽으로.",
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
						"speaker": "나비",
						"title": "총구의 방향",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"군이 사람을 안으로 몰았다면, 총은 어디를 보고 있었나.",
							"탄약고 안에 명령서가 있다. 봉인부터 뜯어야 한다.",
							"뜯는 데 십팔 초. 그 십팔 초는 시끄럽다.",
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
						"탄약고를 지키라는 명령이 아직 살아 있다. 명령한 사람은 없는데.",
						"지키라는 게 탄약이 아니었던 모양이다.",
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
				"알아낸 것. 군은 총구를 바깥이 아니라 도시 안쪽으로 돌렸다.",
				"사람이 도망치지 못하게 서 있었던 거다.",
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
			"title": "협조 각서",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "협조 각서",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"군이 도왔다면 종이가 남았을 거다. 군은 종이 없이 안 움직인다.",
							"사령부 금고에 그 종이가 있다.",
							"인증표부터 뺏는다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "sealed_cargo",
						"title": "금고 안 · 종이 한 장",
						"lines": [
							"금고에 무기는 없다. 종이 한 장이다.",
							"군과 민간이 맺은 협조 각서다. 수송 열두 회차분.",
							"요청한 쪽 서명은 사자. 승인한 쪽은 군이다.",
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
						"title": "열아홉 번째 줄",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"봤지. 이제 내가 왜 그놈을 쫓는지 말해 줄게.",
							"명단 스물일곱 줄. 열아홉 번째가 우리 집 사람이야.",
							"나한테 밥 주던 사람. 나 안고 자던 사람.",
							"사자가 그 이름을 받아 적었어. 나는 그 글씨를 안다.",
							"나는 그놈 죽이러 간다. 너는 네 볼일 봐.",
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
					"step_title": "메인 임무 · 협조 각서 0/3",
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
				"title": "군·민간 협조 각서",
				"description": "사령부 금고에 있던 종이 한 장입니다. 수송 열두 회차를 요청한 쪽과 승인한 쪽의 서명이 나란히 찍혀 있습니다.",
				"label": "사령부 금고 개방",
				"map_label": "사령부 금고 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.6,
				"distance": 48.0,
				"separation": 36.0,
				"step_title": "사령부 금고 개방 · 1/3",
				"detail": "인증표로 금고를 열고 각서를 가져온다 · 경보 주의",
				"role": "locked",
				"locked_reason": "사령부 인증표가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "각서 운반 중 · 가장 가까운 하수구로 이동한다",
			"carry_notice": "협조 각서 확보 · 탈출하면 다음에 갈 곳이 나옵니다",
			"carry_monologue": [
				"알아낸 것. 군은 알고도 도왔다. 요청한 쪽이 사자다.",
				"주홍은 그 명단에서 자기 사람 이름을 찾았다.",
			],
			"reward": {
				"canned_food": 42,
				"churu": 6,
				"components": {"scope_lens": 4},
				# 쉘터 Tier 5 확장 키 — 사령부 금고의 통제 키. 첫 회수에만.
				"progression_items": {"yongsan_control_key": 1, "artisan_seal": 1},
				"xp": 2400,
				"summary": "협조 각서 해독 · 통조림 +42 · 츄르 +6 · 스코프 렌즈 +4 · XP +2400\n새 기록 · ‘군·민간 협조 각서’ 해금",
			},
			"repeat_reward": {
				"canned_food": 15,
				"xp": 760,
				"summary": "각서 사본 회수 · 통조림 +15 · XP +760",
			},
			"lore": "군·민간 협조 각서 · 용산 사령부\n종이 한 장짜리 각서다. 수송 열두 회차 동안 군이 봉쇄선을 유지하고 민간 협력자가 명단을 제공한다고 적혀 있다. 요청한 쪽 서명은 사자, 승인한 쪽은 사령관이다. 각서 끝에 수송 종착지가 한 줄 적혀 있다. 남산.",
		},
	],
	# ── 남산 관제탑 ──────────────────────────────────────────────
	# 이 구역에서 알아내는 것: 사람들은 지하에 살아 있고, 스위치는 하나다.
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
						"speaker": "나비",
						"title": "거짓 수치",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"수송의 끝은 남산이다. 그런데 여긴 오염 구역으로 찍혀 있다.",
							"오염 관측기가 셋이다. 셋을 맞춰야 원본 수치가 읽힌다.",
							"숫자가 맞는지부터 본다.",
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
						"관측기 안쪽 수치가 두 벌이다. 하나는 표시용, 하나는 실제.",
						"실제 수치는 종로보다 낮다.",
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
				"알아낸 것. 남산이 위험하다는 건 거짓말이다.",
				"사람을 못 올라오게 하려고 적어 둔 숫자였다.",
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
						"speaker": "나비",
						"title": "아직 돌아가는 기계",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"관제탑 문을 열려면 아래 기계를 먼저 돌려야 한다.",
							"제어반을 누르면 라인이 돈다. 이십 초.",
							"이십 초 동안 여기 서 있는다.",
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
						"기계가 돈다. 사람이 사라진 뒤로 계속 예약된 채였다.",
						"누가 아직 이걸 쓸 생각이라는 뜻이다.",
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
				"알아낸 것. 수거는 끝난 게 아니다. 기계는 다음 회차를 기다린다.",
				"열세 번째 회차. 명단 칸은 아직 비어 있다.",
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
			"title": "스위치",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"mode": "bark"},
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e2c15f", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "스위치",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"맨 위층에 방송을 틀던 방이 있다.",
							"열두 회차를 굴린 기계도 거기 있다.",
							"오늘은 두 가지를 정한다. 사람을 어떻게 할지, 기계를 어떻게 할지.",
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
							"열두 회차가 전부 한 곳으로 들어간다. 사람들은 거기 있다.",
							"살아 있다. 자고 있다. 깨울 수 있다.",
							"콘솔에 손잡이가 둘이다.",
						],
					},
					{
						"type": "choice",
						"id": "namsan_final_switch",
						"prompt": "손잡이는 둘이다. 하나만 당길 수 있다.",
						"options": [
							{
								"id": "shutdown",
								"label": "기계를 끈다",
								"detail": "수거를 멈춘다 · 사람은 지하에 그대로 잠든다",
								"effect": {
									"pressure": -80.0,
									"notice": "수거 시스템 정지 · 열세 번째 회차는 없습니다",
									"monologue": [
										"껐다. 열세 번째 회차는 없다.",
										"지하에 있는 사람들은 그대로 잔다. 나는 못 깨운다.",
										"대신 더 데려가지도 못한다. 오늘은 그걸로 됐다.",
									],
								},
							},
							{
								"id": "wake",
								"label": "사람을 깨운다",
								"detail": "사람을 돌려받는다 · 기계는 계속 돌아간다 · 정산 보상 상승",
								"effect": {
									"reward_multiplier": 0.2,
									"pressure": 60.0,
									"notice": "지하 개방 · 사람들이 올라옵니다 · 기계는 계속 돌아갑니다",
									"monologue": [
										"깨웠다. 지하에서 문이 하나씩 열린다.",
										"사람들이 걸어 올라온다. 이번엔 아무도 안 웃는다.",
										"기계는 못 껐다. 언젠가 다시 명단을 만들 거다.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 스위치 0/3",
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
				"title": "관제탑 운영 기록",
				"description": "맨 위층 콘솔에서 뽑아낸 기록입니다. 열두 회차가 어디로 들어갔는지, 그리고 사람들이 아직 살아 있다는 것이 적혀 있습니다.",
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
				"알아낸 것. 사람들은 지하에 살아 있다.",
				"그리고 나는 방금 골랐다. 이제 사자한테 물어볼 차례다.",
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
			"lore": "사람들은 아직 자고 있다 · 남산 관제탑\n사람은 도망친 게 아니라 수거됐다. 녹음된 방송이 이름을 불렀고, 사람들은 걸어 나가 지하 선로에서 수레에 실렸다. 열두 회차가 전부 남산 아래 한 곳으로 들어갔고, 그곳의 사람들은 아직 살아서 자고 있다. 명단을 받아 적은 건 고양이 손이었고, 수송을 요청한 서명은 사자였다.",
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
