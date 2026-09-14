extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func turn(spec:Dictionary,speed:float,road:String,dt:float=1.0/60) -> RefCounted:
	var car=Dynamics.new(spec)
	car.velocity=Vector2(0,-speed)
	for i in range(roundi(.4/dt)):car.step(dt,1,false,false,road)
	return car
func _initialize() -> void:
	for spec in Catalog.CARS:
		var slow=turn(spec,8,"asphalt")
		var fast=turn(spec,32,"asphalt")
		var dirt=turn(spec,32,"dirt")
		print(spec.id," slow_slip=",slow.slip," fast_slip=",fast.slip," dirt_slip=",dirt.slip)
		check(fast.slip>slow.slip*2,"Speed should increase rear slide")
		check(dirt.slip>fast.slip,"Dirt should break rear traction sooner")
		check(absf(fast.yaw)>.3,"High speed must allow body rotation beyond grip-limited understeer")
		var responsive=Dynamics.new(spec)
		responsive.step(.1,1,false,false,"asphalt")
		check(responsive.steering>=.89,"Steering should reach 90 percent lock in 0.1 seconds")
		var mirrored=Dynamics.new(spec)
		mirrored.velocity=Vector2(0,-32)
		for i in range(24):mirrored.step(1.0/60,-1,false,false,"asphalt")
		check(absf(mirrored.yaw+fast.yaw)<.001 and absf(mirrored.slip-fast.slip)<.001,"Left and right oversteer should be symmetric")
		var initial_rate:float=fast.yaw_rate
		for i in range(12):fast.step(1.0/60,-1,false,false,"asphalt")
		check(fast.yaw_rate*initial_rate<0,"Countersteering should reverse yaw within 0.2s")
		var straight=Dynamics.new(spec)
		straight.velocity=Vector2(0,-35)
		for i in range(60):straight.step(1.0/60,0,true,false,"asphalt")
		check(absf(straight.yaw)<.001 and straight.slip<.001,"Speed alone must not cause spontaneous spinning")
		var coarse=turn(spec,32,"asphalt",.05)
		check(absf(coarse.yaw-turn(spec,32,"asphalt").yaw)<.15,"20Hz AI and 60Hz handling should remain comparable")
		fast.reset_at(Vector2.ZERO,0)
		check(fast.yaw_rate==0 and fast.slip==0,"Reset must clear rotational momentum and slide")
	print("HANDLING checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
