extends SceneTree
const Car=preload("res://scripts/race_car.gd")
const Catalog=preload("res://scripts/catalog.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Observe=preload("res://tests/steering_observation.gd")
const Controls=preload("res://scripts/touch_controls.gd")
class FlatPath extends RefCounted:
 var road:String="asphalt"
 func nearest(_p:Vector2,_s:float=-1) -> Dictionary:return {"s":0.0,"height":0.0,"surface":road,"tangent":Vector2(0,-1)}
 func slope_at(_s:float) -> float:return 0.0
 func gate(_index:int) -> Dictionary:return {"s":0.0}
 func sample(_s:float) -> Dictionary:return {"s":0.0,"point":Vector2.ZERO,"height":0.0,"tangent":Vector2(0,-1)}
const Style=preload("res://scripts/model_style.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  failures+=1
  if failures<=8:push_error(message)
var path=FlatPath.new()
var input
var car
var wall
func _initialize():call_deferred("run")
func touch(action:String,index:int,down:bool=true):
 var event=InputEventScreenTouch.new();event.index=index;event.pressed=down;event.position=input.areas[action].get_center();Input.parse_input_event(event);Input.flush_buffered_events()
func push_cases() -> Array:
 var traces:Array=[]
 path.road="asphalt"
 for spec in Catalog.CARS:
  for heading in [PI,-PI+.0001]:
   for old in [-1,1]:
    for count in [1,2]:
     input.clear();car=Car.new();root.add_child(car);car.configure(spec,Vector2.ZERO,heading,true)
     car.dynamics.velocity=car.dynamics.forward()*.4
     touch("left" if old<0 else "right",0)
     for frame in range(8):
      await physics_frame;car.tick(1.0/60,input.driving(),path)
     var actors:Array=[]
     var f:Vector2=car.dynamics.forward()
     for i in range(count):
      var actor=Car.new();root.add_child(actor)
      var p:Vector2=car.dynamics.position+f*(5.5 if i==0 else -7.0)
      actor.configure(Catalog.CARS[0],p,car.dynamics.yaw+(PI if i==0 else 0),false)
      actor.dynamics.velocity=actor.dynamics.forward()*16
      actors.append(actor)
     var first_hit:=false;var crossed_negative:=false;var positive_after:=false;var valid_motion:=true;var samples:Array=[];var hit_actors:Dictionary={}
     for frame in range(150):
      await physics_frame
      if frame==35:
       for actor in actors:actor.queue_free()
       await process_frame
      var pre_push:float=car.dynamics.speed()
      var normals:Array=[]
      for i in range(actors.size()):
       if not is_instance_valid(actors[i]):continue
       actors[i].tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
       for j in range(actors[i].get_slide_collision_count()):
        var hit=actors[i].get_slide_collision(j)
        if hit.get_collider()==car:hit_actors[i]=true;normals.append(str(hit.get_normal()))
      if not first_hit and not hit_actors.is_empty():
       first_hit=true;touch("left" if old<0 else "right",0,false);touch("right" if old<0 else "left",0)
      crossed_negative=crossed_negative or (pre_push>=0 and car.dynamics.speed()<-.1)
      if first_hit and frame>=35:touch("throttle",1)
      var before:Vector2=car.dynamics.forward()
      var incoming_speed:float=car.dynamics.speed()
      var state=Observe.before(car.dynamics)
      car.tick(1.0/60,input.driving(),path)
      valid_motion=valid_motion and Observe.valid(car.dynamics,state,input.driving().steer,1.0/60)
      if first_hit:
       var contrary:float=before.angle_to(car.dynamics.forward())*old
       if frame>35 and car.dynamics.speed()>.2:positive_after=true
       var sample=Observe.row(car.dynamics,state,input.driving(),frame);sample["collision_normals"]=normals;sample["speed_before_push"]=pre_push;sample["speed_after_push"]=incoming_speed;samples.append(sample)
     check(first_hit and crossed_negative,"Physical car impulse must cross forward speed through zero")
     check(hit_actors.size()==count,"All actual attacking cars must contact the player")
     check(valid_motion,"Pushed player must use signed motion and unmodified angular integration")
     check(positive_after,"Released GAS then GAS must recover forward travel")
     check(not car.dynamics.reverse,"Collision recoil must not toggle brake-to-reverse mode")
     traces.append({"heading":heading,"old_input":old,"cars":count+1,"valid_motion":valid_motion,"samples":samples})
     for actor in actors:
      if is_instance_valid(actor):actor.queue_free()
     car.queue_free();await process_frame
 return traces
func free_driving_cases():
 path.road="asphalt"
 for spec in Catalog.CARS:
  for heading in [0.0,PI]:
   var body=Car.new();root.add_child(body);body.configure(spec,Vector2.ZERO,heading,true)
   var reference=Dynamics.new(spec);reference.reset_at(Vector2.ZERO,heading)
   body.dynamics.velocity=body.dynamics.forward()*25;reference.velocity=body.dynamics.velocity
   var identical:=true;var no_contacts:=true;var retained_drift:=false;var reversed_correctly:=false
   for frame in range(270):
    var steer:float=1.0 if frame<30 or frame>=190 else (-1.0 if frame<60 else 0.0)
    var command={"steer":steer,"throttle":frame<30,"brake":(frame>=90 and frame<180) or frame>=182}
    var before:Vector2=body.dynamics.forward()
    reference.step(1.0/60,command.steer,command.throttle,command.brake,"asphalt")
    await physics_frame;body.tick(1.0/60,command,path)
    identical=identical and absf(wrapf(body.dynamics.yaw-reference.yaw,-PI,PI))<.00001 and absf(body.dynamics.yaw_rate-reference.yaw_rate)<.00001 and body.dynamics.velocity.distance_to(reference.velocity)<.001
    no_contacts=no_contacts and body.get_slide_collision_count()==0
    if frame==30:retained_drift=body.dynamics.yaw_rate<0
    if frame>230:reversed_correctly=reversed_correctly or (body.dynamics.reverse and body.dynamics.speed()<-.5 and before.angle_to(body.dynamics.forward())<0)
   check(no_contacts and identical,"Ordinary free driving/countersteer must match unchanged dynamics: "+str(spec.id))
   check(retained_drift,"Contact-free countersteering keeps existing turn inertia")
   check(reversed_correctly,"Deliberate reverse changes body yaw relative to the same wheel input")
   body.reset_to_gate(path)
   check(body.dynamics.turn_speed==0 and body.dynamics.target_yaw_rate==0,"Reset clears steering-stage telemetry")
   body.queue_free();await process_frame
func run():
 Engine.physics_ticks_per_second=600;Engine.max_physics_steps_per_frame=64;Engine.time_scale=10
 root.size=Vector2i(1280,720);input=Controls.new();root.add_child(input);input.enabled=true;input.layout()
 var results:Array=[]
 for road in ["asphalt","dirt","grass"]:
  path.road=road
  for heading in [0.0,PI/2,PI,-PI,PI-.0001,-PI+.0001,3.55]:
   for angle in [.5,.8,1.05,1.35]:
    for mode in ["coast","regas","held_gas","delayed_regas"]:
     for old in [-1,1]:
      if mode=="delayed_regas" and (road!="asphalt" or angle!=.5):continue
      input.clear();car=Car.new();root.add_child(car);car.configure(Catalog.CARS[3],Vector2.ZERO,heading,true);car.dynamics.velocity=car.dynamics.forward()*25
      touch("left" if old<0 else "right",0);touch("throttle",1)
      for frame in range(28):
       await physics_frame;car.tick(1.0/60,input.driving(),path)
      # Rigidly rotate the entire free fixture so impact poses cover down/PI seams.
      var spin:float=car.dynamics.yaw-heading
      car.dynamics.velocity=car.dynamics.velocity.rotated(spin);car.dynamics.yaw=heading;car.rotation.y=heading;car.reset_physics_interpolation()
      var f:Vector2=car.dynamics.forward();var n:Vector2=f.rotated(angle*old)
      wall=StaticBody3D.new();wall.add_to_group("track_boundary");var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(80,3,.5);shape.shape=box;shape.position.y=1;wall.add_child(shape);wall.position=Vector3(car.dynamics.position.x+n.x*3,0,car.dynamics.position.y+n.y*3);wall.rotation.y=car.dynamics.yaw-angle*old;root.add_child(wall)
      await physics_frame
      if mode!="held_gas":touch("throttle",1,false)
      var hit=false
      for frame in range(24):
       await physics_frame;car.tick(1.0/60,input.driving(),path)
       if car.get_slide_collision_count()>0:hit=true;break
      if hit:
       if mode=="delayed_regas":
        for delay in range(60):
         await physics_frame;car.tick(1.0/60,input.driving(),path)
        touch("throttle",1)
       touch("left" if old<0 else "right",0,false);touch("right" if old<0 else "left",0)
       var valid_motion:=true;var samples:Array=[]
       for frame in range(30):
        if mode=="regas" and frame==12:touch("throttle",1)
        var f0:Vector2=car.dynamics.forward();var v0:float=car.dynamics.speed();var yaw0:float=car.dynamics.yaw
        var state=Observe.before(car.dynamics)
        await physics_frame;car.tick(1.0/60,input.driving(),path)
        valid_motion=valid_motion and Observe.valid(car.dynamics,state,input.driving().steer,1.0/60)
        var contrary:float=f0.angle_to(car.dynamics.forward())*old;
        var normals:Array=[]
        for i in range(car.get_slide_collision_count()):normals.append(str(car.get_slide_collision(i).get_normal()))
        var sample=Observe.row(car.dynamics,state,input.driving(),frame);sample["collision_normals"]=normals;samples.append(sample)
       check(valid_motion,"Contact must not override signed-motion target or angular inertia")
       results.append({"road":road,"heading":heading,"angle":angle,"old_input":old,"mode":mode,"valid_motion":valid_motion,"samples":samples})
      car.queue_free();wall.queue_free();await process_frame
 var pushes:Array=await push_cases()
 await free_driving_cases()
 check(results.filter(func(sample):return sample.mode=="delayed_regas").size()>=14,"Delayed restart must include both directions at every tested orientation")
 check(results.size()>=300,"Sweep must include actual collisions across directions and pedal transitions")
 var worst:Array=[]
 for mode in ["coast","regas","held_gas","delayed_regas"]:
  for sample in results:
   if sample.mode==mode:worst.append(sample);break
 DirAccess.make_dir_recursive_absolute("res://build/validation/collision-steering")
 var file=FileAccess.open("res://build/validation/collision-steering/current-"+Style.selected()+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"wall_cases":worst,"push_cases":pushes},"  "));file.close()
 print("COLLISION_STEERING checks=%d failures=%d contacts=%d"%[checks,failures,results.size()]);input.queue_free();await process_frame;quit(1 if failures else 0)
