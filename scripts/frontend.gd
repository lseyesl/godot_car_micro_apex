extends Control
const Catalog=preload("res://scripts/catalog.gd")
const Career=preload("res://scripts/career.gd")
const Track=preload("res://scripts/track_path.gd")
const ACCENT=Color("ffc857")
const MINT=Color("68dec5")
const INK=Color("0b1423")
const MUTED=Color("99b1ca")
var game
var career:Career
var page:="home"
var cup:=0
var car:=3
var circuit_page:=0
var message:=""
var content:VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func open(host, destination:String="home") -> void:
	game=host
	career=Career.new(game.saved)
	page=destination
	car=game.selected_car
	cup=int(career.recommended_event()/6)
	render()

func box(color:Color=Color("142339"),border:Color=Color("263b54"),radius:int=14) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(16)
	return style

func text(value:String,size:int=18,color:Color=Color("f2f6ff")) -> Label:
	var label:=Label.new()
	label.text=value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func action(value:String,callback:Callable,primary:bool=false) -> Button:
	var button:=Button.new()
	button.text=value
	button.custom_minimum_size.y=48
	button.add_theme_stylebox_override("normal",box(ACCENT if primary else Color("1b304a"),ACCENT if primary else Color("35516b"),8))
	button.add_theme_stylebox_override("hover",box(Color("ffe09a") if primary else Color("284865"),MINT,8))
	button.add_theme_stylebox_override("pressed",box(Color("daa53c") if primary else Color("355974"),MINT,8))
	button.add_theme_stylebox_override("focus",box(Color(0,0,0,0),MINT,8))
	button.add_theme_stylebox_override("disabled",box(Color("152234"),Color("283548"),8))
	button.add_theme_color_override("font_color",INK if primary else Color("f2f6ff"))
	button.add_theme_color_override("font_hover_color",INK if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color",INK if primary else Color.WHITE)
	button.add_theme_color_override("font_disabled_color",Color("60768e"))
	button.add_theme_font_size_override("font_size",17)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style:=button.get_theme_stylebox(state)
		style.content_margin_top=10
		style.content_margin_bottom=10
	button.pressed.connect(func():game.play_cue("click");callback.call())
	return button

func horizontal(parent:Node,separation:int=16) -> HBoxContainer:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",separation)
	parent.add_child(row)
	return row

func card(parent:Node,width:float=0) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",box())
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x=width
	parent.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	return column

func gap(parent:Node,height:float=0,expand:bool=false) -> void:
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=height
	if expand:spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func change(destination:String) -> void:
	message=""
	page=destination
	render()

func render() -> void:
	for child in get_children():remove_child(child);child.queue_free()
	var background:=ColorRect.new()
	background.color=INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,28)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",14)
	margin.add_child(root)
	var header:=horizontal(root)
	var brand:=text("MICRO / APEX",26)
	header.add_child(brand)
	header.add_child(text("RACING CLUB",12,MINT))
	gap(header,0,true)
	header.add_child(text("★  %02d / %d"%[career.total_stars(),Career.EVENT_COUNT*3],18,MINT))
	header.add_child(text("CR  %s"%format_number(career.credits()),22,ACCENT))
	var nav:=horizontal(root,8)
	for entry in [["home","俱乐部"],["career","生涯赛事"],["garage","车库 / 升级"],["freeplay","自由驾驶"],["settings","设置"]]:
		var destination:String=entry[0]
		var button:=action(entry[1],func():change(destination),page==destination)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		nav.add_child(button)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)
	content.modulate.a=0.0
	create_tween().tween_property(content,"modulate:a",1.0,.18)
	if not message.is_empty():content.add_child(text(message,16,MINT))
	if game.saved.load_failed:
		content.add_child(text("存档及备份均无法读取，已保护原文件。请在设置中查看恢复说明。",16,Color("ff9980")))
	elif game.saved.last_error!=OK:
		content.add_child(text("上次保存失败，请检查设备的可用存储空间。",15,Color("ff9980")))
	elif game.saved.recovered_from_backup:
		content.add_child(text("已从上一份有效备份恢复进度。",15,MINT))
	match page:
		"home":home()
		"career":events()
		"garage":garage()
		"freeplay":freeplay()
		"settings":settings()
		"credits":credits_page()
	var footer:=horizontal(root)
	footer.add_child(text("离线单机  /  自动保存",12,MUTED))
	gap(footer,0,true)
	footer.add_child(text("WASD / 方向键驾驶 · 空格刹车 · R 复位 · Esc 返回",12,MUTED))

static func format_number(value:int) -> String:
	var raw:=str(value)
	var result:=""
	for i in range(raw.length()):
		if i>0 and (raw.length()-i)%3==0:result+=","
		result+=raw[i]
	return result

func home() -> void:
	var row:=horizontal(content,20)
	var left:=card(row,420)
	left.add_child(text("YOUR NEXT CHAPTER",13,MINT))
	left.add_child(text("每个弯道，\n都值得争先。",32))
	left.add_child(text("从新秀起步，赢下属于你的冠军杯。",17,MUTED))
	var next:=career.recommended_event()
	var pending=game.saved.config.get_value("career","active",{})
	if pending is Dictionary and not pending.is_empty() and career.unlocked(int(pending.get("event",-1))):
		next=int(pending.event)
		left.add_child(text("上次赛事未完成，可以重新挑战。",14,ACCENT))
	var definition:=Career.event(next)
	left.add_child(text("%s  /  第 %d 站"%[Career.CUP_NAMES[definition.cup],definition.round+1],18,ACCENT))
	left.add_child(text(definition.name+"  ·  "+Catalog.TRACKS[definition.track].name,18))
	left.add_child(action("继续生涯   →",func():game.launch_event(next),true))
	if not bool(game.saved.setting("tutorial_complete",false)):
		left.add_child(action("第一次开车？开始驾驶训练",game.launch_tutorial))
	else:
		left.add_child(action("查看全部 36 场赛事",func():change("career")))
	var right:=card(row)
	right.add_child(text("READY TO RACE",13,MINT))
	var spec:Dictionary=career.specification(game.selected_car)
	var showroom=game.car_preview(spec.id)
	showroom.custom_minimum_size=Vector2(300,180)
	right.add_child(showroom)
	var car_row:=horizontal(right)
	car_row.add_child(text(spec.name,28))
	gap(car_row,0,true)
	car_row.add_child(text(spec.role,16,MUTED))
	right.add_child(text("极速 %d km/h    加速 %.1f    转弯 %.1f m"%[int(spec.top*3.6),spec.accel,spec.radius],16,MUTED))
	right.add_child(action("进入车库  /  调整你的座驾",func():change("garage")))
	var stats:=horizontal(content)
	for item in [["赛事完成","%02d / %d"%[career.completed(),Career.EVENT_COUNT]],["收藏进度","%d / %d 辆"%[owned_count(),Catalog.CARS.size()]],["挑战目标","%02d / %d 星"%[career.total_stars(),Career.EVENT_COUNT*3]]]:
		var cell:=card(stats)
		cell.add_child(text(item[0],13,MUTED))
		cell.add_child(text(item[1],23,MINT))
	if career.completed()==Career.EVENT_COUNT:
		content.add_child(text("APEX CHAMPION  ·  全部赛事已完成！重返赛场，向全星满贯发起挑战。",20,ACCENT))

func owned_count() -> int:
	var count:=0
	for i in range(Catalog.CARS.size()):
		if career.owned(i):count+=1
	return count

func events() -> void:
	var cups:=GridContainer.new()
	cups.columns=3
	content.add_child(cups)
	for i in range(Career.CUP_NAMES.size()):
		var index:=i
		var button:=action(Career.CUP_NAMES[i],func():cup=index;render(),cup==i)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		cups.add_child(button)
	var locked:bool=career.total_stars()<Career.CUP_GATES[cup]
	content.add_child(text(("还需 %d 星解锁"%[Career.CUP_GATES[cup]-career.total_stars()]) if locked else "名次挑战：冠军 3 星 · 前三 2 星 · 完赛 1 星；计时赛按目标时间评星。",15,ACCENT if locked else MUTED))
	var grid:=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	content.add_child(grid)
	for i in range(cup*6,cup*6+6):
		var index:=i
		var event:=Career.event(i)
		var cell:=card(grid)
		cell.add_theme_constant_override("separation",4)
		var compact:=box()
		compact.set_content_margin_all(12)
		cell.get_parent().add_theme_stylebox_override("panel",compact)
		cell.add_child(text("%02d   %s"%[i+1,"★".repeat(career.stars(i))+"☆".repeat(3-career.stars(i))],13,ACCENT))
		cell.add_child(text(event.name,19))
		cell.add_child(text(Catalog.TRACKS[event.track].name+(" · 反向" if event.reverse else " · 正向"),13,MUTED))
		cell.add_child(text(("单圈计时 · 金牌 %.1f 秒"%event.gold) if event.mode=="trial" else ("六车竞速 · %d 圈 · %s"%[event.laps,Catalog.DIFFICULTIES[event.difficulty]]),12,MUTED))
		cell.add_child(text("基础奖励  %d CR"%event.reward,13,MINT))
		var button:=action("尚未解锁" if locked else "赛事详情  →",func():event_details(index),not locked)
		button.disabled=locked
		cell.add_child(button)

func event_details(index:int) -> void:
	var event:=Career.event(index)
	var column=game.modal(event.name,Catalog.TRACKS[event.track].name+(" / 反向" if event.reverse else " / 正向"))
	column.add_child(text("座驾：%s"%Catalog.CARS[game.selected_car].name,20,MINT))
	column.add_child(text("完成赛事获得金币，首次完赛额外 +900 CR。",17))
	column.add_child(text(("金牌 ≤ %.1f 秒   银牌 ≤ %.1f 秒   完成即获铜牌（复位后只计铜牌）"%[event.gold,event.gold*1.22]) if event.mode=="trial" else "冠军 3 星  /  前三 2 星  /  完赛 1 星",16,MUTED))
	column.add_child(action("发车   →",func():game.launch_event(index),true))
	column.add_child(action("返回赛事",func():game.dismiss_overlay()))

func garage() -> void:
	var tabs:=GridContainer.new()
	tabs.columns=4
	content.add_child(tabs)
	for i in range(Catalog.CARS.size()):
		var index:=i
		var button:=action(Catalog.CARS[i].name+("" if career.owned(i) else " · 未拥有"),func():car=index;render(),car==i)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var row:=horizontal(content,20)
	var left:=card(row)
	var spec:=career.specification(car)
	left.add_child(text(spec.name,32))
	left.add_child(text(spec.role+"  /  "+["长直道上的速度利器","紧凑灵活，适合连续弯道","在松软路面释放全部实力","可靠平衡，冠军生涯的起点","重型底盘，适合长距离土路","开放座舱，柏油弯道抓地强","长车头与高极速，提前规划制动","管架车身，轻快加速穿越松软路面"][car],16,MUTED))
	var showroom=game.car_preview(spec.id)
	showroom.custom_minimum_size=Vector2(360,180)
	left.add_child(showroom)
	left.add_child(text("极速 %d km/h   加速 %.1f   转弯 %.1f m\n抓地 %.1f   制动 %.1f   土路保持 %d%%"%[int(spec.top*3.6),spec.accel,spec.radius,spec.grip,spec.brake,int(spec.dirt*100)],17,MUTED))
	if career.owned(car):
		left.add_child(action("当前座驾" if game.selected_car==car else "选择这辆车",func():game.selected_car=car;game.saved.set_setting("car",car);message="已更换座驾";render(),true))
	else:
		left.add_child(action("解锁  /  %s CR"%format_number(Career.CAR_PRICES[car]),func():apply_transaction(career.buy_car(car)),true))
	var right:=card(row,365)
	right.add_child(text("性能工坊",26))
	right.add_child(text("永久升级；计时纪录按升级等级分别保存。",14,MUTED))
	for i in range(3):
		var part:String=Career.PARTS[i]
		var level:=career.level(car,part)
		right.add_child(text(Career.PART_NAMES[i]+"   "+"■".repeat(level)+"□".repeat(3-level),19,MINT))
		right.add_child(text(["每级：极速 +3.5%，加速 +6%","每级：抓地 +4.5%，转弯半径 -2.5%","每级：制动力 +8%"][i],14,MUTED))
		var button:=action("已满级" if level==3 else "升级  /  %d CR"%Career.UPGRADE_PRICES[level],func():apply_transaction(career.upgrade(car,part)))
		button.disabled=not career.owned(car) or level==3
		right.add_child(button)

func apply_transaction(result:Dictionary) -> void:
	message="已保存，准备出发。" if result.ok else result.message
	render()

func freeplay() -> void:
	content.add_child(text("自由驾驶",32))
	content.add_child(text("用已拥有的赛车熟悉每一条路线。自由比赛和练习不发放生涯金币。",17,MUTED))
	var pages:=horizontal(content)
	for group in range(2):
		var index:=group
		pages.add_child(action(["经典赛道 01–03","新境赛道 04–06"][group],func():circuit_page=index;render(),circuit_page==group))
	var row:=GridContainer.new()
	row.columns=3
	row.add_theme_constant_override("h_separation",12)
	row.add_theme_constant_override("v_separation",12)
	content.add_child(row)
	for i in range(circuit_page*3,mini(circuit_page*3+3,Catalog.TRACKS.size())):
		var index:=i
		var cell:=card(row)
		cell.add_child(text("CIRCUIT 0%d"%(i+1),13,MINT))
		cell.add_child(text(Catalog.TRACKS[i].name,23))
		var preview:=RoutePreview.new()
		preview.path=Track.new(i)
		preview.custom_minimum_size=Vector2(200,125)
		cell.add_child(preview)
		var forward_best:float=game.saved.best(i,game.selected_car,career.record_variant(game.selected_car,false))
		var reverse_best:float=game.saved.best(i,game.selected_car,career.record_variant(game.selected_car,true))
		cell.add_child(text("正向最佳  "+Catalog.clock_text(forward_best)+"\n反向最佳  "+Catalog.clock_text(reverse_best),13,MUTED))
		cell.add_child(action("正向竞速",func():game.launch_free(index,false,false),true))
		cell.add_child(action("反向竞速",func():game.launch_free(index,true,false)))
		cell.add_child(action("自由练习",func():game.launch_free(index,false,true)))
	content.add_child(action("驾驶训练 / 重新学习操作",game.launch_tutorial))

func settings() -> void:
	content.add_child(text("按你的节奏来",32))
	var row:=horizontal(content)
	var left:=card(row)
	left.add_child(text("声音与画面",24))
	add_slider(left,"主音量","volume",.8,func(value):game.master_volume=value)
	add_slider(left,"音乐音量","music_volume",.35,func(value):game.music_volume=value)
	left.add_child(action("画质："+("精细" if game.quality else "流畅"),func():game.quality=1-game.quality;game.sun.shadow_enabled=game.quality>0;game.saved.set_setting("quality",game.quality);render()))
	left.add_child(action("声音："+("开" if game.sound else "关"),func():game.sound=not game.sound;game.saved.set_setting("sound",game.sound);render()))
	var right:=card(row)
	right.add_child(text("驾驶与辅助",24))
	right.add_child(action("自动油门："+("开" if game.saved.setting("auto_throttle",false) else "关"),func():game.saved.set_setting("auto_throttle",not game.saved.setting("auto_throttle",false));render()))
	right.add_child(action("触控尺寸："+("加大" if game.saved.setting("large_controls",false) else "标准"),func():game.saved.set_setting("large_controls",not game.saved.setting("large_controls",false));render()))
	right.add_child(action("镜头："+("宽视野" if game.saved.setting("wide_camera",false) else "近距离"),func():game.saved.set_setting("wide_camera",not game.saved.setting("wide_camera",false));render()))
	right.add_child(action("比赛难度："+Catalog.DIFFICULTIES[game.difficulty],func():game.difficulty=(game.difficulty+1)%3;game.saved.set_setting("difficulty",game.difficulty);render()))
	right.add_child(text("难度设置用于自由比赛；生涯赛事使用固定难度。",13,MUTED))
	content.add_child(action("制作信息 / 素材许可 / 隐私",func():change("credits")))
	if game.saved.load_failed:
		content.add_child(text("原存档已受保护。你可以从设备备份恢复，也可以保留损坏文件并新建存档。",15,ACCENT))
		content.add_child(action("存档恢复选项",recovery_options))

func add_slider(parent:Node,title:String,key:String,fallback:float,callback:Callable) -> void:
	var row:=horizontal(parent)
	row.add_child(text(title,17))
	var slider:=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=.05
	slider.value=game.saved.setting(key,fallback)
	slider.custom_minimum_size=Vector2(200,40)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	slider.value_changed.connect(func(value):callback.call(value))
	slider.drag_ended.connect(func(_changed):game.saved.set_setting(key,slider.value))
	slider.focus_exited.connect(func():game.saved.set_setting(key,slider.value))

func credits_page() -> void:
	var column:=card(content)
	column.add_child(text("MICRO APEX  /  制作与隐私",30))
	for line in ["单机赛车 · 8 辆赛车 · 12 个路线方向 · 36 场生涯赛事。", "游戏进度仅保存在本机；不包含广告、内购、账号或数据上传。卸载会删除本地进度。", "Godot Engine：MIT License。Noto Sans CJK：SIL Open Font License 1.1。", "赛车、建筑和植被由项目生成器制作；路面与建筑材质使用 Poly Haven CC0 资源；音乐与音效由项目合成器生成。", "完整引擎、字体和材质许可随游戏打包在 assets/legal/ 中。"]:
		var label:=text(line,17,MUTED)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	column.add_child(action("阅读第三方许可",show_licenses))
	column.add_child(action("返回设置",func():change("settings"),true))

func show_licenses() -> void:
	var column=game.modal("第三方许可","Godot Engine / Noto Sans CJK")
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(700,300)
	column.add_child(scroll)
	var license:=RichTextLabel.new()
	license.custom_minimum_size.x=660
	license.fit_content=true
	license.text=FileAccess.get_file_as_string("res://assets/legal/Godot-LICENSE.txt")+"\n\n"+FileAccess.get_file_as_string("res://assets/legal/Godot-COPYRIGHT.txt")+"\n\n"+FileAccess.get_file_as_string("res://assets/legal/Noto-CJK-LICENSE.txt")+"\n\n"+FileAccess.get_file_as_string("res://assets/legal/PolyHaven-CC0.txt")
	scroll.add_child(license)
	column.add_child(action("关闭",func():game.dismiss_overlay()))

class RoutePreview extends Control:
	var path
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if path==null:return
		var scale_factor:=minf(size.x,size.y)/270
		var line:=PackedVector2Array()
		for point in path.points:line.append(point*scale_factor+size*.5)
		line.append(line[0])
		draw_polyline(line,Color("2b4259"),9,true)
		draw_polyline(line,Color("68dec5"),3,true)
		draw_circle(line[0],5,Color("ffc857"))

func recovery_options() -> void:
	var column=game.modal("新建存档？","金币、车辆与生涯将从初始状态开始。旧文件会另存为 .damaged 备份。")
	column.add_child(action("取消，保留当前状态",func():game.dismiss_overlay(),true))
	column.add_child(action("备份旧文件并新建存档",func():
		if game.saved.reset_damaged_profile():
			game.selected_car=3
			game.show_menu()
		else:
			game.dismiss_overlay()
			message="备份或写入失败，旧文件保持原样。请检查存储空间。"
			render()))
