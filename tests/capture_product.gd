extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new()
	var file:="/tmp/apex-capture-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(file)
	root.add_child(game)
	game.smoke_mode=false
	for page in ["home","career","garage","freeplay","settings","credits"]:
		game.frontend.change(page)
		for i in range(16):await process_frame
		await RenderingServer.frame_post_draw
		var status:=root.get_texture().get_image().save_png("res://build/product-"+page+".png")
		if status!=OK:quit(1);return
		print("PRODUCT_CAPTURE page=",page," status=0")
	game.automated_player=true
	game.launch_event(0)
	game.countdown=.01
	for i in range(35):await process_frame
	await RenderingServer.frame_post_draw
	var status:=root.get_texture().get_image().save_png("res://build/product-race.png")
	print("PRODUCT_CAPTURE page=race status=",status)
	game.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	quit(0 if status==OK else 1)
