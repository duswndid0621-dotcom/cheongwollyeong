extends Control
## [Animation-N] 재생: 프레임 그림을 순서대로 보여주고 다음 장면(Game.route)으로 넘어간다.

var _frames: Array = []
var _durs: Array = []
var _rect: TextureRect
var _i := 0
var _acc := 0.0
var _done := false
var _hoof_t := 0.0
var _hoofs := false
var _next: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.field = null
	UI.set_hud_visible(false)
	var p: Dictionary = Game.pending
	Game.pending = {}
	var id: String = p.get("anim", "anim1")
	_next = p.get("next", {"type": "area", "area": "road1", "spawn": "left"})
	_hoofs = id in ["anim1", "anim2"]
	var meta: Dictionary = Game._read_json("res://assets/anim/anim_meta.json").get(id, {})
	var last: int = int(meta.get("last", 41))
	_durs = meta.get("durations", [])
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in last + 1:
		_frames.append(load("res://assets/anim/%s/%03d.webp" % [id, k]))
	_rect = TextureRect.new()
	_rect.texture = _frames[0]
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 2.3: 건너뛰기 없음 (애니메이션은 끝까지 본다)
	if p.has("music"):
		Audio.play_music(p.music, 1.0)
	Audio.play_amb(p.get("amb", ["wind", ""]), 1.0)
	if p.has("sfx"):
		Audio.sfx(p.sfx, -4)
	UI.fade_in(1.0)

func _dur(i: int) -> float:
	return float(_durs[i]) if i < _durs.size() else 0.16

func _process(delta: float) -> void:
	if _done:
		return
	_acc += delta
	if _hoofs:
		_hoof_t += delta
		if _hoof_t > 0.42:
			_hoof_t = 0.0
			Audio.sfx("hoof", -16, randf_range(0.9, 1.05))
	while _i < _frames.size() - 1 and _acc >= _dur(_i):
		_acc -= _dur(_i)
		_i += 1
		_rect.texture = _frames[_i]
	if _i >= _frames.size() - 1 and _acc > 1.4:
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	await UI.fade_out(1.0)
	Game.route(_next)
