extends Node3D

const PathData = preload("res://scripts/track_path.gd")
var path
var decoration: Node3D
var gate_marker: Node3D
var cached_models: Dictionary = {}

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=1.0
	return m

func add_box(at: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size=size
	node.mesh=cube
	node.material_override=material(color)
	parent.add_child(node)
	node.position=at
	return node

func model(id: String, at: Vector3, angle: float = 0.0, parent: Node3D = self) -> Node3D:
	if not cached_models.has(id):
		cached_models[id]=load("res://assets/models/"+id+".glb")
	var node: Node3D = cached_models[id].instantiate()
	parent.add_child(node)
	node.position=at
	node.rotation.y=angle
	return node

func ribbon_vertex(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, height: float) -> void:
	for p in [a,b,c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(PathData.world(p,height))

func build(data, quality: int) -> void:
	path=data
	decoration=Node3D.new()
	add_child(decoration)
	add_box(Vector3(0,-0.24,0),Vector3(1100,0.3,1100),Color("75845d"))
	var strips: Dictionary={}
	for road in ["asphalt","dirt","white","red","verge"]:
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		strips[road]=st
	for i in range(path.points.size()):
		var a:Vector2=path.points[i]
		var b:Vector2=path.points[(i+1)%path.points.size()]
		var prev:Vector2=path.points[posmod(i-1,path.points.size())]
		var after:Vector2=path.points[(i+2)%path.points.size()]
		var ta:Vector2=(b-prev).normalized()
		var tb:Vector2=(after-a).normalized()
		var na:=Vector2(-ta.y,ta.x)
		var nb:=Vector2(-tb.y,tb.x)
		var half:float=path.WIDTH*0.5
		var road:String=path.surface_at((path.distances[i]+path.distances[i+1])*0.5)
		var st:SurfaceTool=strips[road]
		ribbon_vertex(st,a-na*half,b-nb*half,b+nb*half,0.01)
		ribbon_vertex(st,a-na*half,b+nb*half,a+na*half,0.01)
		for side in [-1.0,1.0]:
			var inner_a:Vector2=a+na*(half+0.1)*side
			var inner_b:Vector2=b+nb*(half+0.1)*side
			var outer_a:Vector2=a+na*(half+0.8)*side
			var outer_b:Vector2=b+nb*(half+0.8)*side
			var edge:SurfaceTool=strips["red" if i%4<2 else "white"]
			ribbon_vertex(edge,inner_a,inner_b,outer_b,0.035)
			ribbon_vertex(edge,inner_a,outer_b,outer_a,0.035)
			var verge:SurfaceTool=strips.verge
			ribbon_vertex(verge,outer_a,outer_b,b+nb*(half+3.0)*side,0.005)
			ribbon_vertex(verge,outer_a,b+nb*(half+3.0)*side,a+na*(half+3.0)*side,0.005)
	var colors:Dictionary={"asphalt":Color("363f46"),"dirt":Color("b18451"),"white":Color("e5ded0"),"red":Color("e35a44"),"verge":Color("87965f")}
	for road in strips:
		var node:=MeshInstance3D.new()
		node.mesh=strips[road].commit()
		var m:=material(colors[road])
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
		node.material_override=m
		add_child(node)
	var start:Dictionary=path.gate(0)
	var gantry:=model("start_gantry",PathData.world(start.point),PathData.heading(start.tangent))
	gantry.scale.x=2.05
	for j in range(14):
		for k in range(2):
			var normal:=Vector2(-start.tangent.y,start.tangent.x)
			var point:Vector2=start.point+normal*(j-6.5)+start.tangent*(k-0.5)
			var stripe:=add_box(PathData.world(point,0.045),Vector3(1,.035,1),Color("f4eee2") if (j+k)%2==0 else Color("19272d"))
			stripe.rotation.y=PathData.heading(start.tangent)
	for i in range(path.GATE_COUNT):
		var gate:Dictionary=path.gate(i)
		var n:=Vector2(-gate.tangent.y,gate.tangent.x)
		for side in [-1,1]:
			model("cone",PathData.world(gate.point+n*(path.WIDTH*.5+1.3)*side)).scale=Vector3.ONE*1.8
	var rng:=RandomNumberGenerator.new()
	rng.seed=1291+path.index
	for i in range(110):
		var s:float=rng.randf()*path.length
		var at:Dictionary=path.sample(s)
		var n:=Vector2(-at.tangent.y,at.tangent.x)
		var p:Vector2=at.point+n*rng.randf_range(16,40)*(1 if i%2 else -1)
		if path.nearest(p).distance < 13:
			continue
		var prop:=model("tree" if i%4 else "rock",PathData.world(p),rng.randf()*TAU,decoration)
		prop.scale=Vector3.ONE*rng.randf_range(1.6,3.0)
	# Local safety barriers around selected corners; road edges remain recoverable.
	for i in range(4, path.points.size(), 24):
		var sample:Dictionary=path.sample(path.distances[i])
		var n:=Vector2(-sample.tangent.y,sample.tangent.x)
		for k in range(3):
			var p:Vector2=sample.point+n*10.5+sample.tangent*(k-1)*3.0
			var barrier:=model("safety_barrier",PathData.world(p),PathData.heading(sample.tangent))
			var body:=StaticBody3D.new()
			barrier.add_child(body)
			var shape:=CollisionShape3D.new()
			var box:=BoxShape3D.new()
			box.size=Vector3(.6,1.2,3.0)
			shape.shape=box
			shape.position.y=.6
			body.add_child(shape)
	gate_marker=Node3D.new()
	add_child(gate_marker)
	for side in [-1,1]:
		add_box(Vector3(side*(path.WIDTH*.5+1.0),2,0),Vector3(.18,4,.18),Color("b5f46c"),gate_marker)
	set_quality(quality)

func show_gate(index: int) -> void:
	var g:Dictionary=path.gate(index)
	gate_marker.position=PathData.world(g.point)
	gate_marker.rotation.y=PathData.heading(g.tangent)

func set_quality(quality:int) -> void:
	if is_instance_valid(decoration):
		decoration.visible=quality>0
