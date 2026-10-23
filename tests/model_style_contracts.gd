extends SceneTree
const Style=preload("res://scripts/model_style.gd")
const Catalog=preload("res://scripts/catalog.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 check(Style.selected() in Style.STYLES,"Selected style must be valid")
 for id in DirAccess.get_files_at("res://assets/models"):
  if not id.ends_with(".glb"):continue
  var name=id.trim_suffix(".glb")
  var original=load(Style.model_path_for("original",name)).instantiate()
  var clay=load(Style.model_path_for("bright_clay",name)).instantiate()
  check(original.transform.is_equal_approx(clay.transform),"Root transform changed: "+name)
  var a=original.find_children("*","Node3D",true,false)
  var b=clay.find_children("*","Node3D",true,false)
  check(a.size()==b.size(),"Node count changed: "+name)
  for i in range(mini(a.size(),b.size())):
   check(a[i].name==b[i].name and a[i].transform.is_equal_approx(b[i].transform),"Node contract changed: "+name)
   if a[i] is MeshInstance3D:
    check(a[i].mesh.get_aabb().is_equal_approx(b[i].mesh.get_aabb()),"Mesh bounds changed: "+name)
    check(a[i].mesh.get_surface_count()==b[i].mesh.get_surface_count(),"Surface count changed: "+name)
  if name.begins_with("car_"):
   check(clay.find_children("Wheel_*","Node3D",true,false).size()==4,"Four wheel pivots required: "+name)
  original.free();clay.free()
 print("MODEL_STYLE_CONTRACTS checks=%d failures=%d style=%s"%[checks,failures,Style.selected()])
 quit(1 if failures else 0)
