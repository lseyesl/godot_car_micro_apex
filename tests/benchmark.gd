extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Progress=preload("res://scripts/race_progress.gd")
const Driver=preload("res://scripts/ai_driver.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var results:Array=[]
	var failed:=false
	for track_index in range(3):
		var path=Track.new(track_index)
		for car_index in range(4):
			var car=Dynamics.new(Catalog.CARS[car_index])
			var start:Dictionary=path.sample(-2)
			car.reset_at(start.point,Track.heading(start.tangent))
			var progress=Progress.new()
			var driver=Driver.new()
			driver.difficulty=2
			var t:=0.0
			var offroad:=0
			var steps:=0
			var max_error:=0.0
			while t<300 and progress.finish_time<0:
				var input:Dictionary=driver.controls(car,path,t)
				var before:Vector2=car.position
				var near:Dictionary=path.nearest(before)
				if near.surface=="grass":offroad+=1
				max_error=maxf(max_error,near.distance)
				car.step(.05,input.steer,input.throttle,input.brake,near.surface)
				t+=.05
				steps+=1
				progress.advance(before,car.position,path,t,3)
			var result:Dictionary={"track":track_index,"car":car_index,"seconds":snappedf(progress.finish_time,.01),"best_lap":snappedf(progress.best_lap,.01) if is_finite(progress.best_lap) else -1,"laps":progress.laps,"offroad_fraction":float(offroad)/maxi(1,steps),"max_lateral_error":max_error}
			results.append(result)
			print(JSON.stringify(result))
			if progress.laps!=3:failed=true
	var report:Dictionary={"method":"Deterministic solo hard AI, same physics, 20Hz, three laps; no collisions; not a human skill balance proof.","results":results}
	var file:=FileAccess.open("res://build/balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BENCHMARK_COMPLETE failed=%s"%failed)
	quit(1 if failed else 0)
