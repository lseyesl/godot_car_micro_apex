extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Style=preload("res://scripts/model_style.gd")
var game
var prefix:String
func _initialize():call_deferred("run")
func capture(name:String):
 for frame in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/countdown-controls/"+prefix+"-"+name+".png")
 print("COUNTDOWN_CAPTURE ",name," speed=",game.player.dynamics.speed()," time=",game.time," input=",game.controls.driving()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func touch(index:int,action:String,down:bool=true):
 var e=InputEventScreenTouch.new();e.index=index;e.pressed=down;e.position=game.controls.areas[action].get_center();Input.parse_input_event(e);Input.flush_buffered_events()
func run():
 DirAccess.make_dir_recursive_absolute("res://build/validation/countdown-controls");prefix=Style.selected();root.size=Vector2i(1280,720)
 game=Main.new();game.saved=Store.new("/tmp/apex-countdown-capture-%d.cfg"%OS.get_process_id());root.add_child(game)
 game.quality=1;game.start_race();game.set_physics_process(false);game.set_process(false);game.controls.auto_throttle=false
 game.controls.layout();game.update_hud();await capture("ready")
 touch(0,"left");touch(1,"throttle");touch(2,"brake")
 for frame in range(15):game._physics_process(1.0/60)
 await capture("pressed")
 touch(2,"brake",false);game.countdown=.001;game._physics_process(1.0/60);game._physics_process(1.0/60)
 await capture("go")
 game.queue_free()
 for frame in range(4):await process_frame
 quit()
