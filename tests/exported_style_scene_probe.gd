extends SceneTree
func _initialize():call_deferred("run")
func run():
 var Main=load("res://scripts/main.gd")
 var Style=load("res://scripts/model_style.gd")
 var UI=load("res://scripts/clay_ui.gd")
 var Store=load("res://scripts/save_store.gd")
 var failures:=0
 var game=Main.new();game.saved=Store.new("/tmp/apex-packed-scene-%d.cfg"%OS.get_process_id());root.add_child(game)
 game.set_process(false);game.quality=1
 for track in range(load("res://scripts/catalog.gd").TRACKS.size()):
  game.launch_free(track,false,true);game.countdown=1000
  for frame in range(3):await process_frame
  if game.speed_label.get_theme_color("font_color")!=(UI.ACCENT if Style.is_crafted() else Color("ffd34e")):
   failures+=1;push_error("Packaged UI theme does not match locked model style")
  if Style.is_crafted():
   var box=game.controls.get_theme_stylebox("normal") if game.controls.has_theme_stylebox("normal") else UI.box("touch")
   if box.paper!=Style.is_paper():failures+=1;push_error("Packaged UI shape does not match style")
  var district=game.circuit.get_child(1)
  if district.get_meta("new_landmarks",[]).size()!=2 or district.get_meta("new_greenery",[]).size()<24 or district.get_meta("new_leaf_clusters",0)==0:
   failures+=1;push_error("Missing packaged scenery additions")
  print("PACKED_STYLE_SCENE style=%s track=%d cars=%d"%[Style.selected(),track,game.cars.size()])
 print("PACKED_STYLE_SCENES_COMPLETE tracks=%d failures=%d"%[load("res://scripts/catalog.gd").TRACKS.size(),failures])
 game.queue_free()
 for frame in range(4):await process_frame
 quit(1 if failures else 0)
