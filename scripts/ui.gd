extends CanvasLayer
## 화면 위 모든 UI: 대화창·선택지·아이템 획득·토스트·지역 이름·조작 안내·지도·수집록·일시정지·챕터 카드·페이드.

signal _advance
signal _chosen(index: int)
signal overlay_closed

const INK := Color("2b2118")
const PORTRAITS := {
	"최헌": "res://assets/portraits/choi_heon.png",
	"서문경": "res://assets/portraits/seo.png",
	"최옥순": "res://assets/portraits/grandma.png",
	"이정언": "res://assets/portraits/teacher.png",
	"주모": "res://assets/portraits/jumo.png",
	"나그네": "res://assets/portraits/nageune.png",
	"노인": "res://assets/portraits/oldman.png",
	"월선": "res://assets/portraits/wolseon.png",
	"최인백": "res://assets/portraits/inbaek.png",
	"어둑시니": "res://assets/portraits/adukshini.png",
}
const S := 1280.0 / 1672.0  # 대화창 원본 → 화면 배율
const BOX_SCALE := 0.7        # 대화창을 줄여 화면 맨 아래(땅 부분)에 둔다
const BOX_POS_P := Vector2(192, 263)
const BOX_POS_W := Vector2(192, 238)

var field: Node = null       # 현재 필드 (이벤트 처리용)
var busy := false            # 대화 진행 중
var current_id := ""         # 지금 진행 중인 대사 id (디버그·테스트용)
var overlay := ""            # "", "map", "collection", "pause", "item"

var _root: Control
var _dlg: Control
var _box_p: TextureRect
var _box_w: TextureRect
var _name: Label
var _text: RichTextLabel
var _portrait: TextureRect
var _next: Label
var _choices: Control
var _choice_nodes: Array = []
var _choice_sel := 0
var _waiting_choice := false
var _typing := false
var _waiting := false
var _toast: Label
var _toast_tw: Tween
var _loc: Label
var _hints: Label
var _obj: PanelContainer
var _obj_text: Label
var _obj_cur := ""
var _obj_hidden := false   # 인트로 · 챕터 넘어갈 때(화면이 검을 때) 목표를 숨긴다
var _fade: ColorRect
var _card: Control
var _item_pop: Control
var _ov: Control
var _ov_sel := 0
var _ov_mode := ""
var _ov_items: Array = []
var _pause_sel := 0
var _pause_opts: Array = []
var _map_view: Control
var _log: Array = []          # 대화 기록 [{s, t, kind}]  (kind: "say" / "pick")
signal _keys_closed

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Game.theme   # CanvasLayer 아래에도 그리운폴감성 글꼴이 적용되게
	add_child(_root)
	_build_hud()
	_build_dialogue()
	_build_item_popup()
	_ov = Control.new()
	_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ov.visible = false
	_root.add_child(_ov)
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_root.add_child(_card)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

# =========================================================
# HUD
# =========================================================
func _build_hud() -> void:
	_loc = Label.new()
	_loc.position = Vector2(36, 26)
	_loc.add_theme_font_override("font", Game.font_title)
	_loc.add_theme_font_size_override("font_size", 26)
	_loc.add_theme_color_override("font_color", Color("efe6d4"))
	_loc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_loc.add_theme_constant_override("outline_size", 8)
	_loc.modulate.a = 0
	_root.add_child(_loc)
	_hints = Label.new()
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hints.position = Vector2(380, 682)
	_hints.size = Vector2(880, 30)
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hints.add_theme_font_size_override("font_size", 20)
	_hints.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hints.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hints.add_theme_constant_override("outline_size", 6)
	_root.add_child(_hints)
	# 목표 (오른쪽 위)
	_obj = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.05, 0.55)
	sb.border_color = Color(0.85, 0.72, 0.5, 0.55)
	sb.border_width_left = 3
	sb.corner_radius_top_left = 6; sb.corner_radius_bottom_left = 6
	sb.corner_radius_top_right = 6; sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 14; sb.content_margin_right = 16
	sb.content_margin_top = 8; sb.content_margin_bottom = 9
	_obj.add_theme_stylebox_override("panel", sb)
	_obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_obj.add_child(vb)
	var head := Label.new()
	head.text = "목표"
	head.add_theme_font_override("font", Game.font_ui)
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", Color("d9b98a"))
	vb.add_child(head)
	_obj_text = Label.new()
	_obj_text.add_theme_font_override("font", Game.font_ui)
	_obj_text.add_theme_font_size_override("font_size", 22)
	_obj_text.add_theme_color_override("font_color", Color("f3ecdc"))
	_obj_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_obj_text.add_theme_constant_override("outline_size", 4)
	vb.add_child(_obj_text)
	_obj.visible = false
	_root.add_child(_obj)
	_toast = Label.new()
	_toast.size = Vector2(1280, 40)
	_toast.position = Vector2(0, 92)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_color", Color("f3ecdc"))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0
	_root.add_child(_toast)

func set_hud_visible(v: bool) -> void:
	_loc.visible = v
	_hints.visible = v
	_obj.visible = v and _obj_cur != "" and not _obj_hidden

## 화면이 검게 가려졌을 때(인트로 글, 챕터 카드, 장면 전환) 목표를 숨기고, 화면이 밝아지면 다시 밀려 들어온다
func _update_obj_hidden() -> void:
	var dark := _card.visible or _fade.color.a > 0.05
	if is_instance_valid(field) and field.get("_black") != null and field._black.color.a > 0.05:
		dark = true
	if dark == _obj_hidden:
		return
	_obj_hidden = dark
	if dark:
		_obj.visible = false
	elif _obj_cur != "" and _hints.visible:
		_obj_slide_in()

func _obj_slide_in() -> void:
	_obj.visible = true
	_obj.reset_size()
	var w := _obj.get_combined_minimum_size().x
	var end := Vector2(1280 - 24 - w, 22)
	_obj.position = end + Vector2(40, 0)
	_obj.modulate = Color(1.4, 1.25, 0.9, 0.0)
	var tw := create_tween()
	tw.tween_property(_obj, "position", end, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_obj, "modulate", Color(1.4, 1.25, 0.9, 1.0), 0.3)
	tw.tween_property(_obj, "modulate", Color.WHITE, 0.8)
	Audio.sfx("paper", -16, 1.2)

## 목표 글 바꾸기: 바뀔 때마다 오른쪽에서 살짝 밀려 들어오며 반짝인다
func set_objective(text: String) -> void:
	if text == _obj_cur:
		return
	_obj_cur = text
	_obj_text.text = text
	_obj.visible = text != "" and _hints.visible and not _obj_hidden
	if not _obj.visible:
		return
	_obj_slide_in()

func show_location(text: String) -> void:
	_loc.text = text
	var tw := create_tween()
	tw.tween_property(_loc, "modulate:a", 1.0, 1.0)
	tw.tween_interval(3.0)
	tw.tween_property(_loc, "modulate:a", 0.0, 1.5)

func set_hints(text: String) -> void:
	_hints.text = text

func toast(text: String, secs := 3.0) -> void:
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	_toast_tw.tween_interval(secs)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

# =========================================================
# 페이드 / 카드
# =========================================================
func fade_out(t := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	await tw.finished

func fade_in(t := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, t)
	await tw.finished

func set_black(v: bool) -> void:
	_fade.color.a = 1.0 if v else 0.0

## 검은 화면 위 가운데 정렬 글줄. lines: [[글, 크기, 색, 제목체?], ...]
func show_card(lines: Array, hold := 2.4, bg_alpha := 1.0) -> void:
	for c in _card.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.05, bg_alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_card.add_child(box)
	for ln in lines:
		var l := Label.new()
		l.text = ln[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", ln[1])
		l.add_theme_color_override("font_color", ln[2])
		if ln.size() > 3 and ln[3]:
			l.add_theme_font_override("font", Game.font_title)
		box.add_child(l)
	_card.modulate.a = 0
	_card.visible = true
	Audio.sfx("card", -4)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 1.2)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 1.2)
	await tw.finished
	_card.visible = false

# =========================================================
# 대화
# =========================================================
func _build_dialogue() -> void:
	_dlg = Control.new()
	_dlg.size = Vector2(1280, 720)
	_dlg.scale = Vector2(BOX_SCALE, BOX_SCALE)
	_dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.visible = false
	_root.add_child(_dlg)
	_box_p = _full_tex("res://assets/ui/box_portrait.png")
	_box_w = _full_tex("res://assets/ui/box_wide.png")
	_dlg.add_child(_box_p)
	_dlg.add_child(_box_w)
	_box_p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(1000, 414)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.size = Vector2(206, 209)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.clip_contents = true
	_dlg.add_child(_portrait)
	_name = Label.new()
	_name.position = Vector2(89, 405)
	_name.size = Vector2(255, 40)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 35)
	_name.add_theme_color_override("font_color", INK)
	_dlg.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 39)
	_text.add_theme_color_override("default_color", INK)
	_text.add_theme_constant_override("line_separation", 8)
	_dlg.add_child(_text)
	_next = Label.new()
	_next.text = "▼"
	_next.add_theme_font_size_override("font_size", 24)
	_next.add_theme_color_override("font_color", Color("8a2a20"))
	_dlg.add_child(_next)
	_choices = Control.new()
	_choices.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_choices)

func _full_tex(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.position = Vector2.ZERO
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(1280, 720)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _process(delta: float) -> void:
	_update_obj_hidden()
	if _next.visible:
		_next.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	if _map_view and _map_view.visible:
		_map_view.queue_redraw()

## 대화 실행. 끝날 때까지 기다린다.
func run(id: String) -> void:
	var cmds: Array = Game.dialogue.get(id, [])
	if cmds.is_empty():
		push_warning("대사 없음: " + id)
		return
	while busy:
		await get_tree().process_frame
	busy = true
	current_id = id
	var labels := {}
	for i in cmds.size():
		if cmds[i].has("label"):
			labels[cmds[i].label] = i
	var i := 0
	while i < cmds.size():
		var c: Dictionary = cmds[i]
		i += 1
		if c.has("label"):
			continue
		if c.has("go"):
			var ok := true
			if c.has("if"): ok = Game.flag(c["if"])
			if c.has("ifnot"): ok = not Game.flag(c["ifnot"])
			if c.has("has"): ok = Game.has_item(c["has"])
			if c.has("hasnot"): ok = not Game.has_item(c["hasnot"])
			if ok:
				i = labels.get(c.go, cmds.size())
			continue
		if c.has("set"):
			Game.set_flag(c.set)
		elif c.has("choice"):
			var opts: Array = []
			for o in c.choice:
				if o.has("if") and not Game.flag(o["if"]): continue
				if o.has("ifnot") and Game.flag(o["ifnot"]): continue
				if o.has("has") and not Game.has_item(o["has"]): continue
				opts.append(o)
			var texts := opts.map(func(o): return o.t)
			var k: int = await choose(texts)
			var picked: Dictionary = opts[k]
			log_add("", str(texts[k]), "pick")
			if picked.has("set"):
				Game.set_flag(picked.set)
			i = labels.get(picked.go, cmds.size())
		elif c.has("item"):
			await item_get(c.item)
		elif c.has("take"):
			Game.state.items.erase(c.take)
		elif c.has("sfx"):
			Audio.sfx(c.sfx)
		elif c.has("bgm"):
			Audio.play_music(c.bgm)
		elif c.has("shake"):
			if field: field.shake(float(c.shake))
		elif c.has("event"):
			if field and field.has_method("handle_event"):
				_dlg.visible = false
				await field.handle_event(c.event)
		elif c.has("wait"):
			_dlg.visible = false
			await get_tree().create_timer(float(c.wait)).timeout
		elif c.has("cycle"):
			var arr: Array = c.cycle
			var k := Game.next_cycle(id + ":" + str(i), arr.size())
			await say(c.get("s", ""), arr[k])
		elif c.has("t"):
			await say(c.get("s", ""), c.t)
		elif c.has("n"):
			await say("", c.n)
	_dlg.visible = false
	busy = false

func say(speaker: String, text: String) -> void:
	log_add(speaker, text)
	var has_p := PORTRAITS.has(speaker)
	if speaker != "" and not has_p:
		text = speaker + "  「" + text + "」"
	_box_p.visible = has_p
	_box_w.visible = not has_p
	_portrait.visible = has_p
	_name.visible = has_p
	if has_p:
		_portrait.texture = load(PORTRAITS[speaker])
		_name.text = speaker
		_dlg.position = BOX_POS_P
		_text.position = Vector2(122, 462)
		_text.size = Vector2(860, 160)
		_next.position = Vector2(950, 586)
	else:
		_dlg.position = BOX_POS_W
		_text.position = Vector2(118, 498)
		_text.size = Vector2(1100, 140)
		_next.position = Vector2(1210, 606)
	_text.text = text
	_text.visible_characters = 0
	_dlg.visible = true
	_next.visible = false
	_typing = true
	var total := text.length()
	var shown := 0.0
	var blip := 0
	while _typing and shown < total:
		await get_tree().process_frame
		shown += get_process_delta_time() * 42.0
		var n := int(shown)
		if n != _text.visible_characters:
			_text.visible_characters = n
			blip += 1
			if blip % 3 == 0 and speaker != "":
				Audio.sfx("blip", -22, randf_range(0.9, 1.1))
	_typing = false
	_text.visible_characters = -1
	_next.visible = true
	_waiting = true
	await _advance
	_waiting = false
	_next.visible = false

func choose(texts: Array) -> int:
	for n in _choice_nodes:
		n.queue_free()
	_choice_nodes.clear()
	var tex: Texture2D = load("res://assets/ui/choice.png")
	var w := 560.0
	var h := 84.6
	var step := 88.0
	var top := 526.0 - texts.size() * step
	for k in texts.size():
		var b := TextureRect.new()
		b.texture = tex
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_SCALE
		b.size = Vector2(w, h)
		b.position = Vector2((1280 - w) / 2.0, top + k * step)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := Label.new()
		l.text = texts[k]
		l.position = Vector2(70, 12)
		l.size = Vector2(420, 60)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 26 if texts[k].length() < 18 else 22)
		l.add_theme_color_override("font_color", INK)
		b.add_child(l)
		var idx := k
		b.mouse_entered.connect(func(): _select_choice(idx))
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick_choice(idx))
		_choices.add_child(b)
		_choice_nodes.append(b)
	_next.visible = false
	_waiting_choice = true
	_select_choice(0, false)
	var r: int = await _chosen
	for n in _choice_nodes:
		n.queue_free()
	_choice_nodes.clear()
	return r

func _select_choice(k: int, snd := true) -> void:
	if k == _choice_sel and not snd:
		pass
	if snd and k != _choice_sel:
		Audio.sfx("ui_move", -6)
	_choice_sel = k
	for j in _choice_nodes.size():
		var n: TextureRect = _choice_nodes[j]
		n.modulate = Color(1, 1, 1) if j == k else Color(0.72, 0.68, 0.64)
		n.position.x = (1280 - n.size.x) / 2.0 + (10.0 if j == k else 0.0)

func _pick_choice(k: int) -> void:
	if not _waiting_choice:
		return
	_waiting_choice = false
	Audio.sfx("ui_confirm", -4)
	_chosen.emit(k)

# =========================================================
# 아이템 획득 팝업
# =========================================================
func _build_item_popup() -> void:
	_item_pop = Control.new()
	_item_pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_pop.visible = false
	_root.add_child(_item_pop)

static func josa(word: String, pair: String) -> String:
	# pair: "을를", "이가", "은는", "과와"
	var c := word.unicode_at(word.length() - 1)
	var has_final := c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0
	return word + (pair[0] if has_final else pair[1])

func item_get(id: String) -> void:
	Game.give_item(id)
	var data: Dictionary = Game.items_data.get(id, {})
	for c in _item_pop.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_pop.add_child(bg)
	var glow := TextureRect.new()
	glow.texture = _radial(Color(1, 0.85, 0.55, 0.5))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(420, 420)
	glow.position = Vector2(430, 70)
	_item_pop.add_child(glow)
	var ic := TextureRect.new()
	ic.texture = load(data.get("icon", ""))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.size = Vector2(220, 220)
	ic.position = Vector2(530, 170)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_pop.add_child(ic)
	var l := Label.new()
	l.text = "「%s」%s 얻었다." % [data.get("name", id), "을" if _final(data.get("name", id)) else "를"]
	l.size = Vector2(1280, 50)
	l.position = Vector2(0, 420)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color("f6eedb"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	_item_pop.add_child(l)
	var h := Label.new()
	h.text = "수집록에 기록되었다  ·  I 키로 볼 수 있다"
	h.size = Vector2(1280, 30)
	h.position = Vector2(0, 474)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 20)
	h.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_item_pop.add_child(h)
	_item_pop.modulate.a = 0
	_item_pop.visible = true
	_dlg.visible = false
	Audio.sfx("item_get", -2)
	var tw := create_tween()
	tw.tween_property(_item_pop, "modulate:a", 1.0, 0.35)
	ic.scale = Vector2(0.8, 0.8)
	ic.pivot_offset = ic.size / 2
	create_tween().tween_property(ic, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.5).timeout
	_waiting = true
	await _advance
	_waiting = false
	var tw2 := create_tween()
	tw2.tween_property(_item_pop, "modulate:a", 0.0, 0.3)
	await tw2.finished
	_item_pop.visible = false

func _final(word: String) -> bool:
	var c := word.unicode_at(word.length() - 1)
	return c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0

func _radial(col: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t

# =========================================================
# 입력
# =========================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	if overlay == "" and _log_allowed():
		if event.is_action("log"):
			open_log()
			get_viewport().set_input_as_handled()
			return
		if event.is_action("keys"):
			show_keys()
			get_viewport().set_input_as_handled()
			return
	if overlay != "":
		_overlay_input(event)
		get_viewport().set_input_as_handled()
		return
	if _waiting_choice:
		if event.is_action("move_up"):
			_select_choice((_choice_sel - 1 + _choice_nodes.size()) % _choice_nodes.size())
		elif event.is_action("move_down"):
			_select_choice((_choice_sel + 1) % _choice_nodes.size())
		elif event.is_action("interact"):
			_pick_choice(_choice_sel)
		elif event is InputEventKey and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var k: int = event.keycode - KEY_1
			if k < _choice_nodes.size():
				_select_choice(k)
				_pick_choice(k)
		if not click:
			get_viewport().set_input_as_handled()
		return
	if _typing and (event.is_action("interact") or click):
		_typing = false
		get_viewport().set_input_as_handled()
		return
	if _waiting and (event.is_action("interact") or click):
		_advance.emit()
		get_viewport().set_input_as_handled()
		return
	if busy or _card.visible:
		get_viewport().set_input_as_handled()

# =========================================================
# 오버레이 공통
# =========================================================
func _open_overlay(kind: String) -> void:
	for c in _ov.get_children():
		c.queue_free()
	overlay = kind
	_ov.visible = true
	_ov.modulate.a = 0
	create_tween().tween_property(_ov, "modulate:a", 1.0, 0.2)
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ov.add_child(dim)

func close_overlay() -> void:
	if overlay == "":
		return
	var was := overlay
	overlay = ""
	_ov.visible = false
	_map_view = null
	for c in _ov.get_children():
		c.queue_free()
	get_tree().paused = false
	if was == "pause_sub":
		open_pause()
		return
	overlay_closed.emit()

func close_all() -> void:
	overlay = ""
	_ov.visible = false
	_map_view = null
	get_tree().paused = false
	_dlg.visible = false
	_card.visible = false
	for n in _choice_nodes:
		n.queue_free()
	_choice_nodes.clear()
	busy = false
	_waiting = false
	_waiting_choice = false
	_typing = false

func _overlay_input(event: InputEvent) -> void:
	match overlay:
		"map":
			if event.is_action("map") or event.is_action("cancel") or event.is_action("interact"):
				Audio.sfx("paper", -6)
				close_overlay()
		"collection":
			_collection_input(event)
		"pause":
			_pause_input(event)
		"name":
			_name_input_key(event)
		"log":
			_log_input(event)
		"keys":
			if event.is_action("interact") or event.is_action("cancel") or event.is_action("keys") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
				Audio.sfx("paper", -8)
				close_overlay()
				_keys_closed.emit()
		"gameover":
			if event is InputEventMouseButton:
				# 마우스로 '다시하기' / '타이틀로' 누르기 (2.3: 클릭이 버튼까지 닿지 않던 것)
				if event.button_index == MOUSE_BUTTON_LEFT:
					for k in 2:
						var l: Label = _ov.get_node_or_null("g%d" % k)
						if l and Rect2(Vector2(440, l.position.y - 4), Vector2(400, l.size.y + 8)).has_point(_ov.get_local_mouse_position()):
							_go_select(k)
							_go_pick()
			elif event.is_action("move_up") or event.is_action("move_down"):
				_go_select(1 - _go_sel)
			elif event.is_action("interact"):
				_go_pick()

# =========================================================
# 지도
# =========================================================
func open_map() -> void:
	if Game.flag("blood_map"):
		_open_blood_map()
		return
	_open_overlay("map")
	Audio.sfx("paper", -4)
	var tex: Texture2D = load("res://assets/ui/map_original.png")
	var h := 640.0
	var sc := h / tex.get_height()
	var w := tex.get_width() * sc
	var origin := Vector2((1280 - w) / 2.0 - 120, 20)
	var m := TextureRect.new()
	m.texture = tex
	m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.size = Vector2(w, h)
	m.position = origin
	_ov.add_child(m)
	_map_ko_labels(origin, sc, Color("3a2316"), Color(0.96, 0.9, 0.78, 0.95))
	_map_view = MapView.new()
	_map_view.origin = origin
	_map_view.sc = sc
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov.add_child(_map_view)
	# 오른쪽 설명
	var side := Label.new()
	side.position = origin + Vector2(w + 40, 120)
	side.size = Vector2(330, 420)
	side.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_theme_font_size_override("font_size", 24)
	side.add_theme_color_override("font_color", Color("efe6d4"))
	side.add_theme_constant_override("line_spacing", 6)
	var here: String = MapData.area_label(Game.state.area)
	var note := "「이 길을 따라가거라.」\n\n지금 있는 곳\n%s" % here
	if Game.state.area == "road3" and Game.flag("map_guide") and not Game.flag("flame_gone"):
		note += "\n\n지도의 붉은 선은 북쪽 고갯길을 가리킨다.\n그런데 불빛은 자꾸 산 안쪽으로 흘러간다."
	side.text = note
	_ov.add_child(side)
	var t := Label.new()
	t.text = "이정언의 지도"
	t.position = origin + Vector2(w + 40, 60)
	t.add_theme_font_override("font", Game.font_title)
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("f6eedb"))
	_ov.add_child(t)
	_close_hint("M · Esc  닫기")

## 지도 위 한글 지명 (한자 지명 곁에 작게)
func _map_ko_labels(origin: Vector2, sc: float, col: Color, outline: Color) -> void:
	for p in MapData.KO_LABELS:
		var l := Label.new()
		l.text = p.t
		l.size = Vector2(120, 34)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.position = origin + Vector2(p.x, p.y) * sc - l.size / 2.0
		l.add_theme_font_override("font", Game.font_ui)
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ov.add_child(l)

func _open_blood_map() -> void:
	_open_overlay("map")
	Audio.sfx("paper", -4)
	Audio.sfx("heartbeat", -8)
	var tex: Texture2D = load("res://assets/ui/map_blood.png")
	var h := 650.0
	var w := tex.get_width() * h / tex.get_height()
	var m := TextureRect.new()
	m.texture = tex
	m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.size = Vector2(w, h)
	m.position = Vector2((1280 - w) / 2.0 - 120, 18)
	_ov.add_child(m)
	_map_ko_labels(m.position, h / tex.get_height(), Color("4a1410"), Color(0.93, 0.82, 0.74, 0.95))
	var t := Label.new()
	t.text = "이정언의 지도"
	t.position = m.position + Vector2(w + 40, 60)
	t.add_theme_font_override("font", Game.font_title)
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("e8c8c0"))
	_ov.add_child(t)
	var side := Label.new()
	side.position = m.position + Vector2(w + 40, 120)
	side.size = Vector2(330, 420)
	side.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_theme_font_size_override("font_size", 24)
	side.add_theme_color_override("font_color", Color("e8d6cc"))
	side.add_theme_constant_override("line_spacing", 6)
	side.text = "「이 길을 따라가거라.」\n\n지금 있는 곳\n…모르겠다.\n\n붉은 선이 산 안쪽으로 꺾여 들어가 있다.\n그 끝에 '한양'이라고 적혀 있다."
	_ov.add_child(side)
	_close_hint("M · Esc  닫기")

## 이름 쓰기: Enter를 누를 때마다 한 글자씩 적는다 (崔, 憲)
signal _name_done
var _name_chars: Array = []
var _name_i := 0
func name_input() -> void:
	_open_overlay("name")
	get_tree().paused = false
	var paper := ColorRect.new()
	paper.color = Color("efe4c8")
	paper.size = Vector2(420, 560)
	paper.position = Vector2(430, 70)
	_ov.add_child(paper)
	var border := ReferenceRect.new()
	border.border_color = Color("5a3a26")
	border.border_width = 3.0
	border.editor_only = false
	border.size = Vector2(380, 520)
	border.position = Vector2(450, 90)
	_ov.add_child(border)
	var head := Label.new()
	head.text = "姓  名"
	head.position = Vector2(430, 110)
	head.size = Vector2(420, 50)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", Game.font_title)
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color("6a2a1e"))
	_ov.add_child(head)
	_name_chars.clear()
	for k in 2:
		var c := Label.new()
		c.text = ["崔", "憲"][k]
		c.position = Vector2(430, 190 + k * 170)
		c.size = Vector2(420, 160)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_theme_font_override("font", Game.font_title)
		c.add_theme_font_size_override("font_size", 120)
		c.add_theme_color_override("font_color", Color("15100e"))
		c.modulate.a = 0
		_ov.add_child(c)
		_name_chars.append(c)
	var hint := Label.new()
	hint.text = "Enter  이름을 적는다"
	hint.size = Vector2(1280, 30)
	hint.position = Vector2(0, 660)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_ov.add_child(hint)
	_name_i = 0
	await _name_done
	await get_tree().create_timer(1.2).timeout
	close_overlay()

func _name_input_key(event: InputEvent) -> void:
	if not event.is_action("interact") or _name_i >= 2:
		return
	var c: Label = _name_chars[_name_i]
	_name_i += 1
	Audio.sfx("brush", -2)
	create_tween().tween_property(c, "modulate:a", 1.0, 0.45)
	if _name_i >= 2:
		_name_done.emit()

func _close_hint(text: String) -> void:
	var c := Label.new()
	c.text = text
	c.size = Vector2(1240, 30)
	c.position = Vector2(0, 680)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_ov.add_child(c)

class MapView extends Control:
	var origin := Vector2.ZERO
	var sc := 1.0
	func _draw() -> void:
		var cur: Vector2 = origin + MapData.current_point() * sc
		var t := Time.get_ticks_msec() / 1000.0
		var r := 9.0 + 4.0 * sin(t * 3.0)
		draw_arc(cur, r + 4, 0, TAU, 32, Color(0.95, 0.85, 0.5, 0.5), 2.0)
		draw_arc(cur, r, 0, TAU, 32, Color(0.98, 0.9, 0.55, 0.95), 3.0)
		draw_circle(cur, 4.0, Color(1, 0.95, 0.75))

# =========================================================
# 수집록
# =========================================================
## mode: "game"(진행 중), "title"(타이틀), "summary"(챕터 끝)
func open_collection(mode := "game") -> void:
	_open_overlay("collection")
	_ov_mode = mode
	Audio.sfx("paper", -4)
	_ov_items = Game.state.items if mode != "title" else Game.collection()
	var tex: Texture2D = load("res://assets/ui/inventory_panel.png")
	var sc := 1150.0 / tex.get_width()
	var origin := Vector2((1280 - 1150) / 2.0, 22)
	var panel := TextureRect.new()
	panel.texture = tex
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.size = Vector2(tex.get_width(), tex.get_height()) * sc
	panel.position = origin
	_ov.add_child(panel)
	var cols := [152, 323, 494, 666]
	var rows := [168, 338, 505, 672]
	for k in 16:
		var cx: float = cols[k % 4]
		var cy: float = rows[k / 4]
		var slot := TextureRect.new()
		slot.name = "slot%d" % k
		slot.position = origin + Vector2(cx + 10, cy + 10) * sc
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.size = Vector2(118, 118) * sc
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if k < Game.item_order.size():
			var id: String = Game.item_order[k]
			slot.texture = load(Game.items_data[id].icon)
			if not id in _ov_items:
				slot.modulate = Color(0, 0, 0, 0.45)
			var idx := k
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_entered.connect(func(): _collection_select(idx))
		_ov.add_child(slot)
	var sel := ReferenceRect.new()
	sel.name = "sel"
	sel.border_color = Color("b8402e")
	sel.border_width = 3.0
	sel.editor_only = false
	sel.size = Vector2(142, 142) * sc
	_ov.add_child(sel)
	# 오른쪽 페이지
	var pn := Label.new()
	pn.name = "pname"
	pn.position = origin + Vector2(1000, 116) * sc
	pn.size = Vector2(330, 68) * sc
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pn.add_theme_font_size_override("font_size", 26)
	pn.add_theme_color_override("font_color", INK)
	_ov.add_child(pn)
	var big := TextureRect.new()
	big.name = "pbig"
	big.position = origin + Vector2(1065, 210) * sc
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.size = Vector2(210, 210) * sc
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ov.add_child(big)
	var wh := Label.new()
	wh.name = "pwhere"
	wh.position = origin + Vector2(905, 430) * sc
	wh.size = Vector2(530, 40) * sc
	wh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wh.add_theme_font_size_override("font_size", 19)
	wh.add_theme_color_override("font_color", Color("7a4a30"))
	_ov.add_child(wh)
	var ds := Label.new()
	ds.name = "pdesc"
	ds.position = origin + Vector2(925, 480) * sc
	ds.size = Vector2(490, 340) * sc
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.add_theme_font_size_override("font_size", 21)
	ds.add_theme_color_override("font_color", INK)
	ds.add_theme_constant_override("line_spacing", 2)
	_ov.add_child(ds)
	var got := 0
	for id in Game.item_order:
		if id in _ov_items: got += 1
	var head := Label.new()
	head.size = Vector2(1280, 34)
	head.position = Vector2(0, 676)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color("f3ecdc"))
	var title_txt := "수집록"
	if mode == "summary": title_txt = "제1장에서 모은 물건"
	if mode == "ending": title_txt = "청월령에서 모은 물건"
	head.text = "%s   ·   %d / %d   ·   방향키로 살펴보기   %s" % [title_txt, got, Game.item_order.size(), "Enter 계속" if mode in ["summary", "ending"] else "Esc 닫기"]
	_ov.add_child(head)
	_ov.set_meta("origin", origin)
	_ov.set_meta("sc", sc)
	_collection_select(0, false)

func _collection_select(k: int, snd := true) -> void:
	if overlay != "collection":
		return
	k = clampi(k, 0, Game.item_order.size() - 1)
	if snd and k != _ov_sel:
		Audio.sfx("ui_move", -6)
	_ov_sel = k
	var origin: Vector2 = _ov.get_meta("origin")
	var sc: float = _ov.get_meta("sc")
	var cols := [152, 323, 494, 666]
	var rows := [168, 338, 505, 672]
	var sel: ReferenceRect = _ov.get_node("sel")
	sel.position = origin + Vector2(cols[k % 4] - 2, rows[k / 4] - 2) * sc
	var id: String = Game.item_order[k]
	var d: Dictionary = Game.items_data[id]
	var owned: bool = id in _ov_items
	(_ov.get_node("pname") as Label).text = d.name if owned else "???"
	var big: TextureRect = _ov.get_node("pbig")
	big.texture = load(d.icon)
	big.modulate = Color(1, 1, 1) if owned else Color(0, 0, 0, 0.35)
	(_ov.get_node("pwhere") as Label).text = ("얻은 곳 · " + d.where) if owned else ""
	(_ov.get_node("pdesc") as Label).text = d.desc if owned else "아직 얻지 못한 물건이다.\n\n" + d.get("hint", "길 위의 어딘가에서 기다리고 있다.")

func _collection_input(event: InputEvent) -> void:
	var cols := 4
	if event.is_action("move_left"): _collection_select(_ov_sel - 1)
	elif event.is_action("move_right"): _collection_select(_ov_sel + 1)
	elif event.is_action("move_up"): _collection_select(_ov_sel - cols if _ov_sel >= cols else _ov_sel)
	elif event.is_action("move_down"): _collection_select(_ov_sel + cols)
	elif event.is_action("cancel") or event.is_action("collection") or (event.is_action("interact") and _ov_mode in ["summary", "ending"]):
		Audio.sfx("paper", -6)
		close_overlay()

# =========================================================
# 일시정지
# =========================================================
func open_pause() -> void:
	_open_overlay("pause")
	Audio.sfx("ui_move", -4)
	var t := Label.new()
	t.text = "잠시 멈춤"
	t.size = Vector2(1280, 60)
	t.position = Vector2(0, 120)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Game.font_title)
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color("f3ecdc"))
	_ov.add_child(t)
	_pause_opts = ["계속하기", "수집록"]
	if Game.has_item("map"):
		_pause_opts.append("지도")
	_pause_opts += ["대화 기록", "조작 방법", "저장하고 타이틀로", "게임 끝내기"]
	for k in _pause_opts.size():
		var l := Label.new()
		l.name = "p%d" % k
		l.text = _pause_opts[k]
		l.size = Vector2(1280, 46)
		l.position = Vector2(0, 210 + k * 54)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 32)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := k
		l.mouse_entered.connect(func(): _pause_select(idx))
		l.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pause_pick())
		_ov.add_child(l)
	_pause_select(0, false)

func _pause_select(k: int, snd := true) -> void:
	if snd and k != _pause_sel:
		Audio.sfx("ui_move", -6)
	_pause_sel = k
	for j in _pause_opts.size():
		var l: Label = _ov.get_node_or_null("p%d" % j)
		if l:
			l.add_theme_color_override("font_color", Color("ffffff") if j == k else Color(1, 1, 1, 0.45))
			l.text = ("◆  " + _pause_opts[j] + "  ◆") if j == k else _pause_opts[j]

func _pause_input(event: InputEvent) -> void:
	if event.is_action("move_up"): _pause_select((_pause_sel - 1 + _pause_opts.size()) % _pause_opts.size())
	elif event.is_action("move_down"): _pause_select((_pause_sel + 1) % _pause_opts.size())
	elif event.is_action("interact"): _pause_pick()
	elif event.is_action("cancel"):
		close_overlay()

func _pause_pick() -> void:
	Audio.sfx("ui_confirm", -6)
	match _pause_opts[_pause_sel]:
		"계속하기":
			close_overlay()
		"수집록":
			close_overlay()
			open_collection("game")
			overlay = "collection"
		"지도":
			close_overlay()
			open_map()
		"대화 기록":
			close_overlay()
			open_log()
		"조작 방법":
			close_overlay()
			show_keys()
		"저장하고 타이틀로":
			if field: field.store_position()
			Game.save_game()
			close_overlay()
			await fade_out(0.6)
			Game.go_title()
		"게임 끝내기":
			if field: field.store_position()
			Game.save_game()
			get_tree().quit()

# =========================================================
# 대화 기록 (L)  ·  조작 방법 (F1 / H)
# =========================================================
func clear_log() -> void:
	_log.clear()

func log_add(speaker: String, text: String, kind := "say") -> void:
	if text.strip_edges() == "" and kind == "say":
		return
	var place := _loc.text if _loc and _loc.text != "" else ""
	var cs := get_tree().current_scene
	if cs and cs.name == "Still":
		place = "꿈 · 회상" if place == "" else place
	_log.append({"s": speaker, "t": text, "kind": kind, "place": place})
	if _log.size() > 400:
		_log.pop_front()

func _log_allowed() -> bool:
	# 이름 쓰기 · 게임오버 · 화면 전환 중에는 열지 않는다
	if _card.visible or _fade.color.a > 0.5:
		return false
	var cs := get_tree().current_scene
	return cs != null and cs.name in ["Field", "Still"]

func _paper_panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.88, 0.77, 0.97)
	sb.border_color = Color(0.36, 0.24, 0.15)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	_ov.add_child(p)
	return p

## 대화 기록: 책 모양. 왼쪽 쪽에는 대화(스크롤), 오른쪽 쪽에는 고른 줄의 말한 사람 초상 · 이름 · 장소.
const BOOK_SC := 700.0 / 1047.0
const BOOK_POS := Vector2(138, 10)
var _log_sel := 0
var _log_rows: Array = []
var _log_scroll: ScrollContainer
var _log_side := {}

func _bk(x: float, y: float) -> Vector2:
	return BOOK_POS + Vector2(x, y) * BOOK_SC

func open_log() -> void:
	_open_overlay("log")
	Audio.sfx("paper", -6)
	_log_rows.clear()
	# 오른쪽 초상 (책 그림의 창 뒤에 깔린다)
	var win0 := _bk(946, 140)
	var win1 := _bk(1267, 450)
	var por := TextureRect.new()
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.position = win0
	por.size = win1 - win0
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	por.clip_contents = true
	_ov.add_child(por)
	var por_bg := ColorRect.new()
	por_bg.color = Color(0.08, 0.06, 0.05)
	por_bg.position = win0
	por_bg.size = win1 - win0
	_ov.add_child(por_bg)
	_ov.move_child(por_bg, _ov.get_child_count() - 2)   # 초상 뒤
	var book := TextureRect.new()
	book.texture = load("res://assets/ui/log_book.png")
	book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book.position = BOOK_POS
	book.size = Vector2(1502, 1047) * BOOK_SC
	book.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov.add_child(book)
	# 왼쪽 위 이름표: "대화 기록"
	var t := Label.new()
	t.text = "대화 기록"
	t.position = _bk(190, 122)
	t.size = (_bk(670, 216) - _bk(190, 122))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Game.font_title)
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color("3a2616"))
	_ov.add_child(t)
	# 왼쪽 쪽: 대화 목록 (스크롤)
	var sc := ScrollContainer.new()
	sc.position = _bk(150, 250)
	sc.size = _bk(715, 900) - _bk(150, 250)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ov.add_child(sc)
	_log_scroll = sc
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = sc.size.x - 14
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	if _log.is_empty():
		var e := Label.new()
		e.text = "아직 나눈 이야기가 없다."
		e.add_theme_font_size_override("font_size", 20)
		e.add_theme_color_override("font_color", Color("7a6a58"))
		vb.add_child(e)
	for k in _log.size():
		var e: Dictionary = _log[k]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.48, 0.18, 0.11, 0.0)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		row.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = vb.custom_minimum_size.x - 12
		l.add_theme_font_size_override("font_size", 19)
		if e.kind == "pick":
			l.text = "▶ " + str(e.t)
			l.add_theme_color_override("font_color", Color("8a3b22"))
		elif str(e.s) == "":
			l.text = str(e.t)
			l.add_theme_color_override("font_color", Color("5e5040"))
		else:
			l.text = str(e.s) + "  :  " + str(e.t)
			l.add_theme_color_override("font_color", Color("2e2218"))
		row.add_child(l)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var idx := k
		row.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_log_pick(idx))
		vb.add_child(row)
		_log_rows.append(row)
	# 오른쪽 쪽: 이름 · 장소
	var nm := Label.new()
	nm.position = _bk(800, 490)
	nm.size = Vector2(_bk(1400, 0).x - _bk(800, 0).x, 50)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_override("font", Game.font_title)
	nm.add_theme_font_size_override("font_size", 34)
	nm.add_theme_color_override("font_color", Color("6e2416"))
	_ov.add_child(nm)
	var line := ColorRect.new()
	line.color = Color(0.36, 0.24, 0.15, 0.6)
	line.position = _bk(880, 580)
	line.size = Vector2((_bk(1320, 0).x - _bk(880, 0).x), 2)
	_ov.add_child(line)
	var pl := Label.new()
	pl.position = _bk(800, 610)
	pl.size = Vector2(_bk(1400, 0).x - _bk(800, 0).x, 40)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override("font_size", 22)
	pl.add_theme_color_override("font_color", Color("4a3a2a"))
	_ov.add_child(pl)
	var hint := Label.new()
	hint.text = "↑ ↓  한 줄씩      마우스 휠  넘겨 보기\nL · Esc  닫기"
	hint.position = _bk(800, 790)
	hint.size = Vector2(_bk(1400, 0).x - _bk(800, 0).x, 60)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("7a6a58"))
	_ov.add_child(hint)
	_log_side = {"por": por, "name": nm, "place": pl}
	_log_pick(max(0, _log.size() - 1), false)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

func _log_pick(k: int, snd := true) -> void:
	if _log.is_empty():
		_log_side.name.text = ""
		_log_side.place.text = ""
		return
	k = clampi(k, 0, _log.size() - 1)
	if snd and k != _log_sel:
		Audio.sfx("ui_move", -10)
	_log_sel = k
	for j in _log_rows.size():
		var sb: StyleBoxFlat = _log_rows[j].get_theme_stylebox("panel")
		sb.bg_color.a = 0.16 if j == k else 0.0
	var e: Dictionary = _log[k]
	var who: String = "최헌" if e.kind == "pick" else str(e.s)
	if who == "":
		_log_side.por.texture = null
		_log_side.name.text = "· 이야기 ·"
	else:
		_log_side.por.texture = load(PORTRAITS[who]) if PORTRAITS.has(who) else null
		_log_side.name.text = who
	_log_side.place.text = str(e.get("place", ""))
	if snd and k < _log_rows.size() and is_instance_valid(_log_scroll):
		_log_scroll.ensure_control_visible(_log_rows[k])

func _log_input(event: InputEvent) -> void:
	if event.is_action("log") or event.is_action("cancel") or event.is_action("interact"):
		Audio.sfx("paper", -8)
		close_overlay()
		return
	if event.is_action("move_up"):
		_log_pick(_log_sel - 1)
	elif event.is_action("move_down"):
		_log_pick(_log_sel + 1)

## 조작 방법. 새 게임을 시작할 때 한 번 보여 주고, 언제든 F1 / H 또는 메뉴에서 다시 볼 수 있다. 닫힐 때까지 기다린다.
func show_keys() -> void:
	_open_overlay("keys")
	Audio.sfx("paper", -6)
	_paper_panel(Rect2(250, 80, 780, 560))
	var t := Label.new()
	t.text = "조작 방법"
	t.size = Vector2(1280, 50)
	t.position = Vector2(0, 100)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Game.font_title)
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color("3a2616"))
	_ov.add_child(t)
	var rows := [
		["← →   /   A  D", "걷기"],
		["Shift", "달리기 (쫓길 때)"],
		["E   /   Space   /   Enter", "살펴보기 · 말 걸기 · 대화 넘기기"],
		["↑ ↓", "선택지 고르기"],
		["R", "말 타기 · 내리기"],
		["M", "지도 펼치기"],
		["I   /   Tab", "수집록 (얻은 물건)"],
		["L", "대화 기록 (지난 대화 다시 보기)"],
		["F1   /   H", "조작 방법 다시 보기"],
		["Esc", "메뉴 · 닫기"],
	]
	for k in rows.size():
		var y := 172 + k * 40
		var a := Label.new()
		a.text = rows[k][0]
		a.position = Vector2(300, y)
		a.size = Vector2(300, 36)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.add_theme_font_size_override("font_size", 24)
		a.add_theme_color_override("font_color", Color("7a2e1c"))
		_ov.add_child(a)
		var b := Label.new()
		b.text = rows[k][1]
		b.position = Vector2(640, y)
		b.size = Vector2(360, 36)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color("2e2218"))
		_ov.add_child(b)
	var n := Label.new()
	n.text = "반짝이는 별 = 살펴볼 수 있는 곳      말풍선 = 말을 걸 수 있는 사람"
	n.size = Vector2(1280, 30)
	n.position = Vector2(0, 590)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 20)
	n.add_theme_color_override("font_color", Color("5e5040"))
	_ov.add_child(n)
	_close_hint("E · Enter  확인")
	await _keys_closed

# =========================================================
# 길을 잃었다 (게임 오버)
# =========================================================
signal _go_picked(choice: String)
var _go_sel := 0
var _go_ready := false   # 2.3: 글과 버튼이 다 뜬 뒤에만 고를 수 있게

## 「길을 잃었다」 화면. "retry" 또는 "title"을 돌려준다.
func game_over() -> String:
	# 2.3: 대화 도중에 길을 잃으면 대화창이 게임오버 화면을 가리던 것 → 잠시 숨긴다
	var dlg_was: bool = _dlg.visible
	_dlg.visible = false
	_next.visible = false
	_go_ready = false
	_open_overlay("gameover")
	get_tree().paused = false
	for c in _ov.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.0, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1280, 720)
	_ov.add_child(bg)
	var vign := TextureRect.new()
	vign.texture = _radial(Color(0.45, 0.02, 0.02, 0.55))
	vign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vign.size = Vector2(1500, 900)
	vign.position = Vector2(-110, -100)
	_ov.add_child(vign)
	var t := Label.new()
	t.text = "길을 잃었다"
	t.size = Vector2(1280, 120)
	t.position = Vector2(0, 210)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Game.font_title)
	t.add_theme_font_size_override("font_size", 88)
	t.add_theme_color_override("font_color", Color("d8c8c0"))
	t.add_theme_color_override("font_outline_color", Color(0.2, 0, 0, 0.9))
	t.add_theme_constant_override("outline_size", 10)
	t.modulate.a = 0
	_ov.add_child(t)
	var sub := Label.new()
	sub.text = "…푸른 불이 멀어진다."
	sub.size = Vector2(1280, 40)
	sub.position = Vector2(0, 330)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.75, 0.7))
	sub.modulate.a = 0
	_ov.add_child(sub)
	var opts := ["다시하기", "타이틀로"]
	for k in 2:
		var l := Label.new()
		l.name = "g%d" % k
		l.size = Vector2(1280, 50)
		l.position = Vector2(0, 450 + k * 62)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 34)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.set_meta("label", opts[k])
		var idx := k
		l.mouse_entered.connect(func(): _go_select(idx))
		l.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_go_pick())
		l.modulate.a = 0
		_ov.add_child(l)
	_go_select(0, false)
	Audio.sfx("sting", -6)
	var tw := create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 1.6)
	tw.tween_property(sub, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func():
		for k in 2:
			create_tween().tween_property(_ov.get_node("g%d" % k), "modulate:a", 1.0, 0.5))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): _go_ready = true)
	var r: String = await _go_picked
	overlay = ""
	_ov.visible = false
	for c in _ov.get_children():
		c.queue_free()
	_dlg.visible = dlg_was and r == "retry"
	return r

func _go_select(k: int, snd := true) -> void:
	if snd and k != _go_sel:
		Audio.sfx("ui_move", -6)
	_go_sel = k
	for j in 2:
		var l: Label = _ov.get_node_or_null("g%d" % j)
		if l:
			var txt: String = l.get_meta("label")
			l.text = ("◆  " + txt + "  ◆") if j == k else txt
			l.add_theme_color_override("font_color", Color("ffffff") if j == k else Color(1, 1, 1, 0.45))

func _go_pick() -> void:
	if overlay != "gameover" or not _go_ready:
		return
	_go_ready = false
	Audio.sfx("ui_confirm", -4)
	_go_picked.emit("retry" if _go_sel == 0 else "title")
