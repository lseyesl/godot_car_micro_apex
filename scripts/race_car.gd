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
var marker:MeshInstance3D
var occlusion_visual:Node3D
var visual: Node3D
var wheels: Array[Node3D] = []
var wheel_rotations: Array[Vector3] = []
var wheel_angle := 0.0
var impact := 0.0
var finish_elapsed:=0.0
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
		occlusion_visual=visual.duplicate() as Node3D
		add_child(occlusion_visual)
		var silhouette:=StandardMaterial3D.new()
		silhouette.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		silhouette.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		silhouette.albedo_color=Color(.5,1.0,.88,.65)
		silhouette.no_depth_test=true
		silhouette.render_priority=100
		for mesh in occlusion_visual.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=silhouette
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		occlusion_visual.hide()
		marker=MeshInstance3D.new()
		var torus:=TorusMesh.new()
		torus.inner_radius=2.0
		torus.outer_radius=2.14
		marker.mesh=torus
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color("ffd34e")
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test=true
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
	visual.rotation.x=atan(path.slope_at(road.s)*dynamics.forward().dot(road.tangent))
	if marker!=null:
		var normal:=Vector3(-road.tangent.x*path.slope_at(road.s),1,-road.tangent.y*path.slope_at(road.s)).normalized()
		marker.basis=Basis(Quaternion(Vector3.UP,global_basis.inverse()*normal))
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
	var pose:Dictionary=path.sample(gate.s+2.5)
	dynamics.reset_at(pose.point,PathData.heading(pose.tangent))
	position=PathData.world(dynamics.position,pose.height+.06)
	dynamics.route_s=pose.s
	rotation.y=dynamics.yaw
	velocity=Vector3.ZERO
	previous=dynamics.position
	progress.invalidate_for_reset()
	reset_cooldown=2.0
