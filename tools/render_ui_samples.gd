extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var prefix:String
func _initialize():call_deferred("run")
func capture(name:String):
 await create_timer(.3).timeout
 for frame in range(3):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/ui/"+prefix+"-"+name+".png")
 print("UI_CAPTURE ",name," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," texture_bytes=",Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
func run():
 DirAccess.make_dir_recursive_absolute("res://build/validation/ui")
 prefix=OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,720)
 var game=Main.new();game.saved=Store.new("/tmp/apex-ui-capture-%d.cfg"%OS.get_process_id());root.add_child(game)
 for page in ["home","garage","freeplay","career","settings"]:
  game.frontend.change(page);await capture(page)
 game.selected_track=0;game.quality=1;game.practice=true;game.start_race();game.state=Main.State.RACING;game.controls.pedals_locked=false;game.countdown=0;game.set_process(false);game.set_physics_process(false);game.controls.enabled=true;game.center_label.text="";game.update_hud()
 await capture("hud")
 game.controls.layout()
 for pair in [[0,"left"],[1,"throttle"]]:
  var event=InputEventScreenTouch.new();event.index=pair[0];event.pressed=true;event.position=game.controls.get_global_transform_with_canvas()*game.controls.areas[pair[1]].get_center();Input.parse_input_event(event)
 Input.flush_buffered_events();await capture("pressed")
 game.pause_game();await capture("pause")
 game.resume_game();game.show_results();await capture("results")
 game.queue_free()
 for frame in range(12):await process_frame
 await RenderingServer.frame_post_draw
 quit()
