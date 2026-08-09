class_name BgmDirector
extends RefCounted

# 배경음 3상태 — 쉘터(안식), 필드(불안), 전투(압박).
#
# 예전에는 프로시저럴 앰비언트 톤 하나가 오프닝부터 쉘터까지 전부였다.
# "돌아왔다"는 안도감은 절반이 오디오에서 온다. 곡을 넣기 전까지는
# 프로시저럴로라도 세 상태를 구분한다.
#
# 사용:
#   bgm.attach(scene_root)
#   bgm.set_state("field")        # "shelter" | "field" | "combat"
#   bgm.notify_combat()           # 총성/피격 시 호출 -> 잠시 combat으로
#   bgm.tick(delta)               # 매 프레임 (combat 감쇠)

const MIX_RATE := 22050
const CROSSFADE_SECONDS := 1.6
const COMBAT_LINGER_SECONDS := 6.0
const BASE_VOLUME_DB := -21.0

var host: Node
var _players: Array[AudioStreamPlayer] = []
var _active_player := 0
var _streams: Dictionary = {}
var _state := ""
var _combat_linger := 0.0
var _state_before_combat := "field"


func attach(owner_node: Node) -> void:
	host = owner_node
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "BgmLayer%d" % index
		player.bus = "Master"
		player.volume_db = -60.0
		host.add_child(player)
		_players.append(player)
	_streams = {
		"shelter": _create_shelter_stream(),
		"field": _create_field_stream(),
		"combat": _create_combat_stream(),
	}


func set_state(state: String) -> void:
	if state == _state or not _streams.has(state):
		return
	_state = state
	if state != "combat":
		_state_before_combat = state
	var next_index := 1 - _active_player
	var incoming: AudioStreamPlayer = _players[next_index]
	var outgoing: AudioStreamPlayer = _players[_active_player]
	incoming.stream = _streams[state]
	incoming.volume_db = -60.0
	incoming.play()
	_active_player = next_index
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", BASE_VOLUME_DB, CROSSFADE_SECONDS)
	tween.tween_property(outgoing, "volume_db", -60.0, CROSSFADE_SECONDS)
	tween.set_parallel(false)
	tween.tween_callback(outgoing.stop)


func notify_combat() -> void:
	# 총성이나 피격이 있는 동안은 전투. 잦아들면 원래 상태로 돌아간다.
	_combat_linger = COMBAT_LINGER_SECONDS
	if _state != "combat":
		set_state("combat")


func tick(delta: float) -> void:
	if _state != "combat":
		return
	_combat_linger -= delta
	if _combat_linger <= 0.0:
		set_state(_state_before_combat)


# ── 스트림 생성 ────────────────────────────────────────────────


func _create_shelter_stream() -> AudioStreamWAV:
	# 안식: 낮고 느린 드론 + 발전기 허밍. 위협 요소 없음.
	return _render(16.0, 91307, func(time: float, noise: float) -> float:
		var drone := sin(TAU * 55.0 * time) * 0.18
		drone += sin(TAU * 82.4 * time + 0.9) * 0.10
		drone += sin(TAU * 110.0 * time + 0.3) * 0.05
		var generator_hum := sin(TAU * 30.0 * time) * (0.06 + sin(TAU * 0.11 * time) * 0.02)
		var warmth := sin(TAU * 164.8 * time) * 0.03 * (0.5 + 0.5 * sin(TAU * 0.07 * time))
		var soft_static := noise * 0.012
		return drone + generator_hum + warmth + soft_static
	)


func _create_field_stream() -> AudioStreamWAV:
	# 불안: 기존 아포칼립스 앰비언트 — 먼 사이렌, 빗소리, 심장 같은 펄스.
	return _render(18.0, 130713, func(time: float, noise: float) -> float:
		var drone := sin(TAU * 43.65 * time) * 0.26
		drone += sin(TAU * 65.41 * time + 1.7) * 0.12
		drone += sin(TAU * 98.0 * time + 0.4) * 0.06
		var distant_alarm := sin(TAU * 0.075 * time) * sin(TAU * 392.0 * time) * 0.045
		var rain_static := noise * 0.04
		var pulse := 0.0
		var pulse_phase := fmod(time, 6.0)
		if pulse_phase < 0.55:
			pulse = sin(TAU * 72.0 * time) * exp(-pulse_phase * 7.0) * 0.16
		return drone + distant_alarm + rain_static + pulse
	)


func _create_combat_stream() -> AudioStreamWAV:
	# 압박: 빠른 저음 펄스 + 불협 상음 + 거친 노이즈. 심박이 뛰어야 한다.
	return _render(12.0, 77121, func(time: float, noise: float) -> float:
		var drone := sin(TAU * 49.0 * time) * 0.20
		drone += sin(TAU * 51.9 * time + 0.8) * 0.14  # 미세하게 어긋난 불협
		var pulse := 0.0
		var pulse_phase := fmod(time, 0.75)
		if pulse_phase < 0.30:
			pulse = sin(TAU * 60.0 * time) * exp(-pulse_phase * 11.0) * 0.30
		var offbeat_phase := fmod(time + 0.375, 1.5)
		var offbeat := 0.0
		if offbeat_phase < 0.2:
			offbeat = sin(TAU * 88.0 * time) * exp(-offbeat_phase * 14.0) * 0.14
		var grit := noise * 0.05
		var siren := sin(TAU * 0.21 * time) * sin(TAU * 466.2 * time) * 0.03
		return drone + pulse + offbeat + grit + siren
	)


func _render(duration: float, seed_value: int, sampler: Callable) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var noise_hold := 0.0
	for index in sample_count:
		var time := float(index) / MIX_RATE
		if index % 300 == 0:
			noise_hold = random.randf_range(-1.0, 1.0)
		var fade_in := clampf(time / 2.0, 0.0, 1.0)
		var fade_out := clampf((duration - time) / 2.0, 0.0, 1.0)
		var loop_fade := minf(fade_in, fade_out)
		var sample: float = sampler.call(time, noise_hold)
		var encoded := int(clampf(sample * loop_fade, -1.0, 1.0) * 32767.0)
		data[index * 2] = encoded & 0xff
		data[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream
