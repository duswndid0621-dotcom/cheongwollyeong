extends Node
## 게임 전체 상태: 진행 플래그, 아이템, 저장/불러오기, 데이터, 폰트, 장면 전환.

const SAVE_PATH := "user://save.json"
const COLLECTION_PATH := "user://collection.json"
const SAVE_VERSION := 1

var dialogue: Dictionary = {}
var items_data: Dictionary = {}
var item_order: Array = []

var state: Dictionary = {}
var pending: Dictionary = {}  # 다음 필드 진입 시 처리할 것 (spawn, card 등)

var font_ui: FontFile
var font_title: FontFile
var theme: Theme

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_data()
	_setup_fonts()
	new_state()

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		"horse": [KEY_R],
		"map": [KEY_M],
		"collection": [KEY_I, KEY_TAB],
		"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
		"run": [KEY_SHIFT],
		"log": [KEY_L],            # 2.5 이후: 대화 기록
		"keys": [KEY_F1, KEY_H],   # 2.5 이후: 조작 방법
	}
	for action in map:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# 패드 지원 (기본)
	_add_joy("interact", JOY_BUTTON_A)
	_add_joy("cancel", JOY_BUTTON_B)
	_add_joy("horse", JOY_BUTTON_X)
	_add_joy("map", JOY_BUTTON_BACK)
	_add_joy("collection", JOY_BUTTON_Y)
	_add_joy("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy("move_up", JOY_BUTTON_DPAD_UP)
	_add_joy("move_down", JOY_BUTTON_DPAD_DOWN)

func _add_joy(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _load_data() -> void:
	dialogue = {}
	for fn in ["dialogue.json", "dialogue_ch2.json", "dialogue_ch3.json", "dialogue_ch4.json", "dialogue_end.json"]:
		dialogue.merge(_read_json("res://data/" + fn), true)
	var it: Dictionary = _read_json("res://data/items.json")
	items_data = it.get("items", {})
	item_order = it.get("order", [])

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("데이터를 열 수 없음: " + path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

func _setup_fonts() -> void:
	var hanja: FontFile = load("res://assets/fonts/hanja_fallback.otf")
	font_ui = load("res://assets/fonts/Griun_PolSensibility-Rg.ttf")
	font_ui.fallbacks = [hanja]
	font_title = font_ui   # 모든 글씨를 같은 글꼴로
	theme = Theme.new()
	theme.default_font = font_ui
	theme.default_font_size = 28
	get_tree().root.theme = theme

# ---------------- 상태 ----------------
func new_state() -> void:
	state = {
		"version": SAVE_VERSION,
		"area": "gotaek",
		"x": 300.0,
		"facing": 1,
		"mounted": false,
		"horse_x": -1.0,
		"flags": {},
		"items": [],
		"cycles": {},
	}

func flag(name: String) -> bool:
	return state.flags.get(name, false)

func set_flag(name: String, v: bool = true) -> void:
	state.flags[name] = v

func has_item(id: String) -> bool:
	return id in state.items

func give_item(id: String) -> void:
	if not has_item(id):
		state.items.append(id)
	_add_to_collection(id)

func next_cycle(key: String, count: int) -> int:
	var i: int = state.cycles.get(key, 0)
	state.cycles[key] = i + 1
	return i % max(1, count)

# ---------------- 저장 ----------------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return false
	new_state()
	for k in data:
		state[k] = data[k]
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## 플레이 기록과 상관없이 한 번이라도 얻은 아이템 (타이틀의 수집록용)
func collection() -> Array:
	if not FileAccess.file_exists(COLLECTION_PATH):
		return []
	var f := FileAccess.open(COLLECTION_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	return data.get("items", []) if data is Dictionary else []

func collection_cleared() -> bool:
	if not FileAccess.file_exists(COLLECTION_PATH):
		return false
	var f := FileAccess.open(COLLECTION_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	return data is Dictionary and data.get("ch1_clear", false)

func _add_to_collection(id: String, clear := false) -> void:
	var items := collection()
	if id != "" and not id in items:
		items.append(id)
	var cleared := collection_cleared() or clear
	var f := FileAccess.open(COLLECTION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"items": items, "ch1_clear": cleared}))

func mark_chapter_clear() -> void:
	_add_to_collection("", true)

func mark_ending_clear() -> void:
	_add_to_collection("", true)
	var f := FileAccess.open(COLLECTION_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else {}
	if not data is Dictionary: data = {}
	data["ending_clear"] = true
	var w := FileAccess.open(COLLECTION_PATH, FileAccess.WRITE)
	if w: w.store_string(JSON.stringify(data))

# ---------------- 장면 전환 ----------------
func start_new_game() -> void:
	new_state()
	UI.clear_log()
	pending = {"intro": true}
	await UI.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/field.tscn")

func continue_game() -> void:
	if load_game():
		pending = {"continue": true}
		await UI.fade_out(0.8)
		get_tree().change_scene_to_file("res://scenes/field.tscn")

func change_area(area: String, spawn: String, extra: Dictionary = {}) -> void:
	state.area = area
	pending = {"spawn": spawn}
	pending.merge(extra)
	get_tree().change_scene_to_file("res://scenes/field.tscn")

func play_animation_then(area: String, spawn: String, extra: Dictionary = {}) -> void:
	var nxt := {"type": "area", "area": area, "spawn": spawn}
	nxt.merge(extra)
	route({"type": "anim", "anim": "anim1", "music": "dusk", "next": nxt})

## 장면 흐름: {"type": "area"|"anim"|"still"|"title", ...}
func route(r: Dictionary) -> void:
	match r.get("type", "area"):
		"area":
			state.area = r.area
			pending = {"spawn": r.get("spawn", "left")}
			for k in ["x", "run", "card", "dismount", "mount"]:
				if r.has(k):
					pending[k] = r[k]
			get_tree().change_scene_to_file("res://scenes/field.tscn")
		"anim":
			pending = r
			get_tree().change_scene_to_file("res://scenes/anim.tscn")
		"still":
			pending = r
			get_tree().change_scene_to_file("res://scenes/still.tscn")
		"title":
			go_title()

func go_title() -> void:
	UI.close_all()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
