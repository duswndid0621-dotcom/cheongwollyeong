extends Node2D
## 필드: 지역 하나를 그리고, 이동·말 타기·상호작용·자동 이벤트·도깨비불·추격·괴물 연출을 처리한다.

const GROUND_Y := 556.0   # 2.3: 그라운드 라인 8px(약 2mm) 내림
const FLAME_Y := 416.0
const WALK_SPEED := 170.0
const RUN_SPEED := 306.0      # 2.3: 걷기의 1.8배 (추격 중에만)
const CHASER_SPEED := 306.0   # 2.3: 걷기의 1.8배 (닿을 듯 말 듯 따라붙지만, 잡지는 않는다)
const RIDE_SPEED := 285.0
const INTERACT_RANGE := 85.0
const HORSE_RANGE := 120.0
const CHAR_DIR := "res://assets/characters/"
const MON_DIR := "res://assets/monsters/"

var A: Dictionary
var area_id := ""
var W := 2000.0
var cam_x := 0.0
var locked := false
var _ready_done := false

# 화면 구성
var _sky_a: TextureRect
var _sky_b: TextureRect
var _layers: Array = []   # [Node2D, factor]
var _world: Node2D
var _glow_root: Node2D
var _mod: CanvasModulate
var _black: ColorRect
var _red: ColorRect
var _fx_layer: CanvasLayer
var _prompt: Label
var _lights: Array = []
var _scene := {}          # 배경 장면 정보
var _view: AreaView
var _fx: Array = []       # [CPUParticles2D, kind]

# 플레이어
var px := 300.0
var facing := 1
var mounted := false
var horse_x := -1.0
var _vx := 0.0
var _anim_t := 0.0
var _moving := false
var _running := false
var pose := ""
var _player: Node2D
var _psprite: Sprite2D
var _horse: Sprite2D
var _tex := {}
var _has_walk := false

# 동행 (서문경)
var _seo: Node2D
var _seo_sprite: Sprite2D
var _seo_horse: Sprite2D
var _seo_x := 0.0
var _seo_t := 0.0
var _seo_follow := false
var _seo_mounted := false
var _seo_pose := ""
var _seo_face := 1
var _seo_v := 0.0
var _turn_t := 0.0
var _last_face := 1
var _breath := 0.0

var _npcs := {}   # id -> {node, sprite, data, t, home, wx, wdir}
var _flame: Node2D
var _flame_sprite: Sprite2D
var _flame_glow: Sprite2D
var _flame_ground: Sprite2D
var _flame_mode := "off"
var _flame_target := Vector2.ZERO
var _flame_t := 0.0
var _pp := "choi_heon"   # 조종하는 인물 그림 이름
var _figure: Sprite2D
var _marks := {}   # 2.3: 상호작용 지점 표시 (아직 안 본 것 위에 반짝이는 별 / 말풍선)
var _seal_fx := {}   # 봉인석 뒤 거대한 어둑시니 그림자와 연기
var _halo: Sprite2D
var _wisps: Array = []
var _fog: Array = []
var _shake_t := 0.0
var _shake_amp := 0.0
var _wall_cool := 0.0
var _bumping := false
var _glints: Array = []
var _props := {}
var _mons: Array = []     # [{sprite, base, n, fps, t, once}]
var tint_dark := 0.0
var _barking := false
var _bark_queue: Array = []
var _still: CanvasLayer
var _chase := {}

func _ready() -> void:
	area_id = Game.state.area
	A = AreaData.AREAS[area_id]
	W = A.width
	_pp = A.get("player", "choi_heon")
	_has_walk = ResourceLoader.exists(CHAR_DIR + _pp + "_walk_0.png")
	UI.field = self
	_build_view()
	_place_player()
	_build_npcs()
	_build_companion()
	_build_flame()
	_build_extras()
	_update_camera(true)
	_update_time()
	Audio.play_music(A.bgm)
	Audio.play_amb(A.amb)
	_refresh_hints()
	_intro()

# =========================================================
# 화면 만들기
# =========================================================
func _tex_of(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]

func _build_view() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky_a = _sky_rect()
	_sky_b = _sky_rect()
	sky_layer.add_child(_sky_a)
	sky_layer.add_child(_sky_b)
	_world = Node2D.new()
	add_child(_world)
	_mod = CanvasModulate.new()
	add_child(_mod)
	var glow_layer := CanvasLayer.new()
	glow_layer.layer = 1
	add_child(glow_layer)
	_glow_root = Node2D.new()
	glow_layer.add_child(_glow_root)
	var sid: String = A.get("scenery", area_id)
	# 배경: scenes/areas/<지역>.tscn (고도트 에디터에서 직접 고칠 수 있는 장면)
	var view: AreaView = load("res://scenes/areas/%s.tscn" % sid).instantiate()
	add_child(view)
	move_child(view, 0)
	_view = view
	_scene = {"layers": view.layers(), "conds": view.conds(), "lights": view.lights(),
		"fx": {"leaves": view.leaves, "fireflies": view.fireflies, "embers": view.embers}}
	_layers = _scene.layers
	for l in _scene.lights + A.get("lights", []):
		var s := _glow_sprite(Color(l.color), l.r)
		s.position = Vector2(l.x, l.y)
		_glow_root.add_child(s)
		_lights.append({"node": s, "data": l, "seed": randf() * 10.0})
	Scenery.refresh(_scene.conds)
	var fx: Dictionary = _scene.fx
	if fx.get("leaves", 0):
		var p := Scenery.leaves(12 if area_id.begins_with("road") else 9)
		_world.add_child(p)
		_fx.append([p, "leaves"])
	if fx.get("fireflies", 0):
		var p := Scenery.fireflies()
		_glow_root.add_child(p)
		_fx.append([p, "flies"])
	if fx.get("embers", 0):
		var p := Scenery.embers()
		_glow_root.add_child(p)
		_fx.append([p, "embers"])
	_prompt = Label.new()
	_prompt.add_theme_font_override("font", Game.font_ui)
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color("fff6e2"))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(300, 30)
	_prompt.visible = false
	glow_layer.add_child(_prompt)
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 40
	add_child(_fx_layer)
	_red = ColorRect.new()
	_red.color = Color(0.55, 0.0, 0.0, 0.0)
	_red.size = Vector2(1280, 720)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(_red)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.size = Vector2(1280, 720)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(_black)

func _sky_rect() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(1280, 720)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t

func _glow_sprite(col: Color, radius: float) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.9))
	g.add_point(0.35, Color(col.r, col.g, col.b, 0.35))
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	return s

func _char_sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	var t := _tex_of(path)
	s.texture = t
	s.centered = false
	s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	s.scale = Vector2(0.5, 0.5)
	return s

func _set_tex(s: Sprite2D, path: String) -> void:
	var t := _tex_of(path)
	if s.texture != t:
		s.texture = t
		s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())

# =========================================================
# 배치
# =========================================================
func _place_player() -> void:
	var pend: Dictionary = Game.pending
	if pend.get("continue", false):
		px = float(Game.state.x)
		facing = int(Game.state.facing)
		mounted = bool(Game.state.mounted)
		horse_x = float(Game.state.horse_x)
		pose = str(Game.state.get("pose", ""))
	else:
		var key: String = pend.get("spawn", "start")
		var spawns: Dictionary = A.spawn
		px = float(spawns.get(key, spawns.values()[0]))
		if pend.has("x"):
			px = float(pend.x)
		if pend.get("dismount", false):
			Game.state.mounted = false
		if pend.get("mount", false):
			Game.state.mounted = true
		facing = -1 if key == "right" else 1
		mounted = bool(Game.state.mounted)
		if not A.horse:
			mounted = false
		if A.horse and not mounted:
			if A.has("horse_park"):
				horse_x = A.horse_park
			else:
				horse_x = px - 120 * facing
		pose = ""
		if A.has("start_pose") and not Game.flag(A.start_pose[1]):
			pose = A.start_pose[0]
	if A.get("forced_ride", false):
		mounted = true
	if not A.horse:
		mounted = false
	_horse = _char_sprite(CHAR_DIR + "horse_empty.png")
	_horse.z_index = -2
	_world.add_child(_horse)
	_player = Node2D.new()
	_player.z_index = 3
	_world.add_child(_player)
	var shadow := _shadow(46)
	_player.add_child(shadow)
	_psprite = _char_sprite(CHAR_DIR + _pp + "_side.png")
	_player.add_child(_psprite)
	_halo = _glow_sprite(Color("8fa0d8"), 170)
	_glow_root.add_child(_halo)
	_apply_player_look()
	store_position()

func _shadow(w: float) -> Sprite2D:
	var s := _glow_sprite(Color(0, 0, 0), w)
	s.material = null
	s.modulate = Color(0, 0, 0, 0.35)
	s.scale = Vector2(w / 64.0, w / 64.0 * 0.18)
	s.position = Vector2(0, 2)
	return s

var _exists := {}
func _has(path: String) -> bool:
	if not _exists.has(path):
		_exists[path] = ResourceLoader.exists(path)
	return _exists[path]

## 인물 그림 고르기: [경로, 좌우 뒤집기]. 왼쪽을 보는 그림(…L)이 있으면 그걸 쓰고, 없으면 오른쪽 그림을 뒤집는다.
func _actor(key: String, p: String, ride: bool, moving: bool, t: float, face: int, turning := false) -> Array:
	var left := face < 0
	if p != "":
		return [CHAR_DIR + key + "_" + p + ".png", left]
	if turning and not ride and _has(CHAR_DIR + key + "_front.png"):
		return [CHAR_DIR + key + "_front.png", false]
	var r: String
	var l: String
	var k := int(t) % 5
	if ride:
		if moving:
			r = "%s_ride_%d" % [key, k]; l = "%s_rideL_%d" % [key, k]
		else:
			r = key + "_ride_side"; l = key + "_ride_sideL"
	elif moving and _has(CHAR_DIR + key + "_walk_0.png"):
		r = "%s_walk_%d" % [key, k]; l = "%s_walkL_%d" % [key, k]
	else:
		r = key + "_side"; l = key + "_sideL"
	if not left:
		return [CHAR_DIR + r + ".png", false]
	if _has(CHAR_DIR + l + ".png"):
		return [CHAR_DIR + l + ".png", false]
	return [CHAR_DIR + r + ".png", true]

func _player_tex() -> String:
	return _actor(_pp, pose, mounted, _moving, _anim_t, facing, _turn_t > 0)[0]

func _apply_player_look() -> void:
	var a := _actor(_pp, pose, mounted, _moving, _anim_t, facing, _turn_t > 0)
	_set_tex(_psprite, a[0])
	_psprite.flip_h = a[1]
	_horse.visible = A.horse and not mounted and horse_x >= 0
	_horse.position = Vector2(horse_x, GROUND_Y)
	_player.get_child(0).scale.x = (90.0 if mounted else 46.0) / 64.0

func _build_npcs() -> void:
	for n in A.get("npcs", []):
		var node := Node2D.new()
		node.position = Vector2(n.x, GROUND_Y)
		node.add_child(_shadow(46))
		var s := _char_sprite(CHAR_DIR + n.sprite + "_front.png")
		node.add_child(s)
		_world.add_child(node)
		_npcs[n.id] = {"node": node, "sprite": s, "data": n, "t": randf() * 4.0, "home": float(n.x), "wdir": 1.0, "wait": 2.0}
	_update_npc_visibility()

func _update_npc_visibility() -> void:
	for id in _npcs:
		var d: Dictionary = _npcs[id].data
		_npcs[id].node.visible = not (d.has("hide_if") and Game.flag(d.hide_if)) and _cond_ok(d)
	if not _scene.is_empty():
		Scenery.refresh(_scene.conds)

func _build_companion() -> void:
	if not A.get("companion", false):
		return
	var npc_mode: bool = A.has("seo_npc_x") and not Game.flag("talked_seo")
	_seo_follow = not npc_mode
	_seo = Node2D.new()
	_seo.z_index = 2
	_seo.add_child(_shadow(46))
	_seo_sprite = _char_sprite(CHAR_DIR + "seo_side.png")
	_seo.add_child(_seo_sprite)
	_world.add_child(_seo)
	_seo_horse = _char_sprite(CHAR_DIR + "horse_empty.png")
	_seo_horse.modulate = Color(0.72, 0.62, 0.58)
	_seo_horse.z_index = -3
	_world.add_child(_seo_horse)
	if npc_mode:
		_seo_x = A.seo_npc_x
		_seo_mounted = false
		_set_tex(_seo_sprite, CHAR_DIR + "seo_front.png")
		_seo_sprite.flip_h = false
	else:
		_seo_x = px - 140 * facing
		_seo_mounted = mounted
	_update_seo_look(false)

func _update_seo_look(moving: bool) -> void:
	if _seo == null:
		return
	_seo.position = Vector2(_seo_x, GROUND_Y - (_bench_dy if _seo_pose in ["sit", "lie"] else 0.0))
	if _seo_pose != "":
		var a := _actor("seo", _seo_pose, false, false, 0, _seo_face)
		_set_tex(_seo_sprite, a[0]); _seo_sprite.flip_h = a[1]
	elif _seo_follow:
		var a := _actor("seo", "", _seo_mounted, moving, _seo_t, _seo_face)
		_set_tex(_seo_sprite, a[0]); _seo_sprite.flip_h = a[1]
	_seo_horse.visible = A.horse and not _seo_mounted
	var hx := horse_x + 130.0 if horse_x >= 0 else _seo_x
	if A.has("horse_park") and not Game.flag("talked_seo"):
		hx = A.horse_park + 140
	_seo_horse.position = Vector2(hx, GROUND_Y)
	_seo.get_child(0).scale.x = (90.0 if _seo_mounted else 46.0) / 64.0

func _build_flame() -> void:
	_flame = Node2D.new()
	_flame.visible = false
	_glow_root.add_child(_flame)
	_flame_ground = _glow_sprite(Color("4a78ff"), 120)
	_flame_ground.scale.y *= 0.22
	_flame.add_child(_flame_ground)
	_flame_glow = _glow_sprite(Color("5a86ff"), 230)
	_flame.add_child(_flame_glow)
	_flame_sprite = Sprite2D.new()
	_flame_sprite.texture = _tex_of(CHAR_DIR + "flame_0.png")
	_flame_sprite.scale = Vector2(0.72, 0.72)
	_flame.add_child(_flame_sprite)
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 1.4
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 30
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 8
	p.initial_velocity_max = 22
	p.scale_amount_min = 2
	p.scale_amount_max = 4
	p.color = Color(0.6, 0.75, 1.0, 0.8)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	_flame.add_child(p)
	var fl: Dictionary = A.get("flame", {})
	if not fl.is_empty() and Game.flag(fl.on) and not Game.flag(fl.off):
		_flame.visible = true
		_flame.position = Vector2(px + 300, FLAME_Y)
		_flame_mode = "follow"
		if fl.has("hold") and Game.flag(fl.hold) and not Game.flag(fl.get("hold_off", "")):
			_flame_mode = "hold"
			_flame_target = Vector2(fl.hold_x, FLAME_Y)
			_flame.position = _flame_target

## 발자국, 놓인 물건, 반짝임, 떠다니는 불, 안개
func _build_extras() -> void:
	for d in A.get("decals", []):
		if not _cond_ok(d):
			continue
		_add_decal(d.tex, float(d.x), float(d.get("y", 0)), d.get("flip", false))
	for pr in A.get("props", []):
		if pr.has("hide_if") and Game.flag(pr.hide_if):
			continue
		if not _cond_ok(pr):
			continue
		var ps := _char_sprite(pr.tex if pr.tex.begins_with("res://") else CHAR_DIR + pr.tex)
		ps.position = Vector2(pr.x, GROUND_Y + pr.get("dy", 0))
		ps.flip_h = pr.get("flip", false)
		var mc: Array = pr.get("modulate", [1, 1, 1, 1])
		ps.modulate = Color(mc[0], mc[1], mc[2], mc[3])
		ps.z_index = int(pr.get("z", -1))
		ps.scale = Vector2.ONE * 0.5 * float(pr.get("s", 1.0))
		_world.add_child(ps)
		_props[pr.id] = ps
	# 안개 속 검은 형체들 (배경, 나무 사이): 가까이 다가가면 스르륵 사라진다
	for sh in A.get("shades", []):
		var sp := _char_sprite(MON_DIR + "shade_%d.png" % int(sh[1]))
		var sc: float = float(sh[2]) if sh.size() > 2 else 0.5
		if int(sh[1]) != 2:
			sc *= 1.5      # 아이 형체(2번)만 그대로, 나머지는 1.5배
		sp.scale = Vector2(sc, sc)
		sp.position = Vector2(float(sh[0]), GROUND_Y - 6)
		sp.flip_h = float(sh[0]) > px     # 최헌이 오는 쪽을 본다
		sp.z_index = -12                  # 뒤쪽 나무들 사이에 (큰 나무 앞, 인물 뒤)
		sp.modulate = Color(0.55, 0.55, 0.68, 0.0)   # 처음엔 보이지 않는다 (안개 색에 묻힘)
		_world.add_child(sp)
		# 어둠 속에서도 보이는 하얀 눈 (작게 빛난다)
		var eyes := Node2D.new()
		eyes.position = sp.position
		for e in SHADE_EYES[int(sh[1])]:
			var ex: float = e[0] * (-1.0 if sp.flip_h else 1.0)
			var g := _glow_sprite(Color(1, 1, 0.92), 7)
			g.position = Vector2(ex, e[1]) * sc
			eyes.add_child(g)
			var dot := Sprite2D.new()
			dot.texture = _tex_of(MON_DIR + "shade_eye.png")
			dot.position = Vector2(ex, e[1]) * sc
			dot.scale = Vector2(sc, sc)
			eyes.add_child(dot)
		eyes.modulate.a = 0.0
		_glow_root.add_child(eyes)
		# 2.3: 형체마다 행동을 나눈다 — stay(가만히 서 있음) / flee(다가가면 바로 사라짐) / blink(나타났다 곧 사라짐)
		var mode: String = str(sh[4]) if sh.size() > 4 else ["stay", "flee", "blink"][_shades.size() % 3]
		_shades.append({"sprite": sp, "eyes": eyes, "gone": false, "shown": false, "t": randf() * 6.0,
			"if": str(sh[3]) if sh.size() > 3 else "", "eye_pos": SHADE_EYES[int(sh[1])], "sc": sc, "mode": mode, "tween": null})
	# 고목 아래 웅크린 여인: 지역에 들어설 때부터 늘 앉아 있다 (사라지기 전까지)
	if A.has("woman_x") and not Game.flag("woman_gone"):
		var wm := _anim_sprite(MON_DIR + "woman_%d.png", 1, 0.0, float(A.woman_x), false, 2)
		wm.i0 = 3
		_set_tex(wm.sprite, MON_DIR + "woman_3.png")
		wm.sprite.modulate = Color(0.92, 0.92, 0.96, 0.95)
		_mons_named["woman"] = wm
	for o in A.get("objects", []):
		if o.get("glint", false):
			var gn := Node2D.new()
			gn.position = Vector2(o.x, GROUND_Y - 12)
			gn.add_child(_glow_sprite(Color("ffe6a0"), 34))
			var core := _glow_sprite(Color("fff8e0"), 10)
			gn.add_child(core)
			_glow_root.add_child(gn)
			_glints.append({"node": gn, "data": o, "t": randf() * 6.0})
	for w in A.get("wisps", []):
		var n := Node2D.new()
		n.position = Vector2(w[0], w[1])
		n.add_child(_glow_sprite(Color("5a86ff"), 110))
		var sp := Sprite2D.new()
		sp.texture = _tex_of(CHAR_DIR + "flame_0.png")
		sp.scale = Vector2(0.4, 0.4)
		n.add_child(sp)
		_glow_root.add_child(n)
		_wisps.append({"node": n, "sprite": sp, "base": Vector2(w[0], w[1]), "t": randf() * 6.0})
	if A.get("fog", 0.0) > 0.0:
		var layer := CanvasLayer.new()
		layer.layer = 2
		add_child(layer)
		var nz := FastNoiseLite.new()
		nz.frequency = 0.008
		var tex := NoiseTexture2D.new()
		tex.noise = nz
		tex.width = 512
		tex.height = 256
		tex.seamless = true
		for i in 2:
			var r := TextureRect.new()
			r.texture = tex
			r.stretch_mode = TextureRect.STRETCH_TILE
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.size = Vector2(2560, 720)
			r.modulate = Color(0.7, 0.72, 0.85, A.fog * (1.0 if i == 0 else 0.7))
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(r)
			_fog.append({"node": r, "speed": 18.0 + i * 14.0, "f": 0.4 + i * 0.3})

func _add_decal(tex: String, x: float, y: float, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex_of("res://assets/bg/%s.png" % tex)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(3, 3)
	s.flip_h = flip
	s.position = Vector2(x, GROUND_Y + 14 + y * 3)
	s.z_index = -1
	_world.add_child(s)
	return s

# =========================================================
# 시작 연출
# =========================================================
func _intro() -> void:
	var pend: Dictionary = Game.pending
	Game.pending = {}
	locked = true
	UI.set_hud_visible(true)
	if pend.get("intro", false):
		_black.color.a = 1.0
		UI.set_black(false)
		await get_tree().create_timer(0.6).timeout
		await UI.run("intro")
		var tw := create_tween()
		tw.tween_property(_black, "color:a", 0.0, 2.5)
		await _tw_wait(tw)
		UI.show_location(A.name)
		await get_tree().create_timer(0.8).timeout
		await UI.show_keys()     # 2.5 이후: 처음 시작할 때 조작 방법을 보여 준다
		await UI.run("gotaek_start")
	elif pend.has("card"):
		_black.color.a = 1.0
		UI.set_black(false)
		var c: Array = pend.card
		var muted := Color("b9aec6")
		await UI.show_card([[c[0], 26, muted, true], [c[1], 64, Color("f1e9d8"), true], [c[2], 24, muted, false]], 2.6)
		var tw := create_tween()
		tw.tween_property(_black, "color:a", 0.0, 1.6)
		await _tw_wait(tw)
		UI.show_location(A.name)
	else:
		await UI.fade_in(0.8)
		UI.show_location(A.name)
	if pend.has("run"):
		await UI.run(pend.run)
		_update_npc_visibility()
	Game.save_game()
	locked = false
	_ready_done = true

# =========================================================
# 매 프레임
# =========================================================
var _obj_t := 0.0
var _shades: Array = []
var _eye_glows: Array = []

func _shade_vanish(sh: Dictionary) -> void:
	if sh.gone:
		return
	sh.gone = true
	if sh.shown:
		Audio.sfx("shade_out", -6, randf_range(0.95, 1.1))
	# 2.3 수정: 나타나는 트윈이 아직 돌고 있으면 그게 다시 몸 · 눈을 밝혀서
	#          몸은 비켜 사라지고 눈만 허공에 남던 오류 → 먼저 멈춘다. 눈도 몸과 같이 움직인다.
	var app: Tween = sh.get("tween")
	if app and app.is_valid():
		app.kill()
	var dx := 30.0 if sh.sprite.position.x > px else -30.0
	var tw := create_tween()
	tw.tween_property(sh.sprite, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(sh.sprite, "position:x", sh.sprite.position.x + dx, 0.18)
	tw.parallel().tween_property(sh.eyes, "modulate:a", 0.0, 0.1)
	tw.parallel().tween_property(sh.eyes, "position:x", sh.eyes.position.x + dx, 0.18)
	tw.tween_callback(func():
		if is_instance_valid(sh.sprite): sh.sprite.visible = false
		if is_instance_valid(sh.eyes): sh.eyes.visible = false)
## 검은 형체 그림 속 눈 위치 (그림 아래 가운데 기준, 원본 픽셀)
const SHADE_EYES := {0: [[19.7, -398.4], [34.0, -398.5]], 1: [[37.0, -309.5], [53.5, -309.5]], 2: [[-9.9, -207.5], [12.1, -207.6]],
	3: [[-16.5, -387.5], [-1.0, -387.5]], 4: [[-6.0, -378.0], [8.0, -378.0]]}

func _process(delta: float) -> void:
	for sh in _shades:
		if sh.gone:
			continue
		sh.t += delta
		var d := absf(sh.sprite.position.x - px)
		# 화면 끝쪽에 들어오면 안개 속에서 스윽 드러났다가, 잠깐 뒤 샥 사라진다 (한 번뿐)
		if not sh.shown and d < (720.0 if sh.mode == "flee" else 560.0):
			if sh["if"] != "" and not Game.flag(sh["if"]):
				continue
			sh.shown = true
			Audio.sfx("shade_in", -4, randf_range(0.9, 1.08))
			# 나타나는 순간 최헌 쪽을 보게
			var fl: bool = sh.sprite.position.x > px
			if fl != sh.sprite.flip_h:
				sh.sprite.flip_h = fl
				var k := 0
				for c in sh.eyes.get_children():
					var e: Array = sh.eye_pos[k / 2]
					c.position.x = e[0] * (-1.0 if fl else 1.0) * sh.sc
					k += 1
			var day := darkness() < 0.3
			var tw := create_tween()
			# 4장은 조금 더 선명하게 (지역의 shade_alpha)
			var sa: float = float(A.get("shade_alpha", 0.3 if day else 0.45))
			if A.has("shade_alpha"):
				sh.sprite.modulate = Color(0.3, 0.3, 0.38, sh.sprite.modulate.a)   # 더 검게 → 안개 속에서 윤곽이 보이게
			sh.tween = tw
			var fade := 0.5 if sh.mode == "flee" else 1.3
			tw.tween_property(sh.sprite, "modulate:a", sa, fade).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sh.eyes, "modulate:a", 0.8 if A.has("shade_alpha") else 0.55, fade)
			if sh.mode == "blink":
				# 스윽 나타났다가 잠깐 뒤 샥
				tw.tween_interval(randf_range(0.6, 1.2))
				tw.tween_callback(func(): _shade_vanish(sh))
		elif sh.shown and sh.mode == "flee" and d < 400.0:
			_shade_vanish(sh)      # 다가가자마자 사라진다
		elif sh.shown and sh.mode == "blink" and d < 260.0:
			_shade_vanish(sh)
		# "stay": 움직이지 않고 그 자리에 가만히 서 있다 (사라지지 않음)
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.3
		UI.set_objective(Objectives.current(area_id))
	if not is_instance_valid(_player):
		return
	var free := not locked and not UI.busy and UI.overlay == ""
	var can_move := free and pose == ""
	var dir := 0.0
	if can_move:
		dir = Input.get_axis("move_left", "move_right")
	_running = not _chase.is_empty() and not mounted and Input.is_action_pressed("run") and dir != 0
	var speed := RIDE_SPEED if mounted else (RUN_SPEED if _running else WALK_SPEED)
	_vx = lerpf(_vx, dir * speed, clampf(delta * 8.0, 0, 1))
	if absf(_vx) < 2 and dir == 0:
		_vx = 0
	if dir != 0:
		facing = 1 if dir > 0 else -1
	var nx := px + _vx * delta
	nx = _apply_walls(nx, dir)
	nx = clampf(nx, 40, W - 40)
	if A.get("no_back", false) and nx < 120 and dir < 0 and _wall_cool <= 0:
		UI.toast("(돌아갈 수는 없다. 한양으로 가야 한다.)", 2.0)
		_wall_cool = 3.0
	_wall_cool = maxf(0, _wall_cool - delta)
	# 연출로 px 가 옮겨질 때(다가가기 등)도 걷는 동작이 나오게, 지난 프레임 위치와 비교한다
	var moved := absf(nx - _prev_px)
	if moved > 60.0:
		moved = absf(nx - px)     # 순간이동(장면 시작 등)은 걸음으로 치지 않는다
	px = nx
	_prev_px = px
	_animate_player(moved, delta)
	_update_companion(delta)
	_update_npcs(delta)
	_update_flame(delta)
	_update_mons(delta)
	_update_camera(false)
	_update_time()
	_update_lights(delta)
	_update_wisps(delta)
	_update_fx()
	_update_prompt()
	_update_marks()
	_update_shake(delta)
	if not _chase.is_empty():
		_update_chase(delta)
	Game.state.x = px
	if free and _ready_done:
		_check_exits()
		_check_triggers()

func _animate_player(moved: float, delta: float) -> void:
	_player.position = Vector2(px, GROUND_Y)
	# 방향을 바꾸는 순간 아주 잠깐 정면을 본다 (몸을 돌리는 느낌)
	if facing != _last_face:
		if pose == "" and not mounted and _ready_done:
			_turn_t = 0.07
		_last_face = facing
	_turn_t = maxf(0.0, _turn_t - delta)
	var was := int(_anim_t)
	_moving = moved > 0.05 and _turn_t <= 0
	if _moving:
		# 한 장면당 이동 거리: 걷기 5장이 한 걸음 주기, 말은 5장이 한 번 뛰는 주기
		var per := 34.0 if mounted else (17.0 if not _running else 20.0)
		_anim_t += moved / per
	elif _vx == 0:
		_anim_t = 0.0
	var now := int(_anim_t)
	if now != was and _moving:
		if mounted:
			if now % 5 == 0 or now % 5 == 2:
				Audio.sfx("hoof" if now % 5 == 0 else "hoof2", -10, randf_range(0.92, 1.08))
		elif now % 5 == 1 or now % 5 == 4:
			Audio.sfx("step", -14 if not _running else -10, randf_range(0.9, 1.1) * (1.15 if _running else 1.0))
	_apply_player_look()
	# 숨쉬기: 서 있을 때 아주 조금 위아래로
	_breath += delta
	if pose == "" and not _moving:
		_psprite.scale = Vector2(0.5, 0.5 * (1.0 + 0.008 * sin(_breath * 2.2)))
	else:
		_psprite.scale = Vector2(0.5, 0.5)
	if pose == "":
		_psprite.position = Vector2.ZERO
	elif _bench_dy > 0.0 and pose in ["sit", "lie"]:
		_psprite.position = Vector2(0, -_bench_dy)
	_horse.position = Vector2(horse_x, GROUND_Y)

func _update_companion(delta: float) -> void:
	if _seo == null:
		return
	var moving := false
	if _seo_follow and _seo_pose == "":
		var target := px - (200.0 if _seo_mounted else 125.0) * facing
		var dx := target - _seo_x
		var sp := (RIDE_SPEED if _seo_mounted else WALK_SPEED) * 1.15
		# 가까이 붙으면 천천히, 멀어지면 빠르게 (부드럽게 따라온다)
		var want := clampf(dx * 2.2, -sp, sp) if absf(dx) > 8 else 0.0
		_seo_v = lerpf(_seo_v, want, clampf(delta * 6.0, 0, 1))
		var step := _seo_v * delta
		_seo_x += step
		if absf(step) > 0.15:
			moving = true
			_seo_face = 1 if step > 0 else -1
			_seo_t += absf(step) / (34.0 if _seo_mounted else 17.0)
		else:
			_seo_face = 1 if px > _seo_x else -1
			_seo_t = 0.0
	_update_seo_look(moving)

## NPC: 가까우면 이쪽을 보고, 멀면 제자리 동작(idle) · 누운 자세 · 서성이기
func _update_npcs(delta: float) -> void:
	for id in _npcs:
		var e: Dictionary = _npcs[id]
		if e.get("scripted", false):
			continue
		var d: Dictionary = e.data
		e.t += delta
		var near := absf(px - e.node.position.x) < 220
		var sp: Sprite2D = e.sprite
		if d.has("pose") and not Game.flag(d.get("pose_until", "never")):
			var n: int = int(d.get("pose_frames", 1))
			var cyc := maxi(1, n * 2 - 2)
			var k := int(e.t * 2.0) % cyc
			if k >= n: k = cyc - k
			var path: String = CHAR_DIR + d.pose + (("_%d" % k) if n > 1 else "") + ".png"
			_set_tex(sp, path)
			continue
		if near:
			var a := _actor(d.sprite, "", false, false, 0, -1 if px < e.node.position.x else 1)
			_set_tex(sp, a[0]); sp.flip_h = a[1]
			continue
		if d.has("wander"):
			var r: float = float(d.wander)
			if e.wait > 0:
				e.wait -= delta
				_set_tex(sp, CHAR_DIR + d.sprite + "_front.png")
				sp.flip_h = false
			else:
				var nx: float = e.node.position.x + e.wdir * 34.0 * delta
				e.node.position.x = nx
				e.wt = e.get("wt", 0.0) + 34.0 * delta / 14.0
				var a := _actor(d.sprite, "", false, true, e.wt, int(e.wdir))
				_set_tex(sp, a[0]); sp.flip_h = a[1]
				if absf(nx - e.home) > r:
					e.wdir = -e.wdir
					e.wait = randf_range(2.0, 4.0)
			continue
		if d.has("idle"):
			var n := 0
			while _has(CHAR_DIR + "%s_%d.png" % [d.idle, n]):
				n += 1
			# 제자리 동작은 천천히 왕복 (0 1 2 3 4 3 2 1 …)
			var cyc := maxi(1, n * 2 - 2)
			var k := int(e.t * 3.0) % cyc
			if k >= n: k = cyc - k
			_set_tex(sp, CHAR_DIR + "%s_%d.png" % [d.idle, k])
		else:
			_set_tex(sp, CHAR_DIR + d.sprite + "_front.png")
		sp.flip_h = false

var _cam_hold := -1.0
var _bench_dy := 0.0
var _prev_px := -1.0    # 평상에 앉았을 때 올려 그릴 높이   # 0 이상이면 카메라가 그 자리를 비춘다 (뒤돌아보기 등)

func _update_camera(snap: bool) -> void:
	var target := clampf(px - 640 + facing * 110, 0, W - 1280)
	if _cam_hold >= 0.0:
		target = clampf(_cam_hold, 0, W - 1280)
	cam_x = target if snap else lerpf(cam_x, target, clampf(get_process_delta_time() * 3.0, 0, 1))
	var cx := roundf(cam_x)
	for pair in _layers:
		pair[0].position.x = -roundf(cx * pair[1])
	_world.position.x = -cx
	_glow_root.position.x = -cx

func _update_fx() -> void:
	var d := darkness()
	for pair in _fx:
		var p: CPUParticles2D = pair[0]
		match pair[1]:
			"leaves":
				p.position = Vector2(cam_x + 640, -40)
			"flies":
				p.position = Vector2(cam_x + 640, 430)
				p.modulate.a = clampf(0.15 + d * 1.1, 0.0, 1.0)
			"embers":
				p.position = Vector2(cam_x + 640, 470)

func _time_at(x: float) -> Array:
	var keys: Array = A.time
	if keys.size() == 1 or x <= keys[0][0]:
		return [keys[0][1], keys[0][1], 0.0]
	for i in range(1, keys.size()):
		if x <= keys[i][0]:
			var t: float = (x - keys[i - 1][0]) / max(1.0, keys[i][0] - keys[i - 1][0])
			return [keys[i - 1][1], keys[i][1], t]
	return [keys[-1][1], keys[-1][1], 0.0]

func _update_time() -> void:
	var tm := _time_at(px)
	var a: String = tm[0]
	var b: String = tm[1]
	var t: float = tm[2]
	_mod.color = (AreaData.TINT[a] as Color).lerp(AreaData.TINT[b], t).darkened(tint_dark)
	_sky_a.texture = _tex_of("res://assets/bg/areas/sky_%s.png" % AreaData.SKY[a])
	_sky_b.texture = _tex_of("res://assets/bg/areas/sky_%s.png" % AreaData.SKY[b])
	_sky_b.modulate.a = t
	var sky_tint := Color(1, 1, 1)
	if a == "dusk" or b == "dusk":
		sky_tint = Color(0.75, 0.7, 0.85)
	_sky_a.modulate = Color(sky_tint, 1)
	_sky_b.modulate = Color(sky_tint, t)

func darkness() -> float:
	var tm := _time_at(px)
	return lerpf(AreaData.DARK[tm[0]], AreaData.DARK[tm[1]], tm[2])

func _update_lights(delta: float) -> void:
	var d := darkness()
	if _halo:
		_halo.position = Vector2(px, GROUND_Y - 80)
		_halo.modulate.a = clampf((d - 0.6) * 0.35, 0.0, 0.14)
	for l in _lights:
		var f := 1.0
		if l.data.get("flicker", false):
			l.seed += delta
			f = 0.85 + 0.1 * sin(l.seed * 7.3) + 0.05 * sin(l.seed * 17.1)
		var vis := true
		if l.data.has("hide_if") and Game.flag(l.data.hide_if):
			vis = false
		if l.data.has("show_if") and not Game.flag(l.data.show_if):
			vis = false
		l.node.visible = vis
		l.node.modulate.a = (0.12 + 0.88 * d) * f
	for g in _glints:
		g.t += delta
		g.node.visible = _obj_visible(g.data) and not (g.data.has("glint_off") and Game.flag(g.data.glint_off))
		g.node.modulate.a = 0.35 + 0.45 * pow(0.5 + 0.5 * sin(g.t * 2.6), 3.0)

func _update_wisps(delta: float) -> void:
	for w in _wisps:
		w.t += delta
		w.node.position = w.base + Vector2(sin(w.t * 0.7) * 14, sin(w.t * 1.9) * 9)
		w.sprite.texture = _tex_of(CHAR_DIR + "flame_%d.png" % (int(w.t * 7) % 3))
	for fg in _fog:
		fg.node.position.x = -fmod(cam_x * fg.f + Time.get_ticks_msec() / 1000.0 * fg.speed, 512.0)

func _update_shake(delta: float) -> void:
	if _shake_t > 0:
		_shake_t -= delta
		var o := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amp * (_shake_t / 0.6 if _shake_t < 0.6 else 1.0)
		get_viewport().canvas_transform = Transform2D(0, o)
	else:
		get_viewport().canvas_transform = Transform2D.IDENTITY

func shake(amount: float) -> void:
	_shake_t = 0.4 + amount * 0.8
	_shake_amp = 4 + amount * 8

# =========================================================
# 도깨비불
# =========================================================
## 길을 막을 때: 불이 휙 앞으로 날아와 딱 멈춘다
func _flame_dash(to: Vector2) -> void:
	_flame_mode = "dash"
	_flame_target = to
	Audio.sfx("whoosh", -3, 1.25)
	var tw := create_tween()
	tw.tween_property(_flame, "position", to + Vector2(signf(to.x - _flame.position.x) * 26, -6), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_flame, "position", to, 0.18).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_flame, "scale", Vector2(1.25, 1.25), 0.09)
	tw.tween_property(_flame, "scale", Vector2.ONE, 0.25)
	await _tw_wait(tw)
	Audio.sfx("flame_flare", -6)
	_flame_mode = "block"
	await get_tree().create_timer(1.0).timeout

## 낙석 직전: 불이 휙 날아와 최헌 코앞을 딱 가로막는다 (부풀며 번쩍, 최헌은 움찔 물러선다)
func _flame_bar_way() -> void:
	facing = 1
	_vx = 0.0
	var spot := Vector2(px + 80, FLAME_Y + 40)
	_flame_mode = "dash"
	_flame_target = spot
	Audio.sfx("whoosh", -1, 1.3)
	# 앞(바위 쏟아질 자리)에서 기다리던 불이 최헌 쪽으로 휙 날아와, 코앞에서 딱 멈춘다
	var tw := create_tween()
	tw.tween_property(_flame, "position", Vector2(spot.x - 22, spot.y - 6), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_flame, "position", spot, 0.1).set_ease(Tween.EASE_IN_OUT)
	await _tw_wait(tw)
	_flame_mode = "block"
	# 부풀며 번쩍 — 앞을 가로막듯 옆으로 퍼지는 푸른 빛
	var bar := _glow_sprite(Color("5a86ff"), 70)
	bar.position = spot
	bar.scale = Vector2(0.5, 1.4)
	bar.modulate.a = 0.0
	_glow_root.add_child(bar)
	Audio.sfx("flame_flare", 0, 0.8)
	shake(0.45)
	var tw2 := create_tween()
	tw2.tween_property(_flame, "scale", Vector2(1.8, 1.8), 0.1).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(bar, "modulate:a", 0.95, 0.1)
	tw2.parallel().tween_property(bar, "scale", Vector2(2.8, 2.4), 0.16).set_ease(Tween.EASE_OUT)
	tw2.tween_property(_flame, "scale", Vector2(1.3, 1.3), 0.4)
	tw2.parallel().tween_property(bar, "modulate:a", 0.4, 0.7)
	# 2.3: 최헌이 움찔하는 모션은 뺐다 (말 위에서 어색해서)
	await _tw_wait(tw2)
	await get_tree().create_timer(0.6).timeout
	var tw3 := create_tween()
	tw3.tween_property(bar, "modulate:a", 0.0, 1.2)
	tw3.tween_callback(bar.queue_free)

func _update_flame(delta: float) -> void:
	if not _flame.visible:
		return
	_flame_t += delta
	_flame_sprite.texture = _tex_of(CHAR_DIR + "flame_%d.png" % (int(_flame_t * 7) % 3))
	var bob := 10.0 * sin(_flame_t * 2.1) + 3.0 * sin(_flame_t * 5.3)
	var tgt := _flame.position
	match _flame_mode:
		"follow":
			var ahead := px + 270.0 + 110.0 * sin(_flame_t * 0.45)
			ahead = maxf(ahead, px + 150.0)
			tgt = Vector2(ahead, FLAME_Y + bob)
		"hold":
			tgt = Vector2(_flame_target.x, FLAME_Y + 5 + bob)
		"block":
			tgt = Vector2(_flame_target.x, _flame_target.y + bob * 0.5)
		"vanish":
			tgt = _flame.position + Vector2(20 * delta, -10 * delta)
		"dash":
			return
	var k := 4.0 if _flame_mode == "block" else 1.3
	_flame.position = _flame.position.lerp(tgt, clampf(delta * k, 0, 1))
	_flame_ground.position = Vector2(0, GROUND_Y - _flame.position.y + 4)
	var pulse := 0.85 + 0.15 * sin(_flame_t * 3.7)
	_flame_glow.modulate.a = 0.75 * pulse
	_flame_ground.modulate.a = 0.5 * pulse

# =========================================================
# 상호작용
# =========================================================
func _interactables() -> Array:
	var list := []
	for id in _npcs:
		var e: Dictionary = _npcs[id]
		if e.node.visible and not e.get("scripted", false):
			list.append({"kind": "npc", "x": e.node.position.x, "data": e.data, "label": e.data.get("label", "말 걸기")})
	for o in A.get("objects", []):
		if _obj_visible(o):
			list.append({"kind": "obj", "x": o.x, "data": o, "label": o.label + " 살펴보기"})
	if _seo != null and _seo_pose == "":
		list.append({"kind": "seo", "x": _seo_x, "data": {}, "label": "서문경에게 말 걸기"})
	if A.horse and not mounted and horse_x >= 0 and _horse.visible:
		list.append({"kind": "horse", "x": horse_x, "data": {}, "label": "말 살펴보기"})
	return list

func _nearest() -> Dictionary:
	var best := {}
	var bd := INTERACT_RANGE + (40.0 if mounted else 0.0)
	for it in _interactables():
		var d := absf(it.x - px)
		if (it.kind == "seo" and _seo_follow) or it.kind == "horse":
			d += 45.0  # 사람·물건을 동행보다 먼저
		if d < bd:
			bd = d
			best = it
	return best

## 2.3: 아직 살펴보지 않은 물건·말 걸지 않은 사람 머리 위에 표시를 띄운다 (보고 나면 사라짐)
func _update_marks() -> void:
	var hide_all := locked or UI.busy or UI.overlay != "" or not _chase.is_empty()
	var near := _nearest()
	var live := {}
	if not hide_all:
		for it in _interactables():
			if it.kind != "npc" and it.kind != "obj":
				continue
			var d: Dictionary = it.data
			if not d.has("id") or Game.flag(d.get("done", "seen_%s_%s" % [area_id, d.id])):
				continue
			if absf(it.x - cam_x - 640) > 760:
				continue
			var key: String = it.kind + ":" + str(d.id)
			live[key] = true
			var m: Sprite2D = _marks.get(key)
			if m == null:
				m = Sprite2D.new()
				m.texture = _tex_of("res://assets/ui/mark_%s.png" % it.kind)
				m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				m.z_index = 40
				var g := _glow_sprite(Color(1.0, 0.85, 0.45) if it.kind == "obj" else Color(1, 0.97, 0.9), 44)
				g.show_behind_parent = true
				g.modulate.a = 0.55
				m.add_child(g)
				m.modulate.a = 0.0
				_world.add_child(m)
				_marks[key] = m
			var top: float = d.get("mark_y", 215.0 if it.kind == "npc" else 150.0)
			var t := Time.get_ticks_msec() / 1000.0
			m.position = Vector2(it.x, GROUND_Y - top - (40.0 if mounted and it.kind == "obj" else 0.0) + sin(t * 3.0 + it.x * 0.01) * 5.0)
			# 바로 앞에 와서 E 안내가 뜨면 표시는 살짝 흐리게
			var target := 0.35 if (not near.is_empty() and near.x == it.x) else 1.0
			m.modulate.a = move_toward(m.modulate.a, target, get_process_delta_time() * 3.0)
			if it.kind == "obj":
				m.scale = Vector2.ONE * (1.0 + 0.08 * sin(t * 5.0))
	for key in _marks.keys():
		if not live.has(key):
			var m: Sprite2D = _marks[key]
			m.modulate.a = move_toward(m.modulate.a, 0.0, get_process_delta_time() * 4.0)
			if m.modulate.a <= 0.0:
				m.queue_free()
				_marks.erase(key)

func _update_prompt() -> void:
	if locked or UI.busy or UI.overlay != "" or not _chase.is_empty():
		_prompt.visible = false
		return
	var it := _nearest()
	var lines := []
	if not it.is_empty():
		lines.append("E  " + it.label)
	if A.horse and horse_x >= 0 and not mounted and _horse.visible and absf(horse_x - px) < HORSE_RANGE and Game.flag("talked_seo"):
		lines.append("R  말에 타기")
	if lines.is_empty():
		_prompt.visible = false
		return
	_prompt.text = "    ".join(lines)
	_prompt.size = Vector2(420, 30)
	var x: float = it.x if not it.is_empty() else horse_x
	_prompt.position = Vector2(x - cam_x - 210, GROUND_Y - (250 if mounted else 205))
	_prompt.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_done or locked or UI.busy or UI.overlay != "":
		return
	if not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	if event.is_action("interact"):
		if _chase.is_empty():
			_do_interact()
	elif event.is_action("horse"):
		_toggle_horse()
	elif event.is_action("map"):
		if Game.has_item("map"):
			UI.open_map()
		else:
			UI.toast("아직 지도가 없다.", 2)
	elif event.is_action("collection"):
		UI.open_collection("game")
	elif event.is_action("cancel"):
		store_position()
		UI.open_pause()
	else:
		return
	get_viewport().set_input_as_handled()

func _do_interact() -> void:
	if locked or UI.busy:
		return
	var it := _nearest()
	if it.is_empty():
		return
	locked = true
	_vx = 0
	match it.kind:
		"npc", "obj":
			var d: Dictionary = it.data
			var done_flag: String = d.get("done", "seen_%s_%s" % [area_id, d.id])
			var dlg: String = d.dialogue
			if d.has("pre_if") and not Game.flag(d.pre_if):
				dlg = d.pre_dialogue
			elif mounted and d.has("need_dismount"):
				dlg = d.need_dismount
			elif Game.flag(done_flag) and d.has("repeat"):
				dlg = d.repeat
			if it.kind == "npc" and _npcs.has(d.id):
				# 말을 거는 쪽(최헌)을 바라본다: 왼쪽을 보는 그림이 있으면 그것을 쓴다
				var e: Dictionary = _npcs[d.id]
				var dd: Dictionary = e.data
				if not (dd.has("pose") and not Game.flag(dd.get("pose_until", "never"))):
					var look := _actor(dd.sprite, "", false, false, 0, -1 if px < e.node.position.x else 1)
					_set_tex(e.sprite, look[0]); e.sprite.flip_h = look[1]
				facing = 1 if it.x > px else -1
			await UI.run(dlg)
			if dlg == d.dialogue and not d.has("done"):
				Game.set_flag(done_flag)
		"seo":
			if not _seo_follow:
				await UI.run("golmok_seo")
			else:
				facing = 1 if _seo_x > px else -1
				await UI.run(_seo_dialogue())
		"horse":
			Audio.sfx("snort", -6)
			await UI.run("golmok_horse")
	_update_npc_visibility()
	_refresh_hints()
	locked = false

func _seo_dialogue() -> String:
	if area_id == "road3" and Game.flag("flame_seen") and not Game.flag("flame_gone"):
		return "seo_r_flame"
	if area_id == "road2" and Game.flag("rested"):
		return "seo_r_road2b"
	return "seo_r_" + area_id

func _toggle_horse() -> void:
	if locked or UI.busy:
		return
	if A.get("forced_ride", false):
		UI.toast("(말이 멈추지 않는다. 고삐가 손에 감겨 풀리지 않는다.)", 2.5)
		return
	if not A.horse:
		if area_id in ["road6", "road7", "road8"]:
			UI.toast("(…말이 없다.)", 2)
		else:
			UI.toast("여기서는 말을 탈 수 없다.", 2)
		return
	if not Game.flag("talked_seo"):
		UI.toast("(문경이에게 먼저 말을 걸자.)", 2)
		return
	if mounted:
		mounted = false
		horse_x = px
		px = clampf(px + 55 * facing, 40, W - 40)
		Audio.sfx("mount", -4)
	else:
		if horse_x < 0 or absf(horse_x - px) > HORSE_RANGE:
			UI.toast("말이 너무 멀리 있다.", 2)
			return
		px = horse_x
		mounted = true
		Audio.sfx("mount", -4)
		Audio.sfx("snort", -10)
	_apply_player_look()
	_refresh_hints()
	if _seo != null and _seo_follow:
		await get_tree().create_timer(0.45).timeout
		_seo_mounted = mounted
		Audio.sfx("mount", -14)
		_update_seo_look(false)
	store_position()

func _refresh_hints() -> void:
	var h := ["← →  이동", "E  살펴보기"]
	if not _chase.is_empty():
		h = ["← →  이동", "Shift  달리기"]
	if A.horse and Game.flag("talked_seo") and _pp == "choi_heon" and not A.get("forced_ride", false):
		h.append("R  말")
	if Game.has_item("map"):
		h.append("M  지도")
	h.append("I  수집록")
	h.append("L  대화 기록")
	h.append("Esc  메뉴")
	UI.set_hints("    ".join(h))

func store_position() -> void:
	Game.state.x = px
	Game.state.facing = facing
	Game.state.mounted = mounted
	Game.state.horse_x = horse_x
	Game.state.pose = pose

# =========================================================
# 벽 · 출구 · 자동 이벤트
# =========================================================
func _obj_visible(o: Dictionary) -> bool:
	if o.has("hide_if") and Game.flag(o.hide_if):
		return false
	return _cond_ok(o)

func _cond_ok(d: Dictionary) -> bool:
	if d.has("if") and not Game.flag(d["if"]):
		return false
	if d.has("ifnot") and Game.flag(d["ifnot"]):
		return false
	if d.has("has") and not Game.has_item(d["has"]):
		return false
	if d.has("hasnot") and Game.has_item(d["hasnot"]):
		return false
	return true

func _apply_walls(nx: float, dir: float) -> float:
	for w in A.get("walls", []):
		if w.get("side", "right") == "left":
			if not Game.flag(w.get("ifnot", "")) and px >= w.x and nx < w.x + 10:
				nx = w.x + 10
				if dir < 0 and _wall_cool <= 0 and _ready_done and not UI.busy and w.has("say"):
					UI.toast(w.say, 2.5)
					_wall_cool = 3.0
			continue
		if not Game.flag(w.get("ifnot", "")) and px <= w.x and nx > w.x - 10:
			nx = w.x - 10
			if dir > 0 and not _bumping and _wall_cool <= 0 and _ready_done and not UI.busy:
				if w.has("bump"):
					_bump_sequence(w.bump)
				elif w.has("say"):
					UI.toast(w.say, 2.5)
					_wall_cool = 3.0
	return nx

func _bump_sequence(kind: String) -> void:
	_bumping = true
	locked = true
	if kind == "rockslide":
		await _flame_bar_way()
		await UI.run("road3_rock_stop")
		await get_tree().create_timer(1.0).timeout
		await UI.run("road3_rockslide")
		create_tween().tween_property(_flame, "scale", Vector2.ONE, 0.6)
		_flame_mode = "follow"
	locked = false
	_bumping = false

func _check_exits() -> void:
	var ex: Dictionary = A.get("exits", {})
	for side in ex:
		var e: Dictionary = ex[side]
		var hit: bool = (px >= e.x) if side == "right" else (px <= e.x)
		if not hit:
			continue
		if e.has("cond") and not Game.flag(e.cond):
			px = e.x - 40 if side == "right" else e.x + 40
			_vx = 0
			if e.has("locked"):
				locked = true
				await UI.run(e.locked)
				locked = false
			return
		_leave(e)
		return

func _leave(e: Dictionary) -> void:
	locked = true
	store_position()
	Audio.sfx("cloth", -12)
	if e.get("anim", false) is String:
		# 2.3: 나가면서 애니메이션 하나 보여 주고 다음 지역으로 (예: 신녕 주막 도착 = anim_inn)
		Audio.stop_music(1.2)
		Audio.play_amb([], 1.2)
		await UI.fade_out(1.2)
		Game.save_game()
		Game.route({"type": "anim", "anim": e.anim, "music": e.get("anim_music", "night"),
			"next": {"type": "area", "area": e.to, "spawn": e.spawn}})
	elif e.get("anim", false):
		Audio.stop_music(1.2)
		Audio.play_amb([], 1.2)
		await UI.fade_out(1.2)
		Game.save_game()
		Game.play_animation_then(e.to, e.spawn, {"card": ["第一章", "푸른 불", "경주  →  영천  →  신녕"]})
	else:
		await UI.fade_out(0.7)
		var extra := {}
		if e.has("run"):
			extra["run"] = e.run
		if e.get("mount", false):
			extra["mount"] = true
		Game.change_area(e.to, e.spawn, extra)

func _check_triggers() -> void:
	for t in A.get("triggers", []):
		if t.has("once") and Game.flag(t.once):
			continue
		if not _cond_ok(t):
			continue
		var dir: int = t.get("dir", 1)
		if (dir > 0 and px >= t.x) or (dir < 0 and px <= t.x):
			if t.has("once"):
				Game.set_flag(t.once)
			if t.has("barks") or t.has("amb"):
				_ambient(t)   # 걸음을 멈추지 않는 작은 사건
				continue
			_run_trigger(t)
			return

func _run_trigger(t: Dictionary) -> void:
	locked = true
	_vx = 0
	if t.has("bgm"):
		Audio.play_music(t.bgm)
	if t.has("event"):
		await handle_event(t.event)
	if t.has("dialogue"):
		await UI.run(t.dialogue)
	_update_npc_visibility()
	_refresh_hints()
	Game.save_game()
	locked = false

# =========================================================
# 걸으면서 일어나는 작은 일 (말풍선 · 소리 · 그림자)
# =========================================================
func _ambient(t: Dictionary) -> void:
	if t.has("amb"):
		for a in str(t.amb).split(","):
			_amb_event(a.strip_edges())
	if t.has("barks"):
		_bark_queue.append_array(t.barks)
		if not _barking:
			_run_barks()

func _run_barks() -> void:
	_barking = true
	while not _bark_queue.is_empty() and is_inside_tree():
		var b: Array = _bark_queue.pop_front()
		while (UI.busy or locked) and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree():
			return
		await _bark(b[0], b[1])
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.35).timeout
	_barking = false

func _bark(who: String, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Game.font_ui)
	l.add_theme_font_size_override("font_size", 23)
	var col := Color("fff6e2")
	if who == "":
		col = Color("e2dcf2")
	elif who == "서문경":
		col = Color("ffe7b8")
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	l.size = Vector2(520, 30)
	l.modulate.a = 0
	l.z_index = 60
	_world.add_child(l)
	var dur := clampf(1.6 + text.length() * 0.085, 2.2, 5.0)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	var t := 0.0
	while t < dur and is_instance_valid(l) and is_inside_tree():
		var x := px
		var y := GROUND_Y - 260.0
		if who == "서문경" and _seo != null:
			x = _seo_x
			y = GROUND_Y - (300.0 if _seo_mounted else 260.0)
		elif who == "최헌" or who == "":
			y = GROUND_Y - (300.0 if mounted else 260.0)
			if who == "":
				y -= 26
		elif _npcs.has(who):
			x = _npcs[who].node.position.x
		l.position = Vector2(x - 260, y)
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(l):
		var tw2 := create_tween()
		tw2.tween_property(l, "modulate:a", 0.0, 0.4)
		tw2.tween_callback(l.queue_free)

func _amb_event(a: String) -> void:
	match a:
		"sob":
			Audio.sfx("sob", -6)
		"crows":
			Audio.sfx("crow", -8)
			for i in 6:
				var kind: int = [0, 6, 11][i % 3]     # 세 종류 까마귀, 날갯짓 5장씩
				var m := _anim_sprite(MON_DIR + "crow_%d.png", 5, randf_range(9.0, 12.0), cam_x + 1360 + i * 80, false, 40)
				m.i0 = kind
				m.t = randf() * 2.0
				var c: Sprite2D = m.sprite
				var sc := randf_range(0.32, 0.45)
				c.scale = Vector2(sc, sc)
				c.position.y = 190 + randf_range(-50, 60)
				var tw := create_tween()
				tw.tween_property(c, "position", c.position + Vector2(-1750, randf_range(-90, 20)), randf_range(5.0, 7.0))
				tw.tween_callback(func(): _kill_mon(m))
		"gust":
			Audio.sfx("gust", -6)
			for pair in _fx:
				if pair[1] == "leaves":
					var p: CPUParticles2D = pair[0]
					p.speed_scale = 2.4
					await get_tree().create_timer(2.5).timeout
					if is_instance_valid(p):
						p.speed_scale = 1.0
		"dog":
			Audio.sfx("dog", -12)
		"owl":
			Audio.sfx("owl", -10)
		"whisper":
			Audio.sfx("whisper", -14)
		"steps_behind":
			for i in 4:
				Audio.sfx("step", -16 + i, 0.8)
				await get_tree().create_timer(0.45).timeout
		"redeyes":
			_red_eyes(cam_x + randf_range(900, 1150), randf_range(370, 450))
			Audio.sfx("heartbeat", -12)
		"redeyes2":
			_red_eyes(cam_x + 1000, 400)
			_red_eyes(cam_x + 1180, 370)
			_red_eyes(cam_x + 300, 420)
		"growl":
			Audio.sfx("growl", -10)
		"neigh":
			Audio.sfx("neigh", -12)
		"bell":
			Audio.sfx("bell_ring", -14, 0.9)

# =========================================================
# 괴물 · 움직이는 그림
# =========================================================
func _anim_sprite(fmt: String, n: int, fps: float, x: float, flip := false, z := 4) -> Dictionary:
	var s := _char_sprite(fmt % 0)
	s.position = Vector2(x, GROUND_Y)
	s.flip_h = flip
	s.z_index = z
	_world.add_child(s)
	var m := {"sprite": s, "fmt": fmt, "n": n, "fps": fps, "t": 0.0, "i0": 0}
	_mons.append(m)
	return m

func _update_mons(delta: float) -> void:
	for m in _mons.duplicate():
		if not is_instance_valid(m.sprite):
			_mons.erase(m)
			continue
		m.t += delta
		if m.fps > 0:
			_set_tex(m.sprite, m.fmt % (m.i0 + int(m.t * m.fps) % m.n))

func _kill_mon(m: Dictionary, fade := 0.0) -> void:
	if not is_instance_valid(m.sprite):
		return
	if fade > 0:
		var tw := create_tween()
		tw.tween_property(m.sprite, "modulate:a", 0.0, fade)
		await _tw_wait(tw)
	if is_instance_valid(m.sprite):
		m.sprite.queue_free()
	_mons.erase(m)

func _red_eyes(x: float, y: float) -> void:
	var m := _anim_sprite(MON_DIR + "redeyes_%d.png", 4, 3.0, x, false, -25)
	m.sprite.position.y = y
	m.sprite.scale = Vector2(0.3, 0.3)   # 2.3: 수풀 속 짐승 눈 3/5 크기
	m.sprite.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(m.sprite, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(m.sprite, "modulate:a", 0.0, 0.3)
	await _tw_wait(tw)
	_kill_mon(m)

func red_flash(times := 3, a := 0.6) -> void:
	for i in times:
		_red.color.a = a
		await get_tree().create_timer(0.07).timeout
		_red.color.a = 0.0
		await get_tree().create_timer(0.12).timeout

## 괴물에게 당하는 장면 → 「길을 잃었다」 → 다시하기 / 타이틀로
func _attack(kind: String) -> void:
	Audio.stop_music(0.1)
	match kind:
		"jangsan":
			# 등 뒤(왼쪽)에서 하얀 짐승이 덮친다
			facing = -1
			var m := _anim_sprite(MON_DIR + "jangsan_%d.png", 3, 5.0, cam_x - 260, false, 6)
			Audio.sfx("whisper", -2)
			await get_tree().create_timer(0.6).timeout
			var tw := create_tween()
			tw.tween_property(m.sprite, "position:x", px - 150, 0.9).set_ease(Tween.EASE_OUT)
			await _tw_wait(tw)
			m.fps = 0
			Audio.sfx("screech", 0)
			for k in [3, 4]:
				_set_tex(m.sprite, MON_DIR + "jangsan_%d.png" % k)
				shake(1.0)
				await get_tree().create_timer(0.16).timeout
		"woman":
			var m: Dictionary
			if _mons_named.has("woman") and is_instance_valid(_mons_named.woman.sprite):
				m = _mons_named.woman
			else:
				m = _anim_sprite(MON_DIR + "woman_%d.png", 1, 0.0, A.get("woman_x", px + 300), false, 6)
				_mons_named["woman"] = m
			var sp: Sprite2D = m.sprite
			m.fps = 0.0
			sp.z_index = 6
			sp.modulate = Color.WHITE
			sp.flip_h = sp.position.x < px
			_set_tex(sp, MON_DIR + "woman_2.png")
			await get_tree().create_timer(0.35).timeout
			Audio.sfx("scream", 0)
			_set_tex(sp, MON_DIR + "woman_1.png")
			var tw := create_tween()
			tw.tween_property(sp, "position:x", px + (60 if sp.position.x > px else -60), 0.4).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(sp, "scale", sp.scale * 1.35, 0.4)
			await _tw_wait(tw)
			_set_tex(sp, MON_DIR + "woman_0.png")
			shake(1.2)
		"scarecrow":
			Audio.sfx("screech", -4, 0.6)
			shake(1.2)
	await red_flash(4, 0.7)
	_black.color.a = 1.0
	Audio.sfx("thud", -2)
	for m in _mons.duplicate():
		_kill_mon(m)

func _game_over(kind: String, reward: String) -> bool:
	locked = true
	await _attack(kind)
	await get_tree().create_timer(0.8).timeout
	var r: String = await UI.game_over()
	if r == "title":
		Game.go_title()
		return false
	# 다시하기: 바로 앞 선택지로
	if kind == "woman":
		# 다시 눈을 뜨면 여인은 없고, 그 자리에 가락지만 떨어져 있다
		Game.set_flag("woman_gone")
		if _mons_named.has("woman"):
			_kill_mon(_mons_named.woman)
			_mons_named.erase("woman")
	Audio.play_music(A.bgm, 1.5)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 0.0, 1.2)
	await _tw_wait(tw)
	if reward != "" and not Game.has_item(reward):
		await get_tree().create_timer(0.3).timeout
		UI.toast("…길을 잃었던 자리에, 무언가 떨어져 있다.", 3.0)
		await get_tree().create_timer(1.2).timeout
		await UI.item_get(reward)
	return true

# =========================================================
# 추격
# =========================================================
func _start_chase() -> void:
	var m: Dictionary
	if _mons_named.has("scarecrow") and is_instance_valid(_mons_named.scarecrow.sprite):
		m = _mons_named.scarecrow
	else:
		m = _anim_sprite(MON_DIR + "scarecrow_%d.png", 8, 10.0, px - 800, false, 5)
	_mons_named.erase("scarecrow")
	m.n = 8
	m.fps = 10.0
	m.i0 = 0
	m.sprite.flip_h = false
	m.sprite.modulate = Color.WHITE
	_chase = {"m": m, "x": m.sprite.position.x, "v": 0.0, "start": px, "delay": 1.0, "rush": 0.0, "bob": 0.0}
	Audio.play_music("chase", 0.3)
	Audio.sfx("rush", -2)
	UI.toast("Shift  달리기  —  붙잡히면 안 된다!", 4.0)
	_refresh_hints()

func _update_chase(delta: float) -> void:
	if locked or UI.busy or UI.overlay != "":
		return
	var m: Dictionary = _chase.m
	var gap: float = px - _chase.x
	if _chase.delay > 0:
		_chase.delay -= delta
	else:
		# 달리는 동안엔 등 뒤 120px 쯤, 걷거나 멈추면 70px 까지 바짝 붙는다 — 하지만 잡지는 않는다 (2.2)
		# 2.3: 확 빨라져 바짝 붙었다가 → 속도가 줄며 조금 멀어지고 → 다시 확 빨라지는 것을 되풀이한다
		_chase.pt = _chase.get("pt", 0.0) - delta
		var surge: bool = _chase.get("phase", "surge") == "surge"
		if surge and (_chase.pt <= 0.0 or gap < 175.0):
			_chase.phase = "ease"
			_chase.pt = randf_range(1.4, 2.0)
			surge = false
		elif not surge and (_chase.pt <= 0.0 or gap > 440.0):
			_chase.phase = "surge"
			_chase.pt = 2.4
			surge = true
			Audio.sfx("rush", -4, randf_range(1.0, 1.1))
		var target := (150.0 if _running else 125.0) if surge else 430.0
		var cap := CHASER_SPEED * 1.4 if surge else WALK_SPEED * 1.15   # 빨라질 땐 달리기보다 빠르게, 느려질 땐 걷기 정도로
		var want := maxf(_vx, 0.0) + (gap - target) * 3.2
		want = clampf(want, 0.0 if gap < 120.0 else WALK_SPEED * 0.75, cap)   # 느려질 때도 멈추지는 않고 계속 기어 온다
		_chase.v = lerpf(_chase.v, want, minf(1.0, delta * (5.0 if surge else 2.5)))
		_chase.x += _chase.v * delta
	_chase.x = maxf(_chase.x, cam_x - 300)   # 화면 밖에서 너무 멀어지지 않게
	_chase.bob += delta * 18.0
	m.sprite.position = Vector2(_chase.x, GROUND_Y - absf(sin(_chase.bob)) * 4.0)
	m.fps = 8.0 + _chase.v / 30.0
	# 가까울수록 두두두두
	_chase.rush -= delta
	if gap < 420 and _chase.rush <= 0:
		Audio.sfx("rush", -2 if gap < 180 else -8, randf_range(0.95, 1.08))
		_chase.rush = 1.3
	if gap < 160 and _chase.get("lunge", 0.0) <= 0.0:
		# 바짝 붙으면 손톱을 휘두르며 위협한다 (화면이 흔들리고 붉게 번쩍)
		_chase.lunge = 2.2
		Audio.sfx("screech", -8, 0.8)
		shake(0.5)
		red_flash(1, 0.3)
	_chase.lunge = _chase.get("lunge", 0.0) - delta
	if px >= float(A.get("chase_end", W)):
		_chase_escape()

func _chase_caught() -> void:
	var start: float = _chase.start
	var m: Dictionary = _chase.m
	_chase = {}
	m.fps = 0.0
	var tw := create_tween()
	tw.tween_property(m.sprite, "position", Vector2(px - 10, GROUND_Y - 30), 0.15)
	var ok := await _game_over("scarecrow", "")
	_kill_mon(m)
	if not ok:
		return
	px = start
	facing = 1
	_update_camera(true)
	locked = false
	_start_chase()

func _chase_escape() -> void:
	var m: Dictionary = _chase.m
	_chase = {}
	locked = true
	_vx = 0
	Game.set_flag("chase_done")
	# 허수아비가 연기처럼 흩어진다
	m.fps = 0
	var tw := create_tween()
	tw.tween_property(m.sprite, "modulate", Color(0.6, 0.6, 0.7, 0.0), 1.4)
	tw.parallel().tween_property(m.sprite, "scale", Vector2(0.62, 0.42), 1.4)
	Audio.sfx("gust", -2)
	Audio.stop_music(2.0)
	await _tw_wait(tw)
	_kill_mon(m)
	_refresh_hints()
	await UI.run("ch4_escape")
	Game.save_game()
	locked = false

# =========================================================
# 이벤트 (대사 속 {"event": ...})
# =========================================================
func handle_event(name: String) -> void:
	if OS.has_environment("CWR_DRIVE"):
		print("[ev] ", name)
	match name:
		"hint_move":
			UI.toast("← →  이동      E  살펴보기 · 말 걸기", 4.5)
		"hint_horse":
			UI.toast("R  말에 타기 · 내리기", 4.5)
			_refresh_hints()
		"hint_dismount":
			UI.toast("R  말에서 내리기", 3.0)
		"hint_map":
			UI.toast("M  지도를 펼쳐 볼 수 있다", 4.0)
			_refresh_hints()
		"hint_map_guide":
			Game.set_flag("map_guide")
			UI.toast("M  지도를 펼쳐 보자", 3.5)
		"hint_inn":
			UI.toast("주막 방문 앞에서 E  ·  잠자리에 들 수 있다", 4.0)
		"seo_follow":
			Game.set_flag("seo_following")
			_seo_follow = true
			_seo_mounted = mounted
		"flame_appear":
			Audio.sfx("whoosh", -2)
			Audio.play_music("dokkaebi", 2.5)
			Audio.play_amb(["wind", ""], 2.0)
			_flame.position = Vector2(px + 460, FLAME_Y - 30)
			_flame.modulate.a = 0
			_flame.visible = true
			_flame_mode = "follow"
			facing = 1
			create_tween().tween_property(_flame, "modulate:a", 1.0, 2.0)
			await get_tree().create_timer(2.0).timeout
		"flame_block_fork":
			await _flame_dash(Vector2(A.get("flame", {}).get("fork_x", px + 160), FLAME_Y + 30))
		"flame_resume":
			_flame_mode = "follow"
		"flame_bar_way":
			await _flame_bar_way()
		"flame_hold":
			_flame_mode = "hold"
			_flame_target = Vector2(A.get("flame", {}).get("hold_x", px + 200), FLAME_Y)
		"flame_hold_here":
			Game.set_flag("sindang_hold")
			_flame_mode = "hold"
			_flame_target = Vector2(A.get("flame", {}).get("hold_x", px), FLAME_Y)
		"flame_block_back":
			facing = -1
			await _flame_dash(Vector2(px - 130, FLAME_Y + 30))
		"flame_away":
			# 불이 멀찍이 물러나 목소리 쪽을 비켜 준다
			_flame_mode = "block"
			_flame_target = Vector2(px + 380, FLAME_Y - 40)
			await get_tree().create_timer(0.5).timeout
		"hint_sleep":
			UI.toast("방 앞에서 E  ·  잠자리에 들 수 있다", 4.0)
		"silence":
			Audio.stop_music(1.2)
			Audio.play_amb([], 1.2)
			await get_tree().create_timer(1.3).timeout
		"search_back":
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 1.0, 0.8)
			await _tw_wait(tw)
			Audio.sfx("step", -10)
		"search_return":
			await get_tree().create_timer(0.3).timeout
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.0, 1.2)
			await _tw_wait(tw)
		"blood_map":
			Game.set_flag("blood_map")
			UI.open_map()
			await UI.overlay_closed
			_refresh_hints()
		"map_check":
			UI.open_map()
			await UI.overlay_closed
		"figure_pass":
			await _figure_pass()
		"figure_stand":
			_figure = _char_sprite(CHAR_DIR + "adukshini_sit.png")
			_figure.modulate = Color(0, 0, 0, 0)
			_figure.position = Vector2(px - 420, GROUND_Y)
			_figure.z_index = 1
			_world.add_child(_figure)
			facing = -1
			_psprite.flip_h = true
			Audio.sfx("heartbeat", -6)
			create_tween().tween_property(_figure, "modulate", Color(0.02, 0.02, 0.05, 0.92), 2.0)
			await get_tree().create_timer(1.8).timeout
		"approach_figure":
			facing = -1
			var target := _figure.position.x + 120 if _figure else px - 300
			# 천천히 걸어서 다가간다 (걷기 속도의 절반쯤)
			var tw := create_tween()
			tw.tween_property(self, "px", target, absf(px - target) / 85.0)
			for i in 4:
				Audio.sfx("heartbeat", -4 + i * 2)
				await get_tree().create_timer(0.8).timeout
		"five_flames":
			# 그림자 주위로 작은 불 다섯이 켜지고, 그림자가 일어서며 커진다
			if _figure:
				var fx0 := _figure.position.x
				for i in 5:
					var n := Node2D.new()
					var a := -PI * (0.15 + 0.7 * i / 4.0)
					n.position = Vector2(fx0 + cos(a) * 150, GROUND_Y - 110 + sin(a) * 120)
					n.add_child(_glow_sprite(Color("5a86ff"), 60))
					var sp := Sprite2D.new()
					sp.texture = _tex_of(CHAR_DIR + "flame_%d.png" % (i % 3))
					sp.scale = Vector2(0.3, 0.3)
					n.add_child(sp)
					n.modulate.a = 0
					_glow_root.add_child(n)
					create_tween().tween_property(n, "modulate:a", 1.0, 0.4)
					Audio.sfx("flame_flare", -14 + i)
					await get_tree().create_timer(0.45).timeout
				# 일어선 그림자가 기괴하게 부풀며 두 배로 커진다 (머리카락이 자라나는 6장)
				Audio.sfx("rumble", -2)
				_set_tex(_figure, CHAR_DIR + "adukshini_morph_0.png")
				_figure.modulate = Color(0, 0, 0.02, 1.0)
				var base := _figure.scale
				await get_tree().create_timer(0.5).timeout
				for k in range(1, 6):
					_set_tex(_figure, CHAR_DIR + "adukshini_morph_%d.png" % k)
					# 잔상
					var ghost := _char_sprite(CHAR_DIR + "adukshini_morph_%d.png" % (k - 1))
					ghost.position = _figure.position
					ghost.scale = _figure.scale
					ghost.modulate = Color(0.25, 0, 0.05, 0.55)
					ghost.z_index = _figure.z_index - 1
					_world.add_child(ghost)
					var gt := create_tween()
					gt.tween_property(ghost, "scale", ghost.scale * 1.12, 0.5)
					gt.parallel().tween_property(ghost, "modulate:a", 0.0, 0.5)
					gt.tween_callback(ghost.queue_free)
					var tw := create_tween()
					tw.tween_property(_figure, "scale", base * (1.0 + 0.14 * k) * Vector2(1.06, 0.97), 0.18).set_ease(Tween.EASE_OUT)
					tw.tween_property(_figure, "scale", base * (1.0 + 0.14 * k), 0.22)   # 마지막에 꼭 1.7배
					shake(0.25 + 0.12 * k)
					Audio.sfx("heartbeat", -6 + k * 2, 0.9 - k * 0.05)
					if k == 2:
						_morph_startle()   # 2.3: 커지는 그림자에 최헌이 놀라 뒷걸음질
					await _tw_wait(tw)
					await get_tree().create_timer(0.25).timeout
				Audio.sfx("glitch", -4)
				await red_flash(2, 0.5)
		"thud":
			_black.color.a = 1.0
			Audio.stop_music(0.05)
			Audio.play_amb([], 0.05)
			Audio.sfx("thud", 0)
			UI.set_hud_visible(false)
			Game.set_flag("ch4_done")
			Game.save_game()
			await get_tree().create_timer(5.0).timeout
			var past := {"type": "area", "area": "past", "spawn": "left", "card": ["終章", "이름", "누군가의 과거……, 그리고 봉인."]}
			# [Animation-4] 그림이 들어오면 (assets/anim/anim_past) 그것부터 보여 준다
			if ResourceLoader.exists("res://assets/anim/anim_past/000.webp"):
				Game.route({"type": "anim", "anim": "anim_past", "music": "past", "next": past})
			else:
				Game.route(past)
		"anim2":
			await _go({"type": "anim", "anim": "anim2", "music": "night", "next": {"type": "area", "area": "road4", "spawn": "left", "x": A.get("voice_x", 6880), "run": "ch2_voice_after"}})
		"anim3":
			await _go({"type": "anim", "anim": "anim3", "music": "shrine", "sfx": "bell_ring", "next": {"type": "area", "area": "sindang", "spawn": "after", "run": "ch3_after"}})
		"anim4":
			await _go({"type": "anim", "anim": "anim4", "music": "past", "next": {"type": "area", "area": "past", "spawn": "seal", "run": "end_curse"}})
		"to_hall":
			await _chapter_transition(["", "그리고, 지금", ""], {"type": "area", "area": "hall", "spawn": "left", "card": ["", "그리고, 지금", "한양"]}, false)
		"anim5":
			await _go({"type": "still", "image": "", "dialogue": "end_seo_before", "music": "night",
				"next": {"type": "anim", "anim": "anim5", "music": "dokkaebi",
					"next": {"type": "still", "image": "", "dialogue": "end_seo_after", "music": "night",
						"next": {"type": "area", "area": "hall", "spawn": "after", "run": "end_burn"}}}})
		"name_input":
			await UI.name_input()
		"burn":
			Audio.sfx("burn", -2)
			for i in 5:
				var g := _glow_sprite(Color("5a86ff"), 60)
				g.position = Vector2(1500 + randf_range(-30, 30), GROUND_Y - 20 + randf_range(-10, 10))
				_glow_root.add_child(g)
			shake(0.2)
		"adukshini_appear":
			Audio.play_music("adukshini", 2.0)
			Audio.sfx("whoosh", -2)
			for p in [[700, 0], [1150, 0], [1900, 0], [2250, 0], [450, 0], [1700, -150], [2000, -190]]:
				var n := _glow_sprite(Color("5a86ff"), 90)
				n.position = Vector2(p[0], GROUND_Y + 10 + p[1])
				n.modulate.a = 0
				_glow_root.add_child(n)
				create_tween().tween_property(n, "modulate:a", 1.0, 1.5)
			_aduk_aura(1820.0)
			_figure = _char_sprite(CHAR_DIR + "adukshini_front.png")
			_figure.position = Vector2(1820, GROUND_Y)
			_figure.modulate.a = 0
			_figure.z_index = 2
			_world.add_child(_figure)
			facing = 1
			create_tween().tween_property(_figure, "modulate:a", 1.0, 2.5)
			shake(0.5)
			await get_tree().create_timer(2.0).timeout
		"final_still":
			await _go({"type": "still", "image": "res://assets/bg/background2.png", "dialogue": "end_final", "music": "adukshini",
				"next": {"type": "still", "image": "", "credits": true, "music": "ending"}})
		"ch2_end":
			await _chapter_transition(["第二章", "「어린시절의 꿈」", "끝"], {"type": "area", "area": "uiheung_morning", "spawn": "start", "dismount": true,
				"card": ["第三章", "문을 닫는 자", "의흥  →  함창  →  상주"]})
		"ch3_forced_end":
			await _forced_end()
		"flame_flare":
			var tw := create_tween()
			tw.tween_property(_flame_glow, "scale", _flame_glow.scale * 1.8, 0.25)
			tw.tween_property(_flame_glow, "scale", _flame_glow.scale, 0.8)
			shake(0.2)
			await _tw_wait(tw)
		"rocks_fall":
			await _rocks_fall()
		"flame_vanish":
			_flame_mode = "vanish"
			var tw := create_tween()
			tw.tween_property(_flame, "modulate:a", 0.0, 2.2)
			Audio.play_music("night", 3.0)
			Audio.play_amb(["wind", "crickets"], 3.0)
			await _tw_wait(tw)
			_flame.visible = false
		"chapter_end":
			await _chapter_end()
		"lights_out":
			Audio.stop_music(2.0)
			Audio.play_amb(["", ""], 2.5)
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.9, 1.8)
			await _tw_wait(tw)
			await get_tree().create_timer(0.8).timeout
		"lights_up":
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.0, 1.4)
			await _tw_wait(tw)
		"choice_moment":
			Audio.stop_music(1.5)
			Audio.sfx("heartbeat", -8)
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.45, 1.2)
			await _tw_wait(tw)
		"choice_release":
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.0, 1.2)
			await _tw_wait(tw)
		"leave_moment":
			Audio.sfx("sting", -6)
			Audio.sfx("card", -8)
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.75, 1.0)
			await _tw_wait(tw)
			await get_tree().create_timer(0.6).timeout
		"leave_after":
			var tw := create_tween()
			tw.tween_property(_black, "color:a", 0.0, 2.0)
			Audio.play_music(A.bgm, 3.0)
			await _tw_wait(tw)
		"go_search":
			await _go({"type": "area", "area": "search_pass", "spawn": "right", "dismount": true})
		"search_finish":
			await _go({"type": "area", "area": "sinnyeong_morning", "spawn": "left", "run": "ch2_after_search"})
		"crow":
			Audio.sfx("crow", -4)
			await get_tree().create_timer(0.8).timeout
		"crows_fly":
			_amb_event("crows")
			await get_tree().create_timer(1.2).timeout
		"sangyeo":
			Audio.stop_music(1.0)
			Audio.sfx("sangyeo", -2)
			var tw := create_tween()
			tw.tween_property(self, "tint_dark", 0.4, 3.0)
			await get_tree().create_timer(3.5).timeout
		"tint_restore":
			var tw := create_tween()
			tw.tween_property(self, "tint_dark", 0.0, 2.5)
		"wake":
			pose = "lie"
			await get_tree().create_timer(1.0).timeout
			Audio.sfx("cloth", -8)
			pose = "sit"
			await get_tree().create_timer(1.1).timeout
			Audio.sfx("cloth", -10)
			pose = ""
			await get_tree().create_timer(0.4).timeout
		"bench_sit":
			px = 2245.0
			facing = 1
			mounted = false
			pose = "sit"
			_seo_follow = false
			_seo_x = 2340.0
			_seo_pose = "sit"
			_bench_dy = 50.0   # 2.3: 평상을 12px 올리고 그라운드 라인을 8px 내린 만큼
			_update_camera(true)
			_apply_player_look()
			_update_seo_look(false)
		"bench_stand":
			_bench_dy = 0.0
			pose = ""
			_seo_pose = ""
			_seo_follow = true
			_update_seo_look(false)
		"fall_down":
			await _fall_from_horse()
		"horse_rear":
			Audio.sfx("neigh", -2)
			shake(0.8)
			var tw := create_tween()
			tw.tween_property(_psprite, "rotation", -0.35, 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_property(_psprite, "rotation", 0.0, 0.3)
			await _tw_wait(tw)
		"bulgasari":
			Audio.sfx("rumble", -2)
			shake(0.6)
			var m := _anim_sprite(MON_DIR + "bulgasari_%d.png", 3, 3.0, cam_x + 1500, false, 4)
			_props["bulgasari"] = m.sprite
			_mons_named["bulgasari"] = m
			var tw := create_tween()
			tw.tween_property(m.sprite, "position:x", px + 430, 3.0).set_ease(Tween.EASE_OUT)
			Audio.sfx("growl", 0)
			await _tw_wait(tw)
		"bulgasari_lunge":
			if _mons_named.has("bulgasari"):
				var m: Dictionary = _mons_named.bulgasari
				Audio.sfx("growl", 2)
				var tw := create_tween()
				tw.tween_property(m.sprite, "position:x", px + 120, 0.35).set_ease(Tween.EASE_IN)
				await _tw_wait(tw)
				shake(1.4)
		"hands_burst":
			await _hands_burst()
		"hands_grab":
			# 붉게 번쩍이며, 땅에서 솟은 손들이 발목을 움켜쥔다
			Audio.sfx("sting", 0)
			Audio.sfx("glitch", -6)
			red_flash(3, 0.5)
			pose = "startled"
			_set_tex(_psprite, _player_tex())
			for i in 4:
				_hand_at(px + [-46, -16, 18, 44][i], 0.42, i * 0.05, 1.6)
			for i in 5:
				_hand_at(px + randf_range(-420, 460), 0.4, 0.3 + i * 0.12, 1.8)
			shake(1.0)
			await get_tree().create_timer(1.0).timeout
			Audio.sfx("scratch", -4, 0.7)
			await get_tree().create_timer(1.4).timeout
			pose = ""
			_set_tex(_psprite, _player_tex())
		"crow_speak":
			# 가지 위 까마귀 한 마리가 최헌을 내려다본다
			var c := _char_sprite(MON_DIR + "crow_perch.png")   # 제 발밑 잔가지를 지운 그림 (배경 가지에 앉는다)
			var perch: Array = A.get("crow_perch", [px + 210, GROUND_Y - 250])
			c.position = Vector2(perch[0], perch[1])
			c.scale = Vector2(0.55, 0.55)
			c.flip_h = false     # 왼쪽(최헌 쪽)을 본다
			c.z_index = 20
			c.modulate.a = 0
			_world.add_child(c)
			_mons_named["crow"] = {"sprite": c}
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 1.0, 0.4)
			tw.tween_property(c, "rotation", 0.12, 0.25)
			tw.tween_property(c, "rotation", 0.0, 0.25)
			await _tw_wait(tw)
		"crow_away":
			if _mons_named.has("crow") and is_instance_valid(_mons_named.crow.sprite):
				var c: Sprite2D = _mons_named.crow.sprite
				_mons_named.erase("crow")
				var m := _anim_sprite(MON_DIR + "crow_%d.png", 5, 12.0, c.position.x, false, 20)
				m.sprite.position.y = c.position.y
				m.sprite.scale = c.scale
				c.queue_free()
				Audio.sfx("crow", -4)
				var tw := create_tween()
				tw.tween_property(m.sprite, "position", m.sprite.position + Vector2(-900, -320), 2.2).set_ease(Tween.EASE_IN)
				tw.tween_callback(func(): _kill_mon(m))
			_amb_event("crows")
			await get_tree().create_timer(1.0).timeout
		"hands_ring":
			# 사방에서 손과 눈이 고개를 내민다 (기괴한 숲 들머리)
			Audio.sfx("whisper", -6)
			for i in 6:
				var hx := px + randf_range(-520, 620)
				_hand_at(hx, 0.45, 0.6 + i * 0.15, 4.0)
			for i in 3:
				_eye_at(cam_x + randf_range(150, 1150), randf_range(240, 380), 4.5)
			await get_tree().create_timer(1.6).timeout
		"eyes_open":
			Audio.sfx("sting", -6)
			for i in 7:
				_eye_at(cam_x + 120 + i * 170 + randf_range(-40, 40), randf_range(200, 360), 30.0)   # 대사 동안 떠 있다가 eyes_close 에서 감긴다
				await get_tree().create_timer(0.12).timeout
			Audio.sfx("heartbeat", -4)
			await get_tree().create_timer(2.6).timeout
		"eyes_close":
			# 허공의 눈들이 한꺼번에 감기며 사라진다
			Audio.sfx("whoosh", -8, 0.7)
			for m in _mons.duplicate():
				if is_instance_valid(m.sprite) and m.fmt.ends_with("eye_%d.png"):
					_set_tex(m.sprite, MON_DIR + "eye_1.png")
					var tw := create_tween()
					tw.tween_property(m.sprite, "modulate:a", 0.0, 0.35)
					tw.tween_callback(func(): _kill_mon(m))
			for g in _eye_glows:
				if is_instance_valid(g):
					var tw := create_tween()
					tw.tween_property(g, "modulate:a", 0.0, 0.3)
					tw.tween_callback(g.queue_free)
			_eye_glows.clear()
			await get_tree().create_timer(0.5).timeout
		"eye_drop":
			Audio.sfx("sting", -6)
			for i in 5:
				_eyeball_drop(px + randf_range(-380, 420), i * randf_range(0.18, 0.3))
			await get_tree().create_timer(1.8).timeout
		"redeyes":
			_amb_event("redeyes2")
			await get_tree().create_timer(1.5).timeout
		"woman_show":
			# 이미 앉아 있다. 혹시 없으면 그 자리에 다시 앉힌다
			if not _mons_named.has("woman") or not is_instance_valid(_mons_named.woman.sprite):
				var x: float = A.get("woman_x", px + 300)
				var m := _anim_sprite(MON_DIR + "woman_%d.png", 1, 0.0, x, false, 2)
				m.i0 = 3
				_set_tex(m.sprite, MON_DIR + "woman_3.png")
				_mons_named["woman"] = m
		"woman_stand":
			if _mons_named.has("woman"):
				var m: Dictionary = _mons_named.woman
				_set_tex(m.sprite, MON_DIR + "woman_2.png")
				Audio.sfx("heartbeat", -6)
				var tw := create_tween()
				tw.tween_property(m.sprite, "position:x", m.sprite.position.x - 14, 0.6)
				await _tw_wait(tw)
		"woman_vanish", "woman_gone":
			Game.set_flag("woman_gone")
			if _mons_named.has("woman"):
				await _kill_mon(_mons_named.woman, 1.6)
				_mons_named.erase("woman")
		"horse_ghost":
			Audio.sfx("neigh", 0, 0.8)
			var m := _anim_sprite(MON_DIR + "horse_ghost_%d.png", 4, 12.0, cam_x + 1500, false, 6)
			var tw := create_tween()
			tw.tween_property(m.sprite, "position:x", cam_x - 450, 1.3)
			for i in 6:
				Audio.sfx("hoof" if i % 2 == 0 else "hoof2", -2, 0.75)
				if i == 3:
					shake(0.9)
					red_flash(2, 0.55)
				await get_tree().create_timer(0.2).timeout
			await _tw_wait(tw)
			_kill_mon(m)
		"chase_start":
			_start_chase()
		"scarecrow_show":
			# 어둠 속에서 스르륵 — 땅에서 배어 나오듯 천천히 드러난다 (그림은 원래 오른쪽을 본다)
			var m := _anim_sprite(MON_DIR + "scarecrow_%d.png", 1, 0.0, px - 620, false, 5)
			var sp: Sprite2D = m.sprite
			var base := sp.scale
			sp.modulate = Color(0.2, 0.18, 0.22, 0.0)
			sp.scale = base * Vector2(1.0, 0.25)
			sp.position.y = GROUND_Y + 40
			_mons_named["scarecrow"] = m
			Audio.sfx("scratch", -6, 0.6)
			Audio.sfx("whisper", -10, 0.7)
			var tw := create_tween()
			tw.tween_property(sp, "modulate", Color(0.75, 0.72, 0.75, 0.8), 1.6).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sp, "scale", base, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(sp, "position:y", GROUND_Y, 1.6).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sp, "position:x", px - 430, 1.6)   # 2.3: 속도가 같아져서(1.8배) 처음부터 화면 안에 보이게 조금 더 가까이
			tw.tween_property(sp, "modulate", Color.WHITE, 0.4)
			await _tw_wait(tw)
		"seo_ghost":
			# 거울 속에서 본 문경이가, 잠깐 빈자리에 앉아 있다
			# 2.2: 주인공 바로 뒤(등 쪽)에 선 채로, 다른 물건에 가리지 않게
			var g := _char_sprite(CHAR_DIR + "seo_front.png")
			g.position = Vector2(px - facing * 95.0, GROUND_Y)
			g.modulate = Color(0.55, 0.7, 1.0, 0.0)
			g.z_index = 2
			_world.add_child(g)
			Audio.sfx("drip", -4)
			var tw := create_tween()
			tw.tween_property(g, "modulate:a", 0.75, 0.25)
			tw.tween_interval(0.9)
			tw.tween_property(g, "modulate:a", 0.0, 0.6)
			tw.tween_callback(g.queue_free)
			await _tw_wait(tw)
		"enter_room":
			# 방으로 들어간다 (마루가 아니라 방 안에서 잔다)
			Audio.sfx("door", -6)
			var tw := create_tween()
			tw.tween_property(_psprite, "modulate:a", 0.0, 0.6)
			await _tw_wait(tw)
		"exit_room":
			Audio.sfx("door", -6)
			_psprite.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(_psprite, "modulate:a", 1.0, 0.6)
			await _tw_wait(tw)
		"look_back_pan":
			# 등 뒤에서 소리 → 돌아보면, 화면이 천천히 지나온 집 쪽으로 넘어간다
			facing = -1
			_psprite.flip_h = true
			_vx = 0.0
			await get_tree().create_timer(0.4).timeout
			var house_x: float = A.get("lookback_x", 1350)
			_cam_hold = cam_x
			var tw := create_tween()
			tw.tween_property(self, "_cam_hold", house_x - 640, 2.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			await _tw_wait(tw)
			Audio.sfx("wind_chime" if _has("res://assets/audio/sfx/wind_chime.ogg") else "bell_ring", -10, 0.7)
			await get_tree().create_timer(1.2).timeout
		"look_back_return":
			if _cam_hold >= 0.0:
				var tw := create_tween()
				tw.tween_property(self, "_cam_hold", clampf(px - 640 - 110, 0, W - 1280), 1.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				await _tw_wait(tw)
				_cam_hold = -1.0
		"jangsan_peek":
			# 첫 등장은 그림자뿐: 화면 가운데쯤 수풀 뒤에서 스르륵 나타나, 왼쪽으로 빠르게 사라진다 (약 1.5초)
			var m := _anim_sprite(MON_DIR + "jangsan_%d.png", 3, 6.0, cam_x + 780, true, -25)
			var sp: Sprite2D = m.sprite
			sp.modulate = Color(0.02, 0.02, 0.04, 0.0)
			sp.scale = Vector2(0.4, 0.4)
			sp.position.y = GROUND_Y - 6
			Audio.sfx("whisper", -6, 0.9)
			var tw := create_tween()
			tw.tween_property(sp, "modulate:a", 0.92, 0.5).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sp, "position:x", cam_x + 720, 0.5)
			tw.tween_property(sp, "position:x", cam_x + 330, 0.75).set_ease(Tween.EASE_IN)
			tw.tween_property(sp, "position:x", cam_x + 180, 0.35)
			tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.35)
			await _tw_wait(tw)
			_kill_mon(m)
		"ghost_prints":
			# 내 뒤로, 젖은 발자국 일곱이 빠르게 다가오며 찍힌다
			for i in 7:
				Audio.sfx("step", -10 + i, 0.75)
				var s := _add_decal("print_human", px - 520 + i * 66, float(i % 2) * 4, false)
				s.modulate = Color(0.55, 0.65, 0.9, 0.0)
				create_tween().tween_property(s, "modulate:a", 0.95, 0.12)
				await get_tree().create_timer(0.3 - i * 0.025).timeout
			pose = "startled"
			_set_tex(_psprite, _player_tex())
			await get_tree().create_timer(0.5).timeout
			pose = ""
			_set_tex(_psprite, _player_tex())
			Audio.sfx("sting", -2)
			shake(0.3)
		"glitch":
			Audio.sfx("rumble", 0)
			shake(1.0)
			for i in 6:
				Audio.sfx("glitch", -4)
				get_viewport().canvas_transform = Transform2D(0, Vector2(randf_range(-30, 30), randf_range(-6, 6)))
				_red.color = Color(randf(), 0.1, randf() * 0.6, 0.35)
				await get_tree().create_timer(0.09).timeout
				_red.color.a = 0.0
				_black.color.a = 0.8 if i % 2 == 0 else 0.0
				await get_tree().create_timer(0.07).timeout
			_red.color = Color(0.55, 0.0, 0.0, 0.0)
			_black.color.a = 0.0
		"red_flash":
			await red_flash(3, 0.6)
		"to_gisoe":
			Game.set_flag("ch3_bell")
			await _go({"type": "area", "area": "gisoe", "spawn": "left", "mount": true})
		"seo_lie":
			_seo_pose = "lie"
			_update_seo_look(false)
		"seo_sit":
			_seo_pose = "sit"
			_update_seo_look(false)
		"seal_kneel":
			pose = "kneel"
			_seal_shadow_in()
		"seal_bind":
			await _seal_shadow_bind()
		_:
			if name.begins_with("fade_npc:"):
				var nid := name.substr(9)
				if _npcs.has(nid):
					var nx: float = _npcs[nid].node.position.x
					facing = -1 if nx < px else 1
					_psprite.flip_h = facing < 0
					await get_tree().create_timer(1.2).timeout
					var tw := create_tween()
					tw.tween_property(_npcs[nid].node, "modulate:a", 0.0, 1.5)
					await _tw_wait(tw)
					_npcs[nid].node.visible = false
					_npcs[nid].node.modulate.a = 1.0
				Scenery.refresh(_scene.conds)
			elif name.begins_with("walk_away:"):
				await _walk_away(name.substr(10))
			elif name == "startle":
				# 깜짝 놀라 움찔한다
				var keep := pose
				pose = "startled"
				_set_tex(_psprite, _player_tex())
				Audio.sfx("cloth", -6, 1.3)
				var tw := create_tween()
				tw.tween_property(_psprite, "position:y", -14.0, 0.08).set_ease(Tween.EASE_OUT)
				tw.tween_property(_psprite, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
				await _tw_wait(tw)
				await get_tree().create_timer(0.7).timeout
				pose = keep
				_set_tex(_psprite, _player_tex())
			elif name.begins_with("pose:"):
				pose = name.substr(5)
				_set_tex(_psprite, _player_tex())
				await get_tree().create_timer(0.3).timeout
			elif name.begins_with("face:"):
				facing = int(name.substr(5))
				_psprite.flip_h = facing < 0
			elif name.begins_with("npc_up:"):
				Game.set_flag(name.substr(7) + "_up")
				Audio.sfx("cloth", -8)
				await get_tree().create_timer(0.5).timeout
			elif name.begins_with("still_on:"):
				await _still_on(name.substr(9))
			elif name == "still_off":
				await _still_off()
			elif name.begins_with("gameover:"):
				# gameover:<괴물>:<보상 아이템>
				var parts := name.split(":")
				await _game_over(parts[1], parts[2] if parts.size() > 2 else "")
			elif name.begins_with("toast:"):
				UI.toast(name.substr(6), 4.0)
			elif name.begins_with("bgm:"):
				Audio.play_music(name.substr(4), 2.0)
			elif name.begins_with("amb:"):
				_amb_event(name.substr(4))
	if is_inside_tree():
		await get_tree().process_frame

var _mons_named := {}

## 장면이 바뀐 뒤에도 남은 코루틴이 멈추도록: 기다린 뒤 아직 장면 안이면 true
func _wait(t: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(t).timeout
	return is_inside_tree()

func _hand_at(x: float, s: float, delay: float, hold: float) -> void:
	var kind := randi() % 3
	var sp := _char_sprite(MON_DIR + "hand_%d.png" % (kind * 5))
	sp.scale = Vector2(s, s)
	sp.position = Vector2(x, GROUND_Y + randf_range(4, 26))
	sp.z_index = 6 if randf() < 0.5 else -10
	sp.flip_h = randf() < 0.5
	sp.visible = false
	_world.add_child(sp)
	if not await _wait(delay): return
	if not is_instance_valid(sp):
		return
	sp.visible = true
	for k in 5:
		if not is_instance_valid(sp): return
		_set_tex(sp, MON_DIR + "hand_%d.png" % (kind * 5 + k))
		if not await _wait(0.06): return
	if not await _wait(hold): return
	for k in range(4, -1, -1):
		if not is_instance_valid(sp): return
		_set_tex(sp, MON_DIR + "hand_%d.png" % (kind * 5 + k))
		if not await _wait(0.08): return
	if is_instance_valid(sp):
		sp.queue_free()

## 하늘에서 눈알이 툭 떨어져 구르다가 터진다
func _eyeball_drop(x: float, delay: float) -> void:
	if not await _wait(delay): return
	var m := _anim_sprite(MON_DIR + "eyeball_%d.png", 8, 14.0, x, false, 6)
	var sp: Sprite2D = m.sprite
	var sc := randf_range(0.45, 0.6)
	sp.scale = Vector2(sc, sc)
	sp.position.y = -80.0
	var ground := GROUND_Y + randf_range(2, 14)
	var tw := create_tween()
	tw.tween_property(sp, "position:y", ground, randf_range(0.45, 0.6)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _tw_wait(tw)
	if not is_inside_tree() or not is_instance_valid(sp): return
	Audio.sfx("thud", -12, 1.8)
	# 한 번 튀고 구른다
	var dir := -1.0 if randf() < 0.5 else 1.0
	var tw2 := create_tween()
	tw2.tween_property(sp, "position:y", ground - 22, 0.14).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(sp, "position:x", sp.position.x + dir * 30, 0.3)
	tw2.tween_property(sp, "position:y", ground, 0.14).set_ease(Tween.EASE_IN)
	tw2.tween_property(sp, "position:x", sp.position.x + dir * 70, 0.5).set_ease(Tween.EASE_OUT)
	await _tw_wait(tw2)
	if not is_inside_tree() or not is_instance_valid(sp): return
	m.fps = 0.0
	_mons.erase(m)
	Audio.sfx("scratch", -14, 0.5)
	for k in 4:
		if not is_instance_valid(sp): return
		_set_tex(sp, MON_DIR + "eyeburst_%d.png" % k)
		if not await _wait(0.08): return

## 어둑시니 둘레: 발밑에서 피어오르는 검은 연기 + 둘레를 천천히 도는 도깨비불 + 푸른 불티
func _aduk_smoke(pos: Vector2, ext: Vector2, amount: int, alpha: float, z: int, size: float, col := Color(0, 0, 0)) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _tex_of("res://assets/scenery/fx_puff_px.png")
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pm := CanvasItemMaterial.new()
	pm.particles_animation = true
	pm.particles_anim_h_frames = 4
	pm.particles_anim_v_frames = 1
	p.material = pm
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	p.local_coords = false
	p.position = pos
	p.z_index = z
	p.amount = amount
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = ext
	p.direction = Vector2(0, -1)
	p.spread = 35
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 10
	p.initial_velocity_max = 30
	# 도트 연기: 돌리지 않고, 칸 크기를 (거의) 정수배로
	p.scale_amount_min = size * 3.0
	p.scale_amount_max = size * 4.5
	var c := Curve.new()
	c.add_point(Vector2(0, 0.75))
	c.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = c
	var g := Gradient.new()
	# 투명도도 계단식으로 (도트 느낌: 부드럽게 흐려지지 않고 뚝뚝 바뀐다)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, Color(col.r, col.g, col.b, alpha * 0.5))
	g.add_point(0.12, Color(col.r, col.g, col.b, alpha))
	g.add_point(0.62, Color(col.r, col.g, col.b, alpha * 0.6))
	g.add_point(0.85, Color(col.r, col.g, col.b, alpha * 0.3))
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0))
	p.color_ramp = g
	_world.add_child(p)
	return p

func _aduk_aura(x: float) -> void:
	var fx := Node2D.new()
	fx.modulate.a = 0
	_world.add_child(fx)
	# 검은 연기: 뒤쪽 큰 덩어리(몸 둘레) · 발밑 앞쪽 낮은 연기
	# 잿빛 테두리 연기(맨 뒤, 어두운 하늘에서도 보이게) → 검은 연기 → 발밑 연기
	var haze := _aduk_smoke(Vector2(x, GROUND_Y - 150), Vector2(150, 150), 46, 0.55, 0, 1.5, Color(0.20, 0.19, 0.30))
	haze.lifetime = 6.0
	haze.preprocess = 6.0
	var back := _aduk_smoke(Vector2(x, GROUND_Y - 110), Vector2(115, 125), 70, 1.0, 1, 1.2)
	var feet := _aduk_smoke(Vector2(x, GROUND_Y - 6), Vector2(190, 8), 34, 0.85, 3, 0.85)
	feet.initial_velocity_max = 9
	feet.gravity = Vector2(0, -3)
	for p in [haze, back, feet]:
		p.modulate.a = 0
		create_tween().tween_property(p, "modulate:a", 1.0, 1.6)
	# 푸른 불티
	var sp := Scenery.fireflies(26)
	sp.position = Vector2(x, GROUND_Y - 150)
	sp.emission_rect_extents = Vector2(190, 150)
	sp.gravity = Vector2(0, -10)
	sp.lifetime = 4.0
	sp.preprocess = 4.0
	sp.scale_amount_min = 0.15
	sp.scale_amount_max = 0.4
	var sg := Gradient.new()
	sg.set_color(0, Color(0.4, 0.6, 1.0, 0))
	sg.add_point(0.25, Color(0.5, 0.75, 1.0, 1))
	sg.add_point(0.6, Color(0.35, 0.55, 1.0, 0.5))
	sg.set_color(sg.get_point_count() - 1, Color(0.3, 0.4, 1.0, 0))
	sp.color_ramp = sg
	sp.z_index = 3
	sp.modulate.a = 0
	_world.add_child(sp)
	create_tween().tween_property(sp, "modulate:a", 1.0, 2.0)
	# 도깨비불: 몸 둘레를 타원으로 천천히 돈다 (앞쪽일 땐 인물 앞, 뒤쪽일 땐 뒤)
	var flames := []
	var n := 7
	for i in n:
		var f := Sprite2D.new()
		f.texture = _tex_of(CHAR_DIR + "flame_0.png")
		f.scale = Vector2.ONE * randf_range(0.26, 0.36)
		f.offset = Vector2(0, -75)
		var gl := _glow_sprite(Color("5a86ff"), 70)
		gl.position = Vector2(0, -40)
		gl.scale /= f.scale.x
		gl.show_behind_parent = true
		f.add_child(gl)
		fx.add_child(f)
		flames.append({"s": f, "a": TAU * i / n + randf_range(-0.3, 0.3), "h": randf_range(-40, 50),
			"rx": randf_range(130, 175), "ph": randf() * TAU, "sp": randf_range(0.8, 1.2)})
	var cy := GROUND_Y - 140.0
	fx.create_tween().set_loops().tween_method(func(t: float):
		for f in flames:
			var a: float = f.a + t * 0.25 * f.sp
			var s: Sprite2D = f.s
			s.position = Vector2(x + cos(a) * f.rx, cy + f.h + sin(a) * 26 + sin(t * 1.7 + f.ph) * 12)
			s.z_index = 3 if sin(a) > 0 else 1
			s.modulate = Color(1, 1, 1, 0.65 + 0.35 * (0.5 + 0.5 * sin(a)))
			s.texture = _tex_of(CHAR_DIR + "flame_%d.png" % (int(t * 7 + f.ph * 3) % 3)),
		0.0, 600.0, 600.0)
	create_tween().tween_property(fx, "modulate:a", 1.0, 2.2)

## 2.3: 어둑시니가 부풀어 오를 때 최헌이 화들짝 놀라 뒤로 물러선다 (놀란 자세 유지)
func _morph_startle() -> void:
	pose = "startled"
	_set_tex(_psprite, _player_tex())
	Audio.sfx("cloth", -4, 1.3)
	Audio.sfx("sting", -8)
	var back := px - 55.0 * (1.0 if _figure and _figure.position.x > px else -1.0)
	var tw := create_tween()
	tw.tween_property(_psprite, "position:y", -18.0, 0.08).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "px", back, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(_psprite, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
	await _tw_wait(tw)

## 봉인 장면: 봉인석 뒤로 솟은 거대한 어둑시니 실루엣 + 도트 검은 연기
func _seal_shadow_in() -> void:
	if not _seal_fx.is_empty():
		return
	var x: float = A.objects[0].x if A.has("objects") else 1800.0
	Audio.sfx("whoosh", -2)
	var sh := _char_sprite(CHAR_DIR + "adukshini_front.png")
	sh.scale = Vector2(1.1, 1.1)
	sh.position = Vector2(x, GROUND_Y + 10)
	sh.modulate = Color(0.015, 0.015, 0.05, 0.0)
	sh.z_index = -30          # 먼 숲(-50)보다 앞, 봉인석(-20)보다 뒤
	_world.add_child(sh)
	var tw := create_tween()
	tw.tween_property(sh, "modulate:a", 0.93, 3.0)
	# 숨 쉬듯 아주 조금 부풀었다 줄었다
	var br := sh.create_tween().set_loops()
	br.tween_property(sh, "scale", Vector2(1.12, 1.125), 2.2).set_trans(Tween.TRANS_SINE)
	br.tween_property(sh, "scale", Vector2(1.1, 1.1), 2.2).set_trans(Tween.TRANS_SINE)
	var smokes := [
		_aduk_smoke(Vector2(x, GROUND_Y - 300), Vector2(200, 260), 70, 0.55, -31, 1.6, Color(0.18, 0.17, 0.30)),   # 잿빛 테두리
		_aduk_smoke(Vector2(x, GROUND_Y - 220), Vector2(170, 220), 90, 1.0, -29, 1.4),                            # 몸 둘레 검은 연기
		_aduk_smoke(Vector2(x, GROUND_Y - 8), Vector2(300, 10), 46, 0.9, -19, 1.0),                                # 봉인석 밑동
	]
	smokes[2].initial_velocity_max = 10
	smokes[2].gravity = Vector2(0, -3)
	for p in smokes:
		p.modulate.a = 0
		create_tween().tween_property(p, "modulate:a", 1.0, 2.0)
	_seal_fx = {"shadow": sh, "smokes": smokes, "x": x, "breath": br}
	shake(0.4)

func _seal_shadow_bind() -> void:
	# 이름으로 묶는 순간: 그림자가 봉인석 아래로 빨려 들어가고 연기도 꺼진다
	if _seal_fx.is_empty():
		return
	var sh: Sprite2D = _seal_fx.shadow
	_seal_fx.breath.kill()
	Audio.sfx("whoosh", 0)
	shake(1.2)
	var fl := _glow_sprite(Color("5a86ff"), 260)
	fl.position = Vector2(_seal_fx.x, GROUND_Y - 120)
	fl.modulate.a = 0
	_glow_root.add_child(fl)
	var ft := create_tween()
	ft.tween_property(fl, "modulate:a", 1.0, 0.25)
	ft.tween_property(fl, "modulate:a", 0.0, 1.6)
	ft.tween_callback(fl.queue_free)
	# 땅 밑으로는 그리지 않도록, 그림 아래쪽부터 잘라 내며 내려 앉힌다 (발밑 = 땅)
	var tex_w := float(sh.texture.get_width())
	var tex_h := float(sh.texture.get_height())
	sh.region_enabled = true
	var tw := create_tween().set_parallel()
	tw.tween_method(func(k: float):
		var vis := maxf(1.0, tex_h - k)
		sh.region_rect = Rect2(0, 0, tex_w, vis)
		sh.offset = Vector2(-tex_w / 2.0, -vis),
		0.0, tex_h, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sh, "scale:x", 0.75, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sh, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	for p in _seal_fx.smokes:
		p.emitting = false
	await _tw_wait(tw)
	sh.queue_free()

func _eye_at(x: float, y: float, hold: float) -> void:
	# 허공에 떠서 뜨는 눈 (나무보다 앞, 살짝 떠다니며 희미하게 빛난다)
	var m := _anim_sprite(MON_DIR + "eye_%d.png", 2, 0.0, x, false, 20)
	m.sprite.position.y = y
	m.sprite.scale = Vector2(0.3, 0.3)
	_set_tex(m.sprite, MON_DIR + "eye_1.png")
	m.sprite.modulate.a = 0
	var glow := _glow_sprite(Color(0.85, 0.3, 0.3), 46)
	glow.position = Vector2(x, y - 22)
	glow.modulate.a = 0.0
	_glow_root.add_child(glow)
	_eye_glows.append(glow)
	var bob := create_tween().set_loops(int((hold + 1.0) / 1.6) + 1)
	bob.tween_property(m.sprite, "position:y", y - 8, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(m.sprite, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE)
	var gt := create_tween()
	gt.tween_property(glow, "modulate:a", 0.45, 0.3)
	gt.tween_interval(hold)
	gt.tween_property(glow, "modulate:a", 0.0, 0.4)
	gt.tween_callback(glow.queue_free)
	var tw := create_tween()
	tw.tween_property(m.sprite, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): if is_instance_valid(m.sprite): _set_tex(m.sprite, MON_DIR + "eye_0.png"))
	tw.tween_interval(hold)
	tw.tween_callback(func(): if is_instance_valid(m.sprite): _set_tex(m.sprite, MON_DIR + "eye_1.png"))
	tw.tween_property(m.sprite, "modulate:a", 0.0, 0.4)
	await _tw_wait(tw)
	_kill_mon(m)

func _hands_burst() -> void:
	Audio.stop_music(0.2)
	Audio.sfx("sting", 0)
	shake(1.1)
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		_hand_at(px + side * randf_range(60, 420), randf_range(0.5, 0.8) * 2.0 / 3.0, i * 0.06, 2.6)   # 2.2: 2/3 크기
	await red_flash(2, 0.45)
	Audio.sfx("heartbeat", -2)
	await get_tree().create_timer(3.4).timeout
	Audio.play_music(A.bgm, 2.0)

func _fall_from_horse() -> void:
	# 말이 놀라 뛰어오르고, 최헌이 떨어진다. 말은 왼쪽으로 달아난다.
	mounted = false
	horse_x = px
	_horse.visible = true
	_horse.flip_h = false
	_horse.position = Vector2(px, GROUND_Y)
	Audio.sfx("neigh", 0)
	for k in [3, 2, 1, 0]:
		pose = "fall_%d" % k
		_set_tex(_psprite, _player_tex())
		_psprite.position = Vector2(-40 + k * 10, -40 * k / 3.0)
		await get_tree().create_timer(0.16).timeout
	_psprite.position = Vector2.ZERO
	Audio.sfx("thud", -4)
	shake(0.7)
	pose = "lie"
	px -= 50
	_horse.flip_h = true
	var tw := create_tween()
	tw.tween_property(_horse, "position:x", cam_x - 500, 2.2).set_ease(Tween.EASE_IN)
	for i in 8:
		Audio.sfx("hoof" if i % 2 == 0 else "hoof2", -4 - i * 2, 1.05)
		await get_tree().create_timer(0.24).timeout
	await _tw_wait(tw)
	_horse.visible = false
	horse_x = -1

func _walk_away(nid: String) -> void:
	if not _npcs.has(nid):
		return
	var e: Dictionary = _npcs[nid]
	e.scripted = true
	var d: Dictionary = e.data
	var node: Node2D = e.node
	var sp: Sprite2D = e.sprite
	var t := 0.0
	var start := node.position.x
	Audio.sfx("cloth", -12)
	while t < 4.5:
		t += get_process_delta_time()
		node.position.x = start - 60.0 * t
		# 왼쪽(경주 쪽)으로 걸어간다: 왼쪽을 보는 걷기 그림 (없으면 오른쪽 그림을 뒤집음)
		var a := _actor(d.sprite, "", false, true, t * 60.0 / 14.0, -1)
		_set_tex(sp, a[0]); sp.flip_h = a[1]
		node.modulate.a = clampf((4.5 - t) / 1.5, 0.0, 1.0)
		await get_tree().process_frame
	node.visible = false
	Game.set_flag("gone_" + nid)

func _still_on(path: String) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	await _tw_wait(tw)
	_still = CanvasLayer.new()
	_still.layer = 30
	add_child(_still)
	var img := TextureRect.new()
	img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size = Vector2(1280, 720)
	img.pivot_offset = Vector2(640, 360)
	_still.add_child(img)
	var zoom := img.create_tween().set_loops()
	zoom.tween_property(img, "scale", Vector2(1.04, 1.04), 16.0)
	zoom.tween_property(img, "scale", Vector2(1.0, 1.0), 16.0)
	var sm := Scenery.smoke_layer(_still, 0.12, 380, 340)
	var lv := Scenery.leaves(10)
	lv.local_coords = true
	lv.position = Vector2(640, -30)
	_still.add_child(lv)
	_still.set_meta("smoke", sm)
	_still.set_meta("t0", Time.get_ticks_msec())
	var tw2 := create_tween()
	tw2.tween_property(_black, "color:a", 0.0, 1.0)
	await _tw_wait(tw2)

func _still_off() -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	await _tw_wait(tw)
	if _still:
		_still.queue_free()
		_still = null
	var tw2 := create_tween()
	tw2.tween_property(_black, "color:a", 0.0, 1.0)
	await _tw_wait(tw2)

func _physics_process(_d: float) -> void:
	if _still and _still.has_meta("smoke"):
		Scenery.drift_smoke(_still.get_meta("smoke"), (Time.get_ticks_msec() - int(_still.get_meta("t0"))) / 1000.0)

func _rocks_fall() -> void:
	shake(1.0)
	var x0: float = A.get("rocks_x", px + 120)
	for i in 9:
		var r := Sprite2D.new()
		r.texture = _tex_of("res://assets/scenery/fallrock_%d.png" % (i % 2))
		var s := randf_range(0.18, 0.32)
		r.scale = Vector2(s, s)
		var x := x0 + randf_range(0, 190)
		r.position = Vector2(x, randf_range(-120, -20))
		r.z_index = 4
		_world.add_child(r)
		var tw := create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_property(r, "position:y", GROUND_Y - 18 - randf_range(0, 14), randf_range(0.45, 0.7)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(r, "rotation", randf_range(-3, 3), 0.6)
	await get_tree().create_timer(1.4).timeout

func _go(r: Dictionary) -> void:
	locked = true
	store_position()
	Game.save_game()
	await UI.fade_out(1.0)
	Game.route(r)

## 아주 빠르게 무언가가 화면 앞을 휙 지나간다 (깜짝)
func _figure_pass() -> void:
	var m := _anim_sprite(CHAR_DIR + "adukshini_walkL_%d.png", 5, 22.0, cam_x + 1500, false, 30)
	var f: Sprite2D = m.sprite
	f.modulate = Color(0.02, 0.02, 0.05, 0.95)
	f.scale = Vector2(0.85, 0.85)
	f.position.y = GROUND_Y + 60
	Audio.sfx("whoosh", 0, 0.8)
	Audio.sfx("sting", -2)
	var tw := create_tween()
	tw.tween_property(f, "position:x", cam_x - 400, 0.42)
	shake(0.5)
	await _tw_wait(tw)
	_kill_mon(m)
	await get_tree().create_timer(0.6).timeout

func _forced_end() -> void:
	locked = true
	Audio.stop_music(0.1)
	Audio.play_amb([], 0.1)
	Audio.sfx("sting", 2)
	shake(1.2)
	await red_flash(4, 0.55)
	_black.color.a = 1.0
	UI.set_hud_visible(false)
	Game.set_flag("ch3_clear")
	store_position()
	Game.state.pose = ""
	Game.save_game()
	await get_tree().create_timer(2.5).timeout
	Game.route({"type": "area", "area": "road6", "spawn": "left", "dismount": true,
		"card": ["第四章", "길이 가리키는 곳", "상주  →  문경  →  충주  →  죽산 · 안성  →  한양"]})

func _chapter_transition(card: Array, next: Dictionary, music := true) -> void:
	locked = true
	Audio.stop_music(2.0)
	Audio.play_amb([], 2.0)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 2.2)
	await _tw_wait(tw)
	store_position()
	Game.save_game()
	UI.set_hud_visible(false)
	if music:
		Audio.play_music("chapter_end", 0.3)
		var muted := Color("b9aec6")
		await UI.show_card([[card[0], 26, muted, true], [card[1], 60, Color("f1e9d8"), true], [card[2], 32, muted, true]], 2.6)
	UI.set_black(true)
	Game.route(next)

func _chapter_end() -> void:
	Game.set_flag("chapter1_clear")
	Game.mark_chapter_clear()
	await _chapter_transition(["第一章", "「푸른 불」", "끝"], {"type": "still", "image": "res://assets/bg/background1.png", "dialogue": "ch2_dream", "music": "dream",
		"card": ["第二章", "어린시절의 꿈", "신녕  →  의흥"],
		"next": {"type": "area", "area": "sinnyeong_morning", "spawn": "start", "dismount": true}})

## 이미 끝난 트윈을 기다리다 멈추지 않도록
func _tw_wait(tw: Tween) -> void:
	if tw and tw.is_valid() and tw.is_running():
		await tw.finished
