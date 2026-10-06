extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new()
	var file:="/tmp/apex-art-capture-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(file)
	root.add_child(game)
	game.smoke_mode=false
	for track in (range(Catalog.TRACKS.size()) if "--all" in OS.get_cmdline_user_args() else [0]):
		game.launch_free(track,false,true)
		game.countdown=1000
		game.center_label.hide()
		for shot in range(2):
			var feature:Dictionary=game.path.elevations[shot]
			var pose:Dictionary=game.path.sample((feature.stops[0]+feature.stops[1])*.5)
			game.player.dynamics.reset_at(pose.point,Track.heading(pose.tangent))
			game.player.dynamics.route_s=pose.s
			game.player.position=Track.world(pose.point,pose.height+.06)
			game.player.rotation.y=Track.heading(pose.tangent)
			game.player.tick(1.0/60,{"steer":0,"throttle":false,"brake":true},game.path)
			game.update_camera(1,true)
			for i in range(12):await process_frame
			await RenderingServer.frame_post_draw
			var status:=root.get_texture().get_image().save_png("res://build/elevation-%d-%d.png"%[track,shot])
			if status!=OK:quit(1);return
			print("ART_CAPTURE track=%d shot=%d status=0"%[track,shot])
	game.queue_free()
	for i in range(24):await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	quit()
