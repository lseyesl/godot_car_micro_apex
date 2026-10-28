extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Layout=preload("res://scripts/ui_layout.gd")
var game
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  failures+=1
  if failures<=12:push_error(message)
func _initialize():call_deferred("run")
func touch(index:int,p:Vector2,pressed:bool):
 var e=InputEventScreenTouch.new();e.index=index;e.position=root.get_final_transform()*p;e.pressed=pressed;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(index:int,p:Vector2,delta:Vector2):
 var e=InputEventScreenDrag.new();e.index=index;e.position=root.get_final_transform()*p;e.relative=root.get_final_transform().basis_xform(delta);e.velocity=e.relative*60;Input.parse_input_event(e);Input.flush_buffered_events()
func swipe(p:Vector2,delta:Vector2,multi:bool=false):
 touch(0,p,true)
 if multi:touch(1,Vector2(10,10),true)
 for i in range(12):
  motion(0,p+delta*(i+1)/12,delta/12);await process_frame
 touch(0,p+delta,false)
 if multi:touch(1,Vector2(10,10),false)
 for i in range(3):await process_frame
func settle():
 for frame in range(4):await process_frame
func first_scroll():return game.frontend.find_children("*","ScrollContainer",true,false)[0]
func tap(p:Vector2):
 touch(0,p,true);touch(0,p,false);await process_frame
func run():
 # Headless base DisplayServer reports touch capability through this test-only
 # switch. Send real ScreenTouch/ScreenDrag; use the engine's native mouse bridge.
 Input.emulate_touch_from_mouse=true
 root.size=Vector2i(1280,720)
 game=Main.new();game.saved=Store.new("/tmp/apex-mobile-ui-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_physics_process(false);game.quality=0
 var canvas=Vector2(1600,720)
 check(Layout.safe_content_rect(Rect2i(0,0,2400,1080),Rect2i(60,0,2340,1008),canvas)==Rect2(40,0,1560,672),"Display safe area maps into expanded canvas")
 check(Layout.safe_content_rect(Rect2i(60,24,2340,984),Rect2i(60,24,2340,984),canvas)==Rect2(Vector2.ZERO,canvas),"Already-inset window must not apply system bars twice")
 check(Layout.safe_content_rect(Rect2i(0,0,2400,1080),Rect2i(),canvas)==Rect2(Vector2.ZERO,canvas),"Unavailable safe area must not collapse UI")
 check(Layout.safe_content_rect(Rect2i(0,0,2400,1080),Rect2i(-20,-20,2500,1200),canvas)==Rect2(Vector2.ZERO,canvas),"Safe rect is clipped to this window")
 for pixels in [Vector2i(2048,922),Vector2i(2400,1080),Vector2i(2560,1080),Vector2i(960,432),Vector2i(1280,720),Vector2i(1024,768)]:
  root.size=pixels;await settle()
  var viewport:=root.get_visible_rect().size;var transform:=root.get_final_transform()
  check(transform.origin.length()<.01,"Expanded canvas must have no letterbox offset")
  check((transform*viewport).distance_to(Vector2(pixels))<.1,"Expanded canvas fills the actual window")
  for inset in [false,true]:
   var safe:=Rect2i(Vector2i.ZERO,pixels)
   if inset:safe=Rect2i(48,16,pixels.x-48,pixels.y-104)
   game.fit_ui_to_safe_area(Rect2i(Vector2i.ZERO,pixels),safe);await settle()
   check(Rect2(Vector2.ZERO,viewport).grow(.01).encloses(game.ui.get_global_rect()),"Interactive UI remains inside the viewport: pixels=%s viewport=%s rect=%s"%[pixels,viewport,game.ui.get_global_rect()])
   check(game.menu_backdrop.get_global_rect().size.distance_to(viewport)<.1,"Menu background remains full bleed outside safe UI")
   for page in ["home","career","garage","freeplay","settings","credits"]:
    game.dismiss_overlay();game.show_menu(page);await settle()
    var scroll=first_scroll();var range=scroll.get_v_scroll_bar();var extent:float=maxf(0,range.max_value-range.page)
    check(range.get_minimum_size().x>=24,"Scrollbar reserves a real 24-unit touch width")
    var actions={"pressed":0}
    for button in game.frontend.content.find_children("*","Button",true,false):button.pressed.connect(func():actions.pressed+=1)
    var panels=game.frontend.content.find_children("*","PanelContainer",true,false)
    var start:Vector2=scroll.get_global_rect().get_center()
    if not panels.is_empty():start=panels[0].get_global_rect().intersection(scroll.get_global_rect()).get_center()
    for repeat in range(3):await swipe(start,Vector2(0,-minf(220,scroll.size.y*.55)),repeat==0)
    check(actions.pressed==0 and game.state==Main.State.MENU and game.frontend.page==page,"Scrolling cards/buttons cannot activate navigation or purchases")
    if game.state!=Main.State.MENU or game.frontend.page!=page:continue
    check(absf(scroll.scroll_vertical-extent)<=2,"Touch swipe must reach bottom on %s %s inset=%s extent=%f value=%d"%[page,pixels,inset,extent,scroll.scroll_vertical])
    if extent>1:
     scroll.scroll_vertical=0;await settle()
     var rect:Rect2=range.get_global_rect();check(rect.size.x>=24,"Actual scrollbar geometry must match its enlarged hit width")
     await swipe(rect.position+Vector2(rect.size.x*.5,20),Vector2(0,rect.size.y*.8))
     check(scroll.scroll_vertical>=extent*.8,"Dispatched touch must drag scrollbar to its bottom range")
    var last:Button
    for button in game.frontend.content.find_children("*","Button",true,false):
     if not button.disabled:last=button
    check(last!=null,"Page exposes a usable content action")
    if last!=null:
     var rect:Rect2=last.get_global_rect();var clip:Rect2=scroll.get_global_rect()
     check(clip.grow(2).encloses(rect),"Bottom action must be fully visible after scrolling: "+page)
     await tap(rect.get_center());check(actions.pressed==1,"Bottom action must accept one real touch tap: "+page)
    if game.state!=Main.State.MENU:game.show_menu()
    game.dismiss_overlay()
 # Expanded catalog: real touch selects the last page and reaches its bottom action.
 root.size=Vector2i(960,432);await settle();game.fit_ui_to_safe_area(Rect2i(0,0,960,432),Rect2i(32,8,928,384));game.show_menu("freeplay");await settle()
 var last_page:Button
 for button in game.frontend.find_children("*","Button",true,false):
  if button.text=="多样路线 10–10":last_page=button
 check(last_page!=null,"Expanded route catalog exposes the last page")
 if last_page!=null:
  await tap(last_page.get_global_rect().get_center());await settle()
  check(game.frontend.circuit_page==3,"Touch navigation opens the last route group")
  var last_scroll=first_scroll()
  for repeat in range(4):await swipe(last_scroll.get_global_rect().get_center(),Vector2(0,-200))
  var practice:Button
  for button in game.frontend.find_children("*","Button",true,false):
   if button.text=="自由练习":practice=button
  check(practice!=null and last_scroll.get_global_rect().grow(2).encloses(practice.get_global_rect()),"Tenth route practice action is fully reachable")
  if practice!=null:
   await tap(practice.get_global_rect().get_center())
   check(game.path.index==9 and game.practice,"Real touch launches the selected tenth route")
  game.show_menu("home");await settle()
 # Horizontal slider ownership must survive the scroll propagation fix.
 root.size=Vector2i(1280,720);await settle();game.fit_ui_to_safe_area(Rect2i(0,0,1280,720),Rect2i(0,0,1280,720));game.show_menu("settings");await settle()
 var vibration=game.frontend.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("震动："))[0]
 var sound_before:bool=game.sound
 await tap(vibration.get_global_rect().get_center());await settle()
 check(not game.haptics.enabled and not bool(game.saved.setting("vibration",true)) and game.sound==sound_before,"Real vibration button tap persists off independently of sound")
 vibration=game.frontend.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("震动："))[0]
 await tap(vibration.get_global_rect().get_center());await settle()
 check(game.haptics.enabled and bool(game.saved.setting("vibration",false)),"Real vibration button tap restores on")
 var slider=game.frontend.find_children("*","HSlider",true,false)[0];var before:float=slider.value;var scroll=first_scroll()
 await swipe(slider.get_global_rect().get_center(),Vector2(-80,0))
 check(absf(slider.value-before)>.05 and scroll.scroll_vertical==0,"Horizontal slider edits value without vertically scrolling")
 # Vertical swipe from a slider must scroll, preserving the pre-gesture setting.
 game.fit_ui_to_safe_area(Rect2i(0,0,1280,720),Rect2i(40,40,1240,480));game.show_menu("settings");await settle()
 slider=game.frontend.find_children("*","HSlider",true,false)[0];before=slider.value;scroll=first_scroll()
 await swipe(slider.get_global_rect().get_center(),Vector2(0,-180))
 check(scroll.scroll_vertical>0 and absf(slider.value-before)<.001,"Vertical slider swipe scrolls without changing its setting")
 # Real nested license dialog: outer scroll keeps the Close button reachable.
 game.fit_ui_to_safe_area(Rect2i(0,0,1280,720),Rect2i(40,60,1200,460));game.frontend.show_licenses();await settle()
 var dialogs=game.overlay.find_children("*","ScrollContainer",true,false)
 check(dialogs.size()==2,"License body and bounded dialog have separate scroll regions")
 if dialogs.size()==2:
  var outer=dialogs[0];var inner=dialogs[1];var bar=inner.get_v_scroll_bar();var extent:float=bar.max_value-bar.page
  await swipe(inner.get_global_rect().get_center(),Vector2(0,-150))
  check(inner.scroll_vertical>0 and extent>0,"License text accepts native touch scrolling")
  var rect:Rect2=outer.get_v_scroll_bar().get_global_rect()
  await swipe(rect.position+Vector2(rect.size.x*.5,20),Vector2(0,rect.size.y*.8))
  var close:Button
  for b in game.overlay.find_children("*","Button",true,false):
   if b.text=="关闭":close=b
  check(close!=null and outer.get_global_rect().grow(2).encloses(close.get_global_rect()),"Close button remains reachable in a short safe area")
  if close!=null:await tap(close.get_global_rect().get_center())
  check(not is_instance_valid(game.overlay),"Actual dialog Close tap works")
 # Insets translate input with the UI, never by a screen-space steering sign.
 game.fit_ui_to_safe_area(Rect2i(0,0,1280,720),Rect2i(48,16,1232,616));game.practice=true;game.start_race();game.set_physics_process(false);await settle();game.controls.layout()
 check(not game.menu_backdrop.visible,"Full-bleed menu paint is hidden during races")
 touch(0,game.controls.get_global_transform_with_canvas()*game.controls.areas.left.get_center(),true)
 touch(1,game.controls.get_global_transform_with_canvas()*game.controls.areas.throttle.get_center(),true)
 check(game.controls.driving().steer==-1 and game.controls.held("throttle") and not game.controls.driving().throttle,"Inset countdown touch coordinates preserve two-finger steering/pedal gating")
 game.countdown=.001;game._physics_process(1.0/60);game._physics_process(1.0/60)
 check(game.player.dynamics.speed()>0 and game.controls.driving().steer==-1,"Inset GO preserves held GAS + LEFT")
 touch(0,game.controls.get_global_transform_with_canvas()*game.controls.areas.left.get_center(),false);touch(1,game.controls.get_global_transform_with_canvas()*game.controls.areas.throttle.get_center(),false)
 check(game.controls.driving().steer==0 and not game.controls.driving().throttle,"Inset multi-touch release leaves no driving input")
 game.queue_free();await process_frame
 print("MOBILE_UI_LAYOUT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
