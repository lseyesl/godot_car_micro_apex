extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args();var label=args[0];var track=int(args[1]);var detail=args.size()>2
 root.size=Vector2i(1280,720)
 var game=Main.new();game.saved=Store.new("/tmp/apex-scenery-render.cfg");root.add_child(game)
 game.quality=1;game.selected_track=track;game.selected_car=3;game.practice=true;game.start_race()
 game.set_process(false);game.set_physics_process(false)
 game.camera.fov=50
 for child in game.get_children():
  if child is CanvasLayer:child.visible=false
 var target=Vector3(94,10 if track==0 else 3,143) if detail else Vector3.ZERO
 game.camera.position=target+(Vector3(35,25,45) if detail else Vector3(210,250,260))
 game.camera.look_at(target)
 for frame in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/scenery/"+label+".png")
 print("SCENERY_RENDER ",label," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," texture_bytes=",Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
 game.queue_free();await process_frame;quit()
