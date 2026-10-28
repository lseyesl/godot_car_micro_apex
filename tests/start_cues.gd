extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(2400,1080)
 var g=Main.new();g.saved=Store.new("/tmp/start-cues-%d.cfg"%OS.get_process_id());root.add_child(g);g.quality=0;g.set_process(false);g.set_physics_process(false)
 g.allow_headless_start_audio=true
 var events:Array=[];g.start_cue_presented.connect(func(beat):events.append(beat))
 g.launch_free(0,false,true)
 g.present_start(3);g.present_start(3)
 check(events==[3],"Repeated frames do not replay a beat")
 check(g.center_label.text=="3" and g.countdown_beep==3,"Initial beat and visual agree")
 check(g.start_audio.playing and g.start_audio.stream.resource_path.ends_with("countdown.wav"),"Initial electronic beat plays")
 var before=g.player.dynamics.position
 for beat in [2,1,0]:
  g.countdown=beat+.01;g._physics_process(.02)
  check(g.countdown_beep==beat and g.center_label.text==(str(beat) if beat>0 else "GO!"),"Beat transition synchronized")
  check(g.start_audio.stream.resource_path.ends_with("go.wav" if beat==0 else "countdown.wav"),"GO uses distinct stream")
  check(g.player.dynamics.position==before and g.time==0,"Countdown does not move car or clock")
 check(events==[3,2,1,0],"Exactly one visual/audio event per displayed beat")
 g.pause_game();check(not g.start_audio.playing,"Pause stops start audio")
 g.resume_game();check(g.countdown_beep==3 and g.start_audio.playing,"Resume resets initial beat")
 g.sound=false;g.pause_game();g.resume_game();check(not g.start_audio.playing,"Muted resume remains silent")
 g.sound=true;g.master_volume=0;g.pause_game();g.resume_game();check(not g.start_audio.playing,"Zero volume remains silent")
 g.master_volume=.8;g.start_race();check(g.countdown_beep==3,"Restart begins clean sequence")
 g.show_menu();check(not g.start_audio.playing,"Exit stops start audio")
 for pixels in [Vector2i(960,432),Vector2i(2400,1080),Vector2i(1024,768)]:
  root.size=pixels;g.launch_free(0,false,true)
  for i in range(3):await process_frame
  g.fit_countdown()
  check(g.ui.get_global_rect().encloses(g.countdown_plate.get_global_rect()),"Plate inside safe UI")
  for action in ["left","right","throttle","brake"]:
   var rect:Rect2=g.controls.hit_areas[action];rect.position+=g.controls.global_position
   check(not rect.intersects(g.countdown_plate.get_global_rect()),"Start plate clears touch buttons")
 g.stop_start_cue();g.queue_free()
 for i in range(12):await process_frame
 await create_timer(.1).timeout
 print("START_CUES checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
