extends RefCounted

var difficulty := 1
var phase := 0.0
var lane := 0.0
var stuck_time := 0.0

func controls(car, path, time: float) -> Dictionary:
	var nearest: Dictionary = path.nearest(car.position,car.route_s)
	car.route_s=nearest.s
	var speed:float = car.velocity.length()
	var look := clampf(7.0+speed*0.48,8.0,25.0)
	var target: Dictionary = path.sample(float(nearest.s)+look)
	var offset:float = lane + sin(time*0.7+phase)*[0.65,0.3,0.08][difficulty]
	var t: Vector2 = target.tangent
	var aim: Vector2 = target.point + Vector2(-t.y,t.x)*offset
	var desired:Vector2 = (aim-car.position).normalized()
	var error := wrapf(atan2(-desired.x,-desired.y)-car.yaw,-PI,PI)
	var steer := clampf(-error*float(car.spec.radius)/maxf(look*0.48,3.0),-1.0,1.0)
	var target_speed:float = float(car.spec.top)*[0.77,0.88,0.97][difficulty]
	# Inspect upcoming curvature and brake early; never change vehicle capabilities.
	for ahead in [0.0,12.0,25.0,42.0,65.0]:
		var a: Dictionary = path.sample(float(nearest.s)+ahead)
		var b: Dictionary = path.sample(float(nearest.s)+ahead+10.0)
		var angle := absf((a.tangent as Vector2).angle_to(b.tangent))
		var radius := 10.0/maxf(angle,0.006)
		var corner:float = sqrt(car.grip_for(a.surface)*radius)*[0.67,0.76,0.85][difficulty]
		var feasible := sqrt(corner*corner + 2.0*float(car.spec.brake)*0.65*ahead)
		target_speed = minf(target_speed,feasible)
	if absf(error) > 0.6:
		target_speed = minf(target_speed,12.0)
	if nearest.distance > path.WIDTH*0.43:
		target_speed = minf(target_speed,13.0)
	var mistake:bool = difficulty < 2 and sin(time*0.31+phase) > [0.91,0.98,1.1][difficulty]
	return {"steer":steer,"throttle":speed < target_speed and not mistake,"brake":speed > target_speed+0.8}
