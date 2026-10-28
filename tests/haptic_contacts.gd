extends SceneTree
const Car=preload("res://scripts/race_car.gd")
const Track=preload("res://scripts/track_path.gd")
const Catalog=preload("res://scripts/catalog.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var path=Track.new(6);var events:Array=[]
 var a=Car.new();root.add_child(a);a.configure(Catalog.CARS[3],Vector2.ZERO,0,true)
 var b=Car.new();root.add_child(b);b.configure(Catalog.CARS[3],Vector2(0,-6),0,false)
 for car in [a,b]:car.player_contact.connect(func(k,s):events.append([k,s]))
 a.dynamics.velocity=Vector2(0,-15)
 for i in range(35):await physics_frame;a.tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
 check(events.any(func(e):return e[0]=="vehicle" and e[1]>2.5),"Actual car collision emits relative vehicle impact")
 a.player=false;events.clear();a.dynamics.reset_at(Vector2.ZERO,0);a.position=Track.world(Vector2.ZERO,.06);a.dynamics.velocity=Vector2(0,-15)
 for i in range(35):await physics_frame;a.tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
 check(events.is_empty(),"AI-only actual car contacts do not emit player feedback")
 a.player=true;a.dynamics.reset_at(Vector2(0,-6),0);a.position=Track.world(Vector2(0,-6),.06);a.velocity=Vector3.ZERO
 b.dynamics.reset_at(Vector2.ZERO,0);b.position=Track.world(Vector2.ZERO,.06);b.dynamics.velocity=Vector2(0,-15);events.clear()
 for i in range(35):await physics_frame;b.tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
 check(events.any(func(e):return e[0]=="vehicle" and e[1]>2.5),"AI striking stationary player emits feedback")
 b.queue_free();await process_frame
 var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(20,2,1);shape.shape=box;wall.add_child(shape);root.add_child(wall);wall.position=Vector3(0,0,-6)
 a.player=true;a.dynamics.reset_at(Vector2.ZERO,0);a.position=Track.world(Vector2.ZERO,.06);a.dynamics.velocity=Vector2(0,-15);events.clear()
 for i in range(35):await physics_frame;a.tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
 check(events.any(func(e):return e[0]=="road" and e[1]>2.5),"Actual static wall distinguishes road impact")
 wall.position=Vector3(0,0,0);box.size=Vector3(50,1,50);a.dynamics.reset_at(Vector2.ZERO,0);a.position=Vector3(0,.06,0);a.dynamics.velocity=Vector2(0,-5);events.clear()
 var floor_contacts:=0
 for i in range(10):
  await physics_frame;a.tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
  floor_contacts+=a.get_slide_collision_count()
 check(floor_contacts>0,"Fixture actually contacts floor")
 check(events.is_empty(),"Flat support/ordinary driving is not an impact")
 a.queue_free();wall.queue_free();for i in range(4):await process_frame
 print("HAPTIC_CONTACTS checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
