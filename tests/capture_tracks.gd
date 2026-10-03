extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new()
	var file:="/tmp/apex-track-capture-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(file)
	root.add_child(game)
	game.smoke_mode=false
	for track in range(3):
		game.launch_free(track,false,true)
		# Countdown holds a reproducible actual gameplay camera for each route.
		game.countdown=100
		game.center_label.hide()
		for i in range(24):await process_frame
		await RenderingServer.frame_post_draw
		var status:=root.get_texture().get_image().save_png("res://build/track-%d-race.png"%track)
		if status!=OK:quit(1);return
		print("TRACK_CAPTURE track=",track," status=0")
	game.queue_free()
	for i in range(12):await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	quit()
