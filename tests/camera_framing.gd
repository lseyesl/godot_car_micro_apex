extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new()
	var file:="/tmp/apex-camera-%d.cfg"%OS.get_process_id()
	game.saved=Store.new(file)
	root.add_child(game)
	game.smoke_mode=false
	game.set_process(false)
	for track in range(Catalog.TRACKS.size()):
		game.launch_free(track,false,true)
		game.countdown=1000
		for wide in [false,true]:
			game.saved.config.set_value("settings","wide_camera",wide)
			for direction in [-1.0,1.0]:
				for speed in [0.0,40.0]:
					for step in range(24):
						var pose:Dictionary=game.path.sample(game.path.length*step/24.0)
						game.player.position=Track.world(pose.point,pose.height+.06)
						game.player.dynamics.position=pose.point
						game.player.dynamics.route_s=pose.s
						game.player.dynamics.velocity=pose.tangent*speed*direction
						game.update_camera(1,true)
						var screen:Vector2=game.camera.unproject_position(game.player.position)/root.get_visible_rect().size
						var visible:bool=not game.camera.is_position_behind(game.player.position) and screen.x>.15 and screen.x<.85 and screen.y>.18 and screen.y<.86
						checks+=1
						if not visible:
							failures+=1
							push_error("Player outside usable camera frame: %s"%screen)
						if speed>0:
							var upcoming:Dictionary=game.path.sample(pose.s+18.0*direction)
							var preview:Vector2=game.camera.unproject_position(Track.world(upcoming.point,upcoming.height+.06))/root.get_visible_rect().size
							checks+=1
							if preview.x<.05 or preview.x>.95 or preview.y<.16 or preview.y>.9:
								failures+=1
								push_error("Upcoming road outside usable frame: %s track=%d step=%d direction=%.0f wide=%s"%[preview,track,step,direction,wide])
		# Restart must snap from wide framing without inheriting its zoom.
		game.saved.config.set_value("settings","wide_camera",false)
		game.player.dynamics.velocity=Vector2.ZERO
		game.update_camera(1,true)
		checks+=1
		if not is_equal_approx(game.camera_distance,42.0):failures+=1
	game.queue_free()
	for i in range(24):await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	print("CAMERA_FRAMING checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
