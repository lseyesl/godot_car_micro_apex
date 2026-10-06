extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var failures:=0
var checks:=0

func check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game=Main.new()
	root.add_child(game)
	var temp:="/tmp/micro-apex-integration-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(temp)
	game.practice=false
	game.quality=0
	game.start_race()
	check(game.cars.size()==6,"Race must have player and five AI")
	game.countdown=0.01
	await physics_frame
	await physics_frame
	check(game.state==game.State.RACING,"Countdown starts race")
	game.controls.fingers[42]="throttle"
	for i in range(20):await physics_frame
	check(game.player.dynamics.speed()>1,"Touch throttle reaches live car")
	game.pause_game()
	var stopped_time:float=game.time
	var stopped:Vector3=game.player.position
	for i in range(12):await physics_frame
	check(game.time==stopped_time and game.player.position==stopped,"Pause freezes cars and race clock")
	check(game.controls.fingers.is_empty(),"Pause cancels held touch")
	game.resume_game()
	for i in range(12):await physics_frame
	check(game.time==stopped_time and game.state==game.State.COUNTDOWN,"Resume countdown also freezes time")
	game.countdown=.01
	await physics_frame
	await physics_frame
	game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state==game.State.PAUSED,"System interruption pauses race")
	game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.state==game.State.COUNTDOWN,"Returning from background starts resume countdown")
	game.player.reset_to_gate(game.path)
	check(not game.player.progress.valid_lap,"Live reset invalidates lap")
	game.state=Main.State.RACING
	var opponent=game.cars[1]
	opponent.progress.finish_time=20.0
	await physics_frame
	await physics_frame
	check(opponent.collision_layer==0 and opponent.collision_mask==0,"Finished opponents must not block the finish lane")
	check(opponent.progress.finish_time==20.0,"Clearing finish lane must preserve classification time")
	game.player.progress.finish_time=22.0
	game.cars[1].progress.finish_time=21.0
	check(game.ranking()[0]==game.cars[1] and game.ranking()[1]==game.player,"Finished cars rank by finish order")
	game.show_results()
	check(game.state==game.State.RESULTS and not game.controls.enabled,"Results disable controls")
	game.practice=true
	game.start_race()
	check(game.cars.size()==1,"Practice must not spawn AI")
	game.show_menu()
	check(game.state==game.State.MENU and game.cars.is_empty(),"Exit must discard race state")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(temp):DirAccess.remove_absolute(temp)
	print("INTEGRATION checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
