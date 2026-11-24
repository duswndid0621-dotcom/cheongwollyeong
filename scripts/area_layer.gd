@tool
class_name AreaLayer
extends Node2D
## 배경 한 층. factor = 카메라를 따라 움직이는 빠르기 (1 = 인물과 같이, 0.1 = 아주 먼 산, 1.25 = 화면 맨 앞).
## 이 노드 아래에 그림(Sprite2D)을 넣으면 그 층에 속한다. 앞뒤 순서는 z_index (인물은 0~3).
@export_range(0.0, 2.0, 0.01) var factor := 1.0
