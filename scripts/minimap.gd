extends Control

var path
var cars:Array=[]
var bounds:=Rect2(-250,-200,500,450)

func _ready() -> void:
	if path!=null:
		bounds=Rect2(path.points[0],Vector2.ZERO)
		for p in path.points: bounds=bounds.expand(p)
		bounds=bounds.grow(20)

func project(p:Vector2) -> Vector2:
	return (p-bounds.position)/bounds.size*(size-Vector2(20,20))+Vector2(10,10)

func _draw() -> void:
	if path==null:
		return
	draw_style_box(panel(),Rect2(Vector2.ZERO,size))
	for i in range(path.points.size()):
		var road:String=path.surface_at(path.distances[i])
		draw_line(project(path.points[i]),project(path.points[(i+1)%path.points.size()]),Color("bb9567") if road=="dirt" else Color("a4b6be"),3,true)
	for car in cars:
		if is_instance_valid(car):
			draw_circle(project(car.dynamics.position),4.5 if car.player else 3.0,Color("c9ff7c") if car.player else car.dynamics.spec.color)

func panel() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(0.035,.065,.085,.88)
	s.set_corner_radius_all(14)
	return s
