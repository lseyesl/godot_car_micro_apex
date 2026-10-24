extends SceneTree
# Exercise the engine event dispatcher -> Controls -> Main -> RaceCar -> rendered basis.
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
var game
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=8:push_error(message)
func _initialize() -> void:call_deferred("run")
func key(code:int,down:bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func touch(index:int,action:String,down:bool=true) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index;event.pressed=down
	event.position=game.controls.get_global_transform_with_canvas()*game.controls.areas[action].get_center()
	Input.parse_input_event(event);Input.flush_buffered_events()
func mouse(action:String,down:bool=true) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	event.position=game.controls.get_global_transform_with_canvas()*game.controls.areas[action].get_center()
	Input.parse_input_event(event);Input.flush_buffered_events()
func run() -> void:
	# SceneTree --script starts headless with a 64px window; dispatch in real viewport pixels.
	root.size=Vector2i(1280,720)
	game=Main.new();root.add_child(game)
	var temp:="/tmp/apex-steering-input-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(temp);game.practice=true;game.quality=0
	game.start_race();game.state=Main.State.RACING;game.controls.enabled=true
	game.controls.auto_throttle=false
	await process_frame
	game.controls.layout()
	var spawn:Dictionary=game.path.sample(25)
	var headings:=[0.0,PI/4,PI/2,3*PI/4,PI,-PI,-3*PI/4,-PI/2,-PI/4,PI-.001,-PI+.001,deg_to_rad(Main.CAMERA_YAW)+PI]
	for source in ["wasd","arrows","touch","mouse"]:
		for direction in [-1,1]:
			for heading in headings:
				game.controls.clear()
				game.player.dynamics.reset_at(spawn.point,heading)
				game.player.position=Vector3(spawn.point.x,spawn.height+.06,spawn.point.y)
				game.player.rotation.y=heading
				var forward:Vector2=game.player.dynamics.forward()
				var right:=Vector2(-forward.y,forward.x)
				game.player.dynamics.velocity=forward*8
				var action:String="left" if direction<0 else "right"
				var code:int=(KEY_A if direction<0 else KEY_D) if source=="wasd" else (KEY_LEFT if direction<0 else KEY_RIGHT)
				if source in ["wasd","arrows"]:
					key(code,true);key(KEY_W,true)
				elif source=="touch":
					touch(0,action);touch(1,"throttle")
				else:
					mouse(action);key(KEY_UP,true)
				check(game.controls.driving().steer==direction and game.controls.driving().throttle,"Dispatched %s must steer and accelerate"%source)
				for frame in range(12):await physics_frame
				var rendered:Vector3=-game.player.global_basis.z
				check(Vector2(rendered.x,rendered.z).dot(right)*direction>.001,"Live rendered nose reversed: %s direction=%d yaw=%f"%[source,direction,heading])
				check(Vector2(rendered.x,rendered.z).distance_to(game.player.dynamics.forward())<.0001,"Rendered and simulated nose must agree across yaw seam")
				if source in ["wasd","arrows"]:
					key(code,false);key(KEY_W,false)
				elif source=="touch":
					touch(0,action,false)
					check(game.controls.driving().steer==0 and game.controls.driving().throttle,"Releasing steering must preserve the gas finger")
					touch(1,"throttle",false)
				else:
					mouse(action,false);key(KEY_UP,false)
				check(game.controls.driving().steer==0 and not game.controls.driving().throttle,"Releasing dispatched inputs must clear command")
	# Slide the steering finger across arrows while another finger holds gas.
	touch(0,"left");touch(1,"throttle")
	var drag:=InputEventScreenDrag.new()
	drag.index=0;drag.position=game.controls.get_global_transform_with_canvas()*game.controls.areas.right.get_center()
	Input.parse_input_event(drag);Input.flush_buffered_events()
	check(game.controls.driving().steer==1 and game.controls.driving().throttle,"Dragging left to right must update touch and emulated mouse together")
	touch(0,"right",false);touch(1,"throttle",false)
	# Opposing inputs cancel, regardless of source; re-press brake engages reverse drive.
	key(KEY_A,true);touch(0,"right");touch(1,"throttle")
	check(game.controls.driving().steer==0 and game.controls.driving().throttle,"Keyboard and touch opposite arrows cancel")
	key(KEY_A,false);touch(0,"right",false);touch(1,"throttle",false)
	for direction in [-1,1]:
		game.controls.clear();game.player.dynamics.reset_at(spawn.point,PI)
		game.player.position=Vector3(spawn.point.x,spawn.height+.06,spawn.point.y)
		var right:=Vector2(-game.player.dynamics.forward().y,game.player.dynamics.forward().x)
		key(KEY_A if direction<0 else KEY_D,true);key(KEY_S,true)
		for frame in range(40):await physics_frame
		check(game.player.dynamics.speed()<-.1 and game.player.dynamics.forward().dot(right)*direction<0,"Live reverse reverses body yaw relative to forward travel")
		key(KEY_A if direction<0 else KEY_D,false);key(KEY_S,false)
	game.queue_free();await process_frame
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(temp+suffix):DirAccess.remove_absolute(temp+suffix)
	print("STEERING_INPUT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
