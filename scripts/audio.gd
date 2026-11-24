extends Node
## 음악(교차 페이드), 환경음 2채널, 효과음 풀.

var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var _music_name := ""
var _amb: Array[AudioStreamPlayer] = []
var _amb_names: Array = ["", ""]
var _sfx: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}

const MUSIC_DB := -6.0
const AMB_DB := -10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80
		add_child(p)
		_music.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.volume_db = -80
		add_child(a)
		_amb.append(a)
	for i in 10:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx.append(s)

func _load(path: String, loop: bool) -> AudioStream:
	var key := path + str(loop)
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("소리 파일 없음: " + path)
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		st.loop = loop
	_cache[key] = st
	return st

func play_music(name: String, fade := 1.5) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music[_cur]
	_cur = 1 - _cur
	var nxt := _music[_cur]
	if name != "":
		nxt.stream = _load("res://assets/audio/music/%s.ogg" % name, not name in ["chapter_end", "ending"])
		nxt.volume_db = -40
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", MUSIC_DB, fade)
	var tw := create_tween()
	tw.tween_property(old, "volume_db", -80.0, fade)
	tw.tween_callback(old.stop)

func stop_music(fade := 1.5) -> void:
	play_music("", fade)

func play_amb(names: Array, fade := 2.0) -> void:
	for i in 2:
		var n: String = names[i] if i < names.size() else ""
		if n == _amb_names[i]:
			continue
		_amb_names[i] = n
		var p := _amb[i]
		var tw := create_tween()
		if p.playing:
			tw.tween_property(p, "volume_db", -80.0, fade * 0.5)
		if n != "":
			tw.tween_callback(func():
				p.stream = _load("res://assets/audio/amb/%s.ogg" % n, true)
				p.volume_db = -60
				p.play())
			tw.tween_property(p, "volume_db", AMB_DB, fade)
		else:
			tw.tween_callback(p.stop)

func sfx(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var st := _load("res://assets/audio/sfx/%s.ogg" % name, false)
	if st == null:
		return
	for p in _sfx:
		if not p.playing:
			p.stream = st
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return
	_sfx[0].stream = st
	_sfx[0].play()
