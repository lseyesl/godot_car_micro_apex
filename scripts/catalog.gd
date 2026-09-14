extends RefCounted

const CARS: Array[Dictionary] = [
	{"id":"car_speed", "name":"赤焰 GT", "role":"高速型", "color":Color("f05a42"), "top":49.0, "accel":8.0, "radius":4.0, "grip":15.3, "dirt":0.68, "brake":23.0, "mass":1.2},
	{"id":"car_agile", "name":"黄蜂 RS", "role":"灵巧型", "color":Color("f2c94c"), "top":40.0, "accel":11.5, "radius":2.5, "grip":16.0, "dirt":0.72, "brake":25.0, "mass":0.9},
	{"id":"car_dirt", "name":"蓝岭 RX", "role":"土路型", "color":Color("548feb"), "top":42.0, "accel":9.0, "radius":3.3, "grip":14.2, "dirt":0.94, "brake":22.5, "mass":1.15},
	{"id":"car_balanced", "name":"青岚 S", "role":"均衡型", "color":Color("68ba80"), "top":44.0, "accel":9.6, "radius":3.0, "grip":15.2, "dirt":0.78, "brake":24.0, "mass":1.0}
]
const TRACKS: Array[Dictionary] = [
	{"name":"海湾俱乐部", "tag":"海蓝水岸 · 维修车库 · 连续回转", "dirt_ranges":[Vector2(0.6,0.78)], "bridge_controls":[], "points":[Vector2(-85,92),Vector2(-110,50),Vector2(-108,-45),Vector2(-82,-92),Vector2(-20,-98),Vector2(30,-72),Vector2(88,-92),Vector2(110,-52),Vector2(86,-12),Vector2(22,-10),Vector2(-20,-38),Vector2(-52,-20),Vector2(-48,20),Vector2(12,32),Vector2(78,28),Vector2(104,68),Vector2(70,100),Vector2(0,94)]},
	{"name":"松林营地", "tag":"林间营位 · 混合路面 · 双发卡弯", "dirt_ranges":[Vector2(0.2,0.42),Vector2(0.62,0.88)], "bridge_controls":[], "points":[Vector2(-85,94),Vector2(-108,40),Vector2(-104,-55),Vector2(-72,-100),Vector2(-15,-102),Vector2(5,-65),Vector2(-30,-38),Vector2(-54,-8),Vector2(-22,14),Vector2(20,-10),Vector2(43,-63),Vector2(84,-90),Vector2(108,-48),Vector2(94,9),Vector2(55,48),Vector2(85,84),Vector2(43,107),Vector2(-20,83)]},
	{"name":"红岩牧场", "tag":"砂岩地貌 · 红土内场 · 技术折返", "dirt_ranges":[Vector2(0.15,0.51),Vector2(0.58,0.94)], "bridge_controls":[], "points":[Vector2(-82,96),Vector2(-110,48),Vector2(-100,-18),Vector2(-112,-72),Vector2(-72,-102),Vector2(-25,-80),Vector2(-28,-23),Vector2(10,-7),Vector2(35,-49),Vector2(45,-94),Vector2(87,-93),Vector2(110,-50),Vector2(98,10),Vector2(60,23),Vector2(27,56),Vector2(58,96),Vector2(9,106),Vector2(-33,68)]},
]
const DIFFICULTIES: Array[String] = ["简单", "普通", "困难"]

static func clock_text(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return "--:--.---"
	var ms := int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
