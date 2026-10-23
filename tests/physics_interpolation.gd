extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
class Driver extends Node3D:
	var game
	var steps:Array=[]
	var frames:Array=[]
	var reset_next:=false
	var check_reset:=false
	var reset_error:=INF
	func _physics_process(dt:float) -> void:
		if reset_next:
			game.player.progress.last_gate=8
			game.player.reset_to_gate(game.path)
			reset_next=false;check_reset=true;set_physics_process(false)
			return
		game.player.dynamics.velocity=game.player.dynamics.forward()*40
		game.player.tick(dt,{"steer":0,"throttle":false,"brake":false},game.path)
		steps.append(game.player.global_position)
	func _process(_dt:float) -> void:
		var car=game.player
		var rendered:Vector3=car.get_global_transform_interpolated().origin if get_tree().physics_interpolation else car.global_position
		if check_reset:
			reset_error=rendered.distance_to(car.global_position);check_reset=false
		frames.append({"position":rendered,"screen":game.camera.unproject_position(rendered),"contacts":car.get_slide_collision_count()})
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(physics_interpolation,"Project must enable interpolation for desktop and Android")
	check(Engine.physics_ticks_per_second==60,"Smoothing must not change the 60Hz driving simulation")
	root.size=Vector2i(640,360)
	var game=Main.new();root.add_child(game)
	game.saved=Store.new("/tmp/apex-interpolation-%d.cfg"%OS.get_process_id())
	game.practice=true;game.quality=0;game.sound=false;game.start_race()
	game.set_physics_process(false);game.state=Main.State.RACING;game.ui.hide()
	game.circuit.free();game.effects.free()
	check(game.camera.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"Per-frame camera must not receive a second interpolation pass")
	var pose:Dictionary=game.path.sample(game.path.distances[8*20]+15)
	game.player.dynamics.reset_at(pose.point,Track.heading(pose.tangent))
	game.player.dynamics.route_s=pose.s
	game.player.position=Track.world(pose.point,pose.height+.06);game.player.rotation.y=game.player.dynamics.yaw
	game.player.reset_physics_interpolation();game.update_camera(1,true)
	var driver=Driver.new();driver.game=game;driver.process_priority=1000;root.add_child(driver)
	for frame in range(180):await process_frame
	var frames:Array=driver.frames.slice(60)
	var zero_steps:=0;var max_step:=0.0;var min_step:=INF;var max_screen_accel:=0.0
	for i in range(1,frames.size()):
		var distance:float=frames[i].position.distance_to(frames[i-1].position)
		if distance<.0001:zero_steps+=1
		max_step=maxf(max_step,distance);min_step=minf(min_step,distance)
		if i>=2:
			var accel:Vector2=frames[i].screen-2*frames[i-1].screen+frames[i-2].screen
			max_screen_accel=maxf(max_screen_accel,accel.length())
	check(frames.size()>100,"Controlled render cadence must produce enough frames")
	check(zero_steps==0 and max_step-min_step<.001,"120Hz render must advance between 60Hz physics ticks instead of repeat/jump")
	check(max_screen_accel<.1,"Camera must follow the same smooth rendered pose as the car")
	check(frames.all(func(f):return f.contacts==0),"Motion fixture must exclude collision correction")
	# Pausing cannot leave a moving visual target; restarting/resetting cannot smear across the map.
	driver.set_physics_process(false)
	for i in range(4):await physics_frame
	var stopped:Vector3=game.player.global_position
	for i in range(8):await process_frame
	check(game.player.get_global_transform_interpolated().origin.distance_to(stopped)<.001,"Stopped physics must settle at the same render pose")
	driver.reset_next=true;driver.set_physics_process(true)
	for i in range(6):await process_frame
	check(driver.reset_error<.001,"Gate teleport must clear interpolation history on its first rendered frame")
	check(not game.player.progress.valid_lap and game.player.dynamics.velocity==Vector2.ZERO,"Interpolated reset must retain gameplay reset rules")
	game.set_process(false);game.launch_free(0,false,true)
	check(game.player.get_global_transform_interpolated().origin.distance_to(game.player.global_position)<.001,"New race must start at the actual grid pose")
	driver.queue_free();game.queue_free()
	for i in range(4):await process_frame
	print("PHYSICS_INTERPOLATION checks=%d failures=%d repeated_frames=%d screen_accel_max=%f"%[checks,failures,zero_steps,max_screen_accel])
	quit(1 if failures else 0)
