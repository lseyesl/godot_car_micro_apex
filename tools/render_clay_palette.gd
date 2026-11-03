extends SceneTree
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Style=preload("res://scripts/model_style.gd")
const Catalog=preload("res://scripts/catalog.gd")
var prefix:String
var stage:Node3D
func _initialize():call_deferred("run")
func capture(name:String):
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/clay-palette/"+prefix+"-"+name+".png")
 print("PALETTE_CAPTURE ",prefix," ",name," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
func model(id:String,p:Vector3,s:float=1):
 var n=load(Style.model_path(id)).instantiate();stage.add_child(n);n.position=p;n.scale=Vector3.ONE*s;return n
func run():
 root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute("res://build/validation/clay-palette")
 prefix=Style.selected()+"-"+OS.get_cmdline_user_args()[0]
 stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("b7d8df");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("fff8e8");env.environment.ambient_light_energy=.5;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_color=Color("fff4d9");sun.light_energy=1;sun.shadow_enabled=true;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=42;camera.position=Vector3(16,21,25);camera.look_at(Vector3(0,1,0))
 var floor=MeshInstance3D.new();floor.mesh=BoxMesh.new();floor.mesh.size=Vector3(28,.2,22);var paint=StandardMaterial3D.new();paint.albedo_color=Color("71818b");paint.roughness=1;floor.material_override=paint;floor.position.y=-.15;stage.add_child(floor)
 for i in range(8):var car=model(Catalog.CARS[i].id,Vector3((i%4)*5-7.5,0,(i/4)*6+1));car.rotation.y=.3
 model("district_oak",Vector3(-9,0,-6),.5);model("prop_market_hall",Vector3(-1,0,-6),.4);model("prop_ferris_wheel",Vector3(7,0,-6),.4)
 await capture("models")
 stage.queue_free()
 for i in range(4):await process_frame
 var game=Main.new();game.saved=Store.new("/tmp/clay-palette-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_process(false);game.set_physics_process(false);game.quality=1
 for track in [0,1,2,5]:
  game.launch_free(track,false,true);game.countdown_plate.hide();game.center_label.hide();game.update_hud();await capture("track-"+str(track))
  if track==1:
   game.camera.position=game.player.position+Vector3(5,3.4,6.5);game.camera.look_at(game.player.position+Vector3(0,.7,0));await capture("car-close")
 game.show_menu("garage");await capture("garage")
 game.stop_start_cue();game.queue_free()
 for i in range(12):await process_frame
 quit()
