extends SceneTree
# True rendered, no-throttle forward/reverse fixture with the same left wheel input.
const Car=preload("res://scripts/race_car.gd")
const Catalog=preload("res://scripts/catalog.gd")
const Controls=preload("res://scripts/touch_controls.gd")
class FlatPath extends RefCounted:
 func nearest(_p:Vector2,_s:float=-1) -> Dictionary:return {"s":0.0,"height":0.0,"surface":"asphalt","tangent":Vector2(0,-1)}
 func slope_at(_s:float) -> float:return 0.0
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720);var style=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute("res://build/validation/signed-steering")
 var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("d6dec5");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_energy=.5;root.add_child(world)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-20,0);root.add_child(sun)
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,24,25);camera.look_at(Vector3.ZERO);camera.fov=44;camera.current=true
 var controls=Controls.new();root.add_child(controls);controls.enabled=true;controls.layout()
 var touch=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=controls.areas.left.get_center();Input.parse_input_event(touch);Input.flush_buffered_events()
 var labels:Array=[];var cars:Array=[]
 for i in range(2):
  var label=Label.new();label.position=Vector2(25+i*640,20);label.add_theme_font_size_override("font_size",22);label.add_theme_color_override("font_color",Color("28433d"));root.add_child(label);labels.append(label)
  var car=Car.new();root.add_child(car);car.configure(Catalog.CARS[3],Vector2(-5 if i==0 else 5,0),PI,true);car.dynamics.velocity=car.dynamics.forward()*(6 if i==0 else -6);cars.append(car)
 var path=FlatPath.new()
 for frame in range(31):
  await physics_frame
  for i in range(2):
   var car=cars[i];car.tick(1.0/60,controls.driving(),path)
   labels[i].text=("FORWARD" if i==0 else "BACKWARD")+" | LEFT, no GAS\nframe %d | signed speed %.3f m/s\nwheel %.3f rad | yaw target %.3f\nbody yaw rate %.3f"%[frame,car.dynamics.speed(),-car.dynamics.steering*.35,car.dynamics.target_yaw_rate,car.dynamics.yaw_rate]
  if frame in [0,15,30]:
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/validation/signed-steering/"+style+"-forward-reverse-%02d.png"%frame)
   print(labels[0].text);print(labels[1].text)
 for car in cars:car.queue_free()
 controls.queue_free();await process_frame;quit()
