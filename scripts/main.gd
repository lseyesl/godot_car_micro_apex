extends Node3D

const Catalog = preload("res://scripts/catalog.gd")
const PathData = preload("res://scripts/track_path.gd")
const TrackView = preload("res://scripts/track_view.gd")
const RaceCar = preload("res://scripts/race_car.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const MiniMap = preload("res://scripts/minimap.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Career = preload("res://scripts/career.gd")
const RaceEffects = preload("res://scripts/race_effects.gd")
const Frontend = preload("res://scripts/frontend.gd")
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
var title_font: Font
var automated_player := false
var smoke_mode := false
var capture_done := false
var rendered_frames := 0
var automation_time := 0.0
var event_id := -1
var race_token := ""
var receipt:Dictionary = {}
var reversed_route := false
var target_laps := 3
var tutorial := false
var tutorial_step := 0
var frontend
var music:AudioStreamPlayer
var cue:AudioStreamPlayer
var master_volume := .8
var music_volume := .35
var countdown_beep := 0
var session_difficulty := 1
var effects
var camera_shake := 0.0
var camera_distance := 42.0
const CAMERA_PITCH := 38.0
const CAMERA_YAW := 35.54
const CAMERA_FOV := 34.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	title_font=load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	selected_car=clampi(int(saved.setting("car",3)),0,Catalog.CARS.size()-1)
	selected_track=clampi(int(saved.setting("track",0)),0,Catalog.TRACKS.size()-1)
	difficulty=clampi(int(saved.setting("difficulty",1)),0,2)
	quality=clampi(int(saved.setting("quality",1)),0,1)
	sound=bool(saved.setting("sound",true))
	practice=bool(saved.setting("practice",false))
	master_volume=clampf(float(saved.setting("volume",.8)),0,1)
	music_volume=clampf(float(saved.setting("music_volume",.35)),0,1)
	if not Career.new(saved).owned(selected_car):selected_car=3
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("73bbc7")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("c4d6e3")
	settings.ambient_light_energy=.42
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sky:=Sky.new()
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("799aad")
	sky_material.sky_horizon_color=Color("ced2c8")
	sky_material.ground_bottom_color=Color("52605c")
	sky_material.ground_horizon_color=Color("b1b5a3")
	sky.sky_material=sky_material
	settings.sky=sky
	settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.environment=settings
	add_child(environment)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-58,-32,0)
	sun.light_color=Color("fff4e0")
	sun.light_energy=.85
	sun.shadow_enabled=quality>0
	sun.directional_shadow_max_distance=120
	sun.shadow_bias=.08
	sun.shadow_normal_bias=2.0
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=CAMERA_FOV
	camera.far=700
	add_child(camera)
	camera.current=true
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui)
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	var theme:=Theme.new()
	theme.default_font=title_font
	theme.default_font_size=18
	ui.theme=theme
	engine_audio=audio("engine",true)
	dirt_audio=audio("dirt",true)
	impact_audio=audio("impact",false)
	music=audio("music",true)
	cue=AudioStreamPlayer.new()
	add_child(cue)
	get_tree().auto_accept_quit=false
	show_menu()
	var args:=OS.get_cmdline_user_args()
	smoke_mode="--smoke" in args or "--capture" in args or "--autodrive" in args or "--capture-menu" in args
	if smoke_mode and not "--capture-menu" in args:
		start_race()

func apply_safe_area() -> void:
	if not OS.has_feature("android") or not is_instance_valid(ui):return
	var pixels:=Vector2(DisplayServer.window_get_size())
	if pixels.x<=0 or pixels.y<=0:return
	var safe:=DisplayServer.get_display_safe_area()
	var scale_factor:=get_viewport().get_visible_rect().size/pixels
	ui.offset_left=maxf(0,safe.position.x)*scale_factor.x
	ui.offset_top=maxf(0,safe.position.y)*scale_factor.y
	ui.offset_right=-maxf(0,pixels.x-safe.end.x)*scale_factor.x
	ui.offset_bottom=-maxf(0,pixels.y-safe.end.y)*scale_factor.y

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

func panel(fill:Color=Color("142b46"), border:Color=Color("35516d"), radius:int=10) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(2)
	style.shadow_color=Color(0.01,.025,.06,.25)
	style.shadow_size=5
	style.shadow_offset=Vector2(0,4)
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
	b.add_theme_stylebox_override("normal",panel(Color("ffd34e") if accent else Color("1e3956")))
	b.add_theme_stylebox_override("hover",panel(Color("ffe58b") if accent else Color("2b5072")))
	b.add_theme_stylebox_override("pressed",panel(Color("efb82d") if accent else Color("3a6486")))
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
	v.add_theme_constant_override("separation",8)
	margin.add_child(v)
	return v

func car_preview(id:String) -> SubViewportContainer:
	var container:=SubViewportContainer.new()
	container.custom_minimum_size=Vector2(100,74)
	container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(280,100)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var car:Node3D=load("res://assets/models/"+id+".glb").instantiate()
	car.rotation.y=-.55
	viewport.add_child(car)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-30,0)
	light.light_energy=.9
	viewport.add_child(light)
	var env:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("cbdfff")
	settings.ambient_light_energy=.42
	env.environment=settings
	viewport.add_child(env)
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=3.2
	cam.position=Vector3(5,7,9)
	viewport.add_child(cam)
	cam.basis=Basis.looking_at(Vector3(0,.6,0)-cam.position)
	return container

func menu_track(index:int) -> void:
	selected_track=index
	saved.set_setting("track",index)
	show_menu("freeplay")

func show_menu(destination:String="home") -> void:
	state=State.MENU
	clear_ui()
	clear_world()
	frontend=Frontend.new()
	ui.add_child(frontend)
	frontend.open(self,destination)

func select_car(index:int) -> void:
	if Career.new(saved).owned(index):
		selected_car=index
		saved.set_setting("car",index)
	show_menu("garage")

func dismiss_overlay() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
		overlay=null

func play_cue(id:String) -> void:
	if not sound or DisplayServer.get_name()=="headless":return
	cue.stream=load("res://assets/audio/"+id+".wav")
	cue.volume_db=linear_to_db(maxf(master_volume,.001))-8
	cue.play()

func launch_event(index:int) -> void:
	event_id=index
	tutorial=false
	start_race()

func launch_free(track:int,reverse_route:bool,is_practice:bool) -> void:
	event_id=-1
	tutorial=false
	selected_track=track
	reversed_route=reverse_route
	practice=is_practice
	start_race()

func launch_tutorial() -> void:
	event_id=-1
	tutorial=true
	tutorial_step=0
	selected_track=0
	reversed_route=false
	practice=true
	start_race()

func leave_race() -> void:
	var column:=modal("离开本场比赛？","本场尚未获得的奖励不会结算，已保存的金币与升级会保留。")
	column.add_child(button("继续比赛",resume_game,true))
	column.add_child(button("离开比赛",func():show_menu("career" if event_id>=0 else "home")))


func update_record_hint() -> void:
	if is_instance_valid(help_label):
		help_label.text="最佳单圈  "+Catalog.clock_text(saved.best(selected_track,selected_car))

func start_race() -> void:
	var career:=Career.new(saved)
	var event:Dictionary={}
	if not career.owned(selected_car):selected_car=3
	if event_id>=0:
		var entry:=career.begin_event(event_id,selected_car)
		if not entry.ok:
			var column:=modal("无法开始赛事",entry.message)
			column.add_child(button("返回",dismiss_overlay,true))
			return
		event=entry.event
		race_token=entry.token
		selected_track=event.track
		reversed_route=event.reverse
		practice=event.mode=="trial"
		target_laps=event.laps
		session_difficulty=event.difficulty
	else:
		race_token=""
		target_laps=1 if tutorial else (0 if practice else 3)
		session_difficulty=difficulty
	receipt={}
	countdown_beep=0
	sun.directional_shadow_max_distance=170
	clear_ui()
	clear_world()
	path=PathData.new(selected_track,reversed_route)
	circuit=TrackView.new()
	world.add_child(circuit)
	circuit.build(path,quality)
	effects=RaceEffects.new()
	world.add_child(effects)
	effects.enabled=quality>0
	var count:=1 if practice else 6
	for i in range(count):
		var car=RaceCar.new()
		world.add_child(car)
		var choice:=selected_car if i==0 else ((i-1)%4 if selected_track<3 else (i+3)%Catalog.CARS.size())
		var grid:Dictionary=path.sample(-8.0-float(i/2)*6.0)
		var side:=Vector2(-grid.tangent.y,grid.tangent.x)
		var offset:=0.0 if practice else (-2.0 if i%2==0 else 2.0)
		var spec:Dictionary=career.specification(choice) if i==0 else Career.tuned(Catalog.CARS[choice],int(event.get("ai_level",0)),int(event.get("ai_level",0)),int(event.get("ai_level",0)))
		car.configure(spec,grid.point+side*offset,PathData.heading(grid.tangent),i==0)
		car.effects_enabled=quality>0 and DisplayServer.get_name()!="headless"
		car.car_index=choice
		car.display_name="你" if i==0 else "车手 %02d"%i
		car.driver.difficulty=session_difficulty
		car.driver.phase=i*1.73
		car.driver.lane=offset*.7
		cars.append(car)
	player=cars[0]
	time=0.0
	countdown=3.0
	state=State.COUNTDOWN
	toast="减速入弯 · 反打修正 · 长按 RESET 复位"
	toast_until=10
	build_hud()
	update_camera(1.0,true)

func build_hud() -> void:
	var bar:=Panel.new()
	bar.add_theme_stylebox_override("panel",panel(Color(.055,.12,.21,.90),Color("35516d"),12))
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left=18
	bar.offset_right=-18
	bar.offset_top=16
	bar.offset_bottom=98
	hud_label=label("",22)
	ui.add_child(hud_label)
	hud_label.position=Vector2(36,26)
	speed_label=label("",34,Color("ffd34e"))
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
	minimap.position=Vector2(28,114)
	minimap.size=Vector2(148,136)
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
	center_label=label("3",100,Color("ffd34e"))
	center_label.add_theme_color_override("font_shadow_color",Color("142b46"))
	center_label.add_theme_constant_override("shadow_offset_y",5)
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
	controls.auto_throttle=bool(saved.setting("auto_throttle",false)) and not tutorial
	controls.large=bool(saved.setting("large_controls",false))
	if practice and event_id<0:
		var done:=button("结束训练" if tutorial else "结束练习",show_results)
		ui.add_child(done)
		done.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		done.offset_left=-132
		done.offset_right=-28
		done.offset_top=179
		done.offset_bottom=227

func _physics_process(dt:float) -> void:
	if state==State.COUNTDOWN:
		countdown-=dt
		var beat:=ceili(countdown)
		if beat>0 and beat!=countdown_beep:
			countdown_beep=beat
			play_cue("countdown")
		center_label.text=str(maxi(1,ceili(countdown)))
		if countdown<=0:
			state=State.RACING
			controls.enabled=true
			controls.clear()
			center_label.text="GO!"
			play_cue("go")
		return
	if state!=State.RACING:
		return
	time+=dt
	for car in cars:
		if car.progress.finish_time>=0:
			# Finished opponents clear the finish lane instead of becoming parked obstacles.
			car.collision_layer=0
			car.collision_mask=0
			car.finish_elapsed+=dt
			if car.finish_elapsed<1.2:
				car.tick(dt,car.driver.controls(car.dynamics,path,time),path)
			else:
				car.hide()
				car.dust.emitting=false
			continue
		var input:Dictionary
		if car.player and not automated_player and not ("--autodrive" in OS.get_cmdline_user_args()):
			input=controls.driving()
		else:
			input=car.driver.controls(car.dynamics,path,time)
		car.tick(dt,input,path)
		var event:Dictionary=car.progress.advance(car.previous,car.dynamics.position,path,time,target_laps,car.position.y-.06)
		if car.player and event.has("lap"):
			if event.valid and saved.record(selected_track,selected_car,event.duration,Career.new(saved).record_variant(selected_car,reversed_route)):
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
	effects.sample(cars)
	camera_shake=maxf(camera_shake,player.impact*.025)
	if tutorial:
		if tutorial_step==0 and controls.held("throttle") and player.dynamics.speed()>3:tutorial_step=1
		elif tutorial_step==1 and absf(player.dynamics.steering)>.3:tutorial_step=2
		elif tutorial_step==2 and controls.held("brake"):tutorial_step=3
	if target_laps>0 and player.progress.finish_time>=0:
		show_results()

func _process(dt:float) -> void:
	if is_instance_valid(music):
		music.volume_db=linear_to_db(maxf(master_volume*music_volume*(.38 if state in [State.RACING,State.COUNTDOWN] else .7),.0001)) if sound else -80
	if is_instance_valid(cue):cue.volume_db=linear_to_db(maxf(master_volume,.0001))-8 if sound else -80
	if state in [State.RACING,State.COUNTDOWN]:
		update_camera(dt)
		stats_timer+=dt
		if stats_timer>.1:
			stats_timer=0
			update_hud()
	if is_instance_valid(player) and state==State.RACING and sound and DisplayServer.get_name()!="headless":
		engine_audio.volume_db=-23+linear_to_db(maxf(master_volume,.0001))
		engine_audio.pitch_scale=.65+player.dynamics.velocity.length()/22.0
		dirt_audio.volume_db=(-30 if player.dynamics.surface!="asphalt" else (-35 if player.dynamics.slip>1 else -80))+linear_to_db(maxf(master_volume,.0001))
		if player.impact>2 and not impact_audio.playing:
			impact_audio.volume_db=-17+linear_to_db(maxf(master_volume,.0001))
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
	var base_distance:=62.0 if saved.setting("wide_camera",false) else 42.0
	var zoom:=base_distance+minf(player.dynamics.velocity.length()*.09,3.0)
	camera_distance=zoom if snap else lerpf(camera_distance,zoom,1.0-exp(-dt*2.0))
	var ahead:Vector3=PathData.world(player.dynamics.velocity.limit_length(32.0))*.25
	var target:Vector3=player.position+ahead
	# Preview the vertical profile as well as horizontal motion on bridge descents.
	if player.dynamics.velocity.length()>6:
		var road:Dictionary=path.nearest(player.dynamics.position,player.dynamics.route_s)
		var direction:=signf(player.dynamics.velocity.dot(road.tangent))
		var preview:Dictionary=path.sample(road.s+direction*18.0)
		target.y=lerpf(player.position.y,preview.height+.06,.6)
		# In compact hairpins the route turns away from current velocity; preview the bend.
		target.x=lerpf(target.x,preview.point.x,.25)
		target.z=lerpf(target.z,preview.point.y,.25)
	camera_shake=move_toward(camera_shake,0.0,dt*.6)
	# A narrow perspective lens gives foreground depth without rotating with the car.
	var pitch:=deg_to_rad(CAMERA_PITCH)
	var yaw:=deg_to_rad(CAMERA_YAW)
	var offset:=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*camera_distance
	var desired:=target+offset+Vector3(sin(time*72),0,cos(time*61))*minf(camera_shake,.18)
	camera.position=desired if snap else camera.position.lerp(desired,1.0-exp(-dt*5))
	camera.rotation_degrees=Vector3(-CAMERA_PITCH,CAMERA_YAW,0)
	if player.occlusion_visual!=null:
		player.occlusion_visual.visible=path.overhead_cover(player.position,camera.position)
		player.occlusion_visual.rotation=player.visual.rotation

func ranking() -> Array:
	var sorted:=cars.duplicate()
	sorted.sort_custom(func(a,b):
		if a.progress.finish_time>=0 and b.progress.finish_time>=0:
			return a.progress.finish_time<b.progress.finish_time
		if a.progress.finish_time>=0: return true
		if b.progress.finish_time>=0: return false
		return a.progress.score(path,a.dynamics.position,a.dynamics.route_s)>b.progress.score(path,b.dynamics.position,b.dynamics.route_s))
	return sorted

func update_hud() -> void:
	var place:=ranking().find(player)+1
	var mode:="驾驶训练" if tutorial else ("计时挑战" if event_id>=0 and practice else "计时练习")
	hud_label.text=(mode if practice else "P%d / 6    圈 %d / %d"%[place,mini(player.progress.laps+1,target_laps),target_laps])+"\n"+Catalog.clock_text(time)
	if time>1 and state==State.RACING:center_label.text=""
	var surface_name:String={"asphalt":"柏油路","dirt":"土路","grass":"路外"}[player.dynamics.surface]
	speed_label.text="%03d km/h\n%s"%[roundi(absf(player.dynamics.speed())*3.6),surface_name]
	speed_label.add_theme_font_size_override("font_size",23)
	var message:=toast if time<toast_until else ""
	if message=="":
		var upcoming:Dictionary=path.gate(player.progress.next_gate)
		var nearest:Dictionary=path.nearest(player.dynamics.position,player.dynamics.route_s)
		var past:=fposmod(float(nearest.s)-float(upcoming.s),path.length)
		if past>10 and past<path.length*.3:
			message="漏过检查点 · 请返回黄色标记或长按 RESET"
		elif player.dynamics.velocity.length()>4 and player.dynamics.velocity.dot(nearest.tangent)<-2:
			message="逆向行驶 · 请调整方向"
	if tutorial:
		message=["1 / 4   按住 GAS 或 W，让赛车加速", "2 / 4   按左右按钮或 A / D，沿赛道转向", "3 / 4   按 BRAKE 或空格，减速后再入弯", "4 / 4   沿黄色标记完成一圈；卡住时长按 R 复位"][tutorial_step]
	elif event_id>=0 and practice and message.is_empty():
		message="金牌目标  %.1f 秒"%Career.event(event_id).gold
	help_label.text=message
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
	v.add_child(button("离开比赛",leave_race))

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
	v.add_theme_constant_override("separation",8)
	panel_node.add_child(v)
	v.add_child(label(title,36,Color("ffd34e")))
	v.add_child(label(subtitle,17))
	return v

func show_results() -> void:
	if state==State.RESULTS:return
	state=State.RESULTS
	controls.enabled=false
	controls.clear()
	center_label.text=""
	play_cue("finish")
	if tutorial and player.progress.laps>=1:saved.set_setting("tutorial_complete",true)
	if event_id>=0:
		receipt=Career.new(saved).finish_event(race_token,ranking().find(player)+1,time,player.progress.laps,player.progress.resets==0)
	results_screen()

func results_screen() -> void:
	var career:=Career.new(saved)
	var title:="训练完成" if tutorial and player.progress.laps>=1 else ("训练结束" if tutorial else ("计时结算" if practice else "完赛  /  P%d"%(ranking().find(player)+1)))
	if event_id>=0 and receipt.get("ok",false):title="★".repeat(receipt.stars)+"☆".repeat(3-receipt.stars)+"   "+Career.event(event_id).name
	var v:=modal(title,"总时间 %s    最佳有效圈 %s"%[Catalog.clock_text(time),Catalog.clock_text(player.progress.best_lap)])
	if event_id>=0:
		if receipt.get("ok",false):
			v.add_child(label("+%s CR    已保存    余额 %s CR"%[Frontend.format_number(receipt.reward),Frontend.format_number(receipt.balance)],24,Color("68dec5")))
			if receipt.first_bonus>0:v.add_child(label("包含首次完赛奖励 +900 CR",16))
			if career.completed()==Career.EVENT_COUNT:v.add_child(label("APEX 冠军！全部赛事已完成。",21,Color("ffc857")))
		else:
			v.add_child(label(receipt.get("message","奖励尚未保存"),17,Color("ff9980")))
			v.add_child(button("重试保存奖励",func():receipt=career.finish_event(race_token,ranking().find(player)+1,time,player.progress.laps,player.progress.resets==0);results_screen(),true))
	if not practice:
		var sorted:=ranking()
		for i in range(sorted.size()):
			var car=sorted[i]
			v.add_child(label("%d  %s    %s    %s"%[i+1,car.display_name,Catalog.CARS[car.car_index].name,Catalog.clock_text(car.progress.finish_time) if car.progress.finish_time>=0 else "第 %d 圈"%(car.progress.laps+1)],17,Color("ffc857") if car.player else Color("c6d5e5")))
	else:
		v.add_child(label("完成 %d 圈 · 有效圈速已保存"%player.progress.laps,17))
	if event_id>=0 and receipt.get("ok",false):
		v.add_child(button("下一场赛事  →",func():launch_event(career.recommended_event()),true))
	elif tutorial:
		v.add_child(button("进入生涯赛事",func():show_menu("career"),true))
	else:
		v.add_child(button("再跑一场",start_race,true))
	v.add_child(button("返回俱乐部",func():show_menu("career" if event_id>=0 else "home")))

func _unhandled_key_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if is_instance_valid(overlay) and state==State.MENU:dismiss_overlay()
		elif state==State.MENU:
			if is_instance_valid(frontend) and frontend.page!="home":frontend.change("home")
			else:
				var column:=modal("退出游戏？","进度已经自动保存在本机。")
				column.add_child(button("继续游戏",dismiss_overlay,true))
				column.add_child(button("退出",func():get_tree().quit()))
		elif state==State.PAUSED:resume_game()
		elif state==State.RESULTS:show_menu()
		else:pause_game()

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if is_instance_valid(controls):
			pause_game(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		if state==State.PAUSED and paused_by_system:
			resume_game()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		var back:=InputEventKey.new()
		back.pressed=true
		back.keycode=KEY_ESCAPE
		_unhandled_key_input(back)
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _exit_tree() -> void:
	# Stop looping playback before freeing the scene (also covers Android activity shutdown).
	for playback in [engine_audio,dirt_audio,impact_audio,music,cue]:
		if is_instance_valid(playback):
			playback.stop()
			playback.stream=null
