class_name AreaData
## 지역 정의 (2.0). x 좌표는 화면 픽셀 기준 월드 좌표 (발 높이 y=480).
## 배경 그림은 data/scenery.json (tools/build_scenery.py)이 그리고, 여기에는 사람·물건·사건만 적는다.
## npcs: 사람 / objects: 살펴볼 것 / triggers: 지나가면 자동으로 실행 (barks·amb는 걸음을 멈추지 않는 작은 일)
## walls: 조건이 풀릴 때까지 막힘 / time: [[x, 시간대], ...]

const AREAS := {
	"gotaek": {
		"name": "경주 · 최씨 고택", "width": 2400,
		"time": [[0, "dawn"]], "bgm": "home", "amb": ["wind", "birds"],
		"horse": false, "companion": false,
		"spawn": {"start": 330, "left": 160, "right": 2120},
		"npcs": [
			{"id": "grandma", "sprite": "grandma", "x": 1080, "wander": 70, "dialogue": "gotaek_grandma", "repeat": "gotaek_grandma_r", "done": "talked_grandma"},
		],
		"objects": [
			{"id": "jars", "label": "장독대", "x": 250, "dialogue": "gotaek_jars"},
			{"id": "shrine", "label": "사당", "x": 480, "dialogue": "gotaek_shrine", "repeat": "gotaek_shrine_r"},
			{"id": "jokbo", "label": "족보", "x": 800, "dialogue": "gotaek_jokbo", "repeat": "gotaek_jokbo_r"},
			{"id": "wall", "label": "무너진 담", "x": 1560, "dialogue": "gotaek_wall"},
		],
		"exits": {"right": {"x": 2230, "to": "golmok", "spawn": "left", "cond": "talked_grandma", "locked": "gotaek_gate_locked"}},
	},
	"golmok": {
		"name": "경주 · 고택 앞 길", "width": 3000,
		"time": [[0, "dawn"], [3000, "morning"]], "bgm": "home", "amb": ["birds", "wind"],
		"horse": true, "horse_park": 1290, "companion": true, "seo_npc_x": 1060,
		"spawn": {"left": 230, "right": 2840},
		"npcs": [
			{"id": "dog", "sprite": "dog", "label": "누렁이 쓰다듬기", "x": 1560, "wander": 170, "dialogue": "golmok_dog", "repeat": "golmok_dog_r", "done": "petted_dog"},
		],
		"objects": [
			{"id": "persimmon", "label": "감나무", "x": 1000, "dialogue": "golmok_wall"},
			{"id": "jars", "label": "이웃집 장독", "x": 2000, "dialogue": "golmok_jars"},
		],
		"triggers": [
			{"x": 480, "dialogue": "golmok_start", "once": "golmok_called", "ifnot": "talked_seo"},
			{"x": 1700, "once": "golmok_b1", "if": "talked_seo", "amb": "dog", "barks": [["서문경", "개도 우리 배웅하는구먼."], ["최헌", "(이 골목을 다시 걸을 날이 올까.)"]]},
		],
		"exits": {
			"right": {"x": 2930, "to": "seunim", "spawn": "left", "cond": "talked_seo", "locked": "golmok_exit_locked"},
			"left": {"x": 90, "to": "gotaek", "spawn": "right"},
		},
	},
	"seunim": {
		"name": "경주 · 스승의 집", "width": 2400,
		"time": [[0, "dawn"], [2400, "morning"]], "bgm": "home", "amb": ["birds", ""],
		"horse": true, "companion": true,
		"spawn": {"left": 160, "right": 2250},
		"npcs": [
			{"id": "teacher", "sprite": "teacher", "idle": "teacher_idle", "x": 1180, "dialogue": "seunim_teacher", "repeat": "seunim_teacher_r", "done": "got_map", "need_dismount": "seunim_teacher_mounted"},
		],
		"objects": [
			{"id": "desk", "label": "서안", "x": 930, "dialogue": "seunim_desk"},
			{"id": "pine", "label": "소나무", "x": 1650, "dialogue": "seunim_pine", "repeat": "seunim_pine_r"},
			{"id": "well", "label": "우물", "x": 1900, "dialogue": "seunim_well"},
		],
		"triggers": [
			{"x": 360, "dialogue": "seunim_start", "once": "seunim_entered"},
		],
		"exits": {
			"right": {"x": 2330, "to": "road1", "spawn": "left", "cond": "got_map", "locked": "seunim_exit_locked", "anim": true},
			"left": {"x": 70, "to": "golmok", "spawn": "right"},
		},
	},
	"road1": {
		"name": "경주를 떠나며 · 들판 길", "width": 4200,
		"time": [[0, "morning"], [4200, "day"]], "bgm": "road_day", "amb": ["birds", "wind"],
		"horse": true, "companion": true, "no_back": true,
		"spawn": {"left": 200},
		"objects": [
			{"id": "jangseung", "label": "장승", "x": 940, "dialogue": "road1_jangseung"},
			{"id": "sign", "label": "이정표", "x": 1806, "dialogue": "road1_sign"},
			{"id": "tomb", "label": "길가의 무덤", "x": 2600, "dialogue": "road1_tomb"},
		],
		"triggers": [
			{"x": 300, "dialogue": "road1_start", "once": "road1_started"},
			{"x": 1300, "once": "road1_b1", "barks": [["서문경", "헌이, 저 들판 좀 보게. 벼가 다 누렇군."], ["최헌", "올해는 풍년이라더군."]]},
			{"x": 3200, "once": "road1_b2", "amb": "crows", "barks": [["서문경", "까마귀가 서쪽으로 가는군. 우리보다 먼저 한양 가나."]]},
		],
		"exits": {"right": {"x": 4130, "to": "road2", "spawn": "left"}},
	},
	"road2": {
		"name": "영천 가는 길", "width": 7600,
		"time": [[0, "day"], [4600, "afternoon"], [7000, "sunset"]], "bgm": "road_day", "amb": ["wind", "birds"],
		"horse": true, "companion": true, "no_back": true,
		"spawn": {"left": 200},
		"objects": [
			{"id": "well", "label": "우물", "x": 1160, "dialogue": "road2_well"},
			{"id": "scarecrow", "label": "허수아비", "x": 1905, "dialogue": "road2_scarecrow"},
			{"id": "pavilion", "label": "정자", "x": 6000, "dialogue": "road2_pavilion_r", "if": "rested"},
			{"id": "pavilion2", "label": "정자", "x": 6000, "dialogue": "road2_pavilion_later", "if": "pavilion_asked", "ifnot": "rested"},
		],
		"triggers": [
			{"x": 220, "dialogue": "road2_start", "once": "road2_started"},
			{"x": 2600, "once": "road2_b1", "barks": [["서문경", "헌이, 시제(詩題)가 뭐가 나올 것 같나?"], ["최헌", "작년엔 '민심'이었지."], ["서문경", "올해는 '우정'이 나오면 좋겠군. 내가 할 말이 많거든. 하하!"]]},
			{"x": 3700, "once": "road2_b2", "amb": "gust", "barks": [["", "(바람에 단풍잎이 우수수 쏟아진다.)"], ["서문경", "에취! …가을은 가을이군."]]},
			{"x": 4800, "once": "road2_b3", "barks": [["서문경", "다리가 저리네. 말 위도 오래 있으면 고역이야."], ["최헌", "저 앞에 정자가 보이는군."]]},
			{"x": 5820, "dialogue": "road2_pavilion", "once": "pavilion_asked"},
			{"x": 7000, "dialogue": "road2_sunset", "once": "road2_sunset_seen", "bgm": "dusk"},
		],
		"exits": {"right": {"x": 7530, "to": "road3", "spawn": "left"}},
	},
	"road3": {
		"name": "신녕 가는 산길", "width": 9600,
		"time": [[0, "sunset"], [2200, "dusk"], [3600, "night"]], "bgm": "dusk", "amb": ["wind", "crickets"],
		"horse": true, "companion": true, "no_back": true,
		"spawn": {"left": 200},
		"flame": {"on": "flame_seen", "off": "flame_gone", "hold": "flame_hold", "hold_off": "rock_done", "hold_x": 6330, "fork_x": 5200},
		"rocks_x": 6170,
		"npcs": [
			{"id": "nageune", "sprite": "nageune", "x": 1000, "dialogue": "road3_nageune", "repeat": "road3_nageune_r", "done": "talked_nageune", "hide_if": "gone_nageune"},
		],
		"triggers": [
			{"x": 820, "dialogue": "road3_nageune", "once": "nageune_called", "ifnot": "talked_nageune"},
			{"x": 1250, "dir": -1, "dialogue": "road3_nageune_gone", "once": "nageune_gone_seen", "if": "flame_seen"},
			{"x": 2100, "once": "road3_b1", "amb": "owl", "barks": [["서문경", "…부엉이 소리군."], ["최헌", "산에 들어섰다는 거지."]]},
			{"x": 2800, "once": "road3_b2", "amb": "steps_behind", "barks": [["서문경", "헌이, 방금 뒤에서 발소리 나지 않았나?"], ["최헌", "우리 말발굽 소리가 울린 걸세."]]},
			{"x": 3400, "event": "flame_appear", "dialogue": "road3_flame_appear", "once": "flame_seen", "if": "talked_nageune"},
			{"x": 5000, "dialogue": "road3_fork", "once": "fork_started", "if": "flame_seen"},
			{"x": 5900, "event": "flame_hold", "once": "flame_hold", "if": "fork_done"},
			{"x": 7000, "once": "road3_b3", "if": "rock_done", "barks": [["서문경", "아직도 손이 떨리네…"], ["최헌", "나도 그렇네."]]},
			{"x": 7600, "dialogue": "road3_guide", "once": "guide_seen", "if": "rock_done"},
			{"x": 9000, "dialogue": "road3_flame_vanish", "once": "flame_gone", "if": "guide_seen"},
		],
		"objects": [
			{"id": "pipe", "label": "떨어진 물건", "x": 4300, "dialogue": "road3_pipe", "hide_if": "got_pipe", "glint": true, "if": "flame_seen"},
		],
		"walls": [
			{"x": 1800, "ifnot": "talked_nageune"},
			{"x": 5060, "ifnot": "fork_done"},
			{"x": 6130, "ifnot": "rock_done", "bump": "rockslide"},
		],
		"exits": {"right": {"x": 9530, "to": "sinnyeong", "spawn": "left", "cond": "flame_gone", "anim": "anim_inn", "anim_music": "tavern"}},
	},
	"sinnyeong": {
		"name": "신녕 · 주막거리", "width": 2900,
		"time": [[0, "night"]], "bgm": "tavern", "amb": ["village", "crickets"],
		"horse": true, "companion": true, "no_back": true,
		"spawn": {"left": 200},
		"npcs": [
			{"id": "jumo", "sprite": "jumo", "idle": "jumo_idle", "x": 1500, "dialogue": "sinnyeong_jumo", "repeat": "sinnyeong_jumo_r", "done": "talked_jumo", "need_dismount": "sinnyeong_jumo_mounted"},
		],
		"objects": [
			{"id": "well", "label": "우물", "x": 470, "dialogue": "sinnyeong_well"},
			{"id": "stable", "label": "마구간", "x": 920, "dialogue": "sinnyeong_stable"},
			{"id": "bench", "label": "평상", "x": 2290, "dialogue": "sinnyeong_drink", "repeat": "sinnyeong_bench", "done": "seo_drink_done",
				"pre_if": "talked_jumo", "pre_dialogue": "sinnyeong_bench_early", "need_dismount": "sinnyeong_jumo_mounted"},
			{"id": "door", "label": "주막 방문", "x": 1880, "dialogue": "sinnyeong_door", "repeat": "sinnyeong_door_r", "done": "door_talked",
				"pre_if": "seo_drink_done", "pre_dialogue": "sinnyeong_door_pre", "need_dismount": "sinnyeong_jumo_mounted"},
			{"id": "guest", "label": "건넛방", "x": 2680, "dialogue": "sinnyeong_guest", "repeat": "sinnyeong_guest_r", "done": "heard_cheongwol", "need_dismount": "sinnyeong_jumo_mounted"},
		],
		"triggers": [
			{"x": 260, "dialogue": "sinnyeong_start", "once": "sinnyeong_entered"},
		],
		"walls": [{"x": 2780, "ifnot": "never", "say": "(오늘 밤은 이 주막에서 묵어야 한다.)"}],
	},
	# ===================== 제2장 「어린시절의 꿈」 =====================
	"sinnyeong_morning": {
		"name": "신녕 · 이튿날 아침", "width": 2900,
		"time": [[0, "dawn"], [2600, "morning"]], "bgm": "home", "amb": ["village", "birds"],
		"horse": true, "horse_park": 920, "companion": false,
		"spawn": {"start": 1860, "left": 200},
		"npcs": [
			{"id": "jumo", "sprite": "jumo", "idle": "jumo_idle", "x": 1500, "dialogue": "ch2_jumo", "repeat": "ch2_jumo_r", "done": "talked_jumo2", "need_dismount": "sinnyeong_jumo_mounted"},
		],
		"objects": [
			{"id": "room", "label": "주막 방", "x": 1880, "dialogue": "ch2_room"},
			{"id": "talisman", "label": "찢어진 부적", "x": 2010, "dialogue": "ch2_talisman", "hide_if": "got_talisman", "glint": true},
			{"id": "bench", "label": "평상", "x": 2290, "dialogue": "ch2_bench"},
			{"id": "guest", "label": "건넛방", "x": 2680, "dialogue": "ch2_guestroom"},
			{"id": "stable", "label": "마구간", "x": 980, "dialogue": "ch2_stable"},
			{"id": "well", "label": "우물", "x": 470, "dialogue": "ch2_well_morning"},
		],
		"triggers": [{"x": 0, "dialogue": "ch2_wake", "once": "ch2_woke"}],
		"exits": {"right": {"x": 2830, "to": "road4", "spawn": "left", "cond": "ch2_decided", "locked": "ch2_exit_locked"}},
	},
	"road4": {
		"name": "의흥 가는 산길", "width": 8000,
		"time": [[0, "morning"], [3000, "afternoon"], [5000, "sunset"], [5900, "dusk"], [6500, "night"]],
		"bgm": "road_day", "amb": ["wind", "birds"],
		"horse": true, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		"flame": {"on": "flame2_seen", "off": "flame2_gone", "hold": "help2_started", "hold_off": "help2_done", "hold_x": 3200},
		"voice_x": 6880,
		"decals": [
			{"x": 4260, "tex": "print_beast", "flip": true}, {"x": 4330, "tex": "print_beast", "flip": true},
			{"x": 4400, "tex": "print_beast", "flip": true}, {"x": 4470, "tex": "print_beast", "flip": true},
			{"x": 4540, "tex": "print_beast", "flip": true}, {"x": 4610, "tex": "print_beast", "flip": true},
		],
		"triggers": [
			{"x": 400, "dialogue": "ch2_road_start", "once": "ch2_road_started"},
			{"x": 1100, "once": "road4_b1", "barks": [["최헌", "(문경이가 있었으면 지금쯤 시제 타령을 하고 있겠지.)"]]},
			{"x": 1700, "event": "flame_appear", "dialogue": "ch2_flame", "once": "flame2_seen"},
			{"x": 2500, "once": "road4_b2", "amb": "crows", "barks": [["최헌", "(혼자 걷는 길은… 이렇게 길었던가.)"]]},
			{"x": 3000, "event": "flame_hold", "dialogue": "ch2_help", "once": "help2_started", "if": "flame2_seen"},
			{"x": 4200, "dialogue": "ch2_footprints", "once": "ch2_prints_seen"},
			{"x": 5200, "once": "road4_b3", "amb": "gust", "barks": [["", "(어디선가, 아이 우는 소리가 들린 것 같다.)"], ["최헌", "(…산짐승 소리다.)"]]},
			{"x": 6200, "dialogue": "ch2_doubt", "once": "ch2_doubted", "bgm": "night"},
			{"x": 6820, "dialogue": "ch2_voice", "once": "ch2_voice_started", "if": "ch2_doubted"},
			{"x": 7600, "dialogue": "ch2_flame_leave", "once": "flame2_gone", "if": "voice_done"},
		],
		"objects": [
			{"id": "hair", "label": "덤불에 걸린 것", "x": 4660, "dialogue": "ch2_hair", "glint": true, "glint_off": "saw_hair"},
		],
		"walls": [{"x": 3080, "ifnot": "help2_done"}, {"x": 6880, "ifnot": "voice_done"}],
		"exits": {"right": {"x": 7930, "to": "seonang", "spawn": "left", "cond": "flame2_gone"}},
	},
	"search_pass": {
		"name": "신녕 뒷산 · 어젯밤 넘어온 고갯길", "width": 6000,
		"time": [[0, "gloom"]], "bgm": "eerie", "amb": ["wind", ""], "fog": 0.07,
		"horse": false, "companion": false,
		"spawn": {"right": 5650},
		"decals": [
			{"x": 5200, "tex": "print_human", "flip": true}, {"x": 5110, "tex": "print_human", "flip": true, "y": 4},
			{"x": 5020, "tex": "print_human", "flip": true}, {"x": 4930, "tex": "print_human", "flip": true, "y": 4},
			{"x": 4840, "tex": "print_human", "flip": true}, {"x": 4750, "tex": "print_human", "flip": true, "y": 4},
			{"x": 3400, "tex": "print_human", "flip": true}, {"x": 3310, "tex": "print_human", "flip": true, "y": 4},
			{"x": 3220, "tex": "print_human", "flip": true}, {"x": 3130, "tex": "print_human", "flip": true, "y": 4},
			{"x": 3040, "tex": "print_human", "flip": true}, {"x": 2950, "tex": "print_human", "flip": true, "y": 4},
		],
		"objects": [
			{"id": "coins", "label": "벼랑 끝", "x": 2840, "dialogue": "search_coins", "hide_if": "got_coins", "glint": true},
			{"id": "cliff", "label": "벼랑 끝", "x": 2840, "dialogue": "search_cliff_r", "if": "got_coins"},
		],
		"shades": [[5100, 1, 0.48, "got_coins", "blink"]], "shade_alpha": 0.75,   # 벼랑에서 돌아오는 길에만 — 스윽 나타났다가 사라진다 (2.5 이후: 더 잘 보이게)
		"triggers": [
			{"x": 5500, "dir": -1, "dialogue": "search_start", "once": "search_started"},
			{"x": 4950, "dir": -1, "dialogue": "search_prints", "once": "search_prints_seen"},
			{"x": 4150, "dir": -1, "dialogue": "search_rocks", "once": "search_rocks_seen"},
			{"x": 3200, "dir": -1, "dialogue": "search_fork", "once": "search_fork_seen"},
		],
		"walls": [{"x": 2770, "side": "left", "say": "(더는 길이 없다. 그 너머는 낭떠러지다.)"}],
		"exits": {"right": {"x": 5930, "to": "sinnyeong_morning", "spawn": "left", "cond": "search_done", "locked": "search_exit_locked", "run": "ch2_after_search"}},
	},
	"seonang": {
		"name": "의흥 어귀 · 서낭당 고개", "width": 4800,
		"time": [[0, "night"]], "bgm": "night", "amb": ["wind", "crickets"],
		"horse": true, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		"objects": [
			{"id": "cairn", "label": "서낭당 돌무더기", "x": 2950, "dialogue": "seonang_cairn", "repeat": "seonang_cairn_r", "done": "seonang_cairn_done"},
			{"id": "rope", "label": "금줄 두른 신목", "x": 3200, "dialogue": "seonang_rope", "repeat": "seonang_rope_r", "done": "got_rope", "glint": true, "glint_off": "got_rope"},
			{"id": "jangseung", "label": "장승", "x": 4265, "dialogue": "seonang_jangseung"},
		],
		"triggers": [
			{"x": 260, "dialogue": "seonang_start", "once": "seonang_entered"},
			{"x": 1200, "once": "seonang_b1", "amb": "owl", "barks": [["최헌", "(불이 없으니 발밑이 보이지 않는다.)"]]},
			{"x": 2100, "once": "seonang_b2", "amb": "redeyes", "barks": [["최헌", "(…저 수풀 속에, 무언가 있다.)"]]},
			{"x": 3650, "dialogue": "seonang_stones", "once": "seonang_stones"},
		],
		"exits": {"right": {"x": 4730, "to": "uiheung", "spawn": "left", "cond": "seonang_stones"}},
	},
	"uiheung": {
		"name": "의흥 · 노인의 초가", "width": 2400,
		"time": [[0, "night"]], "bgm": "night", "amb": ["crickets", ""],
		"horse": true, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		"npcs": [
			{"id": "oldman", "sprite": "oldman", "x": 1250, "pose": "oldman_lie", "pose_frames": 3, "pose_until": "oldman_up",
				"dialogue": "ch2_oldman", "repeat": "ch2_oldman_r", "done": "talked_oldman", "need_dismount": "ch2_oldman_mounted"},
		],
		"objects": [
			{"id": "maru", "label": "방", "x": 1560, "dialogue": "ch2_maru", "pre_if": "talked_oldman", "pre_dialogue": "ch2_maru_early", "need_dismount": "ch2_oldman_mounted"},
			{"id": "well", "label": "우물", "x": 1960, "dialogue": "ch2_well", "pre_if": "talked_oldman", "pre_dialogue": "ch2_well_early"},
			{"id": "jars", "label": "장독", "x": 400, "dialogue": "ch2_jars"},
			{"id": "door", "label": "닫힌 사립문", "x": 700, "dialogue": "ch2_gate"},
		],
		"triggers": [{"x": 250, "dialogue": "ch2_uiheung_start", "once": "uiheung_entered"}],
		"walls": [{"x": 2300, "ifnot": "never", "say": "(오늘 밤은 이 집에서 신세를 지자.)"}],
	},
	# ===================== 제3장 「문을 닫는 자」 =====================
	"uiheung_morning": {
		"name": "의흥 · 아침", "width": 3800, "scenery": "uiheung_morning",
		"time": [[0, "gloom"]], "bgm": "home", "amb": ["wind", ""],
		"horse": true, "horse_park": 420, "companion": false, "no_back": true,
		"spawn": {"start": 1560},
		"npcs": [
			{"id": "oldman", "sprite": "oldman", "x": 1250, "dialogue": "ch3_oldman", "repeat": "ch3_oldman_r", "done": "farewell_done", "hide_if": "ch3_lookback"},
		],
		"objects": [
			{"id": "well", "label": "우물", "x": 1960, "dialogue": "ch3_well"},
			{"id": "ruin", "label": "무너진 집", "x": 1350, "dialogue": "ch3_ruin", "if": "ch3_lookback"},
		],
		"triggers": [
			{"x": 0, "dialogue": "ch3_wake", "once": "ch3_woke"},
			{"x": 3050, "dialogue": "ch3_lookback", "once": "ch3_lookback", "if": "farewell_done"},
		],
		"exits": {"right": {"x": 3730, "to": "road5", "spawn": "left", "cond": "farewell_done", "locked": "ch3_exit_locked"}},
	},
	"road5": {
		"name": "함창 · 상주 가는 길", "width": 8400,
		"time": [[0, "gloom"], [8400, "gloom_dark"]], "bgm": "dusk", "amb": ["wind", ""], "fog": 0.05,
		"horse": true, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		"flame": {"on": "flame3_seen", "off": "never"},
		"crow_perch": [7764, 266],
		"triggers": [
			{"x": 400, "dialogue": "ch3_start", "once": "ch3_started"},
			{"x": 1300, "event": "flame_appear", "dialogue": "ch3_father", "once": "flame3_seen"},
			{"x": 2200, "once": "road5_b1", "amb": "crows", "barks": [["최헌", "(까마귀가… 내가 가는 쪽으로만 난다.)"]]},
			{"x": 3000, "dialogue": "ch3_procession", "once": "ch3_procession_seen", "if": "flame3_seen"},
			{"x": 3800, "once": "road5_b2", "amb": "dog", "barks": [["최헌", "(멀리서 개가 짖는다. 마을이 가까운가.)"], ["", "(…개 짖는 소리가 뚝 그쳤다.)"]]},
			{"x": 4600, "dialogue": "ch3_voice", "once": "ch3_voice_heard", "if": "ch3_procession_seen"},
			{"x": 5800, "once": "road5_b3", "amb": "redeyes", "barks": [["최헌", "(누가 보고 있다. 길 양옆에서.)"]]},
			{"x": 7700, "dialogue": "ch3_crows", "once": "ch3_crows_seen", "if": "ch3_voice_heard"},
		],
		"objects": [
			{"id": "sign", "label": "이정표", "x": 7300, "dialogue": "ch3_sign", "repeat": "ch3_sign_r"},
		],
		"exits": {"right": {"x": 8330, "to": "sindang", "spawn": "left", "cond": "ch3_voice_heard"}},
	},
	"sindang": {
		"name": "길가의 신당", "width": 4400,
		"time": [[0, "sunset"], [4400, "dusk"]], "bgm": "shrine", "amb": ["wind", ""],
		"horse": true, "companion": false, "no_back": true,
		"spawn": {"left": 200, "after": 1520},
		"flame": {"on": "flame3_seen", "off": "never", "hold": "sindang_hold", "hold_off": "never", "hold_x": 680},
		"npcs": [
			{"id": "wolseon", "sprite": "wolseon", "idle": "wolseon_idle", "x": 1640, "dialogue": "ch3_wolseon", "done": "wolseon_done", "hide_if": "wolseon_done", "need_dismount": "ch3_wolseon_mounted"},
		],
		"objects": [
			{"id": "tree", "label": "신목", "x": 1430, "dialogue": "ch3_shrine_tree"},
			{"id": "cairn", "label": "돌탑", "x": 1250, "dialogue": "ch3_cairn"},
		],
		"shades": [[2350, 4, 0.42], [3050, 1, 0.48, "ch3_bell"], [3850, 3, 0.5, "ch3_bell"]],   # 배경의 검은 형체 [x, 그림 번호 0~4, 크기, 나타날 조건]
		"triggers": [
			{"x": 350, "dialogue": "ch3_sindang_start", "once": "sindang_entered"},
			{"x": 2700, "once": "sindang_b1", "if": "ch3_bell", "amb": "bell", "barks": [["", "(손에 쥔 방울이, 바람도 없는데 저 혼자 울린다.)"]]},
			{"x": 3500, "once": "sindang_b2", "if": "ch3_bell", "amb": "redeyes", "barks": [["최헌", "(길이… 산 안쪽으로만 나 있다.)"]]},
		],
		# 2.3: 방울을 주운 뒤에는 신당 너머로 걸어서 기괴한 숲으로 간다
		"walls": [{"x": 2400, "ifnot": "ch3_bell", "say": "(신당 앞의 무당이 이쪽을 보고 있다.)"}],
		"exits": {"right": {"x": 4330, "to": "gisoe", "spawn": "left", "cond": "ch3_bell", "mount": true}},
	},
	"gisoe": {
		"name": "어딘가 · 기괴한 숲", "width": 10000,
		"time": [[0, "eternal"]], "bgm": "eerie", "amb": ["wind", ""], "fog": 0.1,
		"horse": true, "forced_ride": true, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		# 2.3: 숲을 더 길게 (불가사리까지 오래 간다), 검은 형체 5
		"shades": [[1500, 1, 0.48], [3000, 2, 0.48], [4600, 0, 0.5], [6300, 4, 0.5], [7700, 3, 0.5]], "shade_alpha": 0.75,
		"triggers": [
			{"x": 300, "dialogue": "gisoe_start", "once": "gisoe_started"},
			{"x": 1200, "once": "gisoe_b1", "amb": "redeyes2,growl", "barks": [["최헌", "(말이… 내 뜻대로 가지 않는다.)"]]},
			{"x": 2400, "once": "gisoe_b2", "amb": "crows", "barks": [["", "(나뭇가지가 손가락처럼 뒤틀려 있다.)"]]},
			{"x": 3600, "once": "gisoe_b3", "amb": "gust", "barks": [["최헌", "(얼마나 들어온 거지… 길이 보이지 않는다.)"]]},
			{"x": 4900, "once": "gisoe_b6", "amb": "bell", "barks": [["", "(품속의 방울이 또 운다. 멈추지 않는다.)"]]},
			{"x": 5900, "once": "gisoe_b4", "amb": "redeyes", "barks": [["", "(숲 안쪽에서, 쇠를 긁는 소리가 난다.)"]]},
			{"x": 7000, "once": "gisoe_b7", "amb": "gust", "barks": [["최헌", "(돌아갈 길도… 이제 보이지 않는다.)"]]},
			{"x": 8200, "once": "gisoe_b5", "amb": "growl", "barks": [["최헌", "(…무언가 있다.)"]]},
			{"x": 8800, "dialogue": "gisoe_beast", "once": "gisoe_beast"},
		],
		"walls": [{"x": 8900, "ifnot": "never"}],
	},
	# ===================== 제4장 「길이 가리키는 곳」 =====================
	"road6": {
		"name": "상주 → 문경", "width": 8000,
		"time": [[0, "eternal"]], "bgm": "eerie", "amb": ["wind", ""], "fog": 0.08,
		"horse": false, "companion": false, "no_back": true,
		"spawn": {"left": 300},
		"start_pose": ["lie", "ch4_started"],
		"shades": [[950, 0, 0.5], [1900, 2, 0.48], [3800, 4, 0.5], [5500, 1, 0.48], [7300, 3, 0.5]], "shade_alpha": 0.75,   # 배경의 검은 형체 [x, 그림 번호 0~4, 크기] — 가까이 가면 스르륵 사라진다
		"triggers": [
			{"x": 0, "dialogue": "ch4_start", "once": "ch4_started"},
			{"x": 1400, "once": "road6_b1", "amb": "redeyes2", "barks": [["최헌", "(눈… 붉은 눈들이 나무 사이에서 깜빡인다.)"], ["최헌", "(보지 말자. 앞만 보자.)"]]},
			{"x": 2400, "event": "figure_pass", "dialogue": "ch4_figure1", "once": "ch4_fig1"},
			{"x": 3300, "once": "road6_b2", "amb": "steps_behind", "barks": [["최헌", "(내 발소리가… 한 박자 늦게 따라온다.)"]]},
			{"x": 4300, "once": "road6_b3", "amb": "whisper", "barks": [["", "「헌아.」"], ["최헌", "(바람이다. 바람 소리다.)"]]},
			{"x": 5200, "once": "road6_b4", "amb": "crows", "barks": [["최헌", "(얼마나 걸었지? 다리가 내 것 같지 않다.)"]]},
			{"x": 5700, "event": "hands_burst", "dialogue": "ch4_hands", "once": "ch4_hands_seen"},
		],
		"objects": [
			{"id": "tree", "label": "뒤틀린 나무", "x": 6200, "dialogue": "ch4_tree"},
			{"id": "stone", "label": "이정표", "x": 6800, "dialogue": "ch4_stone"},
		],
		"exits": {"right": {"x": 7930, "to": "road7", "spawn": "left", "cond": "ch4_hands_seen"}},
	},
	"road7": {
		"name": "문경새재", "width": 8400,
		"time": [[0, "eternal"]], "bgm": "eerie", "amb": ["wind", ""], "fog": 0.15,
		"horse": false, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		"flame": {"on": "flame4_seen", "off": "flame4_gone"},
		"woman_x": 5920,
		"shades": [[1300, 0, 0.5], [2250, 4, 0.5], [3400, 1, 0.48], [4400, 3, 0.5], [7200, 2, 0.46]], "shade_alpha": 0.75,   # 배경의 검은 형체 [x, 그림 번호 0~4, 크기] — 가까이 가면 스르륵 사라진다
		"triggers": [
			{"x": 300, "dialogue": "ch4_saejae", "once": "saejae_entered"},
			{"x": 1900, "event": "flame_appear", "dialogue": "ch4_flame", "once": "flame4_seen"},
			{"x": 2600, "dialogue": "ch4_coins_trail", "once": "ch4_coins_trail", "if": "flame4_seen", "ifnot": "got_coins"},
			{"x": 3800, "event": "eyes_open", "dialogue": "ch4_eyes", "once": "ch4_eyes_seen"},
			{"x": 4700, "once": "road7_b1", "amb": "sob", "barks": [["", "(어디선가 여자가 흐느끼는 소리가 들린다.)"]]},
			{"x": 5500, "dialogue": "ch4_woman", "once": "ch4_woman_met"},
			{"x": 6700, "once": "road7_b2", "if": "woman_gone", "barks": [["최헌", "(…아까 그 여자는, 처음부터 없었던 걸까.)"]]},
			{"x": 7500, "once": "road7_b3", "amb": "crows", "if": "woman_gone", "barks": [["", "(바람 끝에, 말발굽 소리가 실려 온다.)"]]},
		],
		"decals": [
			{"x": 2650, "tex": "coin", "ifnot": "got_coins"}, {"x": 2740, "tex": "coin", "ifnot": "got_coins", "y": 3},
			{"x": 2830, "tex": "coin", "ifnot": "got_coins"}, {"x": 2920, "tex": "coin", "ifnot": "got_coins", "y": 2},
			{"x": 3010, "tex": "coin", "ifnot": "got_coins"},
		],
		"objects": [
			{"id": "coins", "label": "엽전주머니", "x": 3110, "dialogue": "ch4_coins", "hide_if": "got_coins", "glint": true},
			{"id": "ring", "label": "반짝이는 것", "x": 5920, "dialogue": "ch4_ring", "if": "woman_gone", "hide_if": "got_ring", "glint": true},
		],
		"walls": [{"x": 5600, "ifnot": "woman_gone"}],
		"exits": {"right": {"x": 8330, "to": "road8", "spawn": "left", "cond": "woman_gone"}},
	},
	"road8": {
		"name": "문경새재 · 셋째 관문 너머", "width": 11000,
		"time": [[0, "eternal"]], "bgm": "eerie", "amb": ["wind", ""], "fog": 0.2,
		"horse": false, "companion": false, "no_back": true,
		"spawn": {"left": 200},
		"flame": {"on": "flame4_seen", "off": "flame4_gone"},
		"chase_end": 6900,
		"shades": [[1200, 4, 0.5], [5000, 0, 0.5], [7400, 2, 0.46], [8300, 1, 0.48], [9800, 3, 0.5]], "shade_alpha": 0.75,   # 배경의 검은 형체 [x, 그림 번호 0~4, 크기] — 가까이 가면 스르륵 사라진다
		"triggers": [
			{"x": 700, "event": "horse_ghost", "dialogue": "ch4_horse", "once": "ch4_horse_seen"},
			{"x": 1600, "once": "road8_b1", "barks": [["최헌", "(눈이 없는 말… 내가 타고 온 말이었다.)"]]},
			{"x": 2300, "once": "road8_b2", "amb": "redeyes", "barks": [["최헌", "(불은 계속 앞서간다. 한 번도 뒤를 돌아보지 않고.)"]]},
			{"x": 3000, "dialogue": "ch4_scarecrow", "once": "ch4_chase"},
			{"x": 7900, "once": "road8_b3", "if": "chase_done", "barks": [["최헌", "(숨이… 아직도 가슴이 뛴다.)"]]},
			{"x": 8700, "once": "road8_b4", "if": "chase_done", "amb": "gust", "barks": [["", "(「헌아.」 하는 바람 소리.)"]]},
			{"x": 9500, "once": "road8_b5", "if": "chase_done", "amb": "redeyes", "barks": [["최헌", "(불이 멈췄다. 저 앞에 무언가 떨어져 있다.)"]]},
			{"x": 10200, "dialogue": "ch4_sandal", "once": "sandal_found", "if": "chase_done"},
		],
		"walls": [{"x": 10300, "ifnot": "sandal_found"}],
	},
	# ===================== 終章 「이름」 =====================
	"past": {
		"name": "청월령 · 누군가의 과거", "width": 2400, "player": "inbaek",
		"time": [[0, "past"]], "bgm": "past", "amb": ["wind", ""],
		"horse": false, "companion": false, "no_back": true,
		"spawn": {"left": 200, "seal": 1700},
		"start_pose": ["sit", "past_started"],
		"objects": [{"id": "monument", "label": "봉인석", "x": 1800, "dialogue": "end_seal", "ifnot": "sealed"}],
		"triggers": [{"x": 0, "dialogue": "end_past_start", "once": "past_started"}],
		"wisps": [[1500, 300], [1650, 250], [1950, 270], [2100, 320], [1800, 200], [1300, 340]],
	},
	"hall": {
		"name": "한양 · 과거시험장", "width": 2600,
		"time": [[0, "hall"]], "bgm": "hall", "amb": ["drip", ""],
		"horse": false, "companion": false, "no_back": true,
		"spawn": {"left": 420, "after": 1430},
		"shades": [[2050, 1, 0.48, "hall_started"]], "shade_alpha": 0.75,   # 2.3: 텅 빈 시험장 구석의 검은 형체
		"objects": [
			{"id": "gate", "label": "홍살문", "x": 300, "dialogue": "end_gate"},
			{"id": "seats", "label": "빈 자리", "x": 900, "dialogue": "end_seats"},
			{"id": "puddle", "label": "물웅덩이", "x": 1150, "dialogue": "end_puddle", "repeat": "end_puddle_r"},
			{"id": "desk", "label": "책상", "x": 1500, "dialogue": "end_paper", "repeat": "end_paper_done", "done": "wrote_name"},
		],
		"triggers": [
			{"x": 430, "dialogue": "end_hall_start", "once": "hall_started"},
			{"x": 1250, "event": "ghost_prints", "dialogue": "end_prints", "once": "hall_prints", "ifnot": "wrote_name"},
		],
		"walls": [{"x": 2450, "ifnot": "never", "say": "(…더 갈 곳이 없다.)"}],
	},
}

## 시간대별 화면 색 (곱하기)과 하늘 그림
const TINT := {
	"dawn": Color(0.80, 0.77, 0.93), "morning": Color(0.97, 0.95, 0.94), "day": Color(1, 1, 1),
	"afternoon": Color(1.0, 0.95, 0.86), "sunset": Color(1.0, 0.79, 0.70), "dusk": Color(0.60, 0.54, 0.74),
	"night": Color(0.42, 0.46, 0.70),
	"gloom": Color(0.74, 0.74, 0.80), "gloom_dark": Color(0.55, 0.55, 0.66),
	"eternal": Color(0.40, 0.42, 0.58), "past": Color(0.50, 0.55, 0.92), "hall": Color(0.56, 0.60, 0.72),
}
const SKY := {
	"dawn": "dawn", "morning": "day", "day": "day", "afternoon": "day", "sunset": "sunset", "dusk": "sunset", "night": "night",
	"gloom": "overcast", "gloom_dark": "overcast", "eternal": "night", "past": "night", "hall": "void",
}
## 0 = 밝음, 1 = 완전히 어두움 (등불 밝기에 씀)
const DARK := {"dawn": 0.45, "morning": 0.05, "day": 0.0, "afternoon": 0.1, "sunset": 0.3, "dusk": 0.65, "night": 1.0, "gloom": 0.3, "gloom_dark": 0.55, "eternal": 1.0, "past": 0.9, "hall": 0.8}
