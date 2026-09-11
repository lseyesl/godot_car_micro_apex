extends RefCounted

const CARS: Array[Dictionary] = [
	{"id":"car_speed", "name":"赤焰 GT", "role":"高速型", "color":Color("f05a42"), "top":49.0, "accel":8.0, "radius":8.8, "grip":15.3, "dirt":0.68, "brake":23.0, "mass":1.2},
	{"id":"car_agile", "name":"黄蜂 RS", "role":"灵巧型", "color":Color("f2c94c"), "top":40.0, "accel":11.5, "radius":5.5, "grip":16.0, "dirt":0.72, "brake":25.0, "mass":0.9},
	{"id":"car_dirt", "name":"蓝岭 RX", "role":"土路型", "color":Color("548feb"), "top":42.0, "accel":9.0, "radius":7.3, "grip":14.2, "dirt":0.94, "brake":22.5, "mass":1.15},
	{"id":"car_balanced", "name":"青岚 S", "role":"均衡型", "color":Color("68ba80"), "top":44.0, "accel":9.6, "radius":6.8, "grip":15.2, "dirt":0.78, "brake":24.0, "mass":1.0}
]
const TRACKS: Array[Dictionary] = [
	{"name":"滨海疾线", "tag":"高速直道 · 柏油为主", "dirt_ranges":[Vector2(0.46,0.68)], "points":[Vector2(-150,80),Vector2(-150,-90),Vector2(-100,-155),Vector2(150,-155),Vector2(205,-100),Vector2(205,60),Vector2(135,130),Vector2(-70,140)]},
	{"name":"林间折线", "tag":"连续弯道 · 混合路面", "dirt_ranges":[Vector2(0.22,0.42),Vector2(0.65,0.85)], "points":[Vector2(-145,90),Vector2(-170,-10),Vector2(-135,-110),Vector2(-50,-145),Vector2(25,-80),Vector2(110,-145),Vector2(175,-65),Vector2(110,5),Vector2(170,100),Vector2(60,150),Vector2(-15,80),Vector2(-80,150)]},
	{"name":"红土牧场", "tag":"宽弯拉力 · 土路为主", "dirt_ranges":[Vector2(0.15,0.51),Vector2(0.58,0.94)], "points":[Vector2(-140,100),Vector2(-185,-5),Vector2(-130,-115),Vector2(-15,-145),Vector2(115,-100),Vector2(180,-10),Vector2(115,55),Vector2(155,145),Vector2(35,175),Vector2(-65,125)]}
]
const DIFFICULTIES: Array[String] = ["简单", "普通", "困难"]

static func clock_text(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return "--:--.---"
	var ms := int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
