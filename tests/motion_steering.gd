extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Observe=preload("res://tests/steering_observation.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  failures+=1
  if failures<=8:push_error(message)
func _initialize():call_deferred("run")
func run():
 for spec in Catalog.CARS:
  for heading in [0.0,PI/4,PI/2,PI, -PI,PI-.0001,-PI+.0001,3.55]:
   for road in ["asphalt","dirt","grass"]:
    for steer in [-1.0,1.0]:
     for travel in [-8.0,8.0]:
      for pedal in [[false,false],[true,false],[false,true],[true,true]]:
       var car=Dynamics.new(spec);car.reset_at(Vector2.ZERO,heading)
       var f:Vector2=car.forward();var right=Vector2(-f.y,f.x);car.velocity=f*travel
       for frame in range(12):car.step(1.0/60,steer,pedal[0],pedal[1],road)
       check(car.forward().dot(right)*steer*signf(travel)>.001,"Body turn must follow actual forward/reverse travel, independently of heading/pedal: %s yaw=%f speed=%f steer=%f"%[spec.id,heading,travel,steer])
 var noise=Dynamics.new(Catalog.CARS[3]);noise.reset_at(Vector2.ZERO,0)
 for frame in range(240):
  noise.velocity=noise.forward()*(.05 if frame%2==0 else -.05)
  noise.step(1.0/60,1,false,false,"asphalt")
 check(absf(noise.yaw)<.000001,"Tiny signed speed noise must not generate steering torque")
 for heading in [PI,-PI,PI-.00000001,-PI+.00000001]:
  for steer in [-1.0,1.0]:
   var tiny=Dynamics.new(Catalog.CARS[0]);tiny.reset_at(Vector2.ZERO,heading);tiny.velocity=tiny.forward()*.2
   var before=Observe.before(tiny);tiny.step(1.0/60,steer,false,false,"asphalt")
   check(absf(wrapf(tiny.yaw-float(before.yaw)-tiny.yaw_rate/60,-PI,PI))<.00000001,"PI seam must preserve tiny angular increments without endpoint snapping")
 var traces:Array=[]
 for spec in Catalog.CARS:
  var car=Dynamics.new(spec);car.reset_at(Vector2.ZERO,PI-.0001);car.velocity=car.forward()*3
  var states:Array=[];var all_valid:=true;var positive:=false;var negative:=false;var neutral:=false;var lag_seen:=false
  for frame in range(220):
   var command={"steer":1.0,"throttle":frame>=110,"brake":frame<50 or (frame>=51 and frame<110)}
   var before=Observe.before(car);car.step(1.0/60,command.steer,command.throttle,command.brake,"asphalt")
   all_valid=all_valid and Observe.valid(car,before,command.steer,1.0/60)
   positive=positive or car.turn_speed>.1;negative=negative or car.turn_speed<-.1;neutral=neutral or car.turn_speed==0
   lag_seen=lag_seen or car.target_yaw_rate*car.yaw_rate<0
   states.append(Observe.row(car,before,command,frame))
  check(all_valid and positive and negative and neutral,"Drive/brake/reverse/GAS transition must honor signed speed and neutral zone: "+str(spec.id))
  check(lag_seen,"Body yaw inertia may lag a physically reversed target without being forcibly clamped")
  traces.append({"car":spec.id,"samples":states})
  var creep=Dynamics.new(spec)
  for frame in range(90):
   creep.velocity=creep.forward()*-.2;creep.step(1.0/60,1,false,false,"asphalt")
  check(creep.yaw>.01 and not creep.reverse,"Sustained real backward creep turns correctly without reverse-drive flag")
 var quiet=Dynamics.new(Catalog.CARS[3]);var noisy=Dynamics.new(Catalog.CARS[3]);quiet.yaw_rate=.7;noisy.yaw_rate=.7
 var same_decay:=true
 for frame in range(240):
  quiet.velocity=Vector2.ZERO;noisy.velocity=noisy.forward()*(.05 if frame%2==0 else -.05)
  quiet.step(1.0/60,1,false,false,"asphalt");noisy.step(1.0/60,1,false,false,"asphalt")
  same_decay=same_decay and absf(quiet.yaw_rate-noisy.yaw_rate)<.0000001 and noisy.target_yaw_rate==0
 check(same_decay,"Zero-speed jitter adds no new yaw and does not zero existing angular inertia")
 DirAccess.make_dir_recursive_absolute("res://build/validation/signed-steering")
 var file=FileAccess.open("res://build/validation/signed-steering/transitions.json",FileAccess.WRITE);file.store_string(JSON.stringify(traces,"  "));file.close()
 print("MOTION_STEERING checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
