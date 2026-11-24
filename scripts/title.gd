extends Control
## 시작 화면: 배경 그림 + 「청월령 青月嶺」 + 메뉴 (시작하기 / 이어하기 / 수집록 / 끝내기)

var _items: Array = []   # [{label, id, enabled}]
var _labels: Array = []
var _sel := 0
var _cursor: TextureRect
var _bg: TextureRect
var _t := 0.0
var _glows: Array = []
var _confirm := false
var _busy := true
var _menu_box: Control

## 시작 화면 그림(Start_ingame_background) 속 등불 자리 (1280 기준 → 살짝 키운 배경 좌표)
const LANTERNS := [Vector2(265, 373), Vector2(438, 480), Vector2(689, 533)]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.field = null
	UI.set_hud_visible(false)
	_bg = TextureRect.new()
	_bg.texture = load("res://assets/bg/start.png")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.size = Vector2(1320, 742)
	_bg.position = Vector2(-20, -11)
	add_child(_bg)
	for p in LANTERNS:
		var g := _glow(Color("ffb860"), 70)
		g.position = Vector2(p.x * 1320.0 / 1280.0 - 20, p.y * 742.0 / 720.0 - 11)
		add_child(g)
		_glows.append(g)
	var moon := _glow(Color("fff2c8"), 130)
	moon.position = Vector2(1063, 82)
	moon.modulate.a = 0.35
	add_child(moon)
	_add_leaves()
	_add_mist()
	# 제목
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.size = Vector2(1280, 120)
	title.position = Vector2(0, 178)
	title.add_theme_constant_override("separation", 22)
	add_child(title)
	var t1 := Label.new()
	t1.text = "청월령"
	t1.add_theme_font_override("font", Game.font_title)
	t1.add_theme_font_size_override("font_size", 92)
	_title_style(t1)
	title.add_child(t1)
	var t2 := Label.new()
	t2.text = "青月嶺"
	t2.add_theme_font_override("font", Game.font_title)
	t2.add_theme_font_size_override("font_size", 40)
	t2.size_flags_vertical = Control.SIZE_SHRINK_END
	_title_style(t2)
	var t2wrap := MarginContainer.new()
	t2wrap.add_theme_constant_override("margin_bottom", 18)
	t2wrap.add_child(t2)
	title.add_child(t2wrap)
	title.modulate.a = 0
	# 메뉴
	_menu_box = Control.new()
	_menu_box.modulate.a = 0
	add_child(_menu_box)
	_cursor = TextureRect.new()
	_cursor.texture = load("res://assets/characters/flame_0.png")
	_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor.size = Vector2(22, 40)
	_menu_box.add_child(_cursor)
	_build_menu()
	var ver := Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version", "1.0"))
	ver.position = Vector2(24, 684)
	ver.add_theme_font_size_override("font_size", 18)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	add_child(ver)
	# 등장
	UI.set_black(true)
	Audio.play_music("title", 2.5)
	Audio.play_amb(["wind", "crickets"])
	var tw := create_tween()
	tw.tween_callback(func(): UI.fade_in(2.0))
	tw.tween_interval(1.4)
	tw.tween_property(title, "modulate:a", 1.0, 1.8)
	tw.tween_property(_menu_box, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func(): _busy = false)

func _title_style(l: Label) -> void:
	l.add_theme_color_override("font_color", Color("fbf6ea"))
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.05, 0.12, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 10)

func _build_menu() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_items = [
		{"label": "시작하기", "id": "new", "enabled": true},
		{"label": "이어하기", "id": "continue", "enabled": Game.has_save()},
	]
	if not Game.collection().is_empty():
		_items.append({"label": "수집록", "id": "collection", "enabled": true})
	_items.append({"label": "끝내기", "id": "quit", "enabled": true})
	for k in _items.size():
		var l := Label.new()
		l.text = _items[k].label
		l.size = Vector2(300, 44)
		l.position = Vector2(490, 462 + k * 46)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 32)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := k
		l.mouse_entered.connect(func(): if not _busy: _select(idx))
		l.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _busy:
				_select(idx)
				_activate())
		_menu_box.add_child(l)
		_labels.append(l)
	_sel = 0
	_select(0, false)

func _select(k: int, snd := true) -> void:
	if snd and k != _sel:
		Audio.sfx("ui_move", -6)
	_sel = k
	for j in _labels.size():
		var on: bool = j == k
		var en: bool = _items[j].enabled
		var a := 1.0 if on else 0.62
		if not en:
			a = 0.28
		_labels[j].add_theme_color_override("font_color", Color(1, 1, 1, a))
		_labels[j].text = _items[j].label
	var lbl: Label = _labels[k]
	var w := lbl.get_theme_font("font").get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_cursor.position = Vector2(640 - w / 2 - 34, lbl.position.y + 2)

func _activate() -> void:
	var it: Dictionary = _items[_sel]
	if not it.enabled:
		Audio.sfx("ui_cancel", -8)
		return
	match it.id:
		"new":
			if Game.has_save() and not _confirm:
				_confirm = true
				_labels[_sel].text = "새로 시작할까요? 저장이 지워집니다 (Enter)"
				_labels[_sel].size.x = 600
				_labels[_sel].position.x = 340
				Audio.sfx("ui_move", -4)
				return
			_busy = true
			Audio.sfx("ui_confirm", -2)
			Game.delete_save()
			Audio.stop_music(1.0)
			Audio.play_amb([], 1.0)
			Game.start_new_game()
		"continue":
			_busy = true
			Audio.sfx("ui_confirm", -2)
			Audio.stop_music(1.0)
			Game.continue_game()
		"collection":
			Audio.sfx("ui_confirm", -4)
			UI.open_collection("title")
		"quit":
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if _busy or UI.overlay != "":
		return
	if not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	if event.is_action("move_up"):
		_reset_confirm()
		_select((_sel - 1 + _items.size()) % _items.size())
	elif event.is_action("move_down"):
		_reset_confirm()
		_select((_sel + 1) % _items.size())
	elif event.is_action("interact"):
		_activate()
	elif event.is_action("cancel"):
		_reset_confirm()
	else:
		return
	get_viewport().set_input_as_handled()

func _reset_confirm() -> void:
	if _confirm:
		_confirm = false
		_labels[0].size.x = 300
		_labels[0].position.x = 490
		_select(_sel, false)

func _process(delta: float) -> void:
	_t += delta
	_bg.position = Vector2(-20 + sin(_t * 0.05) * 14, -11 + sin(_t * 0.07) * 5)
	for i in _glows.size():
		_glows[i].modulate.a = 0.55 + 0.12 * sin(_t * 6.1 + i * 1.7) + 0.06 * sin(_t * 13.0 + i)
	_cursor.texture = load("res://assets/characters/flame_%d.png" % (int(_t * 7) % 3))
	_cursor.modulate.a = 0.85 + 0.15 * sin(_t * 3)

func _glow(col: Color, radius: float) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.7))
	g.set_color(1, Color(col.r, col.g, col.b, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1, 0.5)
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2.ONE * radius * 2.0 / 64.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	return s

func _add_leaves() -> void:
	var p := Scenery.leaves(22)
	p.local_coords = true
	p.position = Vector2(640, -30)
	add_child(p)
	var f := Scenery.fireflies(18)
	f.local_coords = true
	f.position = Vector2(640, 520)
	f.emission_rect_extents = Vector2(700, 140)
	add_child(f)

func _add_mist() -> void:
	var n := FastNoiseLite.new()
	n.frequency = 0.012
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 512
	tex.height = 128
	tex.seamless = true
	for i in 2:
		var m := TextureRect.new()
		m.texture = tex
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_TILE
		m.size = Vector2(2560, 160)
		m.position = Vector2(0, 470 + i * 70)
		m.modulate = Color(0.75, 0.75, 0.9, 0.10)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.material = mat
		add_child(m)
		var tw := create_tween().set_loops()
		tw.tween_property(m, "position:x", -512.0, 40.0 + i * 15).from(0.0)
