extends Control

var path
var cars:Array=[]
var bounds:=Rect2(-250,-200,500,450)

func _ready() -> void:
	if path!=null:
		bounds=Rect2(Vector2.ONE*(-path.FIELD_SIZE*.5),Vector2.ONE*path.FIELD_SIZE)

func project(p:Vector2) -> Vector2:
	var scale_factor:float=minf(size.x-20,size.y-20)/bounds.size.x
	return (p-bounds.get_center())*scale_factor+size*.5

func _draw() -> void:
	if path==null:
		return
	draw_style_box(panel(),Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(project(bounds.position),project(bounds.end)-project(bounds.position)),Color("64745e"),false,1)
	# Draw upper decks last, masking the lower road at crossings.
	for elevated in [false,true]:
		for i in range(path.points.size()):
			if (path.height_at(path.distances[i])>.2)!=elevated:
				continue
			var a:=project(path.points[i])
			var b:=project(path.points[(i+1)%path.points.size()])
			var road:String=path.surface_at(path.distances[i])
			if elevated:
				draw_line(a,b,Color("172932"),7,true)
			draw_line(a,b,Color("f0cc78") if elevated else (Color("bb9567") if road=="dirt" else Color("a4b6be")),3,true)
	for car in cars:
		if is_instance_valid(car):
			draw_circle(project(car.dynamics.position),4.5 if car.player else 3.0,Color("c9ff7c") if car.player else car.dynamics.spec.color)

func panel() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(0.035,.065,.085,.88)
	s.set_corner_radius_all(14)
	return s
