extends Node3D

const Catalog = preload("res://scripts/catalog.gd")
const PathData = preload("res://scripts/track_path.gd")
const TrackView = preload("res://scripts/track_view.gd")
const RaceCar = preload("res://scripts/race_car.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const MiniMap = preload("res://scripts/minimap.gd")
const SaveStore = preload("res://scripts/save_store.gd")
enum State { MENU, COUNTDOWN, RACING, PAUSED, RESULTS }
var state := State.MENU
var paused_by_system := false
var saved := SaveStore.new()
var selected_car := 3
var selected_track := 0
var difficulty := 1
var practice := false
var quality := 1
var sound := true
var world: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var ui: Control
var overlay: Control
var controls
var minimap
var path
var circuit
var cars: Array = []
var player
var time := 0.0
var countdown := 3.0
var toast := ""
var toast_until := 0.0
var reset_progress := 0.0
var hud_label: Label
var speed_label: Label
var help_label: Label
var center_label: Label
var engine_audio: AudioStreamPlayer
var dirt_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var frame_accumulator := 0.0
var stats_timer := 0.0
var title_font: SystemFont
var automated_player := false
var smoke_mode := false
var capture_done := false
var rendered_frames := 0
var automation_time := 0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	title_font=SystemFont.new()
	title_font.font_names=PackedStringArray(["Noto Sans CJK SC","PingFang SC","Microsoft YaHei","Droid Sans Fallback","sans-serif"])
	selected_car=clampi(int(saved.setting("car",3)),0,3)
	selected_track=clampi(int(saved.setting("track",0)),0,2)
	difficulty=clampi(int(saved.setting("difficulty",1)),0,2)
	quality=clampi(int(saved.setting("quality",1)),0,1)
	sound=bool(saved.setting("sound",true))
	practice=bool(saved.setting("practice",false))
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("869ca7")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("c4d6e3")
	settings.ambient_light_energy=.25
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.environment=settings
	add_child(environment)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-55,-25,0)
	sun.light_color=Color("ffedcc")
	sun.light_energy=.65
	sun.shadow_enabled=quality>0
	sun.directional_shadow_max_distance=110
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=65
	camera.far=700
	add_child(camera)
	camera.current=true
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui)
	var theme:=Theme.new()
	theme.default_font=title_font
	theme.default_font_size=18
	ui.theme=theme
	engine_audio=audio("engine",true)
	dirt_audio=audio("dirt",true)
	impact_audio=audio("impact",false)
	get_tree().auto_accept_quit=false
	show_menu()
	var args:=OS.get_cmdline_user_args()
	smoke_mode="--smoke" in args or "--capture" in args or "--autodrive" in args or "--capture-menu" in args
	if smoke_mode and not "--capture-menu" in args:
		start_race()

func audio(id:String, loop:bool) -> AudioStreamPlayer:
	var p:=AudioStreamPlayer.new()
	var stream:AudioStreamWAV=load("res://assets/audio/"+id+".wav").duplicate()
	if loop:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=stream.data.size()/2
	p.stream=stream
	p.volume_db=-80
	add_child(p)
	if loop and DisplayServer.get_name()!="headless":
		p.play()
	return p

func panel(fill:Color=Color("15252e"), border:Color=Color("34434b"), radius:int=14) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style

func label(text:String,font_size:int=20,color:Color=Color("edf1e8")) -> Label:
	var l:=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	return l

func button(text:String, callback:Callable, accent:bool=false) -> Button:
	var b:=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,48)
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",panel(Color("c3ed86") if accent else Color("1c3039")))
	b.add_theme_stylebox_override("hover",panel(Color("d2ff97") if accent else Color("304955")))
	b.add_theme_stylebox_override("pressed",panel(Color("a9d676") if accent else Color("3b5963")))
	b.add_theme_color_override("font_color",Color("162521") if accent else Color("edf1e8"))
	b.add_theme_color_override("font_hover_color",Color("162521") if accent else Color.WHITE)
	b.pressed.connect(callback)
	return b

func clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	controls=null
	minimap=null
	overlay=null

func clear_world() -> void:
	cars.clear()
	player=null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world=Node3D.new()
	add_child(world)

func menu_margin() -> VBoxContainer:
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:
		margin.add_theme_constant_override("margin_"+side,32)
	for side in ["top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	ui.add_child(margin)
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",10)
	margin.add_child(v)
	return v

func show_menu() -> void:
	state=State.MENU
	clear_ui()
	clear_world()
	var floor_mesh:=MeshInstance3D.new()
	var plane:=BoxMesh.new()
	plane.size=Vector3(100,.3,100)
	floor_mesh.mesh=plane
	var floor_material:=StandardMaterial3D.new()
	floor_material.albedo_color=Color("253d45")
	floor_mesh.material_override=floor_material
	floor_mesh.position=Vector3(0,-.18,0)
	world.add_child(floor_mesh)
	for i in range(4):
		var car:Node3D=load("res://assets/models/"+Catalog.CARS[i].id+".glb").instantiate()
		world.add_child(car)
		var aspect_scale:=get_viewport().get_visible_rect().size.aspect()/(1280.0/720.0)
		car.position=Vector3(-(i-1.5)*5.6*aspect_scale,0,2.2)
		car.rotation.y=-.35
	camera.size=14
	camera.position=Vector3(0,14,-21)
	camera.look_at(Vector3(0,0,1))
	var backdrop:=ColorRect.new()
	backdrop.color=Color(.018,.037,.047,.12)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(backdrop)
	var v:=menu_margin()
	var title_row:=HBoxContainer.new()
	v.add_child(title_row)
	var brand:=label("MICRO APEX",44)
	brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_row.add_child(brand)
	title_row.add_child(label("CIRCUIT CLUB  /  01",18,Color("c3ed86")))
	v.add_child(label("微型赛场 · 土路与柏油之间，找到你的弯心。",19,Color("bccdd1")))
	var gap:=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size.y=65
	v.add_child(gap)
	var card_row:=HBoxContainer.new()
	card_row.add_theme_constant_override("separation",12)
	v.add_child(card_row)
	for i in range(4):
		var spec:Dictionary=Catalog.CARS[i]
		var card:=button("",func(): select_car(i),selected_car==i)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y=128
		card_row.add_child(card)
		var content:=VBoxContainer.new()
		content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=16
		content.offset_top=10
		card.add_child(content)
		var color:=Color("152621") if selected_car==i else Color("e9f1e9")
		content.add_child(label(("●  " if selected_car==i else "○  ")+spec.name,24,color))
		content.add_child(label(spec.role+"  /  "+str(int(float(spec.top)*3.6))+" km/h",17,color))
		content.add_child(label("加速 %.1f  ·  转弯 %.1fm"%[spec.accel,spec.radius],15,color))
		content.add_child(label("土路保持 %d%%"%int(float(spec.dirt)*100),15,color))
		for item in content.get_children():
			item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var options:=HBoxContainer.new()
	options.add_theme_constant_override("separation",12)
	v.add_child(options)
	var tracks:=OptionButton.new()
	for track in Catalog.TRACKS:
		tracks.add_item(track.name+"  /  "+track.tag)
	tracks.select(selected_track)
	tracks.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tracks.custom_minimum_size.y=48
	tracks.item_selected.connect(func(i): selected_track=i; saved.set_setting("track",i); update_record_hint())
	options.add_child(tracks)
	var modes:=OptionButton.new()
	modes.add_item("场地竞速 · 3 圈")
	modes.add_item("计时练习 · 自由圈数")
	modes.select(1 if practice else 0)
	modes.item_selected.connect(func(i): practice=i==1; saved.set_setting("practice",practice))
	options.add_child(modes)
	var levels:=OptionButton.new()
	for level in Catalog.DIFFICULTIES:
		levels.add_item(level)
	levels.select(difficulty)
	levels.item_selected.connect(func(i): difficulty=i; saved.set_setting("difficulty",i))
	options.add_child(levels)
	var bottom:=HBoxContainer.new()
	bottom.add_theme_constant_override("separation",12)
	v.add_child(bottom)
	help_label=label("",16,Color("bdd0d5"))
	help_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom.add_child(help_label)
	bottom.add_child(button("画质："+("中" if quality else "低"),func(): quality=1-quality; saved.set_setting("quality",quality); sun.shadow_enabled=quality>0; show_menu()))
	bottom.add_child(button("声音："+("开" if sound else "关"),func(): sound=not sound; saved.set_setting("sound",sound); show_menu()))
	var go:=button("驶入赛场  →",start_race,true)
	go.custom_minimum_size.x=220
	bottom.add_child(go)
	v.add_child(label("左 / 右键相对车头转向  ·  油门与刹车可同时配合转向  ·  高速入弯请提前减速",15,Color("a8bcc4")))
	update_record_hint()

func select_car(index:int) -> void:
	selected_car=index
	saved.set_setting("car",index)
	show_menu()

func update_record_hint() -> void:
	if is_instance_valid(help_label):
		help_label.text="此车 / 此赛道最佳\n"+Catalog.clock_text(saved.best(selected_track,selected_car))

func start_race() -> void:
	clear_ui()
	clear_world()
	path=PathData.new(selected_track)
	circuit=TrackView.new()
	world.add_child(circuit)
	circuit.build(path,quality)
	var count:=1 if practice else 6
	for i in range(count):
		var car=RaceCar.new()
		world.add_child(car)
		var choice:=selected_car if i==0 else (i-1)%4
		var grid:Dictionary=path.sample(-8.0-float(i/2)*6.0)
		var side:=Vector2(-grid.tangent.y,grid.tangent.x)
		var offset:=0.0 if practice else (-2.0 if i%2==0 else 2.0)
		car.configure(Catalog.CARS[choice],grid.point+side*offset,PathData.heading(grid.tangent),i==0)
		car.car_index=choice
		car.display_name="你" if i==0 else "车手 %02d"%i
		car.driver.difficulty=difficulty
		car.driver.phase=i*1.73
		car.driver.lane=offset*.7
		cars.append(car)
	player=cars[0]
	time=0.0
	countdown=3.0
	state=State.COUNTDOWN
	toast="相对车头转向 · 提前减速入弯 · 长按 RESET 复位"
	toast_until=10
	build_hud()
	camera.size=64
	update_camera(1.0,true)

func build_hud() -> void:
	var bar:=Panel.new()
	bar.add_theme_stylebox_override("panel",panel(Color(.025,.055,.07,.93),Color("34434b"),0))
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom=105
	hud_label=label("",22)
	ui.add_child(hud_label)
	hud_label.position=Vector2(28,20)
	speed_label=label("",34,Color("c3ed86"))
	ui.add_child(speed_label)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed_label.offset_left=-275
	speed_label.offset_right=-125
	speed_label.offset_top=20
	speed_label.offset_bottom=95
	var pause_button:=button("Ⅱ",pause_game)
	ui.add_child(pause_button)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left=-110
	pause_button.offset_right=-30
	pause_button.offset_top=24
	pause_button.offset_bottom=76
	minimap=MiniMap.new()
	minimap.path=path
	minimap.cars=cars
	minimap.position=Vector2(28,124)
	minimap.size=Vector2(190,170)
	minimap.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(minimap)
	help_label=label("",18,Color("ecf4d8"))
	help_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(help_label)
	help_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	help_label.offset_left=-345
	help_label.offset_right=300
	help_label.offset_top=22
	help_label.offset_bottom=85
	help_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	center_label=label("3",86)
	center_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	center_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(center_label)
	center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_label.offset_left=-160
	center_label.offset_right=160
	center_label.offset_top=-100
	center_label.offset_bottom=60
	controls=TouchControls.new()
	ui.add_child(controls)
	controls.enabled=false
	if practice:
		var done:=button("结束练习",show_results)
		ui.add_child(done)
		done.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		done.offset_left=-132
		done.offset_right=-28
		done.offset_top=179
		done.offset_bottom=227

func _physics_process(dt:float) -> void:
	if state==State.COUNTDOWN:
		countdown-=dt
		center_label.text=str(maxi(1,ceili(countdown)))
		if countdown<=0:
			state=State.RACING
			controls.enabled=true
			controls.clear()
			center_label.text=""
		return
	if state!=State.RACING:
		return
	time+=dt
	for car in cars:
		if car.progress.finish_time>=0:
			continue
		var input:Dictionary
		if car.player and not automated_player and not ("--autodrive" in OS.get_cmdline_user_args()):
			input=controls.driving()
		else:
			input=car.driver.controls(car.dynamics,path,time)
		car.tick(dt,input,path)
		var event:Dictionary=car.progress.advance(car.previous,car.dynamics.position,path,time,0 if practice else 3)
		if car.player and event.has("lap"):
			if practice and event.valid and saved.record(selected_track,selected_car,event.duration):
				toast="新纪录！  "+Catalog.clock_text(event.duration)
			else:
				toast=("单圈 " if event.valid else "复位圈不计纪录  ")+Catalog.clock_text(event.duration)
			toast_until=time+5
		if not car.player:
			car.driver.stuck_time=car.driver.stuck_time+dt if car.dynamics.velocity.length()<1.3 else 0.0
			# A missed gate is recovered with the same reset rule as the player.
			var expected:Dictionary=path.gate(car.progress.next_gate)
			var missed:=fposmod(float(car.near.s)-float(expected.s),path.length)
			if car.driver.stuck_time>5.0 or (missed>18.0 and missed<path.length*.2 and car.reset_cooldown<=0):
				car.reset_to_gate(path)
				car.driver.stuck_time=0
	if controls.held("reset"):
		controls.reset_held+=dt
		if controls.reset_held>=1.2 and player.reset_cooldown<=0:
			player.reset_to_gate(path)
			controls.reset_held=0
			toast="已复位 · 本圈不计纪录"
			toast_until=time+4
	else:
		controls.reset_held=0
	controls.queue_redraw()
	circuit.show_gate(player.progress.next_gate)
	if not practice and player.progress.finish_time>=0:
		show_results()

func _process(dt:float) -> void:
	if state in [State.RACING,State.COUNTDOWN]:
		update_camera(dt)
		stats_timer+=dt
		if stats_timer>.1:
			stats_timer=0
			update_hud()
	if is_instance_valid(player) and state==State.RACING and sound and DisplayServer.get_name()!="headless":
		engine_audio.volume_db=-23
		engine_audio.pitch_scale=.65+player.dynamics.velocity.length()/22.0
		dirt_audio.volume_db=-30 if player.dynamics.surface!="asphalt" else (-35 if player.dynamics.slip>1 else -80)
		if player.impact>2 and not impact_audio.playing:
			impact_audio.volume_db=-17
			impact_audio.play()
	else:
		engine_audio.volume_db=-80
		dirt_audio.volume_db=-80
		impact_audio.stop()
	if smoke_mode:
		automation_time+=dt
		rendered_frames+=1
		if rendered_frames>90 and automation_time>5 and not capture_done and ("--capture" in OS.get_cmdline_user_args() or "--capture-menu" in OS.get_cmdline_user_args()):
			capture_done=true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/menu.png" if "--capture-menu" in OS.get_cmdline_user_args() else "res://build/gameplay.png")
			print("CAPTURE_SAVED")
			get_tree().quit()
		if automation_time>7 and "--smoke" in OS.get_cmdline_user_args():
			print("SMOKE_OK cars=%d track_length=%.1f state=%s"%[cars.size(),path.length,state])
			get_tree().quit()

func update_camera(dt:float, snap:bool=false) -> void:
	if not is_instance_valid(player):
		return
	var ahead:Vector3=PathData.world(player.dynamics.velocity)*.55
	var target:Vector3=player.position+ahead
	var desired:=target+Vector3(0,47,31)
	camera.position=desired if snap else camera.position.lerp(desired,1.0-exp(-dt*5))
	# The orientation is fixed in world space, even when the car turns.
	camera.rotation_degrees=Vector3(-56.6,0,0)

func ranking() -> Array:
	var sorted:=cars.duplicate()
	sorted.sort_custom(func(a,b):
		if a.progress.finish_time>=0 and b.progress.finish_time>=0:
			return a.progress.finish_time<b.progress.finish_time
		if a.progress.finish_time>=0: return true
		if b.progress.finish_time>=0: return false
		return a.progress.score(path,a.dynamics.position)>b.progress.score(path,b.dynamics.position))
	return sorted

func update_hud() -> void:
	var place:=ranking().find(player)+1
	hud_label.text=("计时练习" if practice else "P%d / 6    圈 %d / 3"%[place,mini(player.progress.laps+1,3)])+"\n"+Catalog.clock_text(time)
	var surface_name:String={"asphalt":"柏油路","dirt":"土路","grass":"路外"}[player.dynamics.surface]
	speed_label.text="%03d km/h\n%s"%[roundi(absf(player.dynamics.speed())*3.6),surface_name]
	speed_label.add_theme_font_size_override("font_size",23)
	var message:=toast if time<toast_until else ""
	if message=="":
		var upcoming:Dictionary=path.gate(player.progress.next_gate)
		var nearest:Dictionary=path.nearest(player.dynamics.position)
		var past:=fposmod(float(nearest.s)-float(upcoming.s),path.length)
		if past>10 and past<path.length*.3:
			message="漏过检查点 · 请返回绿色标记或长按 RESET"
		elif player.dynamics.velocity.length()>4 and player.dynamics.velocity.dot(nearest.tangent)<-2:
			message="逆向行驶 · 请调整方向"
	help_label.text=message+"\n"+("%.0f FPS"%Engine.get_frames_per_second())
	minimap.queue_redraw()

func pause_game(system_pause:bool=false) -> void:
	if state not in [State.RACING,State.COUNTDOWN]:
		return
	state=State.PAUSED
	paused_by_system=system_pause
	controls.enabled=false
	controls.clear()
	var v:=modal("已暂停","比赛和计时已停止。继续后倒数 3 秒恢复。")
	v.add_child(button("继续比赛",resume_game,true))
	v.add_child(button("重新开始",start_race))
	v.add_child(button("返回选车",show_menu))

func resume_game() -> void:
	paused_by_system=false
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay=null
	controls.clear()
	countdown=3.0
	state=State.COUNTDOWN

func modal(title:String,subtitle:String) -> VBoxContainer:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay=ColorRect.new()
	overlay.color=Color(.02,.035,.05,.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel_node:=PanelContainer.new()
	panel_node.add_theme_stylebox_override("panel",panel())
	center.add_child(panel_node)
	var v:=VBoxContainer.new()
	v.custom_minimum_size.x=560
	v.add_theme_constant_override("separation",10)
	panel_node.add_child(v)
	v.add_child(label(title,36,Color("c3ed86")))
	v.add_child(label(subtitle,17))
	return v

func show_results() -> void:
	if state==State.RESULTS:
		return
	state=State.RESULTS
	controls.enabled=false
	controls.clear()
	center_label.text=""
	var title:="练习结束" if practice else "完赛  /  P%d"%(ranking().find(player)+1)
	var v:=modal(title,"总时间  %s    最佳有效圈  %s"%[Catalog.clock_text(time),Catalog.clock_text(player.progress.best_lap)])
	if not practice:
		var sorted:=ranking()
		for i in range(sorted.size()):
			var car=sorted[i]
			var text:="%d  %-8s  %s    %s"%[i+1,car.display_name,Catalog.CARS[car.car_index].name,Catalog.clock_text(car.progress.finish_time) if car.progress.finish_time>=0 else "第 %d 圈 · 未完赛"%(car.progress.laps+1)]
			v.add_child(label(text,18,Color("c3ed86") if car.player else Color("e9f1e9")))
	else:
		v.add_child(label("完成 %d 圈 · 最佳有效单圈已按车型和赛道保存在本机。"%player.progress.laps,17))
	v.add_child(button("再跑一场",start_race,true))
	v.add_child(button("返回选车",show_menu))

func _unhandled_key_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if state==State.PAUSED:
			resume_game()
		else:
			pause_game()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if is_instance_valid(controls):
			pause_game(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		if state==State.PAUSED and paused_by_system:
			resume_game()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		pause_game()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _exit_tree() -> void:
	# Stop looping playback before freeing the scene (also covers Android activity shutdown).
	for playback in [engine_audio,dirt_audio,impact_audio]:
		if is_instance_valid(playback):
			playback.stop()
			playback.stream=null
