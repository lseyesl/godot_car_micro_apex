extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second=600
	Engine.max_physics_steps_per_frame=64
	Engine.time_scale=10.0
	var game=Main.new()
	root.add_child(game)
	game.saved=Store.new("/tmp/micro-apex-soak.cfg")
	game.selected_track=1
	game.selected_car=3
	game.difficulty=1
	game.practice=false
	game.quality=0
	game.automated_player=true
	game.start_race()
	game.countdown=.01
	var steps:=0
	while game.state!=game.State.RESULTS and steps<24000:
		await physics_frame
		steps+=1
		if steps%3000==0:
			print("SOAK_PROGRESS time=%.1f lap=%d gate=%d"%[game.time,game.player.progress.laps,game.player.progress.next_gate])
	var success:bool=game.state==game.State.RESULTS and game.player.progress.laps==3
	var result:Array=[]
	for car in game.cars:
		result.append({"name":car.display_name,"laps":car.progress.laps,"resets":car.progress.resets,"finish":car.progress.finish_time})
	var file:=FileAccess.open("res://build/race-soak.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":success,"time":game.time,"cars":result},"\t"))
	file.close()
	file=null
	print("RACE_SOAK success=%s time=%.2f cars=%s"%[success,game.time,JSON.stringify(result)])
	game.queue_free()
	await create_timer(.15).timeout
	quit(0 if success else 1)
