extends SceneTree
# Real shipped track/controls: audit motion-based target and untouched yaw integration.
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Track=preload("res://scripts/track_path.gd")
const Observe=preload("res://tests/steering_observation.gd")
var game
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  failures+=1
  if failures<=8:push_error(message)
func _initialize():call_deferred("run")
func touch(index:int,action:String,down:bool=true):
 var event=InputEventScreenTouch.new();event.index=index;event.pressed=down
 event.position=game.controls.get_global_transform_with_canvas()*game.controls.areas[action].get_center()
 Input.parse_input_event(event);Input.flush_buffered_events()
func release():
 touch(0,"left",false);touch(1,"throttle",false);game.controls.clear()
func run():
 Engine.physics_ticks_per_second=600;Engine.max_physics_steps_per_frame=64;Engine.time_scale=10
 root.size=Vector2i(1280,720)
 game=Main.new();game.saved=Store.new("/tmp/apex-signed-wall-%d.cfg"%OS.get_process_id());root.add_child(game)
 game.practice=true;game.quality=0;game.selected_track=0;game.selected_car=3;game.start_race()
 game.state=Main.State.RACING;game.controls.enabled=true;game.controls.auto_throttle=false;game.set_physics_process(false)
 await process_frame;game.controls.layout();await physics_frame
 var base:Dictionary=game.path.nearest(Vector2(-52,-15));var contact_cases:=0;var stops:=0
 for offset in [-6.0,0.0,6.0]:
  var at:Dictionary=game.path.sample(base.s+offset);var normal:=Vector2(-at.tangent.y,at.tangent.x)
  for lateral in [-4.0,-4.9,-5.8,-6.5]:
   for heading in [0.0,PI/2,PI,-PI,PI-.0001,-PI+.0001,3.35,3.55,3.75]:
    for speed in [0.0,3.0,-3.0]:
     for direction in [-1,1]:
      for pedal in ["throttle","brake"]:
       release();var point:Vector2=at.point+normal*lateral;var near:Dictionary=game.path.nearest(point)
       var car=game.player;car.dynamics.reset_at(point,heading);car.dynamics.route_s=near.s
       car.dynamics.velocity=car.dynamics.forward()*speed;car.position=Track.world(point,near.height+.06);car.rotation.y=heading;car.velocity=Track.world(car.dynamics.velocity);car.reset_physics_interpolation()
       await physics_frame;touch(0,"left" if direction<0 else "right");touch(1,pedal)
       var valid:=true;var contacts:=0
       for frame in range(30):
        var command:Dictionary=game.controls.driving();var before=Observe.before(car.dynamics)
        await physics_frame;car.tick(1.0/60,command,game.path)
        valid=valid and Observe.valid(car.dynamics,before,command.steer,1.0/60)
        contacts+=car.get_slide_collision_count()
        if car.get_slide_collision_count()>0 and car.dynamics.velocity.length()<.01:stops+=1
       check(valid,"Real curb cannot override motion-based steering or reset angular inertia")
       if contacts>0:contact_cases+=1
 check(contact_cases>400,"Screenshot neighbourhood must exercise many physical curb contacts")
 check(stops>20,"Translation must still hard-stop at real curbs")
 # Retain the prior crawl escape and glancing-scrape checks: these are still
 # forward-motion scenarios and must not regress when reverse semantics change.
 for direction in [-1,1]:
  release();var point:=Vector2(-52,-15);var heading:=3.55+PI
  var car=game.player;car.dynamics.reset_at(point,heading)
  var near:Dictionary=game.path.nearest(point);car.dynamics.route_s=near.s
  car.position=Track.world(point,near.height+.06);car.rotation.y=heading;car.velocity=Vector3.ZERO;car.reset_physics_interpolation()
  await physics_frame;var forward:Vector2=car.dynamics.forward()
  touch(0,"left" if direction<0 else "right");touch(1,"throttle")
  var contacts:=0
  for frame in range(120):
   await physics_frame;car.tick(1.0/60,game.controls.driving(),game.path);contacts+=car.get_slide_collision_count()
  check(contacts>20 and forward.angle_to(car.dynamics.forward())*direction>.02,"Crawl contact must retain enough lock to escape a head-on obstruction")
 var at:Dictionary=game.path.sample(base.s);var normal:=Vector2(-at.tangent.y,at.tangent.x)
 for side in [-1,1]:
  release();var direction:int=-side;var point:Vector2=at.point+normal*side*5.8
  var car=game.player;car.dynamics.reset_at(point,Track.heading(at.tangent));car.dynamics.route_s=base.s
  car.dynamics.velocity=at.tangent*20+normal*side*7;car.dynamics.steering=direction;car.dynamics.yaw_rate=-direction*1.8
  car.position=Track.world(point,at.height+.06);car.rotation.y=car.dynamics.yaw;car.velocity=Track.world(car.dynamics.velocity);car.reset_physics_interpolation()
  await physics_frame;touch(0,"left" if direction<0 else "right")
  var scraped:=false
  for frame in range(6):
   await physics_frame;car.tick(1.0/60,game.controls.driving(),game.path)
   if car.get_slide_collision_count()>0:scraped=true;break
  var forward:Vector2=car.dynamics.forward()
  await physics_frame;car.tick(1.0/60,game.controls.driving(),game.path)
  check(scraped and car.dynamics.velocity.length()>10 and forward.angle_to(car.dynamics.forward())*direction>.005,"Glancing contact must retain established forward turn")
 release();game.queue_free()
 for frame in range(4):await process_frame
 print("STEERING_WALL checks=%d failures=%d contact_cases=%d hard_stops=%d"%[checks,failures,contact_cases,stops]);quit(1 if failures else 0)
