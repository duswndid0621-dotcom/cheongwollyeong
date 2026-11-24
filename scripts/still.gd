extends Control
## 그림 한 장(또는 검은 화면) 위에서 대화만 진행하는 장면. [Background-N], 시점 전환, 엔딩 크레딧에 쓴다.
## 그림 위에는 단풍잎·연기가 흐른다. Game.pending: {image, dialogue, music, amb, card, credits, next}

var _p: Dictionary
var _smoke: Array = []
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.field = null
	UI.set_hud_visible(false)
	_p = Game.pending
	Game.pending = {}
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _p.get("image", "") != "":
		var img := _image(_p.image)
		var tw := create_tween().set_loops()
		tw.tween_property(img, "scale", Vector2(1.04, 1.04), 18.0)
		tw.tween_property(img, "scale", Vector2(1.0, 1.0), 18.0)
		_add_fx(_p.image)
	_run()

func _image(path: String) -> TextureRect:
	var img := TextureRect.new()
	img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size = Vector2(1280, 720)
	img.pivot_offset = Vector2(640, 360)
	add_child(img)
	return img

## 그림마다 어울리는 효과: 낮 그림엔 단풍잎, 어두운 그림엔 연기와 불티
func _add_fx(path: String) -> void:
	var dark := path.ends_with("background2.png")
	_smoke = Scenery.smoke_layer(self, 0.16 if dark else 0.08, 400, 320)
	if dark:
		var e := Scenery.embers(26)
		e.local_coords = true
		e.position = Vector2(640, 560)
		add_child(e)
	else:
		var l := Scenery.leaves(18)
		l.local_coords = true
		l.position = Vector2(640, -30)
		add_child(l)

func _process(delta: float) -> void:
	_t += delta
	Scenery.drift_smoke(_smoke, _t)

func _run() -> void:
	if _p.has("music"):
		Audio.play_music(_p.music, 1.5)
	Audio.play_amb(_p.get("amb", []), 1.5)
	if _p.has("card"):
		var c: Array = _p.card
		var muted := Color("b9aec6")
		UI.set_black(false)
		await UI.show_card([[c[0], 26, muted, true], [c[1], 64, Color("f1e9d8"), true], [c[2], 24, muted, false]], 2.6)
	else:
		await UI.fade_in(1.2)
	if _p.get("credits", false):
		await _credits()
		return
	if _p.has("dialogue"):
		await get_tree().create_timer(0.6).timeout
		await UI.run(_p.dialogue)
	await get_tree().create_timer(0.4).timeout
	await UI.fade_out(1.2)
	Game.route(_p.get("next", {"type": "title"}))

## 엔딩 크레딧: 이야기 속 그림들이 천천히 바뀌는 위로 글이 올라간다
func _credits() -> void:
	var pics := ["res://assets/bg/background0.png", "res://assets/bg/background1.png", "res://assets/bg/background1_5.png", "res://assets/bg/background2.png"]
	var layers: Array = []
	for path in pics:
		var r := _image(path)
		r.modulate = Color(0.55, 0.55, 0.6, 0.0)
		layers.append(r)
	_smoke = Scenery.smoke_layer(self, 0.1, 420, 300)
	var lv := Scenery.leaves(16)
	lv.local_coords = true
	lv.position = Vector2(640, -30)
	add_child(lv)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.size = Vector2(1280, 720)
	add_child(shade)
	var f := FileAccess.open("res://data/credits.txt", FileAccess.READ)
	var text := f.get_as_text() if f else "청월령"
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Game.font_title)
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color("f1e9dc"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_constant_override("line_spacing", 14)
	l.size = Vector2(1280, 1400)
	l.position = Vector2(0, 760)
	add_child(l)
	var dur := 32.0
	var tw := create_tween()
	tw.tween_property(l, "position:y", -620.0, dur)
	# 그림 바꾸기
	var each := dur / layers.size()
	for i in layers.size():
		var r: TextureRect = layers[i]
		var t2 := create_tween()
		t2.tween_interval(i * each)
		t2.tween_property(r, "modulate:a", 1.0, 2.5)
		t2.parallel().tween_property(r, "scale", Vector2(1.06, 1.06), each + 3.0).from(Vector2.ONE)
		if i < layers.size() - 1:
			t2.tween_interval(maxf(0.1, each - 2.5 - 1.0))
	await tw.finished
	Game.mark_ending_clear()
	UI.open_collection("ending")
	await UI.overlay_closed
	await UI.fade_out(1.5)
	Audio.stop_music(2.0)
	Game.go_title()

func _unhandled_input(event: InputEvent) -> void:
	pass
