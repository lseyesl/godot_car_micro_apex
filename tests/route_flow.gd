extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 Engine.physics_ticks_per_second=600;Engine.max_physics_steps_per_frame=64;Engine.time_scale=10
 var game=Main.new();game.saved=Store.new("/tmp/apex-route-flow-%d.cfg"%OS.get_process_id());root.add_child(game);game.quality=0;game.automated_player=true
 for track in range(6,10):
  for reverse in [false,true]:
   game.launch_free(track,reverse,false)
   game.player.progress.last_gate=3
   game.player.reset_to_gate(game.path)
   var pose:Dictionary=game.path.sample(game.path.gate(3).s+2.5)
   check(game.player.dynamics.position.distance_to(pose.point)<.01 and game.player.dynamics.velocity==Vector2.ZERO and not game.player.progress.valid_lap,"Reset returns to ordered checkpoint and invalidates lap")
   game.launch_free(track,reverse,false);game.target_laps=1;game.countdown=.01
   var ticks:=0
   while game.state!=Main.State.RESULTS and ticks<16000:
    await physics_frame;ticks+=1
   var passed:bool=game.state==Main.State.RESULTS and game.player.progress.laps==1 and game.player.progress.next_gate==1
   check(passed,"Actual six-car race must complete: track=%d reverse=%s gate=%d"%[track,reverse,game.player.progress.next_gate])
   print("NEW_ROUTE_RACE track=%d reverse=%s complete=%s lap=%.2f ticks=%d"%[track,reverse,passed,game.player.progress.finish_time,ticks])
   game.show_menu()
 game.queue_free();await process_frame
 print("ROUTE_FLOW races=8 failures=%d"%failures);quit(1 if failures else 0)
