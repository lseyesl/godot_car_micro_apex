extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const View=preload("res://scripts/track_view.gd")
const Car=preload("res://scripts/race_car.gd")
const Catalog=preload("res://scripts/catalog.gd")
var failures:=0
var checks:=0
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func drive(car, path, steps:int) -> Dictionary:
	var max_distance:=0.0
	var contacts:=0
	for i in range(steps):
		await physics_frame
		car.tick(1.0/60,{"steer":0,"throttle":false,"brake":false},path)
		max_distance=maxf(max_distance,path.nearest(car.dynamics.position,car.dynamics.route_s).distance)
		contacts+=car.get_slide_collision_count()
	return {"max_distance":max_distance,"contacts":contacts}
func place(car,path,s:float,lateral:float,motion:Vector2) -> void:
	var at:Dictionary=path.sample(s)
	var normal:=Vector2(-at.tangent.y,at.tangent.x)
	car.dynamics.reset_at(at.point+normal*lateral,Track.heading(motion.normalized()))
	car.dynamics.route_s=at.s
	car.dynamics.velocity=motion
	car.position=Track.world(car.dynamics.position,at.height+.06)
	car.rotation.y=car.dynamics.yaw
	car.velocity=Track.world(motion)
func run() -> void:
	for index in range(Catalog.TRACKS.size()):
		var path=Track.new(index)
		var view=View.new()
		root.add_child(view)
		view.build(path,0)
		var car=Car.new()
		root.add_child(car)
		car.configure(Catalog.CARS[3],path.sample(0).point,0,false)
		await physics_frame
		check(view.get_node("TrackCurbs").get_child_count()==path.points.size()*2,"Both curbs must cover every segment")
		for control in [3, 12]:
			var s:float=path.distances[control*20]+5
			var at:Dictionary=path.sample(s)
			var normal:=Vector2(-at.tangent.y,at.tangent.x)
			for side in [-1,1]:
				place(car,path,s,side*3.0,normal*side*49)
				var result:Dictionary=await drive(car,path,24)
				check(result.contacts>0,"Head-on collision must hit curb")
				check(result.max_distance<6.5,"High-speed impact must stay on track")
				check(car.dynamics.velocity.length()<.5,"Head-on impact must stop car")
			# Start near the wall so tight new curves cannot turn away before contact.
			place(car,path,s,5.8,at.tangent*30+normal*12)
			var scraped:Dictionary=await drive(car,path,30)
			check(scraped.contacts>0,"Glancing car must contact curb")
			check(scraped.max_distance<6.5,"Scraping car must stay inside curb")
			check(car.dynamics.velocity.length()<26,"Scraping must remove tangential speed")
		# Both routes through the crossing must remain open, at their own height.
		var center_routes:Array=[]
		for i in range(path.points.size()):
			if path.points[i].length()<2:
				center_routes.append(path.distances[i])
		for s in center_routes:
			var at:Dictionary=path.sample(s-12)
			place(car,path,s-12,0,at.tangent*20)
			var passage:Dictionary=await drive(car,path,60)
			check(passage.contacts==0,"Curbs on another level must not block crossing")
			check(car.dynamics.velocity.length()>18,"Crossing must preserve clear-road speed")
		print("CURB_TRACK index=%d checks=%d failures=%d"%[index,checks,failures])
		car.queue_free()
		view.queue_free()
		await process_frame
	print("CURB_COLLISIONS checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
