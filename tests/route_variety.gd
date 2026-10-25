extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Driver=preload("res://scripts/ai_driver.gd")
const Progress=preload("res://scripts/race_progress.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for track in range(6,Catalog.TRACKS.size()):
  for reverse in [false,true]:
   var path=Track.new(track,reverse);var min_radius:=INF;var clearance:=INF
   for s in range(0,int(path.length),4):
    var a:Vector2=path.sample(s-2).point;var b:Vector2=path.sample(s).point;var c:Vector2=path.sample(s+2).point
    var cross:=absf((b-a).cross(c-a))
    if cross>.00001:min_radius=minf(min_radius,a.distance_to(b)*b.distance_to(c)*a.distance_to(c)/(2*cross))
   for i in range(0,path.points.size(),4):
    for j in range(i+4,path.points.size(),4):
     if absf(wrapf(path.distances[i]-path.distances[j],-path.length*.5,path.length*.5))<35:continue
     clearance=minf(clearance,path.points[i].distance_to(path.points[j]))
   check(clearance>18,"Nonlocal road/curb ribbons need clearance: track %d %.2f"%[track,clearance])
   check(min_radius>12.2,"Centerline radius must leave room for widest turning car: track %d %.2f"%[track,min_radius])
   print("ROUTE_GEOMETRY track=%d reverse=%s length=%.1f min_radius=%.2f clearance=%.2f"%[track,reverse,path.length,min_radius,clearance])
   for car_index in range(Catalog.CARS.size()):
    var car=Dynamics.new(Catalog.CARS[car_index]);var driver=Driver.new();driver.difficulty=1
    var start:Dictionary=path.sample(0);car.reset_at(start.point,Track.heading(start.tangent));var progress=Progress.new();var max_off:=0.0;var gates:=0
    for tick in range(18000):
     var before:Vector2=car.position;var controls:Dictionary=driver.controls(car,path,tick/60.0);var near:Dictionary=path.nearest(car.position,car.route_s)
     car.step(1.0/60,controls.steer,controls.throttle,controls.brake,near.surface)
     near=path.nearest(car.position,car.route_s);car.route_s=near.s;max_off=maxf(max_off,near.distance)
     var event:Dictionary=progress.advance(before,car.position,path,tick/60.0,1,0)
     if not event.is_empty():gates+=1
     if progress.laps==1:break
    check(progress.laps==1 and gates==path.GATE_COUNT,"AI must pass all 24 gates in order: track=%d reverse=%s car=%d gate=%d"%[track,reverse,car_index,progress.next_gate])
    check(max_off<Track.WIDTH*.5-1,"AI must fit inside curbs without shortcuts: track=%d reverse=%s car=%d maxoff=%.2f"%[track,reverse,car_index,max_off])
    print("ROUTE_AI track=%d reverse=%s car=%d lap=%.2f max_off=%.2f gates=%d"%[track,reverse,car_index,progress.finish_time,max_off,gates])
   var skip=Progress.new();var last:Dictionary=path.gate(0)
   skip.advance(last.point-last.tangent,last.point+last.tangent,path,10,1,0)
   check(skip.laps==0 and skip.next_gate==1,"Finish cannot skip checkpoints")
 print("ROUTE_VARIETY checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
