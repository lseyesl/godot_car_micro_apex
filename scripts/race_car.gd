extends CharacterBody3D

const Dynamics = preload("res://scripts/vehicle_dynamics.gd")
const Progress = preload("res://scripts/race_progress.gd")
const Driver = preload("res://scripts/ai_driver.gd")
const PathData = preload("res://scripts/track_path.gd")
var dynamics
var progress = Progress.new()
var driver = Driver.new()
var car_index := 0
var player := false
var display_name := ""
var visual: Node3D
var wheels: Array[Node3D] = []
var wheel_rotations: Array[Vector3] = []
var wheel_angle := 0.0
var impact := 0.0
var near:Dictionary={}
var previous := Vector2.ZERO
var reset_cooldown := 0.0
var dust:CPUParticles3D
var effects_enabled:=true

func configure(spec:Dictionary, at:Vector2, heading:float, is_player:bool) -> void:
	dynamics=Dynamics.new(spec)
	dynamics.reset_at(at,heading)
	player=is_player
	position=PathData.world(at,.06)
	rotation.y=heading
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(1.7,1.15,3.4)
	collision.shape=box
	collision.position.y=.65
	add_child(collision)
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	visual=load("res://assets/models/"+str(spec.id)+".glb").instantiate()
	add_child(visual)
	for node in visual.find_children("Wheel_*","Node3D",true,false):
		wheels.append(node)
		wheel_rotations.append(node.rotation)
	dust=CPUParticles3D.new()
	dust.amount=16
	dust.lifetime=.65
	dust.local_coords=false
	dust.fixed_fps=30
	dust.direction=Vector3(0,1,1)
	dust.spread=35
	dust.gravity=Vector3(0,.6,0)
	dust.initial_velocity_min=.4
	dust.initial_velocity_max=1.4
	dust.scale_amount_min=.5
	dust.scale_amount_max=1.3
	var puff:=SphereMesh.new()
	puff.radius=.25
	puff.height=.5
	puff.radial_segments=6
	puff.rings=3
	var dust_material:=StandardMaterial3D.new()
	dust_material.albedo_color=Color("c8ad80")
	dust_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.vertex_color_use_as_albedo=true
	puff.material=dust_material
	dust.mesh=puff
	var fade:=Gradient.new()
	fade.set_color(0,Color(1,1,1,.5))
	fade.set_color(1,Color(1,1,1,0))
	dust.color_ramp=fade
	dust.position=Vector3(0,.2,1.4)
	dust.emitting=false
	add_child(dust)
	if player:
		var marker:=MeshInstance3D.new()
		var torus:=TorusMesh.new()
		torus.inner_radius=2.0
		torus.outer_radius=2.14
		marker.mesh=torus
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color("ffd34e")
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override=material
		marker.position.y=.06
		add_child(marker)

func tick(dt:float, controls:Dictionary, path) -> void:
	previous=dynamics.position
	near=path.nearest(previous,dynamics.route_s)
	dynamics.route_s=near.s
	position.y=near.height+.06
	dynamics.step(dt,float(controls.steer),bool(controls.throttle),bool(controls.brake),near.surface)
	velocity=PathData.world(dynamics.velocity)
	rotation.y=dynamics.yaw
	var incoming:Vector2=dynamics.velocity
	move_and_slide()
	var road:Dictionary=path.nearest(Vector2(position.x,position.z),dynamics.route_s)
	dynamics.route_s=road.s
	position.y=road.height+.06
	visual.rotation.x=atan2(path.height_at(road.s+1)-path.height_at(road.s-1),2.0)
	dynamics.position=Vector2(position.x,position.z)
	dynamics.velocity=Vector2(velocity.x,velocity.z)
	dust.emitting=effects_enabled and dynamics.surface!="asphalt" and dynamics.velocity.length()>6
	impact=move_toward(impact,0.0,dt*12)
	var boundary_contact:=false
	var wall_speed:Vector2=incoming
	for i in range(get_slide_collision_count()):
		var hit:=get_slide_collision(i)
		impact=maxf(impact,previous.distance_to(dynamics.position)/dt*.15)
		var other=hit.get_collider()
		if other != null and other.is_in_group("track_boundary"):
			boundary_contact=true
			var normal:=Vector2(hit.get_normal().x,hit.get_normal().z).normalized()
			var into:=maxf(0.0,-incoming.dot(normal))
			impact=maxf(impact,into*.15)
			# Project the incoming velocity: floating move_and_slide preserves speed
			# along walls, which otherwise rewards holding throttle into a curb.
			wall_speed-=normal*minf(wall_speed.dot(normal),0.0)
			if into > incoming.length()*.72:
				wall_speed=Vector2.ZERO
		if other is CharacterBody3D and other.get("dynamics") != null:
			var push:=Vector2(-hit.get_normal().x,-hit.get_normal().z)
			other.dynamics.velocity+=push*minf(3.0,impact)*float(dynamics.spec.mass)/float(other.dynamics.spec.mass)
	if boundary_contact:
		# Apply friction once per physics tick, independent of seam contact count.
		dynamics.velocity=wall_speed*exp(-5.0*dt)
		velocity=PathData.world(dynamics.velocity)
	wheel_angle+=dynamics.speed()*dt/.34
	for i in range(wheels.size()):
		wheels[i].rotation=wheel_rotations[i]+Vector3(wheel_angle,(-dynamics.steering*.35 if "Front" in wheels[i].name else 0.0),0)
	visual.rotation.z=lerpf(visual.rotation.z,-dynamics.steering*minf(dynamics.velocity.length()/45.0,1.0)*.035,dt*8)
	reset_cooldown=maxf(0.0,reset_cooldown-dt)

func reset_to_gate(path) -> void:
	var gate:Dictionary=path.gate(progress.last_gate)
	dynamics.reset_at(gate.point+gate.tangent*2.5,PathData.heading(gate.tangent))
	position=PathData.world(dynamics.position,gate.height+.06)
	dynamics.route_s=gate.s
	rotation.y=dynamics.yaw
	velocity=Vector3.ZERO
	previous=dynamics.position
	progress.invalidate_for_reset()
	reset_cooldown=2.0
