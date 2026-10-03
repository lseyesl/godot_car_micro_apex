extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new()
	var file:="/tmp/apex-camera-study-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(file)
	root.add_child(game)
	game.smoke_mode=false
	game.launch_free(0,false,true)
	game.set_process(false)
	game.countdown=1000
	game.center_label.hide()
	var pose:Dictionary=game.path.sample(game.path.length*.32)
	game.player.dynamics.reset_at(pose.point,Track.heading(pose.tangent))
	game.player.dynamics.route_s=pose.s
	game.player.position=Track.world(pose.point,.06)
	game.player.rotation.y=Track.heading(pose.tangent)
	var target:Vector3=game.player.position
	for variant in range(3):
		var angle:float=deg_to_rad(49.3 if variant==0 else 38.0)
		var yaw:=deg_to_rad(35.54)
		game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE if variant==2 else Camera3D.PROJECTION_ORTHOGONAL
		game.camera.fov=34
		game.camera.size=38
		game.camera.position=target+Vector3(sin(yaw)*cos(angle),sin(angle),cos(yaw)*cos(angle))*62
		game.camera.look_at(target)
		for i in range(10):await process_frame
		await RenderingServer.frame_post_draw
		var status:=root.get_texture().get_image().save_png("res://build/camera-study-%d.png"%variant)
		if status!=OK:quit(1);return
		print("CAMERA_STUDY variant=%d status=0"%variant)
	game.queue_free()
	for i in range(12):await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	quit()
