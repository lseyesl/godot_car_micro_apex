extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Clay=preload("res://scripts/clay_ui.gd")
var checks:=0
var failures:=0
var game
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func contrast(a:Color,b:Color) -> float:
 var x=a.srgb_to_linear().get_luminance();var y=b.srgb_to_linear().get_luminance()
 return (maxf(x,y)+.05)/(minf(x,y)+.05)
func click(text:String):
 for button in game.ui.find_children("*","Button",true,false):
  if button.text!=text or button.disabled:continue
  var p=button.get_global_rect().get_center()
  var motion=InputEventMouseMotion.new();motion.position=p;Input.parse_input_event(motion)
  for down in [true,false]:
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=p;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
  return
 check(false,"Missing clickable control "+text)
func touch(index:int,action:String):
 var event=InputEventScreenTouch.new();event.index=index;event.pressed=true
 event.position=game.controls.get_global_transform_with_canvas()*game.controls.areas[action].get_center()
 Input.parse_input_event(event);Input.flush_buffered_events()
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 game=Main.new();game.saved=Store.new("/tmp/apex-ui-test-%d.cfg"%OS.get_process_id());root.add_child(game);game.quality=0
 for page in ["home","career","garage","freeplay","settings","credits"]:
  game.frontend.change(page);await process_frame
  for button in game.ui.find_children("*","Button",true,false):
   check(button.custom_minimum_size.y>=48,"Keep mobile button targets")
   if Clay.active():
    for pair in [["normal","font_color"],["pressed","font_pressed_color"],["disabled","font_disabled_color"]]:
     check(contrast(button.get_theme_color(pair[1]),button.get_theme_stylebox(pair[0]).bg_color)>=4.5,"Readable button state "+pair[0])
 game.frontend.change("home");await process_frame
 await click("自由驾驶");check(game.frontend.page=="freeplay","Actual navigation button remains clickable")
 game.launch_free(0,false,true);game.state=Main.State.RACING;game.controls.pedals_locked=false;game.controls.enabled=true;game.controls.layout();game.set_physics_process(false)
 check(game.controls.areas.left==Rect2(28,594,100,100),"Left target geometry unchanged")
 root.size=Vector2i(960,540)
 for frame in range(2):await process_frame
 game.controls.layout()
 check(not game.controls.areas.right.intersects(game.controls.areas.brake),"Small landscape driving targets do not overlap")
 check(Rect2(Vector2.ZERO,game.controls.size).encloses(game.controls.areas.throttle),"Small landscape GAS target stays within viewport")
 root.size=Vector2i(1280,720)
 for frame in range(2):await process_frame
 game.controls.large=true;game.controls.layout()
 check(game.controls.areas.left.size==Vector2(126,126),"Large touch setting preserves target size")
 game.controls.large=false;game.controls.layout()
 touch(0,"left");touch(1,"throttle")
 check(game.controls.driving().steer==-1 and game.controls.driving().throttle,"Two-finger LEFT + GAS unchanged")
 await click("Ⅱ");check(game.state==Main.State.PAUSED and not game.controls.enabled,"Actual pause button clears controls")
 await click("继续比赛");check(game.state==Main.State.COUNTDOWN and game.controls.fingers.is_empty(),"Actual resume button restarts countdown without held fingers")
 game.show_results();await process_frame
 check(game.state==Main.State.RESULTS,"Results screen opens")
 await click("返回俱乐部");check(game.state==Main.State.MENU,"Results return button works")
 var test_button=game.frontend.action("Test",func():pass)
 if Clay.active():
  check(test_button.get_theme_stylebox("normal").corner_radius_top_left>=18,"Rounded clay button")
  check(test_button.get_theme_stylebox("normal").border_width_bottom>test_button.get_theme_stylebox("pressed").border_width_bottom,"Pressed state has visible depth change")
  check(Clay.box("touch")==Clay.box("touch"),"Drawing reuses cached style resources")
 else:
  check(test_button.get_theme_stylebox("normal").bg_color==Color("1b304a"),"Original button palette preserved")
  check(test_button.get_theme_stylebox("normal").corner_radius_top_left==8,"Original button shape preserved")
 test_button.free();game.queue_free();await process_frame
 print("UI_THEME checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
