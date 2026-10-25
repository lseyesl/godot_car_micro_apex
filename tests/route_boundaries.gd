extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const View=preload("res://scripts/track_view.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for index in range(6,10):
  for reverse in [false,true]:
   var path=Track.new(index,reverse);var view=View.new();root.add_child(view);view.build(path,0);await physics_frame
   for gate in range(path.GATE_COUNT):
    var at:Dictionary=path.gate(gate);var n:=Vector2(-at.tangent.y,at.tangent.x)
    for side in [-1,1]:
     var from:Vector3=Track.world(at.point,.4);var to:Vector3=Track.world(at.point+n*side*10,.4)
     var hit:Dictionary=view.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
     check(not hit.is_empty() and hit.collider.is_in_group("track_boundary"),"Physical curb must exist on both sides at every gate")
     if not hit.is_empty():check(from.distance_to(hit.position)>6.8 and from.distance_to(hit.position)<8.1,"Road width/curb clearance stable in both directions")
   view.queue_free();await process_frame
 print("ROUTE_BOUNDARIES checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
