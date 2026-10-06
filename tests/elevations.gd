extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const Catalog=preload("res://scripts/catalog.gd")
const Car=preload("res://scripts/race_car.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for index in range(Catalog.TRACKS.size()):
		var forward=Track.new(index)
		var reverse=Track.new(index,true)
		check(forward.elevations.size()==2,"Every route needs a bridge and crest")
		for step in range(400):
			var s:float=forward.length*step/400.0
			check(absf(forward.height_at(s)-reverse.height_at(reverse.length-s))<.002,"Reverse route must preserve world elevation")
			check(absf(forward.slope_at(s))<.55,"Grades must remain driveable")
			check(absf(forward.height_at(s+.01)-forward.height_at(s-.01))<.012,"No height discontinuities")
		for feature in forward.elevations:
			check(is_equal_approx(forward.height_at((feature.stops[1]+feature.stops[2])*.5),float(feature.height)),"Deck must reach authored height")
			for direction in [forward,reverse]:
				var s:float=(feature.stops[0]+feature.stops[1])*.5
				if direction.reversed:s=direction.length-s
				var pose:Dictionary=direction.sample(s)
				var car=Car.new();root.add_child(car)
				car.configure(Catalog.CARS[3],pose.point,Track.heading(pose.tangent),false)
				car.dynamics.route_s=pose.s
				car.position=Track.world(pose.point,pose.height+.06)
				await physics_frame
				car.tick(1.0/60,{"steer":0,"throttle":false,"brake":true},direction)
				check(absf(car.position.y-pose.height-.06)<.01,"Car must follow the ramp without sinking")
				check(signf(car.visual.rotation.x)==signf(direction.slope_at(s)),"Car nose must pitch with driving direction")
				car.progress.last_gate=2
				car.reset_to_gate(direction)
				check(absf(car.position.y-direction.height_at(direction.gate(2).s+2.5)-.06)<.01,"Reset must use checkpoint elevation")
				car.queue_free();await process_frame
	var store=Store.new("/tmp/apex-elevation-record-test.cfg")
	store.config.set_value("records_elevation_v7","0_3",12.0)
	store.config.set_value("career","credits",1234)
	check(not is_finite(store.best(0,3)),"Old flat-route records must not compete with elevation records")
	check(store.config.get_value("career","credits")==1234,"Wallet must survive new record namespace")
	print("ELEVATIONS checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
