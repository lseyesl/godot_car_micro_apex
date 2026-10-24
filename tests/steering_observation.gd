extends RefCounted
# Independently inspect the integration contract; angular inertia may lag target yaw.
static func before(d) -> Dictionary:
 return {"yaw":d.yaw,"yaw_rate":d.yaw_rate,"steering":d.steering,"signed_speed":d.speed()}
static func valid(d,b:Dictionary,raw:float,dt:float) -> bool:
 var wheel:float=move_toward(float(b.steering),clampf(raw,-1,1),dt*9.0)
 if absf(d.steering-wheel)>.000001:return false
 var signed_speed:float=d.steering_longitudinal
 var expected_speed:float=signed_speed if absf(signed_speed)>.1 else 0.0
 if absf(d.turn_speed-expected_speed)>.000001:return false
 var product:float=wheel*expected_speed
 if product==0.0:
  if absf(d.target_yaw_rate)>.000001:return false
 elif signf(d.target_yaw_rate)!=-signf(product):return false
 var response:float=14.0 if d.target_yaw_rate*float(b.yaw_rate)<0 else 9.0
 var rate:float=lerpf(float(b.yaw_rate),d.target_yaw_rate,1.0-exp(-response*dt))
 if absf(d.yaw_rate-rate)>.000001:return false
 return absf(wrapf(d.yaw-float(b.yaw)-rate*dt,-PI,PI))<.000001
static func row(d,b:Dictionary,command:Dictionary,frame:int) -> Dictionary:
 return {"frame":frame,"time_s":frame/60.0,"input":command,"heading_before":b.yaw,"heading_after":d.yaw,"speed_before_forces":b.signed_speed,"steering_motion_speed":d.steering_longitudinal,"speed_after_collision":d.speed(),"wheel_input_smoothed":d.steering,"front_wheel_radians":-d.steering*.35,"target_yaw_rate":d.target_yaw_rate,"yaw_rate_before":b.yaw_rate,"yaw_rate_after":d.yaw_rate}
