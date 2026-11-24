@tool
class_name LightPoint
extends Node2D
## 등불 빛. 게임에서는 어두울수록 밝게 빛나는 둥근 빛이 된다. 에디터에서는 원으로 보인다.
@export var color := Color("ffb860"):
	set(v):
		color = v
		queue_redraw()
@export_range(10.0, 400.0, 1.0) var radius := 80.0:
	set(v):
		radius = v
		queue_redraw()
@export var flicker := true

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.18))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color.r, color.g, color.b, 0.8), 2.0)
		draw_circle(Vector2.ZERO, 5, color)
