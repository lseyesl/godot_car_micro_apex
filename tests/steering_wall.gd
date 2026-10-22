extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
var game
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=8:push_error(message)
func _initialize() -> void:call_deferred("run")
func touch(index:int,action:String,down:bool=true) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index;event.pressed=down
	event.position=game.controls.get_global_transform_with_canvas()*game.controls.areas[action].get_center()
	Input.parse_input_event(event);Input.flush_buffered_events()
func release() -> void:
	touch(0,"left",false);touch(1,"throttle",false);game.controls.clear()
func place(point:Vector2,heading:float,speed:float,old_direction:int=0) -> void:
	var near:Dictionary=game.path.nearest(point)
	var car=game.player
	car.dynamics.reset_at(point,heading);car.dynamics.route_s=near.s
	car.dynamics.velocity=car.dynamics.forward()*speed
	# A plausible retained full-lock state from the turn preceding the impact.
	car.dynamics.yaw_rate=-old_direction*1.8;car.dynamics.steering=old_direction
	car.position=Track.world(point,near.height+.06);car.rotation.y=heading
	car.velocity=Track.world(car.dynamics.velocity)
func tick() -> void:
	await physics_frame
	# Same dispatched controls and RaceCar entry point as Main's race loop.
	game.player.tick(1.0/60,game.controls.driving(),game.path)
func run() -> void:
	Engine.physics_ticks_per_second=600;Engine.max_physics_steps_per_frame=64;Engine.time_scale=10
	root.size=Vector2i(1280,720)
	game=Main.new();root.add_child(game)
	var temp:="/tmp/apex-steering-wall-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(temp);game.practice=true;game.quality=0
	game.selected_track=0;game.selected_car=3;game.start_race()
	game.state=Main.State.RACING;game.controls.enabled=true;game.controls.auto_throttle=false
	game.set_physics_process(false)
	await process_frame;game.controls.layout();await physics_frame
	# Screenshot: bay district, control 10 -> 11 hairpin exit, rear near inner curb.
	var base:Dictionary=game.path.nearest(Vector2(-52,-15))
	var contact_cases:=0
	for offset in [-6.0,0.0,6.0]:
		var at:Dictionary=game.path.sample(base.s+offset)
		var normal:=Vector2(-at.tangent.y,at.tangent.x)
		for lateral in [-4.0,-4.9,-5.8,-6.5]:
			for heading in [3.35,3.55,3.75]:
				for speed in [0.0,3.0,-3.0]:
					for direction in [-1,1]:
						for pedal in ["throttle","brake"]:
							release();place(at.point+normal*lateral,heading,speed)
							await physics_frame
							touch(0,"left" if direction<0 else "right");touch(1,pedal)
							var turn:=0.0;var contacts:=0
							for frame in range(30):
								var before:Vector2=game.player.dynamics.forward()
								await tick()
								turn+=before.angle_to(game.player.dynamics.forward())*direction
								contacts+=game.player.get_slide_collision_count()
							check(turn>=-.0001,"Rest/rolling near curb must retain nose-relative touch direction")
							if contacts>0:contact_cases+=1
	check(contact_cases>200,"Screenshot neighbourhood must exercise real curb collisions")
	# A real rear-first impact stops translation. Then release or press the opposite arrow + GAS.
	# Both left/right are covered; rotating the car PI tests an equivalent front-first impact.
	for facing in [0.0,PI]:
		for old_direction in [-1,1]:
			for mode in ["idle","countersteer"]:
				release();place(Vector2(-52,-15),3.55+facing,-12 if facing==0 else 12,old_direction)
				await physics_frame
				touch(0,"left" if old_direction<0 else "right")
				var stopped:=false
				for frame in range(30):
					await tick()
					if game.player.get_slide_collision_count()>0 and game.player.dynamics.velocity.length()<.01:
						stopped=true;break
				check(stopped,"Fixture must reach an actual hard curb stop")
				var forward:Vector2=game.player.dynamics.forward()
				var contrary:=0.0
				release()
				if mode=="countersteer":
					touch(0,"right" if old_direction<0 else "left");touch(1,"throttle")
				var command:Dictionary=game.controls.driving()
				check(command.steer==-old_direction and command.throttle and not command.brake if mode=="countersteer" else command.steer==0 and not command.throttle and not command.brake,"Post-impact controls must match the dispatched fresh arrow + GAS or release")
				for frame in range(30):
					await tick()
					var turn:float=forward.angle_to(game.player.dynamics.forward())
					if mode=="idle":
						contrary=maxf(contrary,absf(turn))
					else:
						contrary=maxf(contrary,turn*old_direction)
				if mode=="countersteer":
					check(forward.angle_to(game.player.dynamics.forward())*-old_direction>.001,"A fresh arrow + GAS must actually turn the nose after the hard stop")
				check(contrary<.0001,"Hard-stop %s must not keep old rotation (facing=%f old_direction=%d contrary_deg=%f)"%[mode,facing,old_direction,rad_to_deg(contrary)])
	# Repeated crawl-speed contact must still let a held arrow turn away from a wall.
	for direction in [-1,1]:
		release();place(Vector2(-52,-15),3.55+PI,0)
		await physics_frame
		var forward:Vector2=game.player.dynamics.forward()
		touch(0,"left" if direction<0 else "right");touch(1,"throttle")
		var contacts:=0
		for frame in range(120):
			await tick();contacts+=game.player.get_slide_collision_count()
		check(contacts>20 and forward.angle_to(game.player.dynamics.forward())*direction>.02,"Crawl contact must preserve enough held lock to turn out of a head-on obstruction")
	# A glancing scrape slows translation but retains established steering response.
	var at:Dictionary=game.path.sample(base.s)
	var normal:=Vector2(-at.tangent.y,at.tangent.x)
	for side in [-1,1]:
		var direction:int=-side
		release();place(at.point+normal*side*5.8,Track.heading(at.tangent),20,direction)
		game.player.dynamics.velocity=at.tangent*20+normal*side*7
		await physics_frame
		touch(0,"left" if direction<0 else "right")
		var scraped:=false
		for frame in range(6):
			await tick()
			if game.player.get_slide_collision_count()>0:scraped=true;break
		var forward:Vector2=game.player.dynamics.forward()
		await tick()
		check(scraped and game.player.dynamics.velocity.length()>10 and forward.angle_to(game.player.dynamics.forward())*direction>.005,"Glancing contact must retain the established turn instead of resetting it")
	release();game.queue_free()
	for frame in range(4):await process_frame
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(temp+suffix):DirAccess.remove_absolute(temp+suffix)
	print("STEERING_WALL checks=%d failures=%d contact_cases=%d"%[checks,failures,contact_cases])
	quit(1 if failures else 0)
