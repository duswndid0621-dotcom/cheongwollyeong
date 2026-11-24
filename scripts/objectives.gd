class_name Objectives
## 화면 오른쪽 위에 보이는 '지금 할 일'. 지역마다 위에서부터 조건이 맞는 첫 줄을 보여 준다.
## if = 이 표시들이 모두 켜져 있어야, ifnot = 하나라도 켜져 있으면 안 됨, has/hasnot = 아이템.
## 글을 바꾸고 싶으면 여기 "t" 만 고치면 된다.

const LIST := {
	"gotaek": [
		{"ifnot": ["talked_grandma"], "t": "할머니(최옥순)께 인사드리기"},
		{"t": "오른쪽 대문으로 집을 나서기"},
	],
	"golmok": [
		{"ifnot": ["talked_seo"], "t": "골목에서 기다리는 서문경과 이야기하기"},
		{"t": "말에 타고(R) 오른쪽 스승님 댁으로 가기"},
	],
	"seunim": [
		{"ifnot": ["got_map"], "t": "스승님(이정언)께 인사드리기"},
		{"t": "오른쪽 길로 한양을 향해 떠나기"},
	],
	"road1": [
		{"t": "들판 길을 따라 영천 쪽으로 가기"},
	],
	"road2": [
		{"ifnot": ["pavilion_asked"], "t": "영천 가는 길을 따라가기"},
		{"if": ["pavilion_asked"], "ifnot": ["rested", "road2_sunset_seen"], "t": "정자에서 쉬어 가기 (선택)  ·  길을 따라가기"},
		{"t": "해 지기 전에 산길로 들어서기"},
	],
	"road3": [
		{"ifnot": ["talked_nageune"], "t": "산길을 따라 신녕 쪽으로 가기"},
		{"ifnot": ["flame_seen"], "t": "어두워지는 산길을 계속 가기"},
		{"ifnot": ["fork_done"], "t": "푸른 불을 따라가기"},
		{"ifnot": ["rock_done"], "t": "불이 멈춘 곳까지 가 보기"},
		{"ifnot": ["flame_gone"], "t": "푸른 불을 따라 산을 넘기"},
		{"t": "신녕 주막거리로 가기"},
	],
	"sinnyeong": [
		{"ifnot": ["talked_jumo"], "t": "주막의 주모와 이야기하기"},
		{"ifnot": ["seo_drink_done"], "t": "평상에서 문경이와 한잔하기"},
		{"t": "주막 방문 앞에서 잠자리에 들기"},
	],
	"sinnyeong_morning": [
		{"ifnot": ["talked_jumo2"], "t": "주모에게 문경이를 보았는지 묻기"},
		{"ifnot": ["ch2_decided"], "t": "문경이를 찾을지, 떠날지 정하기"},
		{"t": "오른쪽 의흥 가는 산길로 떠나기"},
	],
	"search_pass": [
		{"ifnot": ["search_done"], "t": "어젯밤 넘어온 고갯길에서 문경이의 흔적 찾기"},
		{"t": "주막거리로 돌아가기 (오른쪽)"},
	],
	"road4": [
		{"ifnot": ["help2_done"], "t": "산길을 따라 의흥으로 가기"},
		{"ifnot": ["voice_done"], "t": "의흥을 향해 계속 걷기"},
		{"t": "고개를 넘어 의흥 어귀로 가기"},
	],
	"seonang": [
		{"ifnot": ["seonang_stones"], "t": "어두운 서낭당 고개를 넘어가기"},
		{"t": "의흥 마을로 내려가기"},
	],
	"uiheung": [
		{"ifnot": ["talked_oldman"], "t": "불 켜진 초가의 노인에게 말 걸기"},
		{"t": "노인이 내준 방에서 잠자리에 들기"},
	],
	"uiheung_morning": [
		{"ifnot": ["farewell_done"], "t": "노인께 작별 인사 드리기"},
		{"t": "사립문을 나와 함창 쪽으로 떠나기"},
	],
	"road5": [
		{"ifnot": ["ch3_voice_heard"], "t": "함창 · 상주 쪽으로 길을 따라가기"},
		{"t": "앞만 보고 계속 가기"},
	],
	"sindang": [
		{"ifnot": ["wolseon_done"], "t": "길가 신당의 무당과 이야기하기"},
		{"if": ["ch3_bell"], "t": "신당 너머, 산 안쪽으로 가기"},
		{"t": "…"},
	],
	"gisoe": [
		{"t": "(말이 멈추지 않는다)"},
	],
	"road6": [
		{"ifnot": ["ch4_hands_seen"], "t": "한양으로 가는 길을 따라 문경 쪽으로"},
		{"t": "문경새재로 가기"},
	],
	"road7": [
		{"ifnot": ["flame4_seen"], "t": "문경새재를 넘기"},
		{"ifnot": ["woman_gone"], "t": "푸른 불과 지도를 따라가기"},
		{"if": ["woman_gone"], "hasnot": "ring", "t": "고목 아래 반짝이는 것 줍기 (E)"},
		{"t": "고개 너머로 계속 가기"},
	],
	"road8": [
		{"if": ["ch4_chase"], "ifnot": ["chase_done"], "t": "Shift 로 달려 도망치기!"},
		{"ifnot": ["chase_done"], "t": "셋째 관문 너머로 계속 가기"},
		{"t": "푸른 불이 멈춘 곳으로 가기"},
	],
	"past": [
		{"ifnot": ["sealed"], "t": "봉인석 앞으로 가기"},
		{"t": "…"},
	],
	"hall": [
		{"ifnot": ["wrote_name"], "t": "시험장 가운데 책상의 종이 살펴보기"},
		{"t": "…"},
	],
}

static func current(area: String) -> String:
	for o in LIST.get(area, []):
		if _ok(o):
			return o.t
	return ""

static func _ok(o: Dictionary) -> bool:
	for f in o.get("if", []):
		if not Game.flag(f):
			return false
	for f in o.get("ifnot", []):
		if Game.flag(f):
			return false
	if o.has("has") and not Game.has_item(o.has):
		return false
	if o.has("hasnot") and Game.has_item(o.hasnot):
		return false
	return true
