extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const Catalog=preload("res://scripts/catalog.gd")
var failures:=0
func _initialize() -> void:
	for index in range(Catalog.TRACKS.size()):
		var path=Track.new(index)
		if index==3:
			var lower:Dictionary=path.sample(path.distances[22*20])
			var at:=Track.world(lower.point,lower.height+.06)
			if not path.overhead_cover(at,at+Vector3(20,26,25)):
				failures+=1;push_error("Underpass must enable player silhouette")
			var upper:Dictionary=path.sample(path.distances[10*20])
			at=Track.world(upper.point,upper.height+.06)
			if path.overhead_cover(at,at+Vector3(20,26,25)):
				failures+=1;push_error("Bridge deck must not enable silhouette")
		var close:=0
		var total:=0
		for x in range(-110,111,10):
			for z in range(-110,111,10):
				total+=1
				if path.nearest(Vector2(x,z)).distance<=20:close+=1
		var coverage:=float(close)/total
		if coverage<.72:failures+=1;push_error("Insufficient interior road coverage")
		var narrow:=0
		for i in range(0,path.points.size(),4):
			for j in range(i+4,path.points.size(),4):
				if absf(wrapf(path.distances[j]-path.distances[i],-path.length*.5,path.length*.5))<45:continue
				if path.points[i].distance_to(path.points[j])<16 and absf(path.height_at(path.distances[i])-path.height_at(path.distances[j]))<6:
					narrow+=1
		if narrow>0:failures+=1;push_error("Separate road ribbons overlap without vertical clearance: %d pairs"%narrow)
		print("LAYOUT_DENSITY track=%d coverage=%.3f narrow=%d"%[index,coverage,narrow])
	print("LAYOUT_DENSITY failures=%d"%failures)
	quit(1 if failures else 0)
