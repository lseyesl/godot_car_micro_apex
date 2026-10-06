extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Driver=preload("res://scripts/ai_driver.gd")
const Catalog=preload("res://scripts/catalog.gd")
const Progress=preload("res://scripts/race_progress.gd")
var failures:=0
func check(value:bool,message:String) -> void:
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	for index in range(Catalog.TRACKS.size()):
		var path=Track.new(index)
		var crossings:=0
		for i in range(path.points.size()):
			check(maxf(absf(path.points[i].x),absf(path.points[i].y))+path.WIDTH<path.FIELD_SIZE*.5,"Road must fit square")
			for j in range(i+10,path.points.size()):
				if path.points.size()-j+i<10:continue
				var hit=Geometry2D.segment_intersects_segment(path.points[i],path.points[(i+1)%path.points.size()],path.points[j],path.points[(j+1)%path.points.size()])
				if hit==null:continue
				crossings+=1
				var first:Dictionary=path.nearest(hit,path.distances[i])
				var second:Dictionary=path.nearest(hit,path.distances[j])
				check(absf(first.height-second.height)>6,"Crossings need car clearance")
				check(absf(wrapf(first.s-second.s,-path.length*.5,path.length*.5))>65,"Route hint must preserve crossing branch")
		check(crossings>0 if index==3 else crossings==0,"Only the port should contain a grade-separated crossing")
		for gate_index in range(path.GATE_COUNT):
			var gate:Dictionary=path.gate(gate_index)
			if gate.height<6:continue
			var wrong_level=Progress.new()
			wrong_level.next_gate=gate_index
			wrong_level.advance(gate.point-gate.tangent,gate.point+gate.tangent,path,1,1,0)
			check(wrong_level.next_gate==gate_index,"Ground car must not trigger bridge checkpoint")
		var car=Dynamics.new(Catalog.CARS[3])
		var driver=Driver.new()
		driver.difficulty=1
		var start:Dictionary=path.sample(0)
		car.reset_at(start.point,Track.heading(start.tangent))
		var progress=Progress.new()
		var max_off:=0.0
		for tick in range(24000):
			var before:Vector2=car.position
			var controls:Dictionary=driver.controls(car,path,tick/60.0)
			var near:Dictionary=path.nearest(car.position,car.route_s)
			car.step(1.0/60,controls.steer,controls.throttle,controls.brake,near.surface)
			var after:Dictionary=path.nearest(car.position,car.route_s)
			car.route_s=after.s
			max_off=maxf(max_off,after.distance)
			progress.advance(before,car.position,path,tick/60.0,1,after.height)
			if progress.laps==1:break
		check(progress.laps==1,"AI must complete square track %d; gate=%d"%[index,progress.next_gate])
		print("MINI_TRACK index=%d length=%.1f crossings=%d lap=%.1f max_off=%.1f"%[index,path.length,crossings,progress.finish_time,max_off])
	print("MINI_TRACKS failures=%d"%failures)
	quit(1 if failures else 0)
