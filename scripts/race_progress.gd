extends RefCounted

var next_gate := 1
var last_gate := 0
var laps := 0
var valid_lap := true
var lap_started := 0.0
var best_lap := INF
var finish_time := -1.0
var resets := 0

# A lap needs every gate, in order, crossing forwards and inside the road.
func advance(previous: Vector2, current: Vector2, path, time: float, target_laps: int = 3) -> Dictionary:
	if finish_time >= 0.0:
		return {}
	var gate: Dictionary = path.gate(next_gate)
	var normal: Vector2 = gate.tangent
	var a: float = (previous-gate.point).dot(normal)
	var b: float = (current-gate.point).dot(normal)
	if a > 0.0 or b <= 0.0 or current.distance_to(previous) > 15.0:
		return {}
	var crossing := previous.lerp(current, -a / maxf(b-a,0.0001))
	if crossing.distance_to(gate.point) > path.WIDTH * 0.5 + 0.5:
		return {}
	last_gate = next_gate
	next_gate = (next_gate+1) % path.GATE_COUNT
	if last_gate != 0:
		return {"gate":last_gate}
	laps += 1
	var duration := time-lap_started
	var result := {"lap":laps,"duration":duration,"valid":valid_lap}
	if valid_lap:
		best_lap = minf(best_lap,duration)
	lap_started = time
	valid_lap = true
	if target_laps > 0 and laps >= target_laps:
		finish_time = time
	return result

func invalidate_for_reset() -> void:
	valid_lap = false
	resets += 1

func score(path, position: Vector2) -> float:
	# Progress is capped at the next legal checkpoint: shortcuts cannot improve rank.
	var g: Dictionary = path.gate(last_gate)
	var span: float = path.length/path.GATE_COUNT
	var near: Dictionary = path.nearest(position)
	var local := fposmod(float(near.s)-float(g.s),path.length)
	if local > path.length*0.5:
		local -= path.length
	if laps == 0 and last_gate == 0 and local < 0.0:
		return local
	return laps*path.length + last_gate*span + clampf(local,0.0,span-0.001)
