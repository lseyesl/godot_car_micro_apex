extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const WIDTH := 14.0
const GATE_COUNT := 24
var points := PackedVector2Array()
var distances := PackedFloat32Array()
var length := 0.0
var index := 0
var definition: Dictionary

func _init(track_index: int = 0) -> void:
	index = track_index
	definition = Catalog.TRACKS[index]
	var controls: Array = definition.points
	for i in range(controls.size()):
		for step in range(20):
			var t := float(step) / 20.0
			var p0: Vector2 = controls[posmod(i - 1, controls.size())]
			var p1: Vector2 = controls[i]
			var p2: Vector2 = controls[(i + 1) % controls.size()]
			var p3: Vector2 = controls[(i + 2) % controls.size()]
			points.append(0.5 * ((2.0*p1) + (-p0+p2)*t + (2.0*p0-5.0*p1+4.0*p2-p3)*t*t + (-p0+3.0*p1-3.0*p2+p3)*t*t*t))
	for i in range(points.size()):
		points[i] *= [1.65,1.15,1.55][index]
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
	return {"point":a.lerp(b, (s-distances[i])/(distances[i+1]-distances[i])), "tangent":tangent, "s":s, "surface":surface_at(s)}

func nearest(p: Vector2) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		var q := a.lerp(b,t)
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			var tangent := (b-a).normalized()
			var s := lerpf(distances[i],distances[i+1],t)
			result = {"point":q,"tangent":tangent,"s":s,"distance":sqrt(d),"lateral":(p-q).dot(Vector2(-tangent.y,tangent.x)),"surface":surface_at(s)}
	if result.distance > WIDTH * 0.5:
		result.surface = "grass"
	return result

func surface_at(distance: float) -> String:
	var t := fposmod(distance,length)/length
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
