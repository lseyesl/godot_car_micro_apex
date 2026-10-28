extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Style=preload("res://scripts/model_style.gd")
var game
var phase:String
var folder="res://build/validation/countdown-opacity/"
func _initialize():call_deferred("run")
func capture(name:String):
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 var path=folder+Style.selected()+"-"+phase+"-"+name+".png"
 root.get_texture().get_image().save_png(path);print("OPACITY_CAPTURE ",path)
func run():
 phase=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(folder)
 game=Main.new();game.saved=Store.new("/tmp/apex-opacity-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for condition in ["bright","dark","wide"]:
  root.size=Vector2i(2400,1080) if condition=="wide" else Vector2i(1280,720)
  game.quality=1;game.launch_free(5 if condition=="bright" else 0,false,true)
  if condition=="dark":
   game.sun.light_energy=.20
   for child in game.get_children():
    if child is WorldEnvironment:child.environment.ambient_light_energy=.12
  game.fit_countdown();game.update_hud();game.present_start(3);await capture(condition+"-3")
  game.present_start(0);await capture(condition+"-go")
  game.countdown_plate.hide();game.center_label.hide();await capture(condition+"-clear")
 game.stop_start_cue();game.queue_free()
 for i in range(12):await process_frame
 quit()
