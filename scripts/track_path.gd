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
	if reversed:
		var forward:=points.duplicate()
		for i in range(1,points.size()):points[i]=forward[forward.size()-i]
	distances.append(0.0)
	for i in range(points.size()):
		length += points[i].distance_to(points[(i+1)%points.size()])
		distances.append(length)

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

# Control indices define a ramp, flat deck and descent, all in route distance.
func height_at(distance: float) -> float:
	var controls: Array = definition.get("bridge_controls", [])
	if controls.is_empty():
		return 0.0
	var s := fposmod(distance,length)
	var start: float = distances[int(controls[0])*20]
	var top: float = distances[int(controls[1])*20]
	var end_top: float = distances[int(controls[2])*20]
	var end: float = distances[int(controls[3])*20]
	return 9.0 * smoothstep(start,top,s) * (1.0-smoothstep(end_top,end,s))

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
