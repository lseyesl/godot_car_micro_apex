extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var game
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  failures+=1
  if failures<=12:push_error(message)
func _initialize():call_deferred("run")
func send_touch(index:int,action:String,down:bool=true,canceled:bool=false):
 var e=InputEventScreenTouch.new();e.index=index;e.pressed=down;e.canceled=canceled
 e.position=root.get_final_transform()*game.controls.get_global_transform_with_canvas()*game.controls.areas[action].get_center()
 Input.parse_input_event(e);Input.flush_buffered_events()
func drag(index:int,point:Vector2):
 var e=InputEventScreenDrag.new();e.index=index;e.position=root.get_final_transform()*game.controls.get_global_transform_with_canvas()*point
 Input.parse_input_event(e);Input.flush_buffered_events()
func key(code:int,down:bool):
 var e=InputEventKey.new();e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func mouse(point:Vector2,down:bool,device:int=0):
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.device=device
 e.position=root.get_final_transform()*game.controls.get_global_transform_with_canvas()*point;Input.parse_input_event(e);Input.flush_buffered_events()
func grid():
 game.start_race();game.set_physics_process(false)
 await process_frame;game.controls.layout();game.controls.auto_throttle=false
 check(game.state==Main.State.COUNTDOWN and game.controls.enabled and game.controls.pedals_locked,"Countdown shows enabled controls with only pedal commands locked")
func go():
 game.countdown=.001;game._physics_process(1.0/60)
 check(game.state==Main.State.RACING and not game.controls.pedals_locked,"GO unlocks pedals without clearing held input")
func run():
 root.size=Vector2i(1280,720)
 game=Main.new();game.saved=Store.new("/tmp/apex-countdown-%d.cfg"%OS.get_process_id());root.add_child(game);game.practice=false;game.quality=0
 await grid()
 # Visible rectangles remain unchanged; only hit testing gains padding.
 for viewport in [Vector2i(480,270),Vector2i(568,320),Vector2i(640,360),Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(1024,768),Vector2i(960,640),Vector2i(1440,720),Vector2i(2340,1080)]:
  root.size=viewport
  for frame in range(2):await process_frame
  for large in [false,true]:
   game.controls.large=large;game.controls.layout()
   var areas:Dictionary=game.controls.areas;var hit:Dictionary=game.controls.hit_areas
   var bounds=Rect2(Vector2.ZERO,game.controls.size)
   check(not hit.left.intersects(hit.right),"Enlarged steering regions must not overlap")
   for action in ["left","right"]:
    check(bounds.encloses(hit[action]) and hit[action].encloses(areas[action]),"Steering targets stay on screen and contain the full painted button")
    check(hit[action].size.x>areas[action].size.x and hit[action].size.y>areas[action].size.y,"Both width and height of actual steering hit areas grow")
    for other in ["brake","throttle","reset"]:check(not hit[action].intersects(hit[other]),"Expanded arrows cannot steal other controls")
    var p:Vector2=areas[action].get_center()-Vector2(0,areas[action].size.y*.5+8)
    check(not areas[action].has_point(p) and game.controls.action_at(p)==action,"Point outside the artwork must activate its arrow")
    var e=InputEventScreenTouch.new();e.index=0;e.pressed=true;e.position=root.get_final_transform()*game.controls.get_global_transform_with_canvas()*p
    Input.parse_input_event(e);Input.flush_buffered_events()
    check(game.controls.held(action),"Expanded target accepts a dispatched touch at every aspect/size")
    send_touch(0,action,false)
 root.size=Vector2i(1280,720)
 for frame in range(2):await process_frame
 game.controls.large=false;game.controls.layout()
 # All cars, timers and translation stay frozen; only player wheel lock prepares.
 var positions:Array=[]
 for car in game.cars:positions.append(car.position)
 var start:Vector2=game.player.dynamics.position;var heading:float=game.player.dynamics.yaw
 send_touch(0,"left");send_touch(1,"throttle");send_touch(2,"brake")
 for frame in range(30):game._physics_process(1.0/60)
 check(game.controls.held("throttle") and game.controls.held("brake"),"Locked pedals still expose pressed state for visual feedback")
 check(game.controls.driving()=={"steer":-1.0,"throttle":false,"brake":false},"Countdown accepts steering but withholds both pedal commands")
 check(game.player.dynamics.steering==-1 and game.player.dynamics.position==start and game.player.dynamics.yaw==heading,"Countdown prepares wheel lock without moving or rotating body")
 check(game.player.dynamics.velocity==Vector2.ZERO and game.player.dynamics.yaw_rate==0 and not game.player.dynamics.brake_was_down and not game.player.dynamics.reverse and game.time==0,"No drivetrain, angular state or race clock advances early")
 for i in range(game.cars.size()):check(game.cars[i].position==positions[i],"Entire starting grid remains frozen")
 for i in range(game.player.wheels.size()):
  var wheel=game.player.wheels[i]
  check(absf(wheel.rotation.y-game.player.wheel_rotations[i].y-(.35 if "Front" in wheel.name else 0.0))<.000001,"Actual front wheel visual reflects ready steering")
 send_touch(2,"brake",false);go()
 check(game.controls.driving().steer==-1 and game.controls.driving().throttle,"LEFT + GAS held across GO remains live")
 game._physics_process(1.0/60)
 check(game.player.dynamics.speed()>0 and game.player.dynamics.yaw_rate>0,"First live physics step accelerates and turns from prepared left wheel lock")
 # BRAKE remains the existing brake/reverse operation, not a new start mechanic.
 for pedal in ["brake","throttle"]:
  await grid();send_touch(0,"right");send_touch(1,pedal)
  for frame in range(8):game._physics_process(1.0/60)
  check(game.player.dynamics.speed()==0,"Held countdown pedal cannot move the grid")
  go();check(game.controls.driving()[pedal],"Held pedal is immediately available at GO")
  game._physics_process(1.0/60)
  check(game.player.dynamics.speed()<0 if pedal=="brake" else game.player.dynamics.speed()>0,"First live step retains normal brake-to-reverse / GAS behavior")
 # Early release, slide out, cancellation and emulated mouse cannot latch a pedal.
 await grid();send_touch(0,"left");send_touch(1,"throttle");send_touch(0,"left",false);send_touch(1,"throttle",false)
 go();game._physics_process(1.0/60)
 check(game.player.dynamics.speed()==0 and game.controls.driving().steer==0,"Countdown taps released before GO never become queued commands")
 await grid();send_touch(0,"left");send_touch(1,"throttle")
 drag(0,Vector2(640,360));drag(1,Vector2(640,360))
 check(not game.controls.held("left") and not game.controls.held("throttle"),"Dragging outside expanded zones releases active actions")
 drag(0,game.controls.areas.right.get_center())
 check(game.controls.driving().steer==1,"Captured steering finger can move back into the other arrow")
 send_touch(0,"right",true,true);send_touch(1,"throttle",true,true)
 check(game.controls.fingers.is_empty(),"Canceled touches are erased even if pressed is true")
 mouse(game.controls.areas.throttle.get_center(),true,InputEvent.DEVICE_ID_EMULATION)
 check(not game.controls.held("throttle"),"Synthesized mouse event cannot resurrect a canceled finger")
 go();game._physics_process(1.0/60);check(game.player.dynamics.speed()==0,"Canceled/outside pedal stays released across GO")
 await grid();send_touch(0,"left");send_touch(1,"right");send_touch(2,"throttle");send_touch(3,"brake")
 check(game.controls.driving().steer==0 and game.controls.held("throttle") and game.controls.held("brake"),"Multiple independent fingers and opposing arrows are preserved")
 send_touch(0,"left",false);send_touch(2,"throttle",false)
 check(game.controls.driving().steer==1 and not game.controls.held("throttle") and game.controls.held("brake"),"Lifting one finger never releases a different control")
 # Keyboard and physical mouse use the same countdown gating and release rules.
 await grid();key(KEY_A,true);key(KEY_W,true)
 check(game.controls.driving().steer==-1 and game.controls.held("throttle") and not game.controls.driving().throttle,"Keyboard input has the same countdown contract")
 key(KEY_A,false);key(KEY_W,false);mouse(game.controls.areas.throttle.get_center(),true)
 check(game.controls.held("throttle") and not game.controls.driving().throttle,"Physical mouse pedal receives feedback while locked")
 mouse(game.controls.areas.throttle.get_center(),false)
 go();game._physics_process(1.0/60);check(game.player.dynamics.speed()==0,"Released keyboard/mouse inputs do not latch at GO")
 # Automatic throttle is also locked until live driving; BRAKE keeps priority.
 await grid();game.controls.auto_throttle=true
 check(not game.controls.driving().throttle,"Automatic throttle is locked in countdown")
 for frame in range(5):game._physics_process(1.0/60)
 check(game.player.dynamics.speed()==0,"Auto throttle cannot start early")
 go();game._physics_process(1.0/60);check(game.player.dynamics.speed()>0,"Existing auto throttle becomes live at GO")
 # Pause/focus loss clears touches, resume shows a fresh locked countdown.
 send_touch(0,"left");send_touch(1,"throttle");game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.state==Main.State.PAUSED and not game.controls.enabled and game.controls.fingers.is_empty(),"Focus pause clears active touch ownership")
 var position:Vector2=game.player.dynamics.position;var velocity:Vector2=game.player.dynamics.velocity;var yaw:float=game.player.dynamics.yaw;var clock:float=game.time
 game._notification(Main.NOTIFICATION_APPLICATION_FOCUS_IN);game.controls.auto_throttle=false
 check(game.state==Main.State.COUNTDOWN and game.controls.enabled and game.controls.pedals_locked and game.controls.fingers.is_empty(),"Resume restores visible controls with fresh touches and locked pedals")
 send_touch(0,"right");send_touch(1,"brake")
 for frame in range(10):game._physics_process(1.0/60)
 check(game.player.dynamics.position==position and game.player.dynamics.velocity==velocity and game.player.dynamics.yaw==yaw and game.time==clock,"Resume countdown freezes existing velocity/body/race clock while steering remains usable")
 game.pause_game();game.resume_game();check(game.controls.fingers.is_empty(),"Repeated countdown pause/resume clears input")
 await grid();check(game.controls.fingers.is_empty() and not game.controls.held("brake"),"Restart cannot carry old touches into the new countdown")
 send_touch(1,"throttle");game.show_results()
 check(not game.controls.enabled and game.controls.fingers.is_empty(),"Results disable and clear countdown controls")
 game.queue_free();await process_frame
 print("COUNTDOWN_CONTROLS checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
