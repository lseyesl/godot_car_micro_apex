extends SceneTree
const Style=preload("res://scripts/model_style.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var prefix:String
var stage:Node3D
var camera:Camera3D
func _initialize():call_deferred("run")
func capture(name:String):
 for i in range(6):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/cardboard/"+prefix+"-"+name+".png")
 print("CARDBOARD_CAPTURE ",prefix," ",name," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
func run():
 prefix=Style.selected()+"-"+OS.get_cmdline_user_args()[0];root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute("res://build/validation/cardboard")
 stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("b7d8df");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("fff8e8");env.environment.ambient_light_energy=.5;stage.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-28,0);light.light_color=Color("fff4d9");light.light_energy=1;light.shadow_enabled=true;stage.add_child(light)
 camera=Camera3D.new();camera.fov=38;stage.add_child(camera);camera.current=true
 for id in ["car_speed","foliage_leaf_cluster","prop_market_hall","prop_ferris_wheel","asphalt_straight","foliage_grass_green"]:
  var model=load(Style.model_path(id)).instantiate();stage.add_child(model)
  var bounds:AABB;var first:=true
  for n in model.find_children("*","MeshInstance3D",true,false):
   var b:AABB=n.global_transform*n.mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
  var center=bounds.get_center();var radius=bounds.size.length()
  camera.position=center+Vector3(1,.65,1.5).normalized()*radius*1.5;camera.look_at(center);await capture(id)
  if id=="car_speed":camera.position=center+Vector3(-1,.4,-1.5).normalized()*radius*1.5;camera.look_at(center);await capture("car-back")
  model.queue_free()
  for i in range(3):await process_frame
 stage.queue_free()
 for i in range(3):await process_frame
 var game=Main.new();game.saved=Store.new("/tmp/cardboard-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_process(false);game.set_physics_process(false);game.quality=1
 game.launch_free(0,false,true);game.center_label.hide();game.countdown_plate.hide();game.update_hud();await capture("race")
 game.camera.position=game.player.position+Vector3(5,2.5,6);game.camera.look_at(game.player.position+Vector3(0,.8,0));await capture("race-front")
 game.camera.position=game.player.position+Vector3(-5,2.5,-6);game.camera.look_at(game.player.position+Vector3(0,.8,0));await capture("race-back")
 game.stop_start_cue();game.queue_free()
 for i in range(10):await process_frame
 quit()
