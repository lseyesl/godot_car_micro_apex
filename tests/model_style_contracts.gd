extends SceneTree
const Style=preload("res://scripts/model_style.gd")
const SAMPLES=["car_speed","car_balanced","district_oak","prop_market_hall","prop_ferris_wheel"]
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:
  failures+=1
  if failures<=15:push_error(message)
func nodes(scene:Node) -> Dictionary:
 var result:Dictionary={}
 for node in scene.find_children("*","Node3D",true,false):result[str(scene.get_path_to(node))]=node
 return result
func tris(mesh:Mesh) -> int:
 var count:=0
 for s in range(mesh.get_surface_count()):
  var arrays=mesh.surface_get_arrays(s);count+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
 return count
func positions(mesh:Mesh) -> Dictionary:
 var result:Dictionary={}
 for surface in range(mesh.get_surface_count()):
  for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:result[vertex.snapped(Vector3.ONE*.00001)]=true
 return result
func _initialize():call_deferred("run")
func run():
 var sample:bool="--sample" in OS.get_cmdline_user_args()
 check(Style.selected() in Style.STYLES,"Selected style must be valid")
 for style in Style.STYLES:
  if style=="original":continue
  var image=load("res://assets/styles/"+style+"/textures/surface_normal.png").get_image()
  if image.is_compressed():image.decompress()
  check(not image.is_empty(),"Shared normal image must decode: "+style)
  var valid:=true
  for y in range(0,image.get_height(),8):
   for x in range(0,image.get_width(),8):valid=valid and image.get_pixel(x,y).b>.8
  check(valid,"Surface normal map cannot be black/invalid: "+style)
 for file in DirAccess.get_files_at("res://assets/models"):
  if not file.ends_with(".glb"):continue
  var id=file.trim_suffix(".glb")
  if sample and id not in SAMPLES:continue
  var original=load(Style.model_path_for("original",id)).instantiate();var a=nodes(original);var source_triangles:=0
  for node in a.values():
   if node is MeshInstance3D:source_triangles+=tris(node.mesh)
  for style in Style.STYLES:
   if style=="original":continue
   var path=Style.model_path_for(style,id)
   check(ResourceLoader.exists(path),"Missing synchronized variant: "+path)
   if not ResourceLoader.exists(path):continue
   var variant=load(path).instantiate();var b=nodes(variant)
   check(original.transform.is_equal_approx(variant.transform),"Root transform changed: "+path)
   check(a.keys()==b.keys(),"Semantic node paths/order changed: "+path)
   var triangles:=0;var changed:=false
   for key in a:
    if not b.has(key):continue
    check(a[key].transform.is_equal_approx(b[key].transform),"Pivot transform changed: "+path+":"+key)
    if a[key] is not MeshInstance3D:continue
    var source:Mesh=a[key].mesh;var mesh:Mesh=b[key].mesh;triangles+=tris(mesh)
    var bounds:AABB=mesh.get_aabb();var expected:AABB=source.get_aabb()
    check(bounds.position.distance_to(expected.position)<.002 and bounds.size.distance_to(expected.size)<.004,"Visual scale/envelope changed: "+path+":"+key)
    check(mesh.get_surface_count()<=source.get_surface_count(),"Craft assets must not add material draw surfaces: "+path)
    changed=changed or tris(source)!=tris(mesh)
    changed=changed or positions(source)!=positions(mesh)
    for s in range(mesh.get_surface_count()):
     var arrays=mesh.surface_get_arrays(s);var color:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
     check(not color.is_empty() and color.size()==arrays[Mesh.ARRAY_VERTEX].size(),"Craft pigment must exist per vertex: "+path)
     var valid_pigment:=true
     for pigment in color:
      valid_pigment=valid_pigment and pigment.r>=0 and pigment.r<=1 and pigment.g>=0 and pigment.g<=1 and pigment.b>=0 and pigment.b<=1 and pigment.a>.999
     check(valid_pigment,"Pigment must be finite, bounded and opaque: "+path)
     var material=mesh.surface_get_material(s)
     check(material is BaseMaterial3D and material.vertex_color_use_as_albedo,"Imported pigment must actually drive albedo: "+path)
     check(material.normal_enabled and material.normal_texture!=null and material.normal_texture.resource_path.begins_with("res://assets/styles/"+style+"/textures/"),"One shared style normal texture is required: "+path)
     check(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.roughness>=.9 and material.metallic<.001,"Craft surfaces remain opaque and matte: "+path)
   check(changed,"Geometry must change, not just palette: "+path)
   check(triangles<=maxf(source_triangles*2.6+64,1500),"Geometry must fit mobile triangle budget: "+path)
   if id.begins_with("car_"):check(variant.find_children("Wheel_*","Node3D",true,false).size()==4,"Four original wheel pivots required: "+path)
   original.set_meta("source_triangles",source_triangles)
   variant.free()
  original.free()
 print("MODEL_STYLE_CONTRACTS checks=%d failures=%d style=%s sample=%s"%[checks,failures,Style.selected(),sample]);quit(1 if failures else 0)
