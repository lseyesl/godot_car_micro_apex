extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.physics_ticks_per_second=600
	Engine.max_physics_steps_per_frame=64
	Engine.time_scale=10
	var file:="/tmp/apex-expansion-%d.cfg"%OS.get_process_id()
	var game=Main.new()
	game.saved=Store.new(file)
	root.add_child(game)
	game.quality=0
	game.automated_player=true
	for track in range(3,6):
		game.selected_car=[4,5,7][track-3]
		game.saved.config.set_value("garage","owned_%d"%game.selected_car,true)
		game.launch_free(track,false,false)
		game.target_laps=1
		game.countdown=.01
		var ticks:=0
		while game.state!=Main.State.RESULTS and ticks<16000:
			await physics_frame
			ticks+=1
		var passed:bool=game.state==Main.State.RESULTS and game.player.progress.laps==1
		if not passed:failures+=1
		print("EXPANSION_RACE track=%d car=%d completed=%s gate=%d"%[track,game.selected_car,passed,game.player.progress.next_gate])
		game.show_menu()
	game.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	print("EXPANSION_FLOW races=3 failures=%d"%failures)
	quit(1 if failures else 0)
