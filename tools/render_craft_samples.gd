extends SceneTree
const Style=preload("res://scripts/model_style.gd")
const UI=preload("res://scripts/clay_ui.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
const Controls=preload("res://scripts/touch_controls.gd")
var stage:Node3D
var sample_name:String
func caption(at:Vector2) -> Label:
 var label=Label.new();label.text=sample_name;label.position=at;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_override("font",load("res://assets/fonts/NotoSansCJK-Regular.ttc"));label.add_theme_font_size_override("font_size",20)
 label.add_theme_color_override("font_color",Color("28433d") if Style.is_crafted() else Color("f5edd7"))
 label.add_theme_color_override("font_outline_color",Color("fff9e9") if Style.is_crafted() else Color("243b36"));label.add_theme_constant_override("outline_size",3);return label
func _initialize():call_deferred("run")
func material(color:Color) -> StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=1
 if Style.is_crafted():m.normal_enabled=true;m.normal_texture=load("res://assets/styles/"+Style.selected()+"/textures/surface_normal.png");m.normal_scale=.7 if Style.is_clay() else .3
 return m
func block(at:Vector3,size:Vector3,color:Color):
 var n=MeshInstance3D.new();n.mesh=BoxMesh.new();n.mesh.size=size;n.material_override=material(color);n.position=at;stage.add_child(n)
func model(id:String,at:Vector3,scale_value:float=1.0):
 var n=load(Style.model_path(id)).instantiate();stage.add_child(n);n.position=at;n.scale=Vector3.ONE*scale_value;return n
func capture(name:String):
 for frame in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/style-study/"+Style.selected()+"-"+name+".png")
 print("CRAFT_CAPTURE ",Style.selected()," ",name," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," texture_bytes=",Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
func run():
 sample_name={"original":"原版 / 实际 Godot 样板","bright_clay":"A 手捏黏土 / 实际 Godot 样板","paper_craft":"C 折纸纸模 / 实际 Godot 样板"}[Style.selected()]
 root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute("res://build/validation/style-study")
 stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("b7d8df");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("fff8e8");env.environment.ambient_light_energy=.5;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_color=Color("fff4d9");sun.light_energy=1.0;sun.shadow_enabled=true;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=40;camera.position=Vector3(18,19,25);camera.look_at(Vector3(0,5,-1))
 block(Vector3(0,-.25,0),Vector3(24,.4,22),Color("99b56f"));block(Vector3(0,-.02,1),Vector3(19,.1,6),Color("454d50"))
 for x in range(-4,5):block(Vector3(x*2,.045,1),Vector3(.9,.012,.10),Color("f7ebce"))
 var car=model("car_speed",Vector3(0,.06,2));car.rotation.y=PI-.38
 model("district_oak",Vector3(-5,0,0),.65);model("prop_market_hall",Vector3(-4,0,-5),.52);model("prop_ferris_wheel",Vector3(5,0,-4),.6)
 var controls=Controls.new();root.add_child(controls);controls.enabled=true;controls.layout()
 var title=caption(Vector2(24,18));root.add_child(title)
 await capture("world")
 camera.position=Vector3(4,4.0,7.4);camera.look_at(car.position+Vector3(0,.75,0));camera.fov=46
 await capture("car-close")
 stage.queue_free();controls.queue_free();title.queue_free()
 for frame in range(3):await process_frame
 var game=Main.new();game.saved=Store.new("/tmp/apex-craft-ui-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_physics_process(false);game.set_process(false);game.frontend.change("garage")
 var stamp=caption(Vector2(430,20));game.ui.add_child(stamp)
 await capture("garage")
 game.frontend.find_children("*","ScrollContainer",true,false)[0].scroll_vertical=1000
 await capture("garage-bottom")
 game.queue_free()
 for frame in range(4):await process_frame
 quit()
