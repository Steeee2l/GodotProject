# 처치 임팩트 공용 모듈 — 히트스톱 + 처치 확인음.
#
# 필드(main.gd)와 건물 내부 던전(building_interior.gd)의 적은 공통
# scripts/enemy.gd를 쓰므로, enemy._start_death 한 곳에서 이 static 헬퍼를
# 부르면 양쪽 씬이 같은 타격감을 공짜로 받는다. 오디오 플레이어 같은 노드
# 상태는 씬이 아니라 SceneTree root 아래에 두어 씬 전환에도 살아남는다.

# ── 히트스톱 ───────────────────────────────────────────────────
# "처치 순간"에만 Engine.time_scale을 급감시키고 실시간 타이머로 복원한다.
# 일반 명중에는 걸지 않는다 — 연사 무기에서 매 발 멈추면 게임이 굼떠진다.
# 이 PC는 ~500fps로 돌아가므로 프레임 카운트 복원은 금물이며, 복원은
# SceneTreeTimer(process_always=true, ignore_time_scale=true)가 보장한다 —
# 일시정지·씬 전환과 겹쳐도 타이머는 트리 소유라 반드시 발화한다.
const HIT_STOP_TIME_SCALE := 0.05
const NORMAL_KILL_STOP_SECONDS := 0.05
const ELITE_KILL_STOP_SECONDS := 0.09
# main._trigger_hit_stop(대미지 누적 45+ 강조 연출)이 쓰는 얕은 슬로모 값.
# 킬 순간에는 대개 같은 프레임에 이 값이 먼저 걸려 있으므로, 처치 히트스톱이
# 이를 "더 깊게" 덮어써야 한다(양쪽 복원은 값 검사로 서로를 존중한다).
const COMBAT_DAMAGE_STOP_TIME_SCALE := 0.24

# ── 처치 확인음 ────────────────────────────────────────────────
const AUDIO_MIX_RATE := 22050
const AUDIO_PLAYER_COUNT := 4

static var hit_stop_serial := 0
static var audio_bank: Node
static var audio_players: Array[AudioStreamPlayer] = []
static var audio_player_cursor := 0
static var audio_random := RandomNumberGenerator.new()
static var normal_kill_stream: AudioStreamWAV
static var elite_kill_stream: AudioStreamWAV
# 프로브·테스트가 "확인음 재생이 실제 호출됐는지"를 세는 카운터.
static var kill_confirm_play_count := 0


static func play_kill_impact(elite: bool) -> void:
	trigger_kill_hit_stop(elite)
	play_kill_confirm(elite)


static func trigger_kill_hit_stop(elite: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	# 접근성 — 화면 흔들림 배율(camera_shake_scale)을 히트스톱 길이에도
	# 같은 패턴으로 적용한다. 0이면 완전히 스킵.
	var intensity := _get_shake_scale(tree)
	if intensity <= 0.01:
		return
	# 깊은 연출(보스 처치 슬로모 0.18, 사망 시퀀스 등)이 time_scale을 쥐고
	# 있으면 양보한다 — 복원 경쟁으로 서로의 연출을 깨는 것이 최악이다.
	# 허용 상태: 평시(1.0) / 우리 자신의 히트스톱(연속 처치 연장) /
	# main의 대미지 강조 슬로모(0.24 — 킬 프레임에 먼저 걸리므로 덮어쓴다.
	# main._trigger_hit_stop의 복원은 값이 0.24일 때만 되돌리므로 안전).
	var can_take_over := (
		Engine.time_scale >= 0.999
		or is_equal_approx(Engine.time_scale, HIT_STOP_TIME_SCALE)
		or is_equal_approx(Engine.time_scale, COMBAT_DAMAGE_STOP_TIME_SCALE)
	)
	if not can_take_over:
		return
	hit_stop_serial += 1
	var serial := hit_stop_serial
	Engine.time_scale = HIT_STOP_TIME_SCALE
	var duration := (
		ELITE_KILL_STOP_SECONDS if elite else NORMAL_KILL_STOP_SECONDS
	) * intensity
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		# 연속 처치로 히트스톱이 연장됐다면 최신 타이머만 복원을 수행한다.
		if serial != hit_stop_serial:
			return
		# 히트스톱 도중 다른 연출이 time_scale을 가져갔다면 복원 책임도
		# 그쪽에 있다 — 우리가 1.0으로 되돌리면 그 연출이 깨진다.
		if is_equal_approx(Engine.time_scale, HIT_STOP_TIME_SCALE):
			Engine.time_scale = 1.0
	)


static func _get_shake_scale(tree: SceneTree) -> float:
	# static 함수라 오토로드 식별자 대신 root에서 직접 찾는다(테스트 포함
	# 어떤 실행 환경에서도 안전).
	var settings := tree.root.get_node_or_null("AccessibilitySettings")
	if settings == null:
		return 1.0
	return clampf(float(settings.get("camera_shake_scale")), 0.0, 1.0)


static func play_kill_confirm(elite: bool) -> void:
	# 짧고 묵직한 킬 컨펌음. 엘리트는 피치 낮고 크게 + 살짝 이중음.
	# 외부 에셋 없이 코드 생성 AudioStreamWAV(웹 빌드에서도 난다)이며,
	# typewriter처럼 플레이어 4개를 돌려 써 연속 처치 시 소리가 겹친다.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_ensure_audio_bank(tree)
	if audio_players.is_empty():
		return
	var player := audio_players[audio_player_cursor % audio_players.size()]
	audio_player_cursor = (audio_player_cursor + 1) % audio_players.size()
	if not is_instance_valid(player):
		# 누군가 뱅크를 지웠다면 다음 처치에서 재생성한다.
		audio_bank = null
		audio_players.clear()
		return
	player.stream = _get_elite_kill_stream() if elite else _get_normal_kill_stream()
	player.volume_db = -3.5 if elite else -7.5
	player.pitch_scale = (
		audio_random.randf_range(0.94, 1.02)
		if elite
		else audio_random.randf_range(0.96, 1.1)
	)
	player.play()
	kill_confirm_play_count += 1


static func _ensure_audio_bank(tree: SceneTree) -> void:
	if is_instance_valid(audio_bank) and not audio_players.is_empty():
		return
	audio_players.clear()
	audio_bank = tree.root.get_node_or_null("KillConfirmAudioBank")
	if audio_bank == null:
		audio_bank = Node.new()
		audio_bank.name = "KillConfirmAudioBank"
		tree.root.add_child(audio_bank)
	for child in audio_bank.get_children():
		if child is AudioStreamPlayer:
			audio_players.append(child)
	while audio_players.size() < AUDIO_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		audio_bank.add_child(player)
		audio_players.append(player)


static func _get_normal_kill_stream() -> AudioStreamWAV:
	if normal_kill_stream != null:
		return normal_kill_stream
	# 일반 처치 — 짧고 마른 "턱". 저음 바디 + 노이즈 크랙에 빠른 감쇠 포락선.
	normal_kill_stream = _build_kill_stream(0.16, 158.0, 0.0, 0.55, 41117)
	return normal_kill_stream


static func _get_elite_kill_stream() -> AudioStreamWAV:
	if elite_kill_stream != null:
		return elite_kill_stream
	# 엘리트 처치 — 기본음을 낮추고 살짝 어긋난 이중음을 겹쳐 더 웅장하게.
	elite_kill_stream = _build_kill_stream(0.24, 104.0, 156.0, 0.72, 90283)
	return elite_kill_stream


static func _build_kill_stream(
	duration: float,
	base_hz: float,
	dual_hz: float,
	noise_amount: float,
	seed_value: int
) -> AudioStreamWAV:
	# typewriter._build_tick_stream과 같은 방식의 코드 생성 WAV.
	var sample_count := int(AUDIO_MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for index in sample_count:
		var time := float(index) / AUDIO_MIX_RATE
		# 저음 바디 — 재생 중 피치가 살짝 떨어지며 "묵직함"을 만든다.
		var body := sin(TAU * base_hz * time * (1.0 - time * 0.9)) * exp(-time * 16.0)
		var dual := 0.0
		if dual_hz > 0.0:
			dual = sin(TAU * dual_hz * time + 0.4) * exp(-time * 14.0) * 0.55
		var crack := random.randf_range(-1.0, 1.0) * exp(-time * 64.0) * noise_amount
		var sample := tanh((body * 0.95 + dual + crack) * 1.6) * 0.82 * exp(-time * 3.0)
		var encoded := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[index * 2] = encoded & 0xff
		data[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
