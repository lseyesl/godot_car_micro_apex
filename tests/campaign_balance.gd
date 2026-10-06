extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Career=preload("res://scripts/career.gd")
const Track=preload("res://scripts/track_path.gd")
const Dynamics=preload("res://scripts/vehicle_dynamics.gd")
const Driver=preload("res://scripts/ai_driver.gd")
const Progress=preload("res://scripts/race_progress.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var results:Array=[]
	var failures:=0
	for track in range(Catalog.TRACKS.size()):
		for reversed in [false,true]:
			var path=Track.new(track,reversed)
			for tier in [0,3]:
				for model in range(Catalog.CARS.size()):
					var car=Dynamics.new(Career.tuned(Catalog.CARS[model],tier,tier,tier))
					var start:Dictionary=path.sample(-2)
					car.reset_at(start.point,Track.heading(start.tangent))
					var driver=Driver.new()
					driver.difficulty=2
					var progress=Progress.new()
					var elapsed:=0.0
					var offroad:=0
					while elapsed<180 and progress.laps<1:
						var input:Dictionary=driver.controls(car,path,elapsed)
						var before:Vector2=car.position
						var near:Dictionary=path.nearest(before,car.route_s)
						if near.surface=="grass":offroad+=1
						car.step(.05,input.steer,input.throttle,input.brake,near.surface)
						elapsed+=.05
						var road:Dictionary=path.nearest(car.position,car.route_s)
						progress.advance(before,car.position,path,elapsed,1,road.height)
					var success:bool=progress.laps==1 and offroad==0
					if not success:failures+=1
					var result:={"track":track,"reverse":reversed,"tier":tier,"car":model,"seconds":snappedf(elapsed,.01),"offroad":offroad,"success":success}
					results.append(result)
					print(JSON.stringify(result))
	var file:=FileAccess.open("res://build/campaign-balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("CAMPAIGN_BALANCE combinations=%d failures=%d"%[results.size(),failures])
	quit(1 if failures else 0)
