# 전투 효과음 뱅크 — 코드 합성 WAV + 공용 플레이어 풀.
#
# 외부 에셋 없이 전부 AudioStreamWAV를 코드로 만든다(웹·모바일 빌드에서도 동일하게
# 난다). 픽셀 아트 톤에 맞춘 90년대 게임 느낌의 스타일라이즈드 사운드가 목표다.
#
# 사용 — 호출부는 preload 상수로 받아 static 헬퍼만 부른다:
#   const SFX := preload("res://scripts/sfx_bank.gd")
#   SFX.play("rifle_shot")                        # 2D(플레이어 자신의 소리·UI)
#   SFX.play("hit_enemy", enemy.global_position)  # 3D 위치 감쇠(멀면 작게)
#   SFX.play_weapon_shot("ak47", position)        # 무기 id → 구경별 총성 매핑
#
# 오토로드가 아니다 — 오토로드 식별자는 --script 테스트 콜드 스타트의 컴파일
# 연쇄를 깨뜨린다. kill_impact.gd와 같은 "static 헬퍼 + root 아래 지연 생성
# 노드" 패턴이라 씬 전환에도 플레이어 풀이 살아남고 어떤 씬에서도 같은 소리가 난다.
#
# 클리핑 방지: 같은 종류 연속 재생은 피치 ±8% 랜덤, 풀 상한(가장 오래된 것부터
# 재사용), 같은 프레임 중복 억제, 종류별 최소 간격(실시간 ms — 500fps 환경이라
# 프레임 수 기반 계산은 쓰지 않는다).

const MIX_RATE := 22050
const PLAYER_POOL_SIZE := 12
const PLAYER_3D_POOL_SIZE := 12
const BANK_NODE_NAME := "SfxBank"
const BUS_NAMES := ["Master", "SFX", "UI", "Music", "Ambient"]
# 정규화 목표 피크 — 생성 단계에서 이 값 이하로 눌러 두므로 클리핑이 없다.
const TARGET_PEAK := 0.9

# 종류별 정의: 버스 / 기본 볼륨 / 피치 지터 / 최소 재생 간격(ms) / 3D 감쇠.
const SOUNDS := {
	# ── 총성 3구경 ──
	"pistol_shot": {"bus": "SFX", "volume_db": -5.0, "pitch_jitter": 0.08, "min_interval_ms": 0, "unit_size": 8.0, "max_distance": 60.0},
	"rifle_shot": {"bus": "SFX", "volume_db": -3.0, "pitch_jitter": 0.08, "min_interval_ms": 0, "unit_size": 9.0, "max_distance": 70.0},
	"shotgun_shot": {"bus": "SFX", "volume_db": -1.5, "pitch_jitter": 0.06, "min_interval_ms": 0, "unit_size": 10.0, "max_distance": 80.0},
	# ── 명중 ──
	"hit_enemy": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.08, "min_interval_ms": 0, "unit_size": 7.0, "max_distance": 40.0},
	"hit_player": {"bus": "SFX", "volume_db": -4.5, "pitch_jitter": 0.06, "min_interval_ms": 60, "unit_size": 7.0, "max_distance": 40.0},
	# ── 근접 ──
	"melee_swing": {"bus": "SFX", "volume_db": -9.0, "pitch_jitter": 0.08, "min_interval_ms": 0, "unit_size": 6.0, "max_distance": 30.0},
	"melee_hit": {"bus": "SFX", "volume_db": -5.0, "pitch_jitter": 0.08, "min_interval_ms": 0, "unit_size": 7.0, "max_distance": 40.0},
	# ── 경보 ──
	"alert_sting": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.03, "min_interval_ms": 250, "unit_size": 8.0, "max_distance": 60.0},
	"reinforce_alarm": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.0, "min_interval_ms": 400, "unit_size": 8.0, "max_distance": 60.0},
	# ── 탄약·장전 ──
	"reload_start": {"bus": "SFX", "volume_db": -9.0, "pitch_jitter": 0.06, "min_interval_ms": 80, "unit_size": 6.0, "max_distance": 30.0},
	"reload_end": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.06, "min_interval_ms": 80, "unit_size": 6.0, "max_distance": 30.0},
	"dry_fire": {"bus": "SFX", "volume_db": -9.0, "pitch_jitter": 0.06, "min_interval_ms": 140, "unit_size": 6.0, "max_distance": 30.0},
	# ── 루팅·UI ──
	"pickup": {"bus": "SFX", "volume_db": -10.0, "pitch_jitter": 0.08, "min_interval_ms": 60, "unit_size": 6.0, "max_distance": 30.0},
	"container_open": {"bus": "SFX", "volume_db": -9.0, "pitch_jitter": 0.06, "min_interval_ms": 120, "unit_size": 6.0, "max_distance": 30.0},
	"ui_tap": {"bus": "UI", "volume_db": -13.0, "pitch_jitter": 0.05, "min_interval_ms": 40, "unit_size": 6.0, "max_distance": 30.0},
	"toast_pop": {"bus": "UI", "volume_db": -17.0, "pitch_jitter": 0.06, "min_interval_ms": 120, "unit_size": 6.0, "max_distance": 30.0},
	# 작업대 강화 성공 — 금속 "챙" 한 번(연타 0.11s 간격이라 최소 간격은 짧게).
	"enhance_clink": {"bus": "UI", "volume_db": -12.0, "pitch_jitter": 0.05, "min_interval_ms": 40, "unit_size": 6.0, "max_distance": 30.0},
	# 전투 숙련도 패키지 — 예고·약점·엄폐 소리.
	"grenade_whistle": {"bus": "SFX", "volume_db": -7.0, "pitch_jitter": 0.04, "min_interval_ms": 200, "unit_size": 8.0, "max_distance": 60.0},
	"crit_hit": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.06, "min_interval_ms": 0, "unit_size": 7.0, "max_distance": 40.0},
	"cover_enter": {"bus": "UI", "volume_db": -14.0, "pitch_jitter": 0.03, "min_interval_ms": 150, "unit_size": 6.0, "max_distance": 30.0},
	"cover_exit": {"bus": "UI", "volume_db": -15.0, "pitch_jitter": 0.03, "min_interval_ms": 150, "unit_size": 6.0, "max_distance": 30.0},
}

static var bank_node: Node
static var players: Array[AudioStreamPlayer] = []
static var players_3d: Array[AudioStreamPlayer3D] = []
static var player_cursor := 0
static var player_3d_cursor := 0
static var streams: Dictionary = {}
static var random := RandomNumberGenerator.new()
static var last_play_frame: Dictionary = {}
static var last_play_msec: Dictionary = {}
# 프로브·테스트용 카운터 — "어떤 소리가 몇 번 요청됐는지".
static var play_counts: Dictionary = {}
static var total_play_count := 0
static var last_played_id := ""


# ── 재생 ───────────────────────────────────────────────────────


static func play(id: String, world_position: Vector3 = Vector3.INF, volume_offset_db: float = 0.0, pitch: float = 1.0) -> bool:
	# world_position을 주면 3D 플레이어(거리 감쇠·패닝), 없으면 2D 플레이어.
	# 반환값은 실제로 재생을 걸었는지(중복 억제·풀 없음이면 false).
	if not SOUNDS.has(id):
		push_warning("SfxBank: 알 수 없는 효과음 id '%s'" % id)
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var now_msec := Time.get_ticks_msec()
	var frame := Engine.get_process_frames()
	var definition: Dictionary = SOUNDS[id]
	# 같은 프레임 중복(산탄 8펠릿 동시 명중 등)과 종류별 최소 간격은 한 번만 울린다.
	if int(last_play_frame.get(id, -1)) == frame:
		return false
	var min_interval := int(definition.get("min_interval_ms", 0))
	if min_interval > 0 and now_msec - int(last_play_msec.get(id, -100000)) < min_interval:
		return false
	_ensure_bank(tree)
	var stream := get_stream(id)
	if stream == null:
		return false
	var jitter := float(definition.get("pitch_jitter", 0.0))
	var pitch_scale := pitch * (random.randf_range(1.0 - jitter, 1.0 + jitter) if jitter > 0.0 else 1.0)
	var volume_db := float(definition.get("volume_db", 0.0)) + volume_offset_db
	var bus := str(definition.get("bus", "SFX"))
	var positional := world_position.is_finite()
	if positional:
		if players_3d.is_empty():
			return false
		var player_3d := _acquire_3d_player()
		if player_3d == null:
			return false
		player_3d.stream = stream
		player_3d.bus = bus
		player_3d.volume_db = volume_db
		player_3d.pitch_scale = pitch_scale
		player_3d.unit_size = float(definition.get("unit_size", 8.0))
		player_3d.max_distance = float(definition.get("max_distance", 50.0))
		player_3d.global_position = world_position
		player_3d.play()
	else:
		if players.is_empty():
			return false
		var player := _acquire_player()
		if player == null:
			return false
		player.stream = stream
		player.bus = bus
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()
	last_play_frame[id] = frame
	last_play_msec[id] = now_msec
	play_counts[id] = int(play_counts.get(id, 0)) + 1
	total_play_count += 1
	last_played_id = id
	return true


static func play_weapon_shot(weapon_id: String, world_position: Vector3 = Vector3.INF, volume_offset_db: float = 0.0) -> bool:
	# WeaponSystem.WEAPONS의 무기 id → 구경별 총성. 적·플레이어 공용.
	return play(shot_sound_for_weapon(weapon_id), world_position, volume_offset_db, shot_pitch_for_weapon(weapon_id))


static func shot_sound_for_weapon(weapon_id: String) -> String:
	match weapon_id:
		"m1911", "mp5":
			# 권총탄(.45 / 9mm) — 짧고 높고 탁한 소리. MP5는 피치만 살짝 올린다.
			return "pistol_shot"
		"double_barrel", "pump_shotgun", "rocket_launcher":
			# 산탄 — 넓게 퍼지는 저음 + 긴 꼬리. 로켓 발사는 같은 소리를 낮춰 쓴다.
			return "shotgun_shot"
		_:
			# 7.62 소총(AK) — 묵직한 저음 바디. 미지정 무기의 기본값.
			return "rifle_shot"


static func shot_pitch_for_weapon(weapon_id: String) -> float:
	match weapon_id:
		"mp5": return 1.1
		"rocket_launcher": return 0.72
		_: return 1.0


static func get_play_count(id: String) -> int:
	return int(play_counts.get(id, 0))


static func reset_play_counts() -> void:
	play_counts.clear()
	total_play_count = 0
	last_played_id = ""


static func sound_ids() -> Array:
	var ids := SOUNDS.keys()
	ids.sort()
	return ids


static func warm_up() -> void:
	# 씬 시작 시 전부 미리 생성 — 첫 총성에서 합성 루프가 프레임을 잡지 않게.
	for id in SOUNDS:
		get_stream(str(id))


# ── 버스 ───────────────────────────────────────────────────────


static func ensure_buses() -> void:
	# default_bus_layout.tres가 Master/SFX/UI/Music/Ambient를 정의하지만,
	# 레이아웃이 없는 환경에서도 버스 이름이 반드시 존재하게 런타임에 보강한다.
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


static func set_bus_volume_percent(bus_name: String, percent: float) -> void:
	# 0~100 슬라이더 값 → dB. 0은 -inf 대신 사실상 무음(-80dB)으로 고정한다.
	ensure_buses()
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var linear := clampf(percent, 0.0, 100.0) / 100.0
	AudioServer.set_bus_volume_db(index, linear_to_db(linear) if linear > 0.001 else -80.0)


# ── 플레이어 풀 ────────────────────────────────────────────────


static func _ensure_bank(tree: SceneTree) -> void:
	if is_instance_valid(bank_node) and not players.is_empty() and not players_3d.is_empty():
		return
	ensure_buses()
	players.clear()
	players_3d.clear()
	bank_node = tree.root.get_node_or_null(BANK_NODE_NAME)
	if bank_node == null:
		bank_node = Node.new()
		bank_node.name = BANK_NODE_NAME
		# 일시정지 중 UI 탭 소리는 나야 한다 — 풀은 항상 처리된다.
		bank_node.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(bank_node)
	for child in bank_node.get_children():
		if child is AudioStreamPlayer3D:
			players_3d.append(child)
		elif child is AudioStreamPlayer:
			players.append(child)
	while players.size() < PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx2D_%d" % players.size()
		player.bus = "SFX"
		bank_node.add_child(player)
		players.append(player)
	while players_3d.size() < PLAYER_3D_POOL_SIZE:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.name = "Sfx3D_%d" % players_3d.size()
		player_3d.bus = "SFX"
		player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		bank_node.add_child(player_3d)
		players_3d.append(player_3d)


static func _acquire_player() -> AudioStreamPlayer:
	# 쉬는 플레이어 우선, 없으면 가장 오래된 것부터 재사용(풀 상한 = 동시 재생 상한).
	var count := players.size()
	for offset in count:
		var candidate := players[(player_cursor + offset) % count]
		if not is_instance_valid(candidate):
			_invalidate_bank()
			return null
		if not candidate.playing:
			player_cursor = (player_cursor + offset + 1) % count
			return candidate
	var stolen := players[player_cursor]
	player_cursor = (player_cursor + 1) % count
	stolen.stop()
	return stolen


static func _acquire_3d_player() -> AudioStreamPlayer3D:
	var count := players_3d.size()
	for offset in count:
		var candidate := players_3d[(player_3d_cursor + offset) % count]
		if not is_instance_valid(candidate):
			_invalidate_bank()
			return null
		if not candidate.playing:
			player_3d_cursor = (player_3d_cursor + offset + 1) % count
			return candidate
	var stolen := players_3d[player_3d_cursor]
	player_3d_cursor = (player_3d_cursor + 1) % count
	stolen.stop()
	return stolen


static func _invalidate_bank() -> void:
	# 누군가 뱅크 노드를 지웠다면 다음 호출에서 재생성한다.
	bank_node = null
	players.clear()
	players_3d.clear()


# ── 합성 ───────────────────────────────────────────────────────


static func get_stream(id: String) -> AudioStreamWAV:
	if streams.has(id):
		return streams[id]
	if not SOUNDS.has(id):
		return null
	var samples := _synthesize(id)
	var stream := _encode(samples)
	streams[id] = stream
	return stream


static func _synthesize(id: String) -> PackedFloat32Array:
	match id:
		"pistol_shot": return _synth_pistol_shot()
		"rifle_shot": return _synth_rifle_shot()
		"shotgun_shot": return _synth_shotgun_shot()
		"hit_enemy": return _synth_hit_enemy()
		"hit_player": return _synth_hit_player()
		"melee_swing": return _synth_melee_swing()
		"melee_hit": return _synth_melee_hit()
		"alert_sting": return _synth_alert_sting()
		"reinforce_alarm": return _synth_reinforce_alarm()
		"reload_start": return _synth_reload_start()
		"reload_end": return _synth_reload_end()
		"dry_fire": return _synth_dry_fire()
		"pickup": return _synth_pickup()
		"container_open": return _synth_container_open()
		"ui_tap": return _synth_ui_tap()
		"toast_pop": return _synth_toast_pop()
		"enhance_clink": return _synth_enhance_clink()
		"grenade_whistle": return _synth_grenade_whistle()
		"crit_hit": return _synth_crit_hit()
		"cover_enter": return _synth_cover_enter()
		"cover_exit": return _synth_cover_exit()
	return PackedFloat32Array()


static func _encode(samples: PackedFloat32Array) -> AudioStreamWAV:
	# 피크 정규화(TARGET_PEAK) 후 16비트 PCM — 생성 단계에서 클리핑을 원천 차단.
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	var gain := TARGET_PEAK / peak if peak > 0.0001 else 1.0
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in samples.size():
		var encoded := int(clampf(samples[index] * gain, -1.0, 1.0) * 32767.0)
		data[index * 2] = encoded & 0xff
		data[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _new_buffer(duration: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(MIX_RATE * duration))
	return buffer


static func _rng(seed_value: int) -> RandomNumberGenerator:
	# 시드 고정 — 같은 id는 매 실행 똑같은 파형(테스트 결정성).
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


static func _synth_pistol_shot() -> PackedFloat32Array:
	# 권총 — 짧고 높고 탁. 날카로운 노이즈 스냅 + 1.4kHz 크랙 + 얕은 바디, 짧은 슬랩.
	var duration := 0.17
	var buffer := _new_buffer(duration)
	var rng := _rng(11001)
	var low_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.72
		var snap := low_pass * exp(-time * 62.0)
		var crack := sin(TAU * 1400.0 * time * (1.0 - time * 1.4)) * exp(-time * 44.0) * 0.55
		var body := sin(TAU * 230.0 * time * (1.0 - time * 1.2)) * exp(-time * 28.0) * 0.5
		var slap := 0.0
		if time > 0.04:
			slap = rng.randf_range(-1.0, 1.0) * exp(-(time - 0.04) * 40.0) * 0.22
		buffer[index] = tanh((snap * 1.1 + crack + body + slap) * 1.5)
	return buffer


static func _synth_rifle_shot() -> PackedFloat32Array:
	# 7.62 소총 — 묵직한 저음 바디(95Hz→피치 하강) + 중역 크랙 + 저역 통과 꼬리.
	# 연사 시 풀에서 겹쳐 울린다.
	var duration := 0.34
	var buffer := _new_buffer(duration)
	var rng := _rng(22002)
	var low_pass := 0.0
	var tail_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.55
		tail_pass += (noise - tail_pass) * 0.12
		var blast := low_pass * exp(-time * 30.0)
		var body := sin(TAU * 95.0 * time * (1.0 - time * 0.6)) * exp(-time * 11.0) * 0.95
		var crack := sin(TAU * 620.0 * time) * exp(-time * 24.0) * 0.45
		var tail := tail_pass * exp(-maxf(0.0, time - 0.03) * 7.5) * 0.7
		var slap := 0.0
		if time > 0.06:
			slap += rng.randf_range(-1.0, 1.0) * exp(-(time - 0.06) * 22.0) * 0.16
		if time > 0.13:
			slap += rng.randf_range(-1.0, 1.0) * exp(-(time - 0.13) * 16.0) * 0.1
		buffer[index] = tanh((blast * 1.0 + body + crack + tail + slap) * 1.4)
	return buffer


static func _synth_shotgun_shot() -> PackedFloat32Array:
	# 더블배럴 — 넓게 퍼지는 저음 폭발 + 2차 붐 + 긴 잔향 꼬리(슬랩 3겹).
	var duration := 0.6
	var buffer := _new_buffer(duration)
	var rng := _rng(33003)
	var wide_pass := 0.0
	var tail_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# 소총보다 어두운 저역 통과 — 산탄은 "넓고 묵직"해야지 날카로우면 안 된다.
		wide_pass += (noise - wide_pass) * 0.13
		tail_pass += (noise - tail_pass) * 0.06
		var blast := wide_pass * exp(-time * 18.0) * 1.1
		var body := sin(TAU * 70.0 * time * (1.0 - time * 0.35)) * exp(-time * 6.0) * 1.0
		var boom := sin(TAU * 118.0 * time) * exp(-time * 12.0) * 0.5
		# 긴 꼬리 — 느린 감쇠로 0.3초 뒤에도 웅웅 남는다.
		var tail := tail_pass * exp(-maxf(0.0, time - 0.05) * 3.2) * 1.3
		var slap := 0.0
		if time > 0.08:
			slap += wide_pass * exp(-(time - 0.08) * 14.0) * 0.3
		if time > 0.17:
			slap += wide_pass * exp(-(time - 0.17) * 11.0) * 0.22
		if time > 0.29:
			slap += wide_pass * exp(-(time - 0.29) * 9.0) * 0.16
		buffer[index] = tanh((blast + body + boom + tail + slap) * 1.35)
	return buffer


static func _synth_hit_enemy() -> PackedFloat32Array:
	# 적 피격 — 둔탁한 살 소리. 140→80Hz 하강 둔음 + 저역 통과 노이즈 퍽.
	var duration := 0.13
	var buffer := _new_buffer(duration)
	var rng := _rng(44004)
	var low_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.22
		var thud := sin(TAU * 140.0 * time * (1.0 - time * 3.2)) * exp(-time * 30.0)
		var smack := low_pass * exp(-time * 48.0) * 0.9
		buffer[index] = tanh((thud * 1.1 + smack) * 1.5)
	return buffer


static func _synth_hit_player() -> PackedFloat32Array:
	# 플레이어 피격 — 적 피격보다 낮고 "윽" 하는 중역 톤이 얹힌다(비네트와 동기).
	var duration := 0.2
	var buffer := _new_buffer(duration)
	var rng := _rng(55005)
	var low_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.18
		var thud := sin(TAU * 105.0 * time * (1.0 - time * 1.8)) * exp(-time * 20.0)
		var tone := sin(TAU * 330.0 * time * (1.0 - time * 0.9)) * exp(-time * 18.0) * 0.45
		var smack := low_pass * exp(-time * 40.0) * 0.7
		buffer[index] = tanh((thud * 1.0 + tone + smack) * 1.4)
	return buffer


static func _synth_melee_swing() -> PackedFloat32Array:
	# 야구방망이 풀스윙 — 공기 가르는 스윕. 대역 통과 노이즈의 중심이 올라갔다
	# 내려오며 포락선은 사인 창(휙—).
	var duration := 0.24
	var buffer := _new_buffer(duration)
	var rng := _rng(66006)
	var low_pass := 0.0
	var high_pass_state := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var progress := time / duration
		var noise := rng.randf_range(-1.0, 1.0)
		# 스윕: 필터 계수를 시간에 따라 올렸다 내린다(중심 주파수 이동).
		var sweep := 0.08 + sin(progress * PI) * 0.3
		low_pass += (noise - low_pass) * sweep
		high_pass_state += (low_pass - high_pass_state) * 0.03
		var band := low_pass - high_pass_state
		var envelope := pow(sin(progress * PI), 1.6)
		buffer[index] = band * envelope * 1.3
	return buffer


static func _synth_melee_hit() -> PackedFloat32Array:
	# 방망이 명중 — 나무 둔탁음: 180Hz 몸통 + 620Hz 클릭 + 노이즈 크랙.
	var duration := 0.15
	var buffer := _new_buffer(duration)
	var rng := _rng(77007)
	var low_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.5
		var wood := sin(TAU * 180.0 * time * (1.0 - time * 1.5)) * exp(-time * 26.0)
		var click := sin(TAU * 620.0 * time) * exp(-time * 70.0) * 0.6
		var crack := low_pass * exp(-time * 55.0) * 0.8
		buffer[index] = tanh((wood + click + crack) * 1.5)
	return buffer


static func _synth_alert_sting() -> PackedFloat32Array:
	# 발각 "!" — 두 음 빠른 상행 스팅(880→1320Hz), 구형파 느낌으로 살짝 거칠게.
	var duration := 0.2
	var buffer := _new_buffer(duration)
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var frequency := 880.0 if time < 0.075 else 1320.0
		var local_time := time if time < 0.075 else time - 0.075
		var tone := sin(TAU * frequency * time)
		tone = tanh(tone * 2.4) # 구형파 쪽으로
		var envelope := exp(-local_time * 22.0) * (1.0 if time < 0.075 else 0.95)
		buffer[index] = tone * envelope
	return buffer


static func _synth_reinforce_alarm() -> PackedFloat32Array:
	# 증원 호출 경보 — 사이렌성 스윕 520↔780Hz 두 사이클, 약한 디스토션.
	# 8초 배너 동안 루프가 아니라 시작 1회 + 3초 남았을 때 1회만 울린다.
	var duration := 0.7
	var buffer := _new_buffer(duration)
	var phase := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var cycle := sin(TAU * time / 0.35 - PI * 0.5) * 0.5 + 0.5 # 0→1→0, 2사이클
		var frequency := lerpf(520.0, 780.0, cycle)
		phase += TAU * frequency / MIX_RATE
		var tone := tanh(sin(phase) * 1.8)
		var overtone := sin(phase * 2.0) * 0.18
		var envelope := minf(1.0, time * 40.0) * minf(1.0, (duration - time) * 12.0)
		buffer[index] = (tone + overtone) * envelope
	return buffer


static func _synth_reload_start() -> PackedFloat32Array:
	# 장전 시작 — 탄창 분리 클릭 2단(금속 짧은 링 + 노이즈 트랜지언트).
	var duration := 0.12
	var buffer := _new_buffer(duration)
	var rng := _rng(88008)
	var click_times: Array[float] = [0.0, 0.055]
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var sample := 0.0
		for click_time in click_times:
			if time < click_time:
				continue
			var local_time := time - click_time
			var ring := sin(TAU * 2200.0 * local_time) * exp(-local_time * 160.0) * 0.6
			var transient := rng.randf_range(-1.0, 1.0) * exp(-local_time * 260.0)
			sample += ring + transient
		buffer[index] = tanh(sample * 1.3)
	return buffer


static func _synth_reload_end() -> PackedFloat32Array:
	# 장전 끝 — 탄창 삽입 + 노리쇠 전진 "철컥"(더 무겁고 낮은 2단 클락).
	var duration := 0.16
	var buffer := _new_buffer(duration)
	var rng := _rng(99009)
	var low_pass := 0.0
	var click_times: Array[float] = [0.0, 0.07]
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.5
		var sample := 0.0
		for click_time in click_times:
			if time < click_time:
				continue
			var local_time := time - click_time
			var ring := sin(TAU * 900.0 * local_time) * exp(-local_time * 90.0) * 0.6
			var ring_high := sin(TAU * 1800.0 * local_time) * exp(-local_time * 140.0) * 0.35
			var transient := low_pass * exp(-local_time * 180.0) * 1.1
			sample += ring + ring_high + transient
		buffer[index] = tanh(sample * 1.3)
	return buffer


static func _synth_dry_fire() -> PackedFloat32Array:
	# 빈 약실 공이 클릭 — 아주 짧은 단일 클릭(3kHz + 노이즈 한 점).
	var duration := 0.07
	var buffer := _new_buffer(duration)
	var rng := _rng(10101)
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var ring := sin(TAU * 3000.0 * time) * exp(-time * 220.0) * 0.7
		var transient := rng.randf_range(-1.0, 1.0) * exp(-time * 320.0)
		var thock := sin(TAU * 420.0 * time) * exp(-time * 120.0) * 0.3
		buffer[index] = tanh((ring + transient + thock) * 1.3)
	return buffer


static func _synth_pickup() -> PackedFloat32Array:
	# 픽업 주머니 — 천 스치는 저역 노이즈에 잔 융기 3개 + 희미한 틱.
	var duration := 0.18
	var buffer := _new_buffer(duration)
	var rng := _rng(12121)
	var low_pass := 0.0
	var bump_times: Array[float] = [0.0, 0.05, 0.1]
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.25
		var bumps := 0.0
		for bump_time in bump_times:
			if time >= bump_time:
				bumps += exp(-(time - bump_time) * 45.0)
		var tick := sin(TAU * 1000.0 * time) * exp(-time * 90.0) * 0.25
		buffer[index] = low_pass * bumps * 0.9 + tick
	return buffer


static func _synth_container_open() -> PackedFloat32Array:
	# 컨테이너 열기 — 걸쇠 클릭 + 삐걱(180Hz 비브라토 톤 + 거친 노이즈) 상승.
	var duration := 0.32
	var buffer := _new_buffer(duration)
	var rng := _rng(13131)
	var low_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.2
		var latch := rng.randf_range(-1.0, 1.0) * exp(-time * 150.0) * 0.9 + sin(TAU * 1500.0 * time) * exp(-time * 120.0) * 0.4
		var creak_env := 0.0
		if time > 0.04:
			var local_time := time - 0.04
			creak_env = minf(1.0, local_time * 18.0) * exp(-local_time * 9.0)
		var vibrato := sin(TAU * 28.0 * time) * 12.0
		var creak := sin(TAU * (180.0 + vibrato + time * 120.0) * time) * creak_env * 0.65
		var grit := low_pass * creak_env * 0.45
		buffer[index] = tanh((latch + creak + grit) * 1.2)
	return buffer


static func _synth_ui_tap() -> PackedFloat32Array:
	# UI 버튼 탭 — 부드러운 짧은 클릭(1.2kHz 사인 + 아주 작은 노이즈).
	var duration := 0.045
	var buffer := _new_buffer(duration)
	var rng := _rng(14141)
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var tone := sin(TAU * 1200.0 * time) * exp(-time * 150.0)
		var transient := rng.randf_range(-1.0, 1.0) * exp(-time * 400.0) * 0.35
		buffer[index] = tone + transient
	return buffer


static func _synth_enhance_clink() -> PackedFloat32Array:
	# 강화 "챙" — 2.6kHz·3.9kHz 비조화 두 음(망치 친 쇠) + 아주 짧은 노이즈 타격, 빠른 감쇠.
	var duration := 0.13
	var buffer := _new_buffer(duration)
	var rng := _rng(20260822)
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var ring := sin(TAU * 2600.0 * time) * exp(-time * 38.0) * 0.7
		var overtone := sin(TAU * 3900.0 * time) * exp(-time * 52.0) * 0.45
		var strike := rng.randf_range(-1.0, 1.0) * exp(-time * 520.0) * 0.5
		buffer[index] = ring + overtone + strike
	return buffer


static func _synth_grenade_whistle() -> PackedFloat32Array:
	# 척탄병 와인드업 휘슬 — 1.6k→2.3kHz 짧게 올라가는 톤 + 숨결 노이즈. "던진다"의 예고.
	var duration := 0.34
	var buffer := _new_buffer(duration)
	var rng := _rng(77010)
	var phase := 0.0
	var band := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var frequency := lerpf(1600.0, 2300.0, minf(1.0, time / 0.28))
		phase += TAU * frequency / MIX_RATE
		var envelope := minf(1.0, time / 0.03) * exp(-maxf(0.0, time - 0.22) * 18.0)
		var noise := rng.randf_range(-1.0, 1.0)
		band += (noise - band) * 0.35
		buffer[index] = (sin(phase) * 0.8 + band * 0.22) * envelope
	return buffer


static func _synth_crit_hit() -> PackedFloat32Array:
	# 헤드샷 '크리' — 짧은 딱. 3.2kHz 클릭 + 900Hz 바디, 아주 빠른 감쇠. 명중음 위에 얹힌다.
	var duration := 0.08
	var buffer := _new_buffer(duration)
	var rng := _rng(77020)
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var click := sin(TAU * 3200.0 * time) * exp(-time * 140.0) * 0.9
		var body := sin(TAU * 900.0 * time) * exp(-time * 70.0) * 0.5
		var crack := rng.randf_range(-1.0, 1.0) * exp(-time * 600.0) * 0.6
		buffer[index] = click + body + crack
	return buffer


static func _synth_cover_enter() -> PackedFloat32Array:
	# 엄폐 진입 — 낮은 "툭" (천이 벽에 닿는 느낌). 260→180Hz 하강, 부드러운 감쇠.
	var duration := 0.12
	var buffer := _new_buffer(duration)
	var rng := _rng(77030)
	var low_pass := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var frequency := lerpf(260.0, 180.0, minf(1.0, time / 0.08))
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.12
		buffer[index] = sin(TAU * frequency * time) * exp(-time * 34.0) * 0.8 + low_pass * exp(-time * 60.0) * 0.5
	return buffer


static func _synth_cover_exit() -> PackedFloat32Array:
	# 엄폐 해제 — 진입의 반대로 살짝 올라가는 짧은 톤(180→240Hz).
	var duration := 0.1
	var buffer := _new_buffer(duration)
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var frequency := lerpf(180.0, 240.0, minf(1.0, time / 0.07))
		buffer[index] = sin(TAU * frequency * time) * exp(-time * 38.0)
	return buffer


static func _synth_toast_pop() -> PackedFloat32Array:
	# 토스트 등장 "톡" — 700→1100Hz 짧게 올라가는 사인 핑.
	var duration := 0.09
	var buffer := _new_buffer(duration)
	var phase := 0.0
	for index in buffer.size():
		var time := float(index) / MIX_RATE
		var frequency := lerpf(700.0, 1100.0, minf(1.0, time / 0.05))
		phase += TAU * frequency / MIX_RATE
		buffer[index] = sin(phase) * exp(-time * 55.0)
	return buffer
