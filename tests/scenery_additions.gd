extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const View=preload("res://scripts/track_view.gd")
const Style=preload("res://scripts/model_style.gd")
const Main=preload("res://scripts/main.gd")
const Additions=preload("res://scripts/scenery_additions.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func footprint(node:Node3D,transform:Transform3D=Transform3D.IDENTITY) -> float:
 var radius:=0.0
 transform=transform*node.transform
 if node is MeshInstance3D:
  var bounds:AABB=node.mesh.get_aabb()
  for i in range(8):
   var p:Vector3=transform*bounds.get_endpoint(i)
   radius=maxf(radius,Vector2(p.x,p.z).length())
 for child in node.get_children():
  if child is Node3D:radius=maxf(radius,footprint(child,transform))
 return radius
func _initialize():call_deferred("run")
func run():
 var report:Array=[]
 var ids:Array[String]=[]
 for file in DirAccess.get_files_at("res://assets/models"):
  if file.ends_with(".glb"):ids.append(file.trim_suffix(".glb"))
 ids.sort()
 for style in Style.STYLES:
  var variants:Array[String]=[]
  var folder="res://assets/models" if style=="original" else "res://assets/styles/"+style+"/models"
  for file in DirAccess.get_files_at(folder):
   if file.ends_with(".glb"):variants.append(file.trim_suffix(".glb"))
  variants.sort();check(ids==variants,"All model catalogs must be synchronized: "+style)
 for id in ids:
  if not (id.begins_with("prop_") or id.begins_with("foliage_")):continue
  var node=load(Style.model_path(id)).instantiate()
  check(node.find_children("*","CollisionObject3D",true,false).is_empty(),"Decorations must not add gameplay collisions")
  var budget:float=16.0 if id=="prop_ferris_wheel" else (12.0 if id.begins_with("prop_") else (2.4 if id.begins_with("foliage_shrub") else (2.4 if id=="foliage_leaf_cluster" else .8)))
  check(footprint(node)<=budget,"Model fits its reserved footprint: "+id)
  var triangles:=0
  for mesh in node.find_children("*","MeshInstance3D",true,false):
   for surface in range(mesh.mesh.get_surface_count()):
    triangles+=mesh.mesh.surface_get_array_index_len(surface)/3
    var material=mesh.get_active_material(surface)
    check(material is StandardMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Foliage/landmarks must remain opaque")
  check(triangles<10000,"Each new asset has a bounded triangle budget: "+id)
  print("NEW_ASSET id=%s triangles=%d"%[id,triangles]);node.free()
 for index in range(Catalog.TRACKS.size()):
  var path=Track.new(index);var view=View.new();root.add_child(view);view.build(path,1)
  var district=view.get_child(1)
  var landmarks:Array=district.get_meta("new_landmarks",[])
  var greenery:Array=district.get_meta("new_greenery",[])
  if Style.is_paper():
   check(is_equal_approx(Additions.PAPER_GRASS_YAW,Main.CAMERA_YAW),"Paper cutouts face the actual fixed gameplay camera")
   var prototypes:Array[Mesh]=[]
   for id in ["foliage_grass_green","foliage_grass_dry"]:
    var grass=load(Style.model_path(id)).instantiate()
    prototypes.append(grass.find_children("*","MeshInstance3D",true,false)[0].mesh);grass.free()
   var grass_count:=0
   var yaw:=deg_to_rad(Main.CAMERA_YAW)
   var camera_forward:=Vector3(sin(yaw),0,cos(yaw))
   # Inspect authored transforms before queued batching removes the source meshes.
   # Headless RenderingServerDummy does not return stored MultiMesh transforms.
   for grass in view.decoration.find_children("*","MeshInstance3D",true,false):
    if grass.mesh not in prototypes:continue
    grass_count+=1
    var transform:Transform3D=grass.global_transform
    check(absf(transform.basis.z.normalized().dot(camera_forward))>cos(deg_to_rad(9.0)),"Single paper grass face remains readable at gameplay camera yaw")
    var bounds:AABB=transform*grass.mesh.get_aabb()
    check(absf(bounds.position.y+.08)<.002,"Placed grass feet meet ground, without floating")
   var expected_grass:=0
   for plot in greenery:
    if str(plot.id).begins_with("foliage_grass"):expected_grass+=1
   check(grass_count==expected_grass and grass_count>0,"All grass plots use the single cardboard board")
  check(landmarks.size()==2,"Two landmarks required on every track")
  check(greenery.size()>=24 and greenery.size()<=48,"Bounded visible greenery required on every track")
  if Style.is_paper():
   check(district.get_meta("new_leaf_clusters",0)==0,"Single tree boards must not have volumetric canopy additions")
   var tree_count:=0
   var camera_yaw:=deg_to_rad(Main.CAMERA_YAW)
   for tree in view.decoration.find_children("*","Node3D",true,false):
    if not tree.get_meta("paper_tree_board",false):continue
    tree_count+=1
    var ground:float=tree.get_meta("paper_tree_ground",INF)
    check(ground in [-.08,.48] and absf(tree.global_position.y-ground)<.002,"Scaled paper tree feet meet ground or existing planter top")
    check(absf(tree.global_transform.basis.z.normalized().dot(Vector3(sin(camera_yaw),0,cos(camera_yaw))))>cos(deg_to_rad(9.0)),"Paper tree silhouette faces gameplay camera")
    check(tree.find_children("*","MeshInstance3D",true,false).size()==1,"Placed tree is one board without added 3D leaf clusters")
   check(tree_count>0,"All tracks retain paper tree scenery")
  else:
   check(district.get_meta("new_leaf_clusters",0)>0,"Existing trees need additional canopy clusters")
  for plot in landmarks+greenery:
   check(path.nearest(plot.point).distance>path.WIDTH*.5+plot.radius+1.0,"Decoration clears entire driving corridor")
   check(plot.point.distance_to(path.gate(0).point)>plot.radius+path.WIDTH*.5,"Decoration clears start")
  print("NEW_SCENERY style=%s track=%d landmarks=%s greenery=%d leaves=%d"%[Style.selected(),index,landmarks,greenery.size(),district.get_meta("new_leaf_clusters",0)])
  report.append({"track":index,"landmarks":landmarks,"greenery":greenery,"leaves":district.get_meta("new_leaf_clusters",0)})
  view.set_quality(0);check(not view.decoration.visible,"Low quality hides additional detail")
  view.queue_free();await process_frame
 DirAccess.make_dir_recursive_absolute("res://build/validation/scenery")
 var file=FileAccess.open("res://build/validation/scenery/placements-"+Style.selected()+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report));file.close()
 print("SCENERY_ADDITIONS checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
