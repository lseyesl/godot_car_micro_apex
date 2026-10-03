extends SceneTree
const Main=preload("res://scripts/main.gd")
const Career=preload("res://scripts/career.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.physics_ticks_per_second=600
	Engine.max_physics_steps_per_frame=64
	Engine.time_scale=10.0
	var file:="/tmp/apex-product-flow-%d.cfg"%OS.get_process_id()
	var game=Main.new()
	game.saved=Store.new(file)
	root.add_child(game)
	game.quality=0
	game.automated_player=true
	var career=Career.new(game.saved)
	for page in ["home","career","garage","freeplay","settings","credits"]:
		game.frontend.change(page)
		await process_frame
		check(game.frontend.page==page,"Navigation page loads: "+page)
	game.launch_event(0)
	check(game.state==Main.State.COUNTDOWN and game.target_laps==2 and game.cars.size()==6,"Career event config reaches actual race")
	game.countdown=.01
	var steps:=0
	while game.state!=Main.State.RESULTS and steps<16000:
		await physics_frame
		steps+=1
	check(game.state==Main.State.RESULTS and game.player.progress.laps==2,"Actual two-lap career race finishes")
	check(game.receipt.get("ok",false) and career.stars(0)>0 and career.credits()>1200,"Race settlement updates wallet and career")
	var balance:int=career.credits()
	game.show_results()
	check(career.credits()==balance,"Results displayed twice cannot pay twice")
	check(career.upgrade(3,"engine").ok,"Race earnings can purchase performance upgrade")
	game.launch_event(2)
	check(game.cars.size()==1 and game.target_laps==1 and game.practice,"Time attack launches solo with one-lap target")
	check(game.player.dynamics.spec.top>44,"Owned upgrade affects actual race vehicle")
	game.countdown=.01
	steps=0
	while game.state!=Main.State.RESULTS and steps<12000:
		await physics_frame
		steps+=1
	check(game.state==Main.State.RESULTS and game.receipt.get("ok",false),"Actual time attack completes and pays")
	game.launch_free(1,true,false)
	check(game.path.reversed and game.event_id==-1 and game.target_laps==3,"Reverse free race uses selected direction")
	game.pause_game()
	check(game.state==Main.State.PAUSED and not game.controls.enabled,"Pause freezes input")
	game.show_menu()
	game.launch_tutorial()
	check(game.tutorial and game.target_laps==1 and game.cars.size()==1,"Tutorial launches dedicated solo lesson")
	game.countdown=.01
	steps=0
	while game.state!=Main.State.RESULTS and steps<12000:
		await physics_frame
		steps+=1
	check(game.saved.setting("tutorial_complete",false),"Finishing tutorial persists completion")
	var loaded=Career.new(Store.new(file))
	check(loaded.stars(0)>0 and loaded.stars(2)>0 and loaded.level(3,"engine")==1,"Restart preserves earned progression")
	game.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	print("PRODUCT_FLOW checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
