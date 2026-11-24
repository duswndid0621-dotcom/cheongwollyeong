class_name MapData
## 지도 위 도시 좌표 (Map_Original.png 887×887 픽셀 기준, 지명은 그림에 그려져 있음)와 붉은 길 경로.

const PLACES := [
	{"name": "경주", "hanja": "慶州", "x": 605, "y": 716, "big": true},
	{"name": "신녕", "hanja": "新寧", "x": 461, "y": 575, "big": true},
	{"name": "함창", "hanja": "咸昌", "x": 502, "y": 429, "big": true},
	{"name": "문경", "hanja": "聞慶", "x": 386, "y": 315, "big": true},
	{"name": "한양", "hanja": "漢陽", "x": 263, "y": 131, "big": true}
]

## 한자 지명 아래(옆)에 붙이는 한글 지명 (지도 그림 픽셀 기준, 글자 가운데)
const KO_LABELS := [
	{"t": "경주", "x": 686, "y": 730},
	{"t": "신녕", "x": 512, "y": 590},
	{"t": "함창", "x": 540, "y": 444},
	{"t": "문경", "x": 415, "y": 340},
	{"t": "한양", "x": 352, "y": 86},
]

## 지도 그림의 붉은 점선을 따라 뽑은 길 (경주 → 한양). 도시 위치: 경주 0, 신녕 0.269, 함창 0.482, 문경 0.704, 한양 1
const ROUTE := [Vector2(605, 716), Vector2(602, 710), Vector2(599, 705), Vector2(597, 700), Vector2(594, 695), Vector2(591, 689), Vector2(589, 684), Vector2(586, 678), Vector2(584, 673), Vector2(581, 668), Vector2(578, 663), Vector2(575, 658), Vector2(571, 653), Vector2(567, 648), Vector2(563, 644), Vector2(559, 640), Vector2(554, 637), Vector2(549, 634), Vector2(543, 631), Vector2(538, 629), Vector2(532, 627), Vector2(526, 625), Vector2(521, 623), Vector2(515, 621), Vector2(509, 620), Vector2(504, 617), Vector2(498, 615), Vector2(493, 612), Vector2(488, 609), Vector2(484, 605), Vector2(480, 601), Vector2(476, 596), Vector2(472, 591), Vector2(469, 586), Vector2(466, 581), Vector2(464, 576), Vector2(462, 570), Vector2(462, 565), Vector2(462, 559), Vector2(463, 553), Vector2(465, 547), Vector2(467, 542), Vector2(470, 537), Vector2(473, 532), Vector2(477, 528), Vector2(482, 524), Vector2(486, 520), Vector2(491, 516), Vector2(496, 513), Vector2(500, 508), Vector2(504, 504), Vector2(507, 499), Vector2(510, 494), Vector2(512, 488), Vector2(514, 483), Vector2(515, 477), Vector2(515, 471), Vector2(514, 465), Vector2(513, 459), Vector2(512, 454), Vector2(510, 448), Vector2(508, 442), Vector2(505, 437), Vector2(503, 431), Vector2(500, 426), Vector2(498, 420), Vector2(496, 415), Vector2(493, 410), Vector2(490, 404), Vector2(487, 399), Vector2(483, 395), Vector2(479, 390), Vector2(475, 386), Vector2(470, 382), Vector2(466, 379), Vector2(460, 375), Vector2(455, 373), Vector2(450, 370), Vector2(444, 368), Vector2(439, 365), Vector2(433, 363), Vector2(428, 360), Vector2(423, 357), Vector2(418, 354), Vector2(413, 350), Vector2(409, 346), Vector2(405, 342), Vector2(401, 338), Vector2(397, 333), Vector2(394, 328), Vector2(391, 323), Vector2(388, 318), Vector2(385, 312), Vector2(382, 307), Vector2(379, 302), Vector2(376, 297), Vector2(373, 292), Vector2(369, 287), Vector2(365, 283), Vector2(361, 279), Vector2(356, 275), Vector2(351, 272), Vector2(346, 270), Vector2(340, 267), Vector2(335, 265), Vector2(330, 262), Vector2(325, 258), Vector2(321, 254), Vector2(318, 249), Vector2(316, 244), Vector2(314, 238), Vector2(314, 232), Vector2(313, 226), Vector2(313, 221), Vector2(313, 215), Vector2(312, 209), Vector2(310, 203), Vector2(307, 198), Vector2(304, 193), Vector2(300, 189), Vector2(296, 185), Vector2(291, 181), Vector2(287, 177), Vector2(282, 173), Vector2(279, 168), Vector2(275, 164), Vector2(273, 158), Vector2(270, 153), Vector2(268, 147), Vector2(267, 143), Vector2(263, 131)]

## 지역별 지도 위 위치 (경로 비율 0=경주, 1=한양). [시작, 끝] 사이를 지역 안 위치로 보간.
const AREA_FRAC := {
	"gotaek": [0.0, 0.0], "golmok": [0.0, 0.0], "seunim": [0.0, 0.005],
	"road1": [0.005, 0.08], "road2": [0.08, 0.17], "road3": [0.17, 0.262], "sinnyeong": [0.269, 0.269],
	"sinnyeong_morning": [0.269, 0.269], "search_pass": [0.235, 0.268], "road4": [0.269, 0.33], "seonang": [0.33, 0.35], "uiheung": [0.35, 0.35], "uiheung_morning": [0.35, 0.36],
	"road5": [0.36, 0.482], "sindang": [0.49, 0.5], "gisoe": [0.5, 0.52], "road6": [0.52, 0.66], "road7": [0.66, 0.70], "road8": [0.70, 0.72],
}
const AREA_LABEL := {
	"gotaek": "경주 · 최씨 고택", "golmok": "경주 · 고택 앞 길", "seunim": "경주 · 스승의 집",
	"road1": "경주 → 영천 · 들판 길", "road2": "영천 가는 길", "road3": "신녕 가는 산길", "sinnyeong": "신녕 · 주막거리",
	"sinnyeong_morning": "신녕 · 주막거리", "search_pass": "신녕 뒷산 고갯길", "road4": "의흥 가는 산길", "seonang": "의흥 어귀 · 서낭당 고개", "uiheung": "의흥", "uiheung_morning": "의흥",
	"road5": "함창 · 상주 가는 길", "sindang": "상주 근처 · 신당", "gisoe": "…어딘가", "road6": "상주 → 문경", "road7": "문경새재", "road8": "문경새재 · 셋째 관문 너머",
}

static func area_label(area: String) -> String:
	return AREA_LABEL.get(area, area)

static func point_at(frac: float) -> Vector2:
	var total := 0.0
	for i in range(1, ROUTE.size()):
		total += (ROUTE[i] - ROUTE[i - 1]).length()
	var target := clampf(frac, 0.0, 1.0) * total
	var acc := 0.0
	for i in range(1, ROUTE.size()):
		var seg: float = (ROUTE[i] - ROUTE[i - 1]).length()
		if acc + seg >= target:
			return ROUTE[i - 1].lerp(ROUTE[i], (target - acc) / max(seg, 0.001))
		acc += seg
	return ROUTE[ROUTE.size() - 1]

static func current_point() -> Vector2:
	var a: String = Game.state.area
	var fr: Array = AREA_FRAC.get(a, [0.0, 0.0])
	var w: float = AreaData.AREAS.get(a, {}).get("width", 2000)
	var t := clampf(float(Game.state.x) / w, 0.0, 1.0)
	return point_at(lerpf(fr[0], fr[1], t))
