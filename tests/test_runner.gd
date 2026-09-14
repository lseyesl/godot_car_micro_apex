extends SceneTree

const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Progress=preload("res://scripts/race_progress.gd")
const Store=preload("res://scripts/save_store.gd")
const Controls=preload("res://scripts/touch_controls.gd")
var failures:=0
var checks:=0

func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for index in range(3):
		var track=Track.new(index)
		check(track.length>650 and track.length<1200,"Track length outside intended race scale")
		check(track.sample(0).point.distance_to(track.sample(track.length).point)<.001,"Track must close")
		var asphalt:=0
		var dirt:=0
		for i in range(100):
			if track.surface_at(track.length*i/100.0)=="dirt":dirt+=1
			else:asphalt+=1
		check(asphalt>10 and dirt>10,"Each track must mix surfaces")
		var off:Dictionary=track.nearest(Vector2(500,500))
		check(off.surface=="grass","Road exterior must slow cars")
	var path=Track.new(0)
	var grid_front=Progress.new()
	var grid_back=Progress.new()
	check(grid_front.score(path,path.sample(-5).point)>grid_back.score(path,path.sample(-12).point),"Starting grid rank must not wrap backwards across finish line")
	var p=Progress.new()
	var g:Dictionary=path.gate(2)
	p.advance(g.point-g.tangent,g.point+g.tangent,path,1)
	check(p.next_gate==1,"Skipping gate must not advance")
	g=path.gate(1)
	p.advance(g.point+g.tangent,g.point-g.tangent,path,2)
	check(p.next_gate==1,"Reverse crossings must not count")
	var side:=Vector2(-g.tangent.y,g.tangent.x)*15
	p.advance(g.point-g.tangent+side,g.point+g.tangent+side,path,3)
	check(p.next_gate==1,"Off-road gate crossing must not count")
	p.invalidate_for_reset()
	var last:Dictionary={}
	for i in range(1,25):
		g=path.gate(i%24)
		last=p.advance(g.point-g.tangent,g.point+g.tangent,path,float(i)+3)
	check(p.laps==1 and not last.valid and not is_finite(p.best_lap),"Reset lap cannot set a best time")
	for lap in range(2):
		for i in range(1,25):
			g=path.gate(i%24)
			p.advance(g.point-g.tangent,g.point+g.tangent,path,28+lap*24+i)
	check(p.laps==3 and p.finish_time>0 and is_finite(p.best_lap),"Three ordered laps should finish")
	var finished:float=p.finish_time
	p.advance(g.point-g.tangent,g.point+g.tangent,path,500)
	check(p.finish_time==finished,"Finishing is immutable")
	var car=Dynamics.new(Catalog.CARS[3])
	for i in range(Catalog.CARS.size()):
		var old_spec:Dictionary=Catalog.CARS[i].duplicate()
		old_spec.radius=[8.8,5.5,7.3,6.8][i]
		var previous=Dynamics.new(old_spec)
		var tighter=Dynamics.new(Catalog.CARS[i])
		for vehicle in [previous,tighter]:
			vehicle.velocity=Vector2(0,-3)
			vehicle.steering=1.0
			vehicle.step(1.0/60,1,false,false,"asphalt")
		check(absf(tighter.yaw)>absf(previous.yaw)*1.4,"Low-speed full-lock turn must be tighter than the original tuning")
	for i in range(180):car.step(1.0/60,0,true,false,"asphalt")
	check(car.speed()>15,"Car must accelerate under throttle")
	for i in range(180):car.step(1.0/60,0,false,true,"asphalt")
	check(absf(car.speed())<.1,"Holding brake must stop without reversing")
	car.step(1.0/60,0,false,false,"asphalt")
	for i in range(90):car.step(1.0/60,0,false,true,"asphalt")
	check(car.speed() < -1 and car.speed()>=-6.01,"Release and repress brake should reverse at capped speed")
	for i in range(180):car.step(1.0/60,0,true,false,"asphalt")
	check(car.speed()>0,"Throttle must brake reverse then drive forward")
	car.reset_at(Vector2.ZERO,0)
	car.velocity=Vector2(0,-40)
	var angle:float=car.yaw
	car.step(.1,1,true,false,"asphalt")
	check(absf(car.yaw-angle)>car.grip_for("asphalt")/40*.1 and absf(car.yaw-angle)<.3,"High-speed body rotation must allow bounded oversteer")
	check(car.grip_for("dirt")<car.grip_for("asphalt"),"Dirt grip must decrease")
	car.reset_at(Vector2.ZERO,0)
	car.velocity=Vector2(0,-40)
	for i in range(120):car.step(1.0/60,0,true,false,"grass")
	check(car.velocity.length()<17,"Off-road speed must decay even with throttle")
	var store_path:="/tmp/micro-apex-record-test-%d.cfg"%OS.get_process_id()
	var store=Store.new(store_path)
	store.config.set_value("records","1_2",1.0)
	check(not is_finite(store.best(1,2)),"Old layout records must not compete with new track times")
	check(store.record(1,2,50),"First record should save")
	check(not store.record(1,2,55),"Slower lap must not replace best")
	check(not store.record(1,2,-1),"Invalid time rejected")
	store.set_setting("quality",0)
	var loaded=Store.new(store_path)
	check(loaded.best(1,2)==50 and not is_finite(loaded.best(1,3)),"Records must persist and be separated by car")
	check(loaded.setting("quality",1)==0,"Settings must persist")
	DirAccess.remove_absolute(store_path)
	var input=Controls.new()
	root.add_child(input)
	input.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	input.size=Vector2(1280,720)
	input.enabled=true
	input.layout()
	var left:=InputEventScreenTouch.new()
	left.index=1;left.pressed=true;left.position=input.areas.left.get_center()
	input._input(left)
	var gas:=InputEventScreenTouch.new()
	gas.index=2;gas.pressed=true;gas.position=input.areas.throttle.get_center()
	input._input(gas)
	check(input.driving().steer==-1 and input.driving().throttle,"Independent fingers must steer and accelerate together")
	left.pressed=false;input._input(left)
	check(input.driving().steer==0 and input.driving().throttle,"Releasing one finger must not cancel another")
	input.clear()
	check(not input.driving().throttle,"Pause clearing must release all touches")
	input.queue_free()
	print("RULE_TESTS checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
