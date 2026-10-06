extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const WIDTH := 14.0
const GATE_COUNT := 24
const FIELD_SIZE := 280.0
var points := PackedVector2Array()
var distances := PackedFloat32Array()
var length := 0.0
var index := 0
var theme := 0
var reversed := false
var definition: Dictionary
var elevations:Array[Dictionary]=[]
var overhead_segments:Array[Dictionary]=[]

func _init(track_index: int = 0, reverse_route: bool = false) -> void:
	reversed=reverse_route
	index = track_index
	definition = Catalog.TRACKS[index]
	theme = int(definition.get("theme",index))
	var controls: Array = definition.points
	for i in range(controls.size()):
		for step in range(20):
			var t := float(step) / 20.0
			var p0: Vector2 = controls[posmod(i - 1, controls.size())]
			var p1: Vector2 = controls[i]
			var p2: Vector2 = controls[(i + 1) % controls.size()]
			var p3: Vector2 = controls[(i + 2) % controls.size()]
			points.append(0.5 * ((2.0*p1) + (-p0+p2)*t + (2.0*p0-5.0*p1+4.0*p2-p3)*t*t + (-p0+3.0*p1-3.0*p2+p3)*t*t*t))
	var forward_distances:=PackedFloat32Array([0.0])
	for i in range(points.size()):
		forward_distances.append(forward_distances[-1]+points[i].distance_to(points[(i+1)%points.size()]))
	for feature in definition.get("elevations",[]):
		var stops:Array[float]=[]
		for control in feature.controls:
			var sample_index:float=float(control)*20.0
			var lower:=int(floor(sample_index))
			stops.append(lerpf(forward_distances[lower],forward_distances[lower+1],sample_index-lower))
		elevations.append({"kind":feature.kind,"height":feature.height,"stops":stops})
	if reversed:
		var forward:=points.duplicate()
		for i in range(1,points.size()):points[i]=forward[forward.size()-i]
	distances.append(0.0)
	for i in range(points.size()):
		length += points[i].distance_to(points[(i+1)%points.size()])
		distances.append(length)
	if index==3:
		for i in range(points.size()):
			var height:float=(height_at(distances[i])+height_at(distances[i+1]))*.5
			if height>3.0:overhead_segments.append({"a":points[i],"span":points[(i+1)%points.size()]-points[i],"height":height})

func sample(distance: float) -> Dictionary:
	var s := fposmod(distance, length)
	var i := 0
	while i < points.size()-1 and distances[i+1] <= s:
		i += 1
	var a := points[i]
	var b := points[(i+1)%points.size()]
	var tangent := (b-a).normalized()
	return {"point":a.lerp(b, (s-distances[i])/(distances[i+1]-distances[i])), "tangent":tangent, "s":s, "surface":surface_at(s), "height":height_at(s)}

func nearest(p: Vector2, route_hint: float = -1.0) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		var q := a.lerp(b,t)
		var s := lerpf(distances[i],distances[i+1],t)
		if route_hint >= 0.0 and absf(wrapf(s-route_hint,-length*0.5,length*0.5)) > 65.0:
			continue
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			var tangent := (b-a).normalized()
			result = {"point":q,"tangent":tangent,"s":s,"distance":sqrt(d),"lateral":(p-q).dot(Vector2(-tangent.y,tangent.x)),"surface":surface_at(s), "height":height_at(s)}
	if result.distance > WIDTH * 0.5:
		result.surface = "grass"
	return result

# Elevations are authored in forward world distance; reversing preserves the structure.
func feature_at(distance:float) -> Dictionary:
	var s:=fposmod(-distance if reversed else distance,length)
	for feature in elevations:
		if s>=feature.stops[0] and s<=feature.stops[3]:return feature
	return {}

func height_at(distance: float) -> float:
	var s:=fposmod(-distance if reversed else distance,length)
	var feature:=feature_at(distance)
	if feature.is_empty():return 0.0
	var stops:Array=feature.stops
	return float(feature.height)*smoothstep(stops[0],stops[1],s)*(1.0-smoothstep(stops[2],stops[3],s))

func slope_at(distance:float) -> float:
	return (height_at(distance+.5)-height_at(distance-.5))

func surface_at(distance: float) -> String:
	var t := fposmod(-distance if reversed else distance,length)/length
	for interval: Vector2 in definition.dirt_ranges:
		if t >= interval.x and t < interval.y:
			return "dirt"
	return "asphalt"

func gate(gate_index: int) -> Dictionary:
	return sample(float(gate_index) * length / GATE_COUNT)

static func world(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x,height,p.y)

static func heading(tangent: Vector2) -> float:
	return atan2(-tangent.x,-tangent.y)

# Approximate camera-ray/deck intersection for the player's occlusion silhouette.
func overhead_cover(at:Vector3,eye:Vector3) -> bool:
	if index!=3 or eye.y<=at.y+.1:return false
	for segment in overhead_segments:
		var height:float=segment.height
		if height<at.y+3.0 or height>eye.y:continue
		var ray_point:=at.lerp(eye,(height-at.y)/(eye.y-at.y))
		var p:=Vector2(ray_point.x,ray_point.z)
		var a:Vector2=segment.a;var span:Vector2=segment.span
		var t:=clampf((p-a).dot(span)/span.length_squared(),0,1)
		if p.distance_to(a+span*t)<WIDTH*.5+3.2:return true
	return false
