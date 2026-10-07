extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Controls=preload("res://scripts/touch_controls.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=8:push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var input=Controls.new();root.add_child(input)
	input.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	input.size=Vector2(1280,720);input.enabled=true;input.layout()
	for button in ["left","right"]:
		input.clear()
		var touch:=InputEventScreenTouch.new()
		touch.index=1;touch.pressed=true;touch.position=input.areas[button].get_center()
		input._input(touch)
		var command:Dictionary=input.driving()
		var expected:float=-1 if button=="left" else 1
		check(command.steer==expected,"Touch arrow must send its own steering direction")
		for spec in Catalog.CARS:
			for heading in range(8):
				for road in ["asphalt","dirt","grass"]:
					# Forward, reversing, and rolling/sliding backwards after a spin.
					for motion in [Vector2(16,0),Vector2(-6,0),Vector2(-10,12)]:
						var car=Dynamics.new(spec)
						car.reset_at(Vector2.ZERO,heading*PI/4)
						var forward:Vector2=car.forward()
						var right:=Vector2(-forward.y,forward.x)
						car.velocity=forward*motion.x+right*motion.y
						for frame in range(18):car.step(1.0/60,command.steer,false,false,road)
						check(car.forward().dot(right)*expected>.001,"Vehicle-relative arrow reversed: %s %s heading=%d motion=%s"%[button,spec.id,heading,motion])
		var stopped=Dynamics.new(Catalog.CARS[3])
		for frame in range(18):stopped.step(1.0/60,command.steer,false,false,"asphalt")
		check(absf(stopped.yaw)<.001,"Steering alone must not spin a stationary car")
		var reversing=Dynamics.new(Catalog.CARS[3])
		for frame in range(60):reversing.step(1.0/60,command.steer,false,true,"asphalt")
		check(reversing.speed()<0 and reversing.yaw*expected<0,"Brake-to-reverse must retain arrow direction")
	input.queue_free();await process_frame
	print("STEERING_DIRECTION checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
