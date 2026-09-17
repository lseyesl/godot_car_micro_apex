extends RefCounted

var spec: Dictionary
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var yaw := 0.0
var steering := 0.0
var yaw_rate := 0.0
var reverse := false
var brake_was_down := false
var slip := 0.0
var route_s := -1.0
var surface := "asphalt"

const STEERING_GAIN: float = 1.2
const GRIP_TURN_AUTHORITY: float = 1.15
const HIGH_SPEED_TURN_AUTHORITY: float = 1.8

func _init(car_spec: Dictionary = {}) -> void:
	spec = car_spec

func forward() -> Vector2:
	return Vector2(-sin(yaw),-cos(yaw))

func speed() -> float:
	return velocity.dot(forward())

func grip_for(road: String) -> float:
	return float(spec.grip) * (float(spec.dirt) if road == "dirt" else (0.42 if road == "grass" else 1.0))

func step(dt: float, steer: float, throttle: bool, brake: bool, road: String) -> void:
	surface = road
	steering = move_toward(steering,clampf(steer,-1,1),dt*9.0)
	var f := forward()
	var longitudinal := velocity.dot(f)
	if brake and not brake_was_down:
		reverse = absf(longitudinal) < 0.35
	if not brake:
		reverse = false
	brake_was_down = brake
	var grip := grip_for(road)
	var road_factor := float(spec.dirt) if road == "dirt" else (0.27 if road == "grass" else 1.0)
	var top := float(spec.top) * (0.9+0.1*road_factor) if road != "grass" else 12.0
	if throttle and not brake:
		if longitudinal < -0.1:
			longitudinal = move_toward(longitudinal,0.0,float(spec.brake)*dt)
		else:
			longitudinal += float(spec.accel)*road_factor*maxf(0.0,1.0-pow(longitudinal/top,2))*dt
	elif brake:
		if reverse and not throttle:
			longitudinal = move_toward(longitudinal,-6.0,float(spec.accel)*0.6*dt)
		else:
			longitudinal = move_toward(longitudinal,0.0,float(spec.brake)*sqrt(road_factor)*dt)
	else:
		longitudinal = move_toward(longitudinal,0.0,(0.65+0.0015*longitudinal*longitudinal)*dt)
	if road == "grass" and absf(longitudinal) > top:
		longitudinal = move_toward(longitudinal,signf(longitudinal)*top,12.0*dt)
	# Body rotation can exceed the rear tires' ability to redirect travel.
	# At speed this creates oversteer; countersteering arrests the rotation.
	var pace := smoothstep(8.0,34.0,absf(longitudinal))
	var loose := 1.2 if road == "dirt" else (1.35 if road == "grass" else 1.0)
	var requested_rate := -steering*longitudinal/float(spec.radius)*STEERING_GAIN
	# Give full-lock input enough authority to rotate the car instead of
	# converting most of the steering into lateral scrub.  The speed-dependent
	# term still keeps high-speed corners bounded, while the small grip boost
	# makes low-speed hairpins feel immediate as well.
	var rotation_limit := grip*GRIP_TURN_AUTHORITY/maxf(absf(longitudinal),2.0) + pace*HIGH_SPEED_TURN_AUTHORITY*loose
	var target_rate := clampf(requested_rate,-rotation_limit,rotation_limit)
	var response := 14.0 if target_rate*yaw_rate < 0.0 else 9.0
	yaw_rate = lerpf(yaw_rate,target_rate,1.0-exp(-response*dt))
	yaw = wrapf(yaw+yaw_rate*dt,-PI,PI)
	var right := Vector2(-f.y,f.x)
	var lateral := velocity.dot(right)
	var rear_grip := grip * (1.0-0.38*pace)
	lateral = move_toward(lateral,0.0,rear_grip*dt)
	var new_forward := forward()
	velocity = f*longitudinal+right*lateral
	velocity = velocity.move_toward(new_forward*longitudinal,rear_grip*dt)
	slip = absf(velocity.dot(Vector2(-new_forward.y,new_forward.x)))
	position += velocity*dt

func reset_at(p: Vector2, angle: float) -> void:
	route_s=-1.0
	position=p
	yaw=angle
	velocity=Vector2.ZERO
	steering=0.0
	yaw_rate=0.0
	slip=0.0
	reverse=false
	brake_was_down=false
