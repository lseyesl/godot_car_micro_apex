extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Style=preload("res://scripts/model_style.gd")
var game
func _initialize():call_deferred("run")
func capture(page:String,phase:String):
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/mobile-ui/"+Style.selected()+"-"+page+"-"+phase+".png")
 var scroll=game.frontend.find_children("*","ScrollContainer",true,false)[0]
 print("MOBILE_UI_CAPTURE ",page," ",phase," window=",root.size," canvas=",root.get_visible_rect().size," transform=",root.get_final_transform()," safe_ui=",game.ui.get_global_rect()," scroll=",scroll.scroll_vertical," max=",scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
func run():
 Input.emulate_touch_from_mouse=true;root.size=Vector2i(2048,922)
 DirAccess.make_dir_recursive_absolute("res://build/validation/mobile-ui")
 game=Main.new();game.saved=Store.new("/tmp/apex-mobile-ui-capture-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_physics_process(false);game.set_process(false)
 game.fit_ui_to_safe_area(Rect2i(0,0,2048,922),Rect2i(55,0,1993,922))
 for page in ["career","garage","freeplay"]:
  game.frontend.change(page)
  if page=="freeplay":game.frontend.circuit_page=1;game.frontend.render()
  await capture(page,"top")
  var scroll=game.frontend.find_children("*","ScrollContainer",true,false)[0]
  var start:Vector2=scroll.get_global_rect().get_center()
  for repeat in range(3):
   var e=InputEventScreenTouch.new();e.index=0;e.pressed=true;e.position=root.get_final_transform()*start;Input.parse_input_event(e);Input.flush_buffered_events()
   for i in range(12):
    var d=InputEventScreenDrag.new();d.index=0;d.position=root.get_final_transform()*(start+Vector2(0,-18*(i+1)));d.relative=root.get_final_transform().basis_xform(Vector2(0,-18));d.velocity=d.relative*60;Input.parse_input_event(d);Input.flush_buffered_events();await process_frame
   e.pressed=false;e.position=root.get_final_transform()*(start+Vector2(0,-216));Input.parse_input_event(e);Input.flush_buffered_events()
  await capture(page,"bottom")
 game.queue_free()
 for i in range(4):await process_frame
 quit()
