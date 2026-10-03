extends RefCounted

const CARS: Array[Dictionary] = [
	{"id":"car_speed", "name":"赤焰 GT", "role":"高速型", "color":Color("f05a42"), "top":49.0, "accel":8.0, "radius":4.0, "grip":15.3, "dirt":0.68, "brake":23.0, "mass":1.2},
	{"id":"car_agile", "name":"黄蜂 RS", "role":"灵巧型", "color":Color("f2c94c"), "top":40.0, "accel":11.5, "radius":2.5, "grip":16.0, "dirt":0.72, "brake":25.0, "mass":0.9},
	{"id":"car_dirt", "name":"蓝岭 RX", "role":"土路型", "color":Color("548feb"), "top":42.0, "accel":9.0, "radius":3.3, "grip":14.2, "dirt":0.94, "brake":22.5, "mass":1.15},
	{"id":"car_balanced", "name":"青岚 S", "role":"均衡型", "color":Color("68ba80"), "top":44.0, "accel":9.6, "radius":3.0, "grip":15.2, "dirt":0.78, "brake":24.0, "mass":1.0},
	{"id":"car_pickup", "name":"铁牛 XT", "role":"越野皮卡", "color":Color("e99b45"), "top":41.0, "accel":8.8, "radius":3.7, "grip":14.8, "dirt":0.98, "brake":23.0, "mass":1.35},
	{"id":"car_roadster", "name":"银箭 R", "role":"敞篷跑车", "color":Color("b4d8df"), "top":47.0, "accel":10.2, "radius":2.8, "grip":16.3, "dirt":0.65, "brake":25.0, "mass":0.92},
	{"id":"car_muscle", "name":"紫电 V8", "role":"肌肉车", "color":Color("a77bcc"), "top":51.0, "accel":8.8, "radius":4.2, "grip":14.8, "dirt":0.66, "brake":24.0, "mass":1.3},
	{"id":"car_buggy", "name":"沙狐 BX", "role":"轻型越野", "color":Color("e1bd53"), "top":39.0, "accel":12.0, "radius":2.6, "grip":15.5, "dirt":1.0, "brake":24.0, "mass":0.8}
]
const TRACKS: Array[Dictionary] = [
	{"name":"海湾街区", "tag":"滨海街道 · 维修街区 · 港口回转", "dirt_ranges":[Vector2(0.6,0.78)], "bridge_controls":[], "points":[Vector2(-68,84),Vector2(-102,64),Vector2(-106,12),Vector2(-106,-50),Vector2(-82,-84),Vector2(-36,-84),Vector2(-13,-64),Vector2(-17,-28),Vector2(9,-9),Vector2(43,-22),Vector2(61,-61),Vector2(89,-77),Vector2(109,-49),Vector2(108,-7),Vector2(82,19),Vector2(47,27),Vector2(33,58),Vector2(64,84),Vector2(23,97),Vector2(-23,83)]},
	{"name":"松林工坊", "tag":"林间木屋 · 伐木工坊 · 连续发卡", "dirt_ranges":[Vector2(0.2,0.42),Vector2(0.62,0.88)], "bridge_controls":[], "points":[Vector2(-67,86),Vector2(-102,54),Vector2(-106,4),Vector2(-100,-51),Vector2(-72,-87),Vector2(-30,-87),Vector2(-7,-62),Vector2(-30,-38),Vector2(-53,-11),Vector2(-36,18),Vector2(-5,22),Vector2(23,-5),Vector2(41,-48),Vector2(70,-81),Vector2(99,-64),Vector2(111,-27),Vector2(93,9),Vector2(66,40),Vector2(85,72),Vector2(52,95),Vector2(8,72)]},
	{"name":"红岩矿镇", "tag":"峡谷矿镇 · 货运车站 · 红土折返", "dirt_ranges":[Vector2(0.15,0.51),Vector2(0.58,0.94)], "bridge_controls":[], "points":[Vector2(-68,89),Vector2(-102,60),Vector2(-108,16),Vector2(-87,-12),Vector2(-104,-48),Vector2(-82,-84),Vector2(-47,-93),Vector2(-24,-69),Vector2(-26,-30),Vector2(-1,-9),Vector2(29,-24),Vector2(44,-63),Vector2(76,-88),Vector2(102,-61),Vector2(111,-20),Vector2(89,11),Vector2(52,24),Vector2(30,54),Vector2(60,83),Vector2(16,96),Vector2(-25,74)]},
	{"name":"货运码头", "tag":"集装箱堆场 · 装卸吊机 · 高速折线", "theme":0, "dirt_ranges":[], "bridge_controls":[], "points":[Vector2(-65,88),Vector2(-102,60),Vector2(-104,-10),Vector2(-100,-75),Vector2(-60,-92),Vector2(0,-88),Vector2(65,-92),Vector2(105,-65),Vector2(100,-20),Vector2(58,-10),Vector2(34,16),Vector2(63,43),Vector2(102,63),Vector2(80,94),Vector2(18,90)]},
	{"name":"集市老城", "tag":"彩篷市集 · 钟楼广场 · 短直道密弯", "theme":0, "dirt_ranges":[Vector2(.27,.52)], "bridge_controls":[], "points":[Vector2(-70,90),Vector2(-104,55),Vector2(-101,0),Vector2(-105,-60),Vector2(-74,-92),Vector2(-28,-86),Vector2(-10,-52),Vector2(-28,-12),Vector2(-5,16),Vector2(30,0),Vector2(48,-53),Vector2(82,-89),Vector2(108,-59),Vector2(103,-4),Vector2(76,32),Vector2(100,70),Vector2(63,96),Vector2(9,77)]},
	{"name":"雪岭营地", "tag":"针叶雪林 · 缆车营地 · 宽弯拉力", "theme":1, "dirt_ranges":[Vector2(.12,.43),Vector2(.62,.95)], "bridge_controls":[], "points":[Vector2(-65,86),Vector2(-103,43),Vector2(-107,-25),Vector2(-83,-82),Vector2(-29,-95),Vector2(28,-87),Vector2(84,-92),Vector2(110,-49),Vector2(84,-12),Vector2(40,-8),Vector2(23,28),Vector2(48,65),Vector2(11,94)]},
]
const DIFFICULTIES: Array[String] = ["简单", "普通", "困难"]

static func clock_text(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return "--:--.---"
	var ms := int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
