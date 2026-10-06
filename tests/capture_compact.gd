extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new()
	var file:="/tmp/apex-layout-capture-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(file);root.add_child(game)
	game.smoke_mode=false;game.set_process(false)
	for track in [0,3]:
		game.launch_free(track,false,true);game.countdown=1000;game.ui.hide()
		game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		game.camera.size=250
		game.camera.position=Vector3(0,230,160);game.camera.look_at(Vector3.ZERO)
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/compact-overview-%d.png"%track)
		print("COMPACT_OVERVIEW ",track)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.ui.show();game.center_label.hide()
	for control in [10,22]:
		var pose:Dictionary=game.path.sample(game.path.distances[control*20]-6.0)
		game.player.dynamics.reset_at(pose.point,Track.heading(pose.tangent));game.player.dynamics.route_s=pose.s
		game.player.position=Track.world(pose.point,pose.height+.06);game.player.rotation.y=Track.heading(pose.tangent)
		game.player.tick(1.0/60,{"steer":0,"throttle":false,"brake":true},game.path)
		game.update_camera(1,true)
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/compact-crossing-%d.png"%control)
		print("COMPACT_CROSSING ",control)
	game.queue_free()
	for i in range(24):await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	quit()
