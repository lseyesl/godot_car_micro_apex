extends SceneTree
const H=preload("res://scripts/haptic_feedback.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var h=H.new();var calls:Array=[];h.sink=func(k,d,a):calls.append([k,d,a])
 check(h.enabled,"Default on")
 h.begin_race();check(h.go(0) and not h.go(1),"One GO per race")
 h.suspend();h.active=true;check(not h.go(500),"Resume cannot repeat GO")
 h.begin_race();h.enabled=false;check(not h.go(0) and not h.collision(20,0,true,500),"Off gates all pulses")
 h.enabled=true;h.begin_race();check(not h.collision(2,0,true,0),"Minimum closing speed")
 h.collision(0,0,false,100);check(h.collision(6,0,true,400),"Vehicle impact")
 check(calls[-1]==["vehicle",65,.65],"Vehicle medium parameters")
 check(not h.collision(20,0,true,800),"Sustained contact suppressed beyond cooldown")
 h.collision(0,0,false,900);check(h.collision(0,12,true,1100),"Road impact after release")
 check(calls[-1]==["road",65,.65],"Road strong parameters")
 h.collision(0,0,false,1150);check(not h.collision(20,0,true,1200),"Quiet and global cooldown enforced")
 h.suspend();check(not h.collision(30,0,true,2000),"Paused")
 for sample in [["vehicle",3.0,40,.40],["vehicle",12.0,90,.90],["road",3.0,25,.25],["road",6.0,45,.45]]:
  h.begin_race();h.collision(sample[1] if sample[0]=="vehicle" else 0, sample[1] if sample[0]=="road" else 0,true,0)
  check(calls[-1]==[sample[0],sample[2],sample[3]],"Impact grade "+str(sample))
 var unsupported=H.new();unsupported.begin_race();check(not unsupported.go(0),"Desktop does not invoke device")
 var file="/tmp/haptics-%d.cfg"%OS.get_process_id();var game=Main.new();game.saved=Store.new(file);root.add_child(game);game.set_process(false);game.set_physics_process(false)
 check(game.haptics.enabled,"Old save missing field defaults on")
 game.toggle_vibration();check(not game.haptics.enabled and Store.new(file).setting("vibration",true)==false,"Disabled setting persisted")
 game.toggle_vibration();check(game.haptics.enabled and Store.new(file).setting("vibration",false)==true,"Enabled persisted")
 game.haptics.sink=func(k,d,a):calls.append([k,d,a])
 game.sound=false;game.launch_free(0,false,true);game.countdown=.001;game._physics_process(.02)
 check(calls[-1][0]=="go","GO independent of mute")
 var count=calls.size();game.pause_game();game.resume_game();game.countdown=.001;game._physics_process(.02);check(calls.size()==count,"Actual resume does not repeat GO")
 game.haptics.begin_race();game.state=game.State.RACING;game.haptic_frame={"vehicle":0.0,"road":0.0,"contact":false}
 game.collect_player_contact("vehicle",6);game.collect_player_contact("vehicle",8);game.collect_player_contact("road",12)
 count=calls.size();game.haptics.collision(game.haptic_frame.vehicle,game.haptic_frame.road,game.haptic_frame.contact,1000)
 check(calls.size()==count+1 and calls[-1]==["road",65,.65],"Multiple contact points aggregate strongest once")
 game._notification(Node.NOTIFICATION_APPLICATION_PAUSED);check(not game.haptics.active,"Background suspends feedback")
 game.show_menu();check(not game.haptics.active,"Menu suspends feedback")
 game.queue_free();for i in range(12):await process_frame
 print("HAPTICS checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
