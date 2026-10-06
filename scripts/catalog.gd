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
	{"name":"海湾街区", "tag":"滨海街道 · 维修街区 · 港口回转", "dirt_ranges":[Vector2(0.6,0.78)], "elevations":[{"kind":"bridge","controls":[1,2,3,4],"height":5.5},{"kind":"hill","controls":[12,12.5,12.8,13.6],"height":3.2}], "points":[Vector2(-65,105),Vector2(-100,90),Vector2(-112,50),Vector2(-110,-40),Vector2(-100,-85),Vector2(-65,-105),Vector2(75,-100),Vector2(105,-80),Vector2(80,-55),Vector2(-50,-55),Vector2(-78,-35),Vector2(-52,-10),Vector2(68,-10),Vector2(99,15),Vector2(72,42),Vector2(-50,42),Vector2(-72,65),Vector2(-45,85),Vector2(35,85),Vector2(55,108),Vector2(-20,110)]},
	{"name":"松林工坊", "tag":"林间木屋 · 伐木工坊 · 连续发卡", "dirt_ranges":[Vector2(0.2,0.42),Vector2(0.62,0.88)], "elevations":[{"kind":"bridge","controls":[1,2,3,4],"height":4.5},{"kind":"hill","controls":[12,12.5,12.8,13.6],"height":3.8}], "points":[Vector2(-65,105),Vector2(-100,90),Vector2(-112,50),Vector2(-110,-40),Vector2(-100,-85),Vector2(-65,-105),Vector2(68,-100),Vector2(98,-80),Vector2(73,-55),Vector2(-45,-55),Vector2(-73,-35),Vector2(-47,-10),Vector2(60,-10),Vector2(91,15),Vector2(64,42),Vector2(-44,42),Vector2(-66,65),Vector2(-39,85),Vector2(35,85),Vector2(55,108),Vector2(-20,110)]},
	{"name":"红岩矿镇", "tag":"峡谷矿镇 · 货运车站 · 红土折返", "dirt_ranges":[Vector2(0.15,0.51),Vector2(0.58,0.94)], "elevations":[{"kind":"bridge","controls":[1,2,3,4],"height":7.0},{"kind":"hill","controls":[12,12.5,12.8,13.6],"height":4.5}], "points":[Vector2(65,-105),Vector2(100,-90),Vector2(112,-50),Vector2(110,40),Vector2(100,85),Vector2(65,105),Vector2(-75,100),Vector2(-105,80),Vector2(-80,55),Vector2(50,55),Vector2(78,35),Vector2(52,10),Vector2(-68,10),Vector2(-99,-15),Vector2(-72,-42),Vector2(50,-42),Vector2(72,-65),Vector2(45,-85),Vector2(-35,-85),Vector2(-55,-108),Vector2(20,-110)]},
	{"name":"货运码头", "tag":"集装箱堆场 · 装卸吊机 · 高速折线", "theme":0, "dirt_ranges":[], "elevations":[{"kind":"bridge","controls":[8,9.6,10.4,11.8],"height":9.0},{"kind":"hill","controls":[14,14.7,15,15.8],"height":3.5}], "points":[Vector2(-70,85),Vector2(-105,60),Vector2(-105,-65),Vector2(-80,-95),Vector2(-40,-80),Vector2(-45,-50),Vector2(-80,-40),Vector2(-80,-5),Vector2(-50,5),Vector2(-25,-30),Vector2(0,0),Vector2(30,45),Vector2(70,85),Vector2(105,60),Vector2(105,-65),Vector2(80,-95),Vector2(40,-80),Vector2(45,-50),Vector2(80,-40),Vector2(80,-5),Vector2(50,5),Vector2(25,-30),Vector2(0,0),Vector2(-30,45)]},
	{"name":"集市老城", "tag":"彩篷市集 · 钟楼广场 · 短直道密弯", "theme":0, "dirt_ranges":[Vector2(.27,.52)], "elevations":[{"kind":"bridge","controls":[1,2,3,4],"height":4.0},{"kind":"hill","controls":[12,12.5,12.8,13.6],"height":3.0}], "points":[Vector2(-105,-65),Vector2(-90,-100),Vector2(-50,-112),Vector2(40,-110),Vector2(85,-100),Vector2(105,-65),Vector2(100,75),Vector2(80,105),Vector2(55,80),Vector2(55,-50),Vector2(35,-78),Vector2(10,-52),Vector2(10,68),Vector2(-15,99),Vector2(-42,72),Vector2(-42,-50),Vector2(-65,-72),Vector2(-85,-45),Vector2(-85,35),Vector2(-108,55),Vector2(-110,-20)]},
	{"name":"雪岭营地", "tag":"针叶雪林 · 缆车营地 · 宽弯拉力", "theme":1, "dirt_ranges":[Vector2(.12,.43),Vector2(.62,.95)], "elevations":[{"kind":"bridge","controls":[1,2,3,4],"height":7.0},{"kind":"hill","controls":[12,12.5,12.8,13.6],"height":4.5}], "points":[Vector2(100.8,65),Vector2(86.4,100),Vector2(48,112),Vector2(-38.4,110),Vector2(-81.6,100),Vector2(-100.8,65),Vector2(-96,-75),Vector2(-76.8,-105),Vector2(-52.8,-80),Vector2(-52.8,50),Vector2(-33.6,78),Vector2(-9.6,52),Vector2(-9.6,-68),Vector2(14.4,-99),Vector2(40.32,-72),Vector2(40.32,50),Vector2(62.4,72),Vector2(81.6,45),Vector2(81.6,-35),Vector2(103.68,-55),Vector2(105.6,20)]},
]
const DIFFICULTIES: Array[String] = ["简单", "普通", "困难"]

static func clock_text(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return "--:--.---"
	var ms := int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
