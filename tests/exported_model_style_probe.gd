extends SceneTree
func _initialize():call_deferred("run")
func run():
 var Style=load("res://scripts/model_style.gd")
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://config/model_style.json"))
 var expected=OS.get_cmdline_user_args()[0]
 var failures:=0
 if Style.selected()!=expected or not data.locked:failures+=1
 for id in data.model_ids:
  var path=Style.model_path(id)
  if not ResourceLoader.exists(path):failures+=1;push_error("Missing packed model "+path);continue
  var node=load(path).instantiate();node.free()
  for other in Style.STYLES:
   if other!=expected and ResourceLoader.exists(Style.model_path_for(other,id)):
    failures+=1;push_error("Unused style is packed: "+other)
 for other in Style.STYLES:
  if other!=expected and other!="original" and ResourceLoader.exists("res://assets/styles/"+other+"/textures/surface_normal.png"):
   failures+=1;push_error("Unused style texture is packed")
 print("EXPORTED_MODEL_STYLE style=%s models=%d failures=%d env=%s"%[Style.selected(),data.model_ids.size(),failures,OS.get_environment(Style.ENVIRONMENT_VARIABLE)])
 quit(1 if failures else 0)
