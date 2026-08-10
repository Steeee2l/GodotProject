class_name Typewriter
extends Node

# 대사를 한 글자씩 드러내는 타자기 연출 + 타이핑 사운드("드르르륵").
#
# 주요 인물의 내러티브는 한 번에 툭 뜨는 것보다, 글자가 소리와 함께 흘러나올 때
# 훨씬 좋은 인상을 준다. Label 하나를 받아 visible_characters로 점진 공개하고,
# 몇 글자마다 짧은 기계식 틱을 재생한다.
#
# 사용:
#   var tw := Typewriter.new()
#   add_child(tw)              # _process가 스스로 돈다
#   tw.attach(my_label)
#   tw.start("드러낼 문장")
#   tw.skip()                 # 남은 글자를 즉시 전부 공개
#   tw.is_typing()            # 아직 타이핑 중인지

signal finished

const CHARS_PER_SECOND := 44.0
const TICK_EVERY_CHARS := 2
const MIX_RATE := 22050

var _label: Label
var _elapsed := 0.0
var _typing := false
var _last_tick_char := 0
var _players: Array[AudioStreamPlayer] = []
var _player_cursor := 0
var _tick_stream: AudioStreamWAV
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_tick_stream = _build_tick_stream()
	# 틱이 겹쳐 울리도록 플레이어를 몇 개 돌려 쓴다. 하나로는 빠른 타이핑에서
	# 이전 소리가 잘려 "드르르륵"의 결이 안 산다.
	for _index in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -16.0
		player.stream = _tick_stream
		add_child(player)
		_players.append(player)


func attach(label: Label) -> void:
	_label = label


func start(text: String) -> void:
	if not is_instance_valid(_label):
		return
	_label.text = text
	_label.visible_characters = 0
	_elapsed = 0.0
	_last_tick_char = 0
	_typing = text.length() > 0
	if not _typing:
		_label.visible_characters = -1
		finished.emit()


func skip() -> void:
	if not _typing:
		return
	_typing = false
	if is_instance_valid(_label):
		_label.visible_characters = -1
	finished.emit()


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	if not _typing or not is_instance_valid(_label):
		return
	_elapsed += delta
	var total := _label.text.length()
	var shown := mini(total, int(_elapsed * CHARS_PER_SECOND))
	if shown != _label.visible_characters:
		_label.visible_characters = shown
		# 공백을 넘길 때는 소리를 내지 않는다 — 실제 타자기처럼.
		if shown > _last_tick_char and (shown / TICK_EVERY_CHARS) != (_last_tick_char / TICK_EVERY_CHARS):
			var index := clampi(shown - 1, 0, total - 1)
			if index < total and not _label.text[index].strip_edges().is_empty():
				_play_tick()
		_last_tick_char = shown
	if shown >= total:
		_typing = false
		finished.emit()


func _play_tick() -> void:
	if _players.is_empty():
		return
	var player := _players[_player_cursor]
	_player_cursor = (_player_cursor + 1) % _players.size()
	player.pitch_scale = _rng.randf_range(0.92, 1.12)
	player.play()


func _build_tick_stream() -> AudioStreamWAV:
	# 짧고 마른 기계식 틱. 노이즈 버스트에 빠른 감쇠 포락선.
	var duration := 0.028
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 20260812
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var envelope := exp(-time * 190.0)
		var tone := sin(TAU * 1650.0 * time) * 0.4
		var noise := random.randf_range(-1.0, 1.0) * 0.6
		var sample := (tone + noise) * envelope * 0.5
		var encoded := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[index * 2] = encoded & 0xff
		data[index * 2 + 1] = (encoded >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
