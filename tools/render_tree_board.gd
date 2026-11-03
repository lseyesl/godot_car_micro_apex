extends SceneTree
const Style=preload("res://scripts/model_style.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const View=preload("res://scripts/track_view.gd")
const PathData=preload("res://scripts/track_path.gd")
var prefix:String
func _initialize():call_deferred("run")
func capture(name:String):
 for i in range(6):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/tree-board/"+prefix+"-"+name+".png")
 print("TREE_CAPTURE ",prefix," ",name," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
func run():
 prefix=Style.selected()+"-"+OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute("res://build/validation/tree-board")
 var stage=Node3D.new();root.add_child(stage);var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("b7d8df");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.5;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_energy=1;sun.shadow_enabled=true;stage.add_child(sun)
 var camera=Camera3D.new();camera.fov=38;stage.add_child(camera);camera.current=true
 var floor=MeshInstance3D.new();floor.mesh=BoxMesh.new();floor.mesh.size=Vector3(40,.05,40);floor.position=Vector3(0,-.105,.09);var m=StandardMaterial3D.new();m.albedo_color=Color("899788");m.roughness=1;floor.material_override=m;stage.add_child(floor)
 for id in ["tree","district_oak","district_pine"]:
  var model=load(Style.model_path(id)).instantiate();stage.add_child(model)
  var reference=load(Style.model_path_for("original",id)).instantiate();stage.add_child(reference)
  var bounds:AABB;var first:=true
  for mesh in reference.find_children("*","MeshInstance3D",true,false):
   var box:AABB=mesh.global_transform*mesh.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
  reference.free()
  if Style.is_paper() and prefix.ends_with("-after"):model.position.y=-.08
  var center:=bounds.get_center();var radius:=bounds.size.length()
  for angle in ["front","side","oblique"]:
   camera.position=center+({"front":Vector3(0,.12,1),"side":Vector3(1,.12,0),"oblique":Vector3(.8,.3,1)}[angle]).normalized()*radius*1.45;camera.look_at(center);await capture(id+"-"+angle)
  model.queue_free()
  for i in range(3):await process_frame
 stage.queue_free()
 for i in range(3):await process_frame
 var game=Main.new();game.saved=Store.new("/tmp/tree-board-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_process(false);game.set_physics_process(false);game.quality=1
 for index in [0,1]:
  game.launch_free(index,false,true);game.center_label.hide();game.countdown_plate.hide();game.update_hud();await capture("race-"+str(index))
  var view
  for node in game.find_children("*","Node3D",true,false):
   if node.get_script()==View:view=node;break
  for tree in view.decoration.find_children("*","Node3D",true,false):
   if tree.scene_file_path.get_file().trim_suffix(".glb") in ["district_oak","district_pine"]:
    var target:Vector3=tree.global_position+Vector3(0,1.5,0);var yaw=deg_to_rad(Main.CAMERA_YAW);game.camera.position=target+Vector3(sin(yaw)*7,3.0,cos(yaw)*7);game.camera.look_at(target);break
  await capture("placed-"+str(index))
 game.stop_start_cue();game.queue_free()
 for i in range(10):await process_frame
 quit()
