extends SceneTree
const Main=preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game=Main.new()
	root.add_child(game)
	game.smoke_mode=false
	var race:bool=true
	game.selected_track=0
	if race:
		game.automated_player=true
		game.start_race()
		game.countdown=.01
	print("VISUAL_START race=",race)
	for i in range(120):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var destination:="res://docs/screenshots/curbs.png"
	var status:=image.save_png(destination)
	print("VISUAL_SAVED ",destination," result=",status)
	quit(0 if status==OK else 1)
