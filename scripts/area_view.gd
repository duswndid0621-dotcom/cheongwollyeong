@tool
class_name AreaView
extends Node2D
## 지역 하나의 배경 장면 (scenes/areas/<지역>.tscn).
## 에디터에서 그림을 끌어 옮기고, 크기·좌우 뒤집기·색을 바꾸고, assets/scenery 의 그림을 끌어다 놓아 추가할 수 있다.
## 화면에 보이는 색깔 선은 게임 속 사람·물건·사건 위치 (끌어도 바뀌지 않음 — scripts/area_data.gd 에 있음).
## 이 장면을 연 채로 F6 (현재 장면 실행)을 누르면 이 지역에서 바로 걸어 볼 수 있다.

@export var area_id := ""
@export_group("효과")
@export var leaves := false        ## 단풍잎이 떨어진다
@export var fireflies := false     ## 반딧불이 (어두울수록 잘 보임)
@export var embers := false        ## 붉은 불티 (어두운 숲)
@export_group("미리보기 (F6)")
@export var preview_x := 300.0     ## F6으로 실행할 때 시작 위치
@export var preview_flags := ""    ## 미리 켜 둘 진행 플래그 (쉼표로 구분)
@export var show_markers := true:
	set(v):
		show_markers = v
		queue_redraw()

const GROUND_Y := 556.0
const GROUND_TOP := 517.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		return
	if get_tree().current_scene == self:
		# F6: 이 지역에서 바로 시작
		Game.new_state()
		for f in preview_flags.split(",", false):
			Game.state.flags[f.strip_edges()] = true
		var id := area_id
		var x := preview_x
		Game.route.call_deferred({"type": "area", "area": id, "spawn": "left", "x": x})

## 게임(field.gd)이 쓰는 정보
func layers() -> Array:
	var out := []
	for c in get_children():
		if c is AreaLayer:
			out.append([c, c.factor])
	return out

func conds() -> Array:
	var out := []
	for n in find_children("*", "CanvasItem", true, false):
		if n.has_meta("show_if") or n.has_meta("hide_if"):
			var d := {}
			if n.has_meta("show_if"): d["show_if"] = n.get_meta("show_if")
			if n.has_meta("hide_if"): d["hide_if"] = n.get_meta("hide_if")
			out.append([n, d])
	return out

func lights() -> Array:
	var out := []
	for n in find_children("*", "LightPoint", true, false):
		var p: Vector2 = n.global_position
		var d := {"x": p.x, "y": p.y, "r": n.radius, "color": n.color.to_html(false), "flicker": n.flicker}
		if n.has_meta("hide_if"): d["hide_if"] = n.get_meta("hide_if")
		if n.has_meta("show_if"): d["show_if"] = n.get_meta("show_if")
		out.append(d)
		n.visible = false
	return out

# ---------------------------------------------------------------- 에디터 표시
var _last_hash := 0
func _process(_d: float) -> void:
	if Engine.is_editor_hint() and show_markers:
		var h := hash(AreaData.AREAS.get(area_id, {}))
		if h != _last_hash:
			_last_hash = h
			queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or not show_markers:
		return
	var A: Dictionary = AreaData.AREAS.get(area_id, {})
	if A.is_empty():
		return
	var font := ThemeDB.fallback_font
	var W: float = A.width
	# 화면 한 장 크기와 땅·발 높이
	draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.35), false, 2.0)
	draw_string(font, Vector2(8, 22), "화면 한 장 (1280×720)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))
	draw_line(Vector2(0, GROUND_Y), Vector2(W, GROUND_Y), Color(1, 1, 0.4, 0.5), 2.0)
	draw_line(Vector2(0, GROUND_TOP), Vector2(W, GROUND_TOP), Color(0.5, 1, 0.5, 0.35), 1.0)
	draw_line(Vector2(W, -100), Vector2(W, 760), Color(1, 0.3, 0.3, 0.8), 3.0)
	draw_string(font, Vector2(W - 120, 40), "지역 끝", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.4, 0.4))
	var y := 120.0
	for n in A.get("npcs", []):
		_mark(font, n.x, Color("66b3ff"), "사람: " + n.id, y)
	for o in A.get("objects", []):
		_mark(font, o.x, Color("ffd24d"), "살펴보기: " + o.label, y + 30)
	var k := 0
	for t in A.get("triggers", []):
		var label := "사건: " + str(t.get("dialogue", t.get("event", t.get("once", ""))))
		if t.has("barks") or t.has("amb"):
			label = "작은 일: " + str(t.get("once", ""))
		_mark(font, t.x, Color("7dff8a") if not t.has("barks") else Color("4fb35a"), label, y + 60 + (k % 3) * 22)
		k += 1
	for w in A.get("walls", []):
		_mark(font, w.x, Color("ff5050"), "막힘", y + 150)
	for side in A.get("exits", {}):
		_mark(font, A.exits[side].x, Color.WHITE, "출구 → " + A.exits[side].to, y + 180)
	for key in A.get("spawn", {}):
		_mark(font, A.spawn[key], Color("40e0e0"), "시작: " + key, y + 210)

func _mark(font: Font, x: float, col: Color, text: String, ty: float) -> void:
	draw_line(Vector2(x, ty + 6), Vector2(x, GROUND_Y), Color(col.r, col.g, col.b, 0.55), 2.0)
	draw_circle(Vector2(x, GROUND_Y), 6, col)
	draw_string(font, Vector2(x + 6, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
