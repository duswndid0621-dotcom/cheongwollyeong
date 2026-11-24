class_name Scenery
## data/scenery.json 을 읽어 필드 배경(먼 산·숲 띠, 집·나무·바위, 땅, 풀숲, 늘어진 가지, 등불, 낙엽·반딧불)을 만든다.
## 요소 그림은 assets/scenery/<id>.png (화면 크기의 2배로 그려져 있어 0.5배로 찍는다).

const DIR := "res://assets/scenery/"
const GROUND_TOP := 440.0
const BACK := 452.0
const FACTOR := {"near": 0.7, "back": 1.0, "front": 1.0, "fore": 1.25, "top": 1.15}
const ZDEF := {"near": -30, "back": -20, "front": 10, "fore": 50, "top": 55}

static var _data := {}
static var _shader: Shader

static func data_for(area: String) -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/scenery.json", FileAccess.READ)
		if f:
			_data = JSON.parse_string(f.get_as_text())
	return _data.get(area, {})

static func sway_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type canvas_item;
uniform float amp = 4.0;
uniform float speed = 1.2;
uniform bool hang = false;
void vertex() {
	float k = hang ? UV.y : 1.0 - UV.y;
	float ph = MODEL_MATRIX[3].x * 0.013;
	VERTEX.x += (sin(TIME * speed + ph) + 0.35 * sin(TIME * speed * 2.3 + ph * 1.7)) * amp * pow(k, 1.5);
}"""
	return _shader

## field: 필드 노드, world: 배율 1 노드(인물과 같은 곳), glow: 빛 노드
## 돌려주는 값: {layers: [[Node2D, factor]], named: {name: Sprite2D}, conds: [[Sprite2D, item]], lights: [dict]}
static func build(field: Node, area: String, W: float, world: Node2D, glow: Node2D) -> Dictionary:
	var D := data_for(area)
	var out := {"layers": [], "named": {}, "conds": [], "lights": [], "fx": D.get("fx", {})}
	if D.is_empty():
		return out
	# --- 먼 띠 (반복)
	for s in D.get("strips", []):
		var c := Node2D.new()
		field.add_child(c)
		field.move_child(c, 0)
		out.layers.append([c, float(s.f)])
		var tex: Texture2D = load(DIR + s.id + ".png")
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sp.region_enabled = true
		var cover := 1280.0 + (W - 1280.0) * float(s.f) + 400.0
		var sc := 0.5 * float(s.s)
		sp.region_rect = Rect2(0, 0, cover / sc, tex.get_height())
		sp.scale = Vector2(sc, sc)
		sp.position = Vector2(-200 - fmod(float(s.f) * 977.0, tex.get_width() * sc), float(s.y) - tex.get_height() * sc)
		sp.modulate = _col(s.m)
		sp.z_index = int(s.z)
		c.add_child(sp)
	# --- 땅
	var gtex: Texture2D = load(DIR + "ground_%s.png" % D.get("ground", "field"))
	var g := Sprite2D.new()
	g.texture = gtex
	g.centered = false
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_enabled = true
	g.region_rect = Rect2(0, 0, (W + 800) / 2.0, gtex.get_height())
	g.scale = Vector2(2, 2)
	g.position = Vector2(-400, GROUND_TOP)
	g.z_index = -45
	world.add_child(g)
	# --- 층별 묶음
	var holders := {}
	for l in ["near", "fore", "top"]:
		var c := Node2D.new()
		field.add_child(c)
		holders[l] = c
		out.layers.append([c, FACTOR[l]])
	for it in D.get("items", []):
		var l: String = it.l
		var tex: Texture2D = load(DIR + it.id + ".png")
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		var sc := 0.5 * float(it.get("s", 1.0))
		sp.scale = Vector2(sc, sc)
		if l == "top":
			sp.offset = Vector2(-tex.get_width() / 2.0, 0)
			sp.position = Vector2(float(it.x), -16.0)
		else:
			sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
			sp.position = Vector2(float(it.x), float(it.get("y", BACK)))
		sp.flip_h = it.get("flip", false)
		if it.has("m"):
			sp.modulate = _col(it.m)
		sp.z_index = int(it.get("z", ZDEF[l]))
		var sw: int = int(it.get("sway", 0))
		if sw > 0:
			var mat := ShaderMaterial.new()
			mat.shader = sway_shader()
			if sw == 1:
				mat.set_shader_parameter("amp", 4.0 if l != "top" else 7.0)
				mat.set_shader_parameter("speed", 0.9 + randf() * 0.4)
			else:
				mat.set_shader_parameter("amp", 9.0)
				mat.set_shader_parameter("speed", 1.8 + randf() * 0.6)
			if l == "top":
				mat.set_shader_parameter("hang", true)
			sp.material = mat
		if l in holders:
			holders[l].add_child(sp)
		else:
			world.add_child(sp)
		if it.has("name"):
			out.named[it.name] = sp
		if it.has("show_if") or it.has("hide_if"):
			out.conds.append([sp, it])
	# --- 등불
	for L in D.get("lights", []):
		out.lights.append(L)
	return out

static func refresh(conds: Array) -> void:
	for pair in conds:
		var it: Dictionary = pair[1]
		var v := true
		if it.has("show_if") and not Game.flag(it.show_if):
			v = false
		if it.has("hide_if") and Game.flag(it.hide_if):
			v = false
		pair[0].visible = v

static func _col(m) -> Color:
	return Color(m[0], m[1], m[2], m[3] if m.size() > 3 else 1.0)

# =========================================================
# 떠다니는 효과
# =========================================================
static func leaves(amount: int = 14) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load(DIR + "fx_leaf.png")
	p.local_coords = false
	p.amount = amount
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.direction = Vector2(-0.35, 1)
	p.spread = 30
	p.gravity = Vector2(-5, 9)
	p.initial_velocity_min = 22
	p.initial_velocity_max = 48
	p.angular_velocity_min = -150
	p.angular_velocity_max = 150
	p.angle_min = 0
	p.angle_max = 360
	p.scale_amount_min = 1.1
	p.scale_amount_max = 2.0
	p.orbit_velocity_min = 0.0
	p.orbit_velocity_max = 0.0
	p.damping_min = 2
	p.damping_max = 6
	var g := Gradient.new()
	g.set_color(0, Color("b8382a"))
	g.add_point(0.5, Color("d8692e"))
	g.set_color(g.get_point_count() - 1, Color("e2a23e"))
	p.color_initial_ramp = g
	var a := Gradient.new()
	a.set_color(0, Color(1, 1, 1, 0))
	a.add_point(0.08, Color(1, 1, 1, 1))
	a.add_point(0.85, Color(1, 1, 1, 1))
	a.set_color(a.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = a
	p.z_index = 45
	return p

static func fireflies(amount: int = 22) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load(DIR + "fx_glow.png")
	p.local_coords = false
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(820, 150)
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.gravity = Vector2(0, -3)
	p.initial_velocity_min = 6
	p.initial_velocity_max = 18
	p.tangential_accel_min = -8
	p.tangential_accel_max = 8
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.55
	var a := Gradient.new()
	a.set_color(0, Color(0.85, 1.0, 0.45, 0))
	a.add_point(0.2, Color(0.85, 1.0, 0.45, 1))
	a.add_point(0.4, Color(0.85, 1.0, 0.45, 0.25))
	a.add_point(0.6, Color(0.9, 1.0, 0.5, 1))
	a.set_color(a.get_point_count() - 1, Color(0.85, 1.0, 0.45, 0))
	p.color_ramp = a
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p

static func embers(amount: int = 16) -> CPUParticles2D:
	var p := fireflies(amount)
	p.gravity = Vector2(4, -10)
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_rect_extents = Vector2(820, 120)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var a := Gradient.new()
	a.set_color(0, Color(1.0, 0.35, 0.25, 0))
	a.add_point(0.3, Color(1.0, 0.4, 0.3, 0.9))
	a.add_point(0.7, Color(0.9, 0.3, 0.6, 0.5))
	a.set_color(a.get_point_count() - 1, Color(0.5, 0.4, 1.0, 0))
	p.color_ramp = a
	return p

## 그림 위를 흐르는 연기 (화면 좌표, 정지 화면·타이틀용)
static func smoke_layer(parent: Node, alpha: float = 0.22, y: float = 420.0, h: float = 300.0) -> Array:
	var out := []
	var tex: Texture2D = load(DIR + "fx_smoke.png")
	for i in 2:
		var r := TextureRect.new()
		r.texture = tex
		r.stretch_mode = TextureRect.STRETCH_TILE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.size = Vector2(1280 + 1024, h)
		r.position = Vector2(0, y + i * 40)
		r.modulate = Color(0.85, 0.85, 0.95, alpha * (1.0 if i == 0 else 0.7))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)
		out.append({"node": r, "speed": 14.0 + i * 11.0})
	return out

static func drift_smoke(list: Array, t: float) -> void:
	for s in list:
		s.node.position.x = -fmod(t * s.speed, 1024.0)
