class_name MainMissionCatalog
extends RefCounted

# 존별 메인 미션 체인 데이터 테이블.
#
# 예전에는 "격리 신호"(잭팟) 하나가 어느 구역에서든 똑같이 떴다. 이야기가
# 한 판도 앞으로 안 나가고, 종로에서 본 신호를 남산에서도 다시 봤다.
# 이제 구역마다 3단계짜리 체인이 있고, 세 단계를 끝낸 구역에서는 메인
# 미션이 더 이상 뜨지 않는다 — 흔적이 다음 도시로 넘어간다.
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
#   carry_monologue     단계 완료 독백 2줄(하드보일드, 세계관 한 겹)
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
#   complete_monologue  이 지점을 끝냈을 때의 독백(빈 배열이면 생략)
#   defense_duration    role == "defense"일 때 버텨야 하는 초
#   defense_waves       role == "defense"일 때 밀려오는 웨이브 수
#
# 신규 기믹은 만들지 않는다. relay(연쇄 상호작용) / defense(방어) /
# keyed(열쇠+거점) 세 골격의 조합으로만 짠다 — 유지보수 가능해야 한다.

const STAGES_PER_ZONE := 3

# 대사창 초상화 — 기존 캐릭터 스프라이트의 정면 대기 프레임을 그대로 쓴다.
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
	"jongno_outskirts": [
		{
			"id": "seoul_line3_relief_core",
			"title": "격리 신호",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"type": "wait", "duration": 0.4},
					{"type": "focus", "at": "site", "hold": 1.1},
					{"type": "flash", "color": "#62c9ca", "pulses": 2, "duration": 0.9},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "불명 격리 신호",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"삼백 밤 동안 죽어 있던 주파수가 방금 한 번 뛰었다.",
							"이 도시에서 저절로 깨어나는 건 없다. 누가 스위치를 눌렀다는 뜻이지.",
							"발신지는 저쪽. 가서 무엇이 아직 살아 있는지 본다.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_0": [
					{
						"type": "image_cut",
						"texture": "manifest_terminal",
						"title": "격리 수송 명부 · 조각",
						"lines": [
							"화면에 남은 건 명부의 절반이다.",
							"품목란은 전부 지워졌고, 목적지란만 살아 있다.",
							"목적지는 스물일곱 줄. 전부 이 도시 안이다.",
							"맨 아래 손글씨 한 줄. ‘잠그지 말 것.’",
						],
					},
				],
				"point_1": [
					{"type": "wait", "duration": 0.3},
					{
						"type": "spawn_actor",
						"key": "runner",
						"root": "res://assets/characters/worker_cat",
						"display_name": "이름 모를 고양이",
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
						"speaker": "이름 모를 고양이",
						"title": "문 앞까지 온 것",
						"portrait": PORTRAIT_WORKER_PATH,
						"lines": [
							"…아래에서 올라왔어. 계단이 끝나는 데까지.",
							"문이 열려 있었어. 전부. 사람이 잠근 문은 하나도 없었어.",
							"그런데 위쪽에 총을 든 것들이… 나는 여기까지야.",
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
										"그래도 두고 가면, 오늘 밤 내가 여기 온 이유가 없어진다.",
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
										"다시 오겠다고 말했다. 그 말을 믿는 눈이 아니었다.",
										"오늘은 화물이 먼저다. 오늘은.",
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
						"title": "봉인 화물 · 개봉 전",
						"lines": [
							"봉인지에 찍힌 건 회사 인장이 아니다. 방역 관인이다.",
							"관인 옆에 손으로 눌러 쓴 글자. ‘안에 살아 있는 것 있음.’",
							"안쪽에서 나는 건 기계음이 아니었다.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 격리 신호 0/4",
					"detail": "TAB 지도 확인 → 주황 신호의 단말을 조사하세요",
					"label": "격리 수송 기록 판독",
					"map_label": "불명 격리 신호",
					"prop": "manifest_terminal",
					"color": "#62c9ca",
					"hold": 1.6,
					"distance": 34.0,
					"separation": 22.0,
					"complete_notice": "격리 기록 복원 · 지하선 3번 화물의 비상 전력 좌표가 지도에 표시됩니다.",
					"complete_monologue": [
						"단말이 아직 살아 있다… 이 격리 기록, 사람이 지워지던 그 밤의 것이다.",
						"지하선 3번 화물. 누군가, 이게 발견되지 않기를 바랐어.",
					],
				},
				{
					"step_title": "비상 전력 복구 · 1/4",
					"detail": "주황 발전기로 이동해 전력을 복구하세요",
					"label": "지하선 비상 전력 복구",
					"map_label": "지하선 비상 발전기",
					"prop": "generator",
					"color": "#e7a847",
					"hold": 2.8,
					"distance": 42.0,
					"separation": 26.0,
					"complete_notice": "경보 발생 · 화물 좌표 노출 · 대응대가 온다",
					"complete_monologue": [
						"전력이 돌아왔다. 삼백 밤 만에, 도시의 일부가 눈을 떴다.",
						"…도시가 눈을 뜨면 다른 것들도 함께 깨어난다. 서둘러야 해.",
					],
				},
			],
			"recovery": {
				"id": "seoul_line3_relief_core",
				"title": "서울 지하선 3번 봉인 화물",
				"description": "격리 수송 당시의 봉인이 그대로 남은 대형 화물입니다. 안쪽에서 낮은 진동이 느껴집니다. 탈출해야 내용물을 확인할 수 있습니다.",
				"label": "봉인 화물 분리",
				"map_label": "경보 발생 · 봉인 화물",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.2,
				"distance": 48.0,
				"separation": 30.0,
				"step_title": "봉인 화물 회수 · 2/4",
				"detail": "붉은 화물 위치로 이동 · 접근하는 약탈대를 경계하세요",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "특수 화물 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "특수 화물 확보 · 탈출 시 특별 보상과 기록 해금",
			"carry_monologue": [
				"무겁다. 그리고 봉인 너머에서… 희미하게 심장 소리 같은 게 난다.",
				"묻는 건 나중이다. 지금은 산 채로 들고 나간다.",
			],
			"reward": {
				"canned_food": 8,
				"churu": 1,
				"components": {"scope_lens": 1},
				"xp": 220,
				"summary": "지하선 3번 보급 코어 개봉 · 통조림 +8 · 츄르 +1 · 스코프 렌즈 +1 · XP +220\n새 세계 기록 · ‘3번선 마지막 명부’ 해금",
			},
			"repeat_reward": {
				"canned_food": 3,
				"churu": 1,
				"xp": 90,
				"summary": "잔존 수송 코어 개봉 · 통조림 +3 · 츄르 +1 · XP +90",
			},
			"lore": "붉은비 격리 기록 · 3번선 마지막 명부\n봉인된 명부에는 인간이 떠나기 직전 개방한 고양이 보호소 27곳이 적혀 있었다. 누군가는 재난의 마지막 순간까지 이 도시의 작은 생존자들이 지하로 도망칠 길을 남겨 두었다.",
		},
		{
			"id": "jongno_watermain_record",
			"title": "끊긴 급수 배관",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "끊긴 급수 배관",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"간선도로 밑에서 물소리가 난다. 수돗물이 끊긴 지 삼백 밤인데.",
							"밸브 셋이 차례로 잠겨 있다. 순서대로 열어야 마지막 방이 열린다.",
							"길을 세 번 건너야 한다는 뜻이다. 트인 도로에서 오래 서 있지 마라.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"point_1": [
					{"type": "focus", "at": "site", "hold": 0.8},
					{"type": "flash", "color": "#6fb7d8", "pulses": 2, "duration": 0.8},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "간선도로 건너편",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"두 번째 밸브를 여는 순간 도로 저쪽에서 불빛이 줄줄이 켜졌다.",
							"가로등이 아니다. 손전등이다. 여섯, 아니 여덟.",
							"저쪽도 물소리를 들었다는 뜻이지. 몸을 낮춰라.",
						],
					},
					{"type": "focus_player", "hold": 0.3},
				],
				"recovery": [
					{
						"type": "image_cut",
						"texture": "convoy_cache",
						"title": "급수 통제 기록 · 손글씨",
						"lines": [
							"배관도 위에 다른 잉크로 선이 하나 더 그어져 있다.",
							"본선에서 갈라져 나가 지하로 내려가는 임시 관.",
							"관 끝마다 같은 표시. 작은 발자국 모양이다.",
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
										"열어 둔 채 나가면 다음에 오는 건 내가 아닐 수도 있다.",
										"잠근다. 이 물은 아직 우리 것이 아니다.",
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
					"step_title": "메인 임무 · 끊긴 급수 배관 0/4",
					"detail": "TAB 지도 확인 → 간선도로 건너편 1번 밸브를 여세요",
					"label": "급수 1번 밸브 개방",
					"map_label": "급수 1번 밸브",
					"prop": "generator",
					"color": "#6fb7d8",
					"hold": 2.2,
					"distance": 40.0,
					"separation": 34.0,
					"complete_notice": "1번 밸브 개방 · 압력이 2번 밸브 쪽으로 밀린다",
					"complete_monologue": [
						"압력계 바늘이 반대로 튄다. 물이 이쪽으로 오는 게 아니라 저쪽으로 빨려 나간다.",
						"관 끝에 뭔가가 있다. 그게 뭐든, 아직 목이 마르다는 뜻이지.",
					],
				},
				{
					"step_title": "2번 밸브 개방 · 1/4",
					"detail": "반대편 블록의 2번 밸브까지 이동하세요 · 노출된 간선도로 주의",
					"label": "급수 2번 밸브 개방",
					"map_label": "급수 2번 밸브",
					"prop": "generator",
					"color": "#6fb7d8",
					"hold": 2.2,
					"distance": 46.0,
					"separation": 38.0,
					"complete_notice": "2번 밸브 개방 · 마지막 밸브 좌표가 지도에 표시됩니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "jongno_watermain_record",
				"title": "종로 급수 통제 기록함",
				"description": "마지막 밸브실 벽에 붙어 있던 통제 기록함입니다. 배관도와 함께, 도면에 없는 손글씨 표기가 남아 있습니다.",
				"label": "급수 통제 기록 회수",
				"map_label": "급수 통제실 · 기록함",
				"prop": "convoy_cache",
				"color": "#e0a94f",
				"hold": 3.4,
				"distance": 52.0,
				"separation": 40.0,
				"step_title": "통제 기록 회수 · 2/4",
				"detail": "마지막 밸브실에서 통제 기록을 회수하세요",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "급수 통제 기록 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "통제 기록 확보 · 탈출하면 배관도가 해독됩니다",
			"carry_monologue": [
				"밸브 셋을 다 열어도 물은 안 나온다. 관 끝이 봉쇄선 안쪽에서 잘려 있어.",
				"도시가 목마른 게 아니었다. 누가 도시를 통째로 잠갔다.",
			],
			"reward": {
				"canned_food": 11,
				"churu": 1,
				"components": {"rubber_gasket": 2},
				"xp": 320,
				"summary": "급수 통제 기록 해독 · 통조림 +11 · 츄르 +1 · 고무 패킹 +2 · XP +320",
			},
			"repeat_reward": {
				"canned_food": 4,
				"xp": 110,
				"summary": "급수 기록 사본 회수 · 통조림 +4 · XP +110",
			},
		},
		{
			"id": "jongno_broadcast_log",
			"title": "잠긴 방송국",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e2c15f", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "잠긴 방송국",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"길가 스피커가 지직거린다. 같은 잡음이 정확히 열두 초마다.",
							"송출이 아직 돌고 있다는 뜻이다. 주조정실 문은 잠겨 있겠지.",
							"열쇠는 사람이 들고 있다. 정확히는, 사람이었던 것들이.",
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
						"role": "붉은 칼의 전령",
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
						"title": "같은 신호를 쫓는 것",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"손 내려. 나도 그 키카드 보고 왔다.",
							"열두 초 잡음. 나는 그걸 여섯 도시에서 들었어. 전부 같은 간격이야.",
							"기계가 고장 나서 반복하는 게 아니다. 누가 반복하라고 시켜 뒀지.",
							"방송국 안에 마지막 송출 로그가 있다. 뭘 읽었는지가 거기 남아.",
							"먼저 말해 두는데, 그 안에서 사람 뼈를 봐도 놀라지 마라.",
							"놀랄 건 뼈가 아니라, 그 사람이 마지막까지 앉아 있던 방향이다.",
							"…들어가. 나는 밖을 본다. 네가 나올 때까지만.",
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
						"title": "최종 송출 로그",
						"lines": [
							"마지막 송출은 대피 안내가 아니었다.",
							"아나운서는 주소 스물일곱 개를 천천히, 두 번 읽었다.",
							"목록 옆 여백에 연필로 눌러 쓴 글자. ‘문 열어 둠.’",
							"목록의 남쪽 끝은 남대문 시장이다.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 잠긴 방송국 0/3",
					"detail": "TAB 지도 확인 → 약탈대가 낀 구역에서 관제 열쇠를 확보하세요",
					"label": "관제 키카드 확보",
					"map_label": "관제 키카드 · 약탈대 점거",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 2.6,
					"distance": 38.0,
					"separation": 30.0,
					"role": "key",
					"guards": 4,
					"complete_notice": "관제 키카드 확보 · 방송국 주조정실이 열립니다",
					"complete_monologue": [
						"키카드에 이름이 없다. 직책만 찍혀 있어 — ‘야간 송출 담당’.",
						"마지막까지 마이크 앞에 앉아 있던 사람이 있었다는 뜻이다.",
					],
				},
			],
			"recovery": {
				"id": "jongno_broadcast_log",
				"title": "종로 방송국 최종 송출 로그",
				"description": "주조정실 콘솔에서 뜯어낸 송출 로그입니다. 마지막 방송은 대피 안내가 아니라, 좌표를 읽어 내려간 목록이었습니다.",
				"label": "주조정실 송출 로그 회수",
				"map_label": "방송국 주조정실 · 잠김",
				"prop": "manifest_terminal",
				"color": "#e66a47",
				"hold": 4.0,
				"distance": 46.0,
				"separation": 34.0,
				"step_title": "주조정실 진입 · 1/3",
				"detail": "키카드로 주조정실을 열고 송출 로그를 회수하세요",
				"role": "locked",
				"locked_reason": "관제 키카드가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "송출 로그 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "송출 로그 확보 · 탈출하면 다음 목적지가 드러납니다",
			"carry_monologue": [
				"방송국 마지막 송출 기록. 대피 안내가 아니라, 좌표 목록이었다.",
				"스물일곱 개. 전부 사람이 비운 건물이고, 전부 문이 열려 있었다.",
			],
			"reward": {
				"canned_food": 14,
				"churu": 2,
				"components": {"magazine_spring": 2},
				"xp": 460,
				"summary": "최종 송출 로그 해독 · 통조림 +14 · 츄르 +2 · 탄창 스프링 +2 · XP +460\n새 세계 기록 · ‘야간 송출 좌표표’ 해금",
			},
			"repeat_reward": {
				"canned_food": 5,
				"xp": 150,
				"summary": "송출 로그 사본 회수 · 통조림 +5 · XP +150",
			},
			"lore": "야간 송출 좌표표 · 종로 방송국\n마지막 방송은 대피 안내가 아니었다. 아나운서는 스물일곱 개의 주소를 천천히 두 번 읽었고, 그 목록의 첫 줄 옆에는 손으로 ‘문 열어 둠’이라고 적혀 있었다. 목록의 남쪽 끝은 남대문 시장이었다.",
		},
	],
	# ── 남대문 폐시장 ────────────────────────────────────────────
	"namdaemun_market": [
		{
			"id": "namdaemun_hidden_ration",
			"title": "천막 미로의 냄새",
			"type": "relay",
			"cinematics": {
				"intro": [
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "천막 미로의 냄새",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"방송국 목록의 남쪽 끝. 여기 골목 어딘가다.",
							"천막이 세 겹으로 겹쳐 있다. 바람 막으려고 친 게 아니야.",
							"냄새가 난다. 상한 냄새가 아니라, 아직 먹을 수 있는 것의 냄새.",
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
							"거기 손대지 마. 그건 내 것도 네 것도 아니야.",
							"반년째 누가 채워 놓고 있어. 새벽마다 조금씩.",
							"본 적은 없어. 발자국만 남아. 사람 발자국이야.",
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
						"title": "은닉 배급 상자",
						"lines": [
							"상자 안은 사람이 먹는 것이 아니었다. 전부 사료다.",
							"바닥에 배급표가 깔려 있다. 날짜가 오늘까지 찍혀 있어.",
							"누군가 아직도, 오지 않을 손님을 위해 상을 차리고 있다.",
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
									"notice": "은닉 배급 전량 회수",
									"monologue": [
										"쉘터에는 오늘 밤 먹을 게 없는 입이 여럿이다.",
										"여기 남긴 몫으로는 아무도 못 산다. 전부 가져간다.",
									],
								},
							},
							{
								"id": "leave_half",
								"label": "절반은 남겨 둔다",
								"detail": "고철 보상 · 이 골목의 밥그릇을 남긴다",
								"effect": {
									"scrap": 2600,
									"notice": "배급 절반 회수 · 나머지는 제자리에",
									"monologue": [
										"채우는 손이 아직 있다면, 그릇도 남아 있어야 한다.",
										"절반만 가져간다. 다음에 올 때 여기가 비어 있으면 곤란하니까.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 천막 미로의 냄새 0/4",
					"detail": "TAB 지도 확인 → 좌판 골목의 첫 흔적을 따라가세요",
					"label": "좌판 밑 흔적 조사",
					"map_label": "좌판 밑 흔적",
					"prop": "convoy_cache",
					"color": "#d9b06a",
					"hold": 1.8,
					"distance": 30.0,
					"separation": 20.0,
					"complete_notice": "흔적 추적 · 다음 냄새가 지도에 표시됩니다",
					"complete_monologue": [
						"사료 냄새다. 상한 것도 아니고, 오래된 것도 아니야.",
						"이 골목 어딘가에서 누가 아직 밥그릇을 채우고 있다.",
					],
				},
				{
					"step_title": "뒤집힌 손수레 · 1/4",
					"detail": "골목 안쪽의 뒤집힌 손수레를 확인하세요",
					"label": "뒤집힌 손수레 확인",
					"map_label": "뒤집힌 손수레",
					"prop": "convoy_cache",
					"color": "#d9b06a",
					"hold": 1.8,
					"distance": 34.0,
					"separation": 24.0,
					"complete_notice": "은닉 물자 더미 좌표 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namdaemun_hidden_ration",
				"title": "천막 밑 은닉 배급 상자",
				"description": "천막 세 겹 아래 숨겨져 있던 배급 상자입니다. 사람 몫이 아니라, 처음부터 다른 것을 먹이려고 쌓아 둔 양입니다.",
				"label": "은닉 배급 상자 회수",
				"map_label": "은닉 배급 상자",
				"prop": "pharmacy_cache",
				"color": "#e66a47",
				"hold": 3.2,
				"distance": 38.0,
				"separation": 26.0,
				"step_title": "은닉 물자 회수 · 2/4",
				"detail": "천막 미로 안쪽의 은닉 물자를 회수하세요",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "배급 상자 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "은닉 배급 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"천막 밑에 쟁여 둔 건 약탈품이 아니라 사료였다. 그것도 반년치.",
				"누군가 우리가 올 걸 알고 있었다. 사라지기 훨씬 전부터.",
			],
			"reward": {
				"canned_food": 16,
				"churu": 2,
				"components": {"rubber_gasket": 2},
				"xp": 520,
				"summary": "은닉 배급 개봉 · 통조림 +16 · 츄르 +2 · 고무 패킹 +2 · XP +520",
			},
			"repeat_reward": {
				"canned_food": 6,
				"xp": 170,
				"summary": "잔여 배급 회수 · 통조림 +6 · XP +170",
			},
		},
		{
			"id": "namdaemun_warehouse_manifest",
			"title": "봉쇄된 시장 창고",
			"type": "defense",
			"cinematics": {
				"intro": [
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{"type": "flash", "color": "#e7a847", "pulses": 3, "duration": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "봉쇄된 시장 창고",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"셔터에 붉은 등이 살아 있다. 배터리로는 반년을 못 버틴다.",
							"선이 어딘가 살아 있는 배전반에 물려 있다는 뜻이지.",
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
						"title": "창고 봉쇄 명부",
						"lines": [
							"반입 기록만 빼곡하다. 반출은 한 줄도 없다.",
							"마지막 반입일은 봉쇄 다음 날이다. 사람이 이미 사라진 뒤.",
							"서명란은 전부 같은 글씨. 이름 대신 숫자 하나. 27.",
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 봉쇄된 시장 창고 0/3",
					"detail": "TAB 지도 확인 → 창고 셔터 제어반을 조작하세요",
					"label": "창고 셔터 제어반 조작",
					"map_label": "시장 창고 셔터",
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
						"셔터를 지키던 건 사람이 아니라 자동 경보였다. 아직도 전기가 살아 있어.",
						"전기를 끊지 않고 떠난 도시. 도망이라면 그럴 리가 없다.",
					],
				},
			],
			"recovery": {
				"id": "namdaemun_warehouse_manifest",
				"title": "시장 창고 봉쇄 명부",
				"description": "셔터 안쪽 사무실에서 회수한 봉쇄 명부입니다. 반출은 없고, 반입만 빼곡히 적혀 있습니다.",
				"label": "봉쇄 명부 회수",
				"map_label": "창고 봉쇄 명부",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.2,
				"step_title": "봉쇄 명부 회수 · 2/3",
				"detail": "열린 창고 안쪽에서 봉쇄 명부를 회수하세요",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "봉쇄 명부 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "봉쇄 명부 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"반입만 있고 반출은 한 줄도 없다. 물건이 들어가고 아무도 안 나왔다.",
				"창고가 아니었어. 여긴 마지막까지 채워 두려던 그릇이다.",
			],
			"reward": {
				"canned_food": 19,
				"churu": 2,
				"components": {"magazine_spring": 2},
				"xp": 640,
				"summary": "봉쇄 명부 해독 · 통조림 +19 · 츄르 +2 · 탄창 스프링 +2 · XP +640",
			},
			"repeat_reward": {
				"canned_food": 7,
				"xp": 210,
				"summary": "명부 사본 회수 · 통조림 +7 · XP +210",
			},
		},
		{
			"id": "namdaemun_guild_ledger",
			"title": "상인 조합 금고",
			"type": "keyed",
			"cinematics": {
				"intro": [
					{"type": "wait", "duration": 0.35},
					{"type": "focus", "at": "site", "hold": 1.0},
					{
						"type": "lines",
						"speaker": "나비",
						"title": "상인 조합 금고",
						"portrait": PORTRAIT_NABI_PATH,
						"lines": [
							"조합 사무실 금고는 아직 안 털렸다. 이 도시에서 그건 이상한 일이다.",
							"약탈대가 못 연 게 아니라, 안 연 거다. 인장이 없으면 안 열리니까.",
							"인장은 조합장이 들고 있었다. 조합장이 어디 누워 있는지는 저쪽이 안다.",
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
						"role": "붉은 칼의 전령",
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
						"title": "장부를 먼저 읽은 것",
						"portrait": PORTRAIT_JUHONG_PATH,
						"lines": [
							"인장 찾았군. 그럼 이제 내가 아는 걸 말해도 되겠다.",
							"방송국 목록, 창고 명부, 조합 장부. 셋 다 스물일곱이 나온다.",
							"나는 그게 창고 번호인 줄 알았어. 아니었다.",
							"열쇠 번호야. 문 스물일곱 개의.",
							"인간이 마지막 사십 분 동안 한 일은 도망이 아니라 개방이었다.",
							"…왜 그랬는지는 나도 모른다. 장부 마지막 장에 답이 있을 거다.",
							"열어. 나는 여기서 등을 봐 준다.",
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
						"title": "조합 최종 장부 · 마지막 장",
						"lines": [
							"돈 계산은 봉쇄 전날에서 끊긴다.",
							"그 다음 장부터는 전부 열쇠 번호와 주소다. 스물일곱 줄.",
							"맨 아래 다른 필체 한 줄. ‘전부 열어 두었음. 잠그지 말 것.’",
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
										"원본이 있어야 다음 도시에서 대조할 수 있다.",
										"읽을 사람이 남아 있는 한, 종이는 무기다.",
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
										"같은 목록을 쫓는 게 나 하나라는 보장이 없다.",
										"태운다. 다음에 여기 오는 놈은 재만 보게 될 거다.",
									],
								},
							},
						],
					},
				],
			},
			"points": [
				{
					"step_title": "메인 임무 · 상인 조합 금고 0/3",
					"detail": "TAB 지도 확인 → 약탈대가 낀 구역에서 조합장 인장을 확보하세요",
					"label": "조합장 인장 확보",
					"map_label": "조합장 인장 · 약탈대 점거",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 2.6,
					"distance": 34.0,
					"separation": 26.0,
					"role": "key",
					"guards": 5,
					"complete_notice": "조합장 인장 확보 · 조합 금고가 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namdaemun_guild_ledger",
				"title": "상인 조합 최종 장부",
				"description": "조합 금고에서 회수한 장부입니다. 돈 대신 열쇠 스물일곱 개의 행방이 적혀 있습니다.",
				"label": "조합 금고 개방",
				"map_label": "상인 조합 금고 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.4,
				"distance": 44.0,
				"separation": 32.0,
				"step_title": "조합 금고 개방 · 1/3",
				"detail": "인장으로 금고를 열고 장부를 회수하세요 · 경보 주의",
				"role": "locked",
				"locked_reason": "조합장 인장이 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "조합 장부 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "조합 장부 확보 · 탈출하면 다음 목적지가 드러납니다",
			"carry_monologue": [
				"금고 안에 돈은 한 장도 없었다. 대신 배급 장부와 열쇠 스물일곱 개.",
				"상인들이 마지막에 판 건 물건이 아니었다. 문이었다.",
			],
			"reward": {
				"canned_food": 22,
				"churu": 3,
				"components": {"scope_lens": 2},
				# 쉘터 Tier 3 확장 키 — 장부 마지막 장이 창고 설계도다. 첫 회수에만.
				"progression_items": {"namdaemun_depot_plans": 1},
				"xp": 820,
				"summary": "조합 장부 해독 · 통조림 +22 · 츄르 +3 · 스코프 렌즈 +2 · XP +820\n새 세계 기록 · ‘조합 열쇠 장부’ 해금",
			},
			"repeat_reward": {
				"canned_food": 8,
				"xp": 260,
				"summary": "장부 사본 회수 · 통조림 +8 · XP +260",
			},
			"lore": "조합 열쇠 장부 · 남대문 상인 조합\n마지막 장에는 상점 스물일곱 곳의 열쇠 번호가 적혀 있고, 그 아래 다른 필체로 한 줄이 덧붙어 있다. ‘전부 열어 두었음. 잠그지 말 것.’ 장부의 다음 인수인계처는 을지로 공방 거리였다.",
		},
	],
	# ── 을지로 지하구역 ──────────────────────────────────────────
	"euljiro_depths": [
		{
			"id": "euljiro_grid_note",
			"title": "끊긴 배전 간선",
			"type": "relay",
			"points": [
				{
					"step_title": "메인 임무 · 끊긴 배전 간선 0/4",
					"detail": "TAB 지도 확인 → 첫 배전반을 복구하세요",
					"label": "1번 배전반 복구",
					"map_label": "1번 배전반",
					"prop": "generator",
					"color": "#7fd0c8",
					"hold": 2.2,
					"distance": 36.0,
					"separation": 30.0,
					"complete_notice": "1번 배전반 복구 · 다음 간선 좌표 확보",
					"complete_monologue": [
						"배전반에 손으로 쓴 쪽지. ‘3구역까지만 살려 둘 것.’",
						"그 3구역이 어디인지, 이제 짐작이 간다.",
					],
				},
				{
					"step_title": "2번 배전반 복구 · 1/4",
					"detail": "긴 산업 통로 끝의 2번 배전반으로 이동하세요",
					"label": "2번 배전반 복구",
					"map_label": "2번 배전반",
					"prop": "generator",
					"color": "#7fd0c8",
					"hold": 2.2,
					"distance": 42.0,
					"separation": 34.0,
					"complete_notice": "2번 배전반 복구 · 간선 종단 좌표 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "euljiro_grid_note",
				"title": "배전 간선 종단 기록",
				"description": "간선 종단함에서 뜯어낸 기록입니다. 전기를 어디까지 살려 둘지 결정한 사람의 서명이 남아 있습니다.",
				"label": "간선 종단 기록 회수",
				"map_label": "간선 종단함",
				"prop": "convoy_cache",
				"color": "#e66a47",
				"hold": 3.6,
				"distance": 48.0,
				"separation": 36.0,
				"step_title": "종단 기록 회수 · 2/4",
				"detail": "간선 종단함에서 기록을 회수하세요 · 경보 주의",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "종단 기록 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "종단 기록 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"살려 둔 전기는 조명도, 통신도 아니었다. 전부 급수와 환기다.",
				"사람이 없는 도시에 누가 숨을 쉬라고 바람을 남겨 뒀나.",
			],
			"reward": {
				"canned_food": 24,
				"churu": 3,
				"components": {"rubber_gasket": 3},
				"xp": 900,
				"summary": "간선 종단 기록 해독 · 통조림 +24 · 츄르 +3 · 고무 패킹 +3 · XP +900",
			},
			"repeat_reward": {
				"canned_food": 9,
				"xp": 300,
				"summary": "종단 기록 사본 회수 · 통조림 +9 · XP +300",
			},
		},
		{
			"id": "euljiro_workshop_cast",
			"title": "공방 봉쇄 해제",
			"type": "defense",
			"points": [
				{
					"step_title": "메인 임무 · 공방 봉쇄 해제 0/3",
					"detail": "TAB 지도 확인 → 공방 봉쇄 제어반을 조작하세요",
					"label": "공방 봉쇄 제어반 조작",
					"map_label": "공방 봉쇄 제어반",
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
						"공방 안쪽 벽에 발자국이 층층이 남아 있다. 사람 것이 아니다.",
						"여기서 뭔가를 아주 오래, 아주 조심스럽게 먹이고 있었다.",
					],
				},
			],
			"recovery": {
				"id": "euljiro_workshop_cast",
				"title": "공방 주조 도면 뭉치",
				"description": "봉쇄가 풀린 공방에서 회수한 도면입니다. 무기 부품 사이에 자물쇠 부품 도면이 섞여 있습니다.",
				"label": "주조 도면 회수",
				"map_label": "공방 주조 도면",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.4,
				"step_title": "주조 도면 회수 · 2/3",
				"detail": "열린 공방 안쪽에서 도면을 회수하세요",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "주조 도면 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "주조 도면 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"도면 절반이 자물쇠다. 그런데 전부 ‘열림 고정’ 사양으로 그려져 있어.",
				"잠그려고 만든 게 아니라, 잠기지 않게 만들려고 애쓴 흔적이다.",
			],
			"reward": {
				"canned_food": 27,
				"churu": 3,
				"components": {"magazine_spring": 3},
				"xp": 1080,
				"summary": "주조 도면 해독 · 통조림 +27 · 츄르 +3 · 탄창 스프링 +3 · XP +1080",
			},
			"repeat_reward": {
				"canned_food": 10,
				"xp": 340,
				"summary": "도면 사본 회수 · 통조림 +10 · XP +340",
			},
		},
		{
			"id": "euljiro_control_log",
			"title": "지하 관제실",
			"type": "keyed",
			"points": [
				{
					"step_title": "메인 임무 · 지하 관제실 0/3",
					"detail": "TAB 지도 확인 → 적이 몰린 구역에서 관제 인증키를 확보하세요",
					"label": "관제 인증키 확보",
					"map_label": "관제 인증키 · 적 밀집",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 2.8,
					"distance": 36.0,
					"separation": 28.0,
					"role": "key",
					"guards": 5,
					"complete_notice": "관제 인증키 확보 · 지하 관제실이 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "euljiro_control_log",
				"title": "지하 관제실 격리 로그",
				"description": "관제실 콘솔에서 통째로 뽑아낸 로그입니다. 격리 명령의 발신지가 바깥이었다는 사실이 시각까지 기록되어 있습니다.",
				"label": "격리 로그 회수",
				"map_label": "지하 관제실 · 잠김",
				"prop": "manifest_terminal",
				"color": "#e66a47",
				"hold": 4.2,
				"distance": 46.0,
				"separation": 34.0,
				"step_title": "관제실 진입 · 1/3",
				"detail": "인증키로 관제실을 열고 격리 로그를 회수하세요 · 경보 주의",
				"role": "locked",
				"locked_reason": "관제 인증키가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "격리 로그 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "격리 로그 확보 · 탈출하면 다음 목적지가 드러납니다",
			"carry_monologue": [
				"관제실 로그: 격리 명령은 바깥에서 내려왔다. 안쪽 사람들은 나가려 했어.",
				"그러니까 도망친 게 아니다. 갇힌 거다. 마지막 한 명까지.",
			],
			"reward": {
				"canned_food": 30,
				"churu": 4,
				"components": {"scope_lens": 3},
				# 쉘터 Tier 4 확장 키 — 관제실 로그에 딸려 온 배전 도면. 첫 회수에만.
				"progression_items": {"euljiro_grid_schematic": 1},
				"xp": 1350,
				"summary": "격리 로그 해독 · 통조림 +30 · 츄르 +4 · 스코프 렌즈 +3 · XP +1350\n새 세계 기록 · ‘외부 발신 격리 명령’ 해금",
			},
			"repeat_reward": {
				"canned_food": 11,
				"xp": 420,
				"summary": "로그 사본 회수 · 통조림 +11 · XP +420",
			},
			"lore": "외부 발신 격리 명령 · 을지로 지하 관제실\n격리 명령의 발신지는 도시 안이 아니었다. 안쪽 관제사는 스물두 번 회신했고, 마지막 회신은 한 문장이었다. ‘여기 사람 있다.’ 그 다음 줄부터 로그는 용산 봉쇄선 주파수로 넘어간다.",
		},
	],
	# ── 용산 봉쇄선 ──────────────────────────────────────────────
	"yongsan_blockade": [
		{
			"id": "yongsan_checkpoint_log",
			"title": "검문 기록 추적",
			"type": "relay",
			"points": [
				{
					"step_title": "메인 임무 · 검문 기록 추적 0/4",
					"detail": "TAB 지도 확인 → 첫 검문소 단말을 조사하세요",
					"label": "1번 검문소 단말 조사",
					"map_label": "1번 검문소 단말",
					"prop": "manifest_terminal",
					"color": "#c8d47a",
					"hold": 2.2,
					"distance": 40.0,
					"separation": 34.0,
					"complete_notice": "검문 기록 일부 복원 · 다음 검문소 좌표 확보",
					"complete_monologue": [
						"검문 기록의 마지막 줄, 통과 인원 0. 대신 반출 상자 스물일곱.",
						"그 상자가 뭘 담았는지는 안 적혀 있다. 적을 필요가 없었겠지.",
					],
				},
				{
					"step_title": "2번 검문소 단말 · 1/4",
					"detail": "봉쇄 간선 반대편의 2번 검문소로 이동하세요 · 장거리 사선 주의",
					"label": "2번 검문소 단말 조사",
					"map_label": "2번 검문소 단말",
					"prop": "manifest_terminal",
					"color": "#c8d47a",
					"hold": 2.2,
					"distance": 48.0,
					"separation": 40.0,
					"complete_notice": "검문 기록 복원 · 반출 상자 보관소 좌표 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "yongsan_checkpoint_log",
				"title": "봉쇄선 반출 기록함",
				"description": "검문 기록을 모아 둔 반출 기록함입니다. 스물일곱 개의 상자가 어디로 갔는지가 적혀 있습니다.",
				"label": "반출 기록함 회수",
				"map_label": "반출 기록함",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.8,
				"distance": 54.0,
				"separation": 42.0,
				"step_title": "반출 기록 회수 · 2/4",
				"detail": "보관소에서 반출 기록함을 회수하세요 · 경보 주의",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "반출 기록함 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "반출 기록 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"상자 스물일곱 개의 도착지가 전부 다르다. 그리고 전부 도시 안이다.",
				"밖으로 내보낸 게 아니었어. 도시 안쪽에 나눠 심은 거다.",
			],
			"reward": {
				"canned_food": 34,
				"churu": 4,
				"components": {"rubber_gasket": 4},
				"xp": 1650,
				"summary": "반출 기록 해독 · 통조림 +34 · 츄르 +4 · 고무 패킹 +4 · XP +1650",
			},
			"repeat_reward": {
				"canned_food": 12,
				"xp": 520,
				"summary": "반출 기록 사본 회수 · 통조림 +12 · XP +520",
			},
		},
		{
			"id": "yongsan_magazine_order",
			"title": "탄약고 사수",
			"type": "defense",
			"points": [
				{
					"step_title": "메인 임무 · 탄약고 사수 0/3",
					"detail": "TAB 지도 확인 → 탄약고 봉인 장치를 해제하세요",
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
						"탄약고를 지키라는 명령은 아직 살아 있었다. 명령을 내린 자는 없는데.",
						"죽은 명령이 산 것들을 움직인다. 이 도시의 규칙이다.",
					],
				},
			],
			"recovery": {
				"id": "yongsan_magazine_order",
				"title": "봉쇄 사수 명령서",
				"description": "탄약고 안쪽 금고에서 회수한 명령서입니다. 사수 대상이 무기가 아니라 좌표 목록으로 적혀 있습니다.",
				"label": "사수 명령서 회수",
				"map_label": "사수 명령서",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.6,
				"step_title": "명령서 회수 · 2/3",
				"detail": "열린 탄약고 안쪽에서 명령서를 회수하세요",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "명령서 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "사수 명령서 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"사수 대상 1번부터 27번까지. 무기 이름은 한 줄도 없다. 전부 주소다.",
				"군인들이 마지막까지 총을 겨눈 방향은 바깥이 아니었다.",
			],
			"reward": {
				"canned_food": 38,
				"churu": 5,
				"components": {"magazine_spring": 4},
				"xp": 1980,
				"summary": "사수 명령서 해독 · 통조림 +38 · 츄르 +5 · 탄창 스프링 +4 · XP +1980",
			},
			"repeat_reward": {
				"canned_food": 14,
				"xp": 620,
				"summary": "명령서 사본 회수 · 통조림 +14 · XP +620",
			},
		},
		{
			"id": "yongsan_command_map",
			"title": "봉쇄 사령부 금고",
			"type": "keyed",
			"points": [
				{
					"step_title": "메인 임무 · 봉쇄 사령부 금고 0/3",
					"detail": "TAB 지도 확인 → 정예 병력이 낀 구역에서 사령부 인증표를 확보하세요",
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
				"title": "보호소 배치도",
				"description": "사령부 금고에서 회수한 배치도입니다. 무기 배치가 아니라, 스물일곱 곳의 문 위치가 그려져 있습니다.",
				"label": "사령부 금고 개방",
				"map_label": "사령부 금고 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 4.6,
				"distance": 48.0,
				"separation": 36.0,
				"step_title": "사령부 금고 개방 · 1/3",
				"detail": "인증표로 금고를 열고 배치도를 회수하세요 · 경보 주의",
				"role": "locked",
				"locked_reason": "사령부 인증표가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "배치도 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "배치도 확보 · 탈출하면 다음 목적지가 드러납니다",
			"carry_monologue": [
				"사령부 금고에는 무기 대신 지도가 있었다. 보호소 스물일곱 곳의 지도.",
				"군인들이 마지막까지 지킨 건 봉쇄선이 아니라 이 종이였다.",
			],
			"reward": {
				"canned_food": 42,
				"churu": 6,
				"components": {"scope_lens": 4},
				# 쉘터 Tier 5 확장 키 — 사령부 금고의 통제 키. 첫 회수에만.
				"progression_items": {"yongsan_control_key": 1},
				"xp": 2400,
				"summary": "보호소 배치도 해독 · 통조림 +42 · 츄르 +6 · 스코프 렌즈 +4 · XP +2400\n새 세계 기록 · ‘보호소 27 배치도’ 해금",
			},
			"repeat_reward": {
				"canned_food": 15,
				"xp": 760,
				"summary": "배치도 사본 회수 · 통조림 +15 · XP +760",
			},
			"lore": "보호소 27 배치도 · 용산 봉쇄 사령부\n지도에는 스물일곱 개의 점이 찍혀 있고, 점마다 개방 시각이 적혀 있다. 마지막 점의 개방 시각은 봉쇄가 완성된 시각보다 사십 분 뒤다. 누군가 봉쇄선 안에 남아, 문을 하나 더 열고 나서 남산으로 올라갔다.",
		},
	],
	# ── 남산 오염 핵심부 ─────────────────────────────────────────
	"namsan_core": [
		{
			"id": "namsan_survey_data",
			"title": "오염 관측 삼각측량",
			"type": "relay",
			"points": [
				{
					"step_title": "메인 임무 · 오염 관측 삼각측량 0/4",
					"detail": "TAB 지도 확인 → 첫 관측기를 회수하세요",
					"label": "1번 관측기 회수",
					"map_label": "1번 오염 관측기",
					"prop": "convoy_cache",
					"color": "#a8d488",
					"hold": 2.2,
					"distance": 42.0,
					"separation": 36.0,
					"complete_notice": "1번 관측 자료 확보 · 다음 관측기 좌표 확보",
					"complete_monologue": [
						"오염 수치는 거짓말이었다. 관측기 셋이 전부 같은 손으로 조작돼 있다.",
						"사람은 못 들어오게. 우리는 들어올 수 있게.",
					],
				},
				{
					"step_title": "2번 관측기 회수 · 1/4",
					"detail": "개활지를 짧게 건너 2번 관측기로 이동하세요",
					"label": "2번 관측기 회수",
					"map_label": "2번 오염 관측기",
					"prop": "convoy_cache",
					"color": "#a8d488",
					"hold": 2.2,
					"distance": 50.0,
					"separation": 40.0,
					"complete_notice": "2번 관측 자료 확보 · 마지막 관측기 좌표 확보",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namsan_survey_data",
				"title": "오염 관측 원본 자료",
				"description": "세 관측기를 맞춰야 읽히는 원본 자료입니다. 조작된 수치와 실제 수치가 나란히 남아 있습니다.",
				"label": "원본 관측 자료 회수",
				"map_label": "3번 관측기 · 원본 자료",
				"prop": "pharmacy_cache",
				"color": "#e66a47",
				"hold": 3.8,
				"distance": 56.0,
				"separation": 44.0,
				"step_title": "원본 자료 회수 · 2/4",
				"detail": "마지막 관측기에서 원본 자료를 회수하세요 · 경보 주의",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/4",
			"carry_detail": "관측 자료 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "원본 자료 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"실제 수치는 종로보다 낮다. 남산은 처음부터 위험한 곳이 아니었어.",
				"위험하다고 적어 둔 사람은, 여기에 뭔가를 숨기고 싶었던 거다.",
			],
			"reward": {
				"canned_food": 46,
				"churu": 6,
				"components": {"rubber_gasket": 5},
				"xp": 2800,
				"summary": "원본 관측 자료 해독 · 통조림 +46 · 츄르 +6 · 고무 패킹 +5 · XP +2800",
			},
			"repeat_reward": {
				"canned_food": 16,
				"xp": 880,
				"summary": "관측 자료 사본 회수 · 통조림 +16 · XP +880",
			},
		},
		{
			"id": "namsan_decon_key",
			"title": "제염소 재가동",
			"type": "defense",
			"points": [
				{
					"step_title": "메인 임무 · 제염소 재가동 0/3",
					"detail": "TAB 지도 확인 → 제염소 가동 제어반을 조작하세요",
					"label": "제염소 가동 제어반 조작",
					"map_label": "제염소 가동 제어반",
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
						"제염소가 돈다. 삼백 밤 동안 아무도 없이 예약 가동된 채로.",
						"떠난 사람들은 우리가 돌아올 날짜까지 계산해 뒀다.",
					],
				},
			],
			"recovery": {
				"id": "namsan_decon_key",
				"title": "관제탑 최종 인증키",
				"description": "제염 라인이 살아나야 열리는 보관함에서 회수한 인증키입니다. 관제탑 최상층으로 가는 마지막 문을 엽니다.",
				"label": "최종 인증키 회수",
				"map_label": "관제탑 최종 인증키",
				"prop": "military_cache",
				"color": "#e66a47",
				"hold": 3.8,
				"step_title": "인증키 회수 · 2/3",
				"detail": "가동된 제염소 안쪽에서 인증키를 회수하세요",
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "최종 인증키 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "최종 인증키 확보 · 탈출 시 특별 보상",
			"carry_monologue": [
				"보관함 예약 개방일은 오늘이었다. 하루도 안 틀렸어.",
				"우리를 기다린 게 아니라, 우리가 올 걸 알고 맞춰 둔 거다.",
			],
			"reward": {
				"canned_food": 52,
				"churu": 7,
				"components": {"magazine_spring": 5},
				"xp": 3400,
				"summary": "최종 인증키 확보 · 통조림 +52 · 츄르 +7 · 탄창 스프링 +5 · XP +3400",
			},
			"repeat_reward": {
				"canned_food": 18,
				"xp": 1050,
				"summary": "예비 인증키 회수 · 통조림 +18 · XP +1050",
			},
		},
		{
			"id": "namsan_final_record",
			"title": "최종 격리 관제탑",
			"type": "keyed",
			"points": [
				{
					"step_title": "메인 임무 · 최종 격리 관제탑 0/3",
					"detail": "TAB 지도 확인 → 최상층 진입 코드를 확보하세요",
					"label": "최상층 진입 코드 확보",
					"map_label": "최상층 진입 코드 · 중무장 경계",
					"prop": "military_cache",
					"color": "#e2c15f",
					"hold": 3.2,
					"distance": 40.0,
					"separation": 32.0,
					"role": "key",
					"guards": 7,
					"complete_notice": "진입 코드 확보 · 관제탑 최상층이 열립니다",
					"complete_monologue": [],
				},
			],
			"recovery": {
				"id": "namsan_final_record",
				"title": "관제탑 최종 기록",
				"description": "관제탑 최상층에서 회수한 마지막 기록입니다. 이 도시에서 인간이 남긴 마지막 문장이 적혀 있습니다.",
				"label": "최종 기록 회수",
				"map_label": "관제탑 최상층 · 잠김",
				"prop": "sealed_cargo",
				"color": "#e66a47",
				"hold": 5.0,
				"distance": 50.0,
				"separation": 38.0,
				"step_title": "최상층 진입 · 1/3",
				"detail": "진입 코드로 최상층을 열고 최종 기록을 회수하세요 · 경보 주의",
				"role": "locked",
				"locked_reason": "최상층 진입 코드가 필요하다",
				"alarm": true,
			},
			"carry_title": "탈출 필요 · 3/3",
			"carry_detail": "최종 기록 운반 중 · 가장 가까운 하수구로 이동하세요",
			"carry_notice": "최종 기록 확보 · 이 도시의 마지막 문장을 들고 나가라",
			"carry_monologue": [
				"관제탑 마지막 기록. ‘우리는 나가지 못한다. 문은 열어 둔다.’",
				"스물일곱 개의 문. 그 뒤에 뭐가 남아 있는지는, 이제 내가 확인할 차례다.",
			],
			"reward": {
				"canned_food": 60,
				"churu": 9,
				"components": {"scope_lens": 5, "magazine_spring": 3},
				"xp": 4200,
				"summary": "관제탑 최종 기록 해독 · 통조림 +60 · 츄르 +9 · 스코프 렌즈 +5 · 탄창 스프링 +3 · XP +4200\n새 세계 기록 · ‘문은 열어 둔다’ 해금",
			},
			"repeat_reward": {
				"canned_food": 20,
				"xp": 1300,
				"summary": "최종 기록 사본 회수 · 통조림 +20 · XP +1300",
			},
			"lore": "문은 열어 둔다 · 남산 관제탑 최종 기록\n인간은 도망치지 않았다. 바깥에서 내려온 명령이 도시를 잠갔고, 안쪽 사람들은 나가지 못했다. 그들이 마지막 사십 분 동안 한 일은 대피가 아니라 개방이었다 — 보호소 스물일곱 곳의 문을 전부 열어 두는 것. 기록의 마지막 줄은 이렇게 끝난다. ‘우리는 나가지 못한다. 문은 열어 둔다. 누가 됐든, 들어와서 살아라.’",
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
