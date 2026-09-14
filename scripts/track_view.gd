extends Node3D

const PathData = preload("res://scripts/track_path.gd")
var path
var decoration: Node3D
var gate_marker: Node3D
var cached_models: Dictionary = {}

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color.srgb_to_linear().lerp(color, .35)
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

func ribbon_vertex(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, heights: Vector3) -> void:
	var vertices := [PathData.world(a,heights.x),PathData.world(b,heights.y),PathData.world(c,heights.z)]
	var normal:Vector3=(vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
	for vertex in vertices:
		st.set_normal(normal)
		st.add_vertex(vertex)

# Shared endpoints keep the raised curb sealed through bends, ramps and the lap seam.
func add_curb(st: SurfaceTool, body: StaticBody3D, a: Vector2, b: Vector2,
		outer_a: Vector2, outer_b: Vector2, ha: float, hb: float, color: Color) -> void:
	var vertices:=PackedVector3Array([
		PathData.world(a,ha-.15),PathData.world(b,hb-.15),
		PathData.world(outer_b,hb-.15),PathData.world(outer_a,ha-.15),
		PathData.world(a,ha+.85),PathData.world(b,hb+.85),
		PathData.world(outer_b,hb+.85),PathData.world(outer_a,ha+.85)])
	for face in [[0,4,5,1],[3,2,6,7],[4,7,6,5],[0,3,7,4],[1,5,6,2],[0,1,2,3]]:
		for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
			st.set_color(color)
			st.add_vertex(vertices[index])
	var shape:=ConvexPolygonShape3D.new()
	shape.points=vertices
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)

func build(data, quality: int) -> void:
	path=data
	decoration=Node3D.new()
	add_child(decoration)
	build_landscape()
	var curb_body:=StaticBody3D.new()
	curb_body.name="TrackCurbs"
	curb_body.add_to_group("track_boundary")
	add_child(curb_body)
	var curbs:=SurfaceTool.new()
	curbs.begin(Mesh.PRIMITIVE_TRIANGLES)
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
		var ha:float=path.height_at(path.distances[i])
		var hb:float=path.height_at(path.distances[i+1])
		var st:SurfaceTool=strips[road]
		ribbon_vertex(st,a-na*half,b-nb*half,b+nb*half,Vector3(ha,hb,hb)+Vector3.ONE*.01)
		ribbon_vertex(st,a-na*half,b+nb*half,a+na*half,Vector3(ha,hb,ha)+Vector3.ONE*.01)
		for side in [-1.0,1.0]:
			var inner_a:Vector2=a+na*(half+0.1)*side
			var inner_b:Vector2=b+nb*(half+0.1)*side
			var outer_a:Vector2=a+na*(half+0.8)*side
			var outer_b:Vector2=b+nb*(half+0.8)*side
			add_curb(curbs,curb_body,inner_a,inner_b,outer_a,outer_b,ha,hb,Color("e35a44") if i%4<2 else Color("e5ded0"))
			var edge:SurfaceTool=strips["red" if i%4<2 else "white"]
			ribbon_vertex(edge,inner_a,inner_b,outer_b,Vector3(ha,hb,hb)+Vector3.ONE*.035)
			ribbon_vertex(edge,inner_a,outer_b,outer_a,Vector3(ha,hb,ha)+Vector3.ONE*.035)
			var verge:SurfaceTool=strips.verge
			ribbon_vertex(verge,outer_a,outer_b,b+nb*(half+3.0)*side,Vector3(ha,hb,hb)+Vector3.ONE*.005)
			ribbon_vertex(verge,outer_a,b+nb*(half+3.0)*side,a+na*(half+3.0)*side,Vector3(ha,hb,ha)+Vector3.ONE*.005)
		if maxf(ha,hb) > .2:
			var midpoint:=PathData.world((a+b)*.5,(ha+hb)*.5)
			var span:=PathData.world(b,hb)-PathData.world(a,ha)
			var deck:=add_box(midpoint-Vector3(0,.28,0),Vector3(path.WIDTH+2.4,.5,span.length()+.1),Color("66747c"))
			deck.rotation=Vector3(atan2(hb-ha,a.distance_to(b)),PathData.heading((b-a).normalized()),0)
			if i%8==0 and minf(ha,hb)>8.5:
				for side in [-1,1]:
					var foot:Vector2=(a+b)*.5+(na+nb).normalized()*(half+1.0)*side
					# Keep bridge supports away from the road underneath.
					if path.nearest(foot).distance>half:
						add_box(PathData.world(foot,(ha+hb)*.25),Vector3(1.2,(ha+hb)*.5,1.2),Color("77848b"))
	curbs.generate_normals()
	var curb_mesh:=MeshInstance3D.new()
	curb_mesh.mesh=curbs.commit()
	var curb_material:=material(Color.WHITE)
	curb_material.vertex_color_use_as_albedo=true
	curb_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	curb_mesh.material_override=curb_material
	add_child(curb_mesh)
	var colors:Dictionary={"asphalt":Color("46515b"),"dirt":Color("c99258"),"white":Color("e5ded0"),"red":Color("e35a44"),"verge":Color("b1bd81")}
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
			model("cone",PathData.world(gate.point+n*(path.WIDTH*.5+1.3)*side,gate.height)).scale=Vector3.ONE*1.8
	build_scenery()
	gate_marker=Node3D.new()
	add_child(gate_marker)
	for side in [-1,1]:
		add_box(Vector3(side*(path.WIDTH*.5+1.0),2,0),Vector3(.18,4,.18),Color("b5f46c"),gate_marker)
	set_quality(quality)

func show_gate(index: int) -> void:
	var g:Dictionary=path.gate(index)
	gate_marker.position=PathData.world(g.point,g.height)
	gate_marker.rotation.y=PathData.heading(g.tangent)

func set_quality(quality:int) -> void:
	if is_instance_valid(decoration):
		decoration.visible=quality>0

# The map is a small tabletop diorama; scenery is kept outside the driveable ribbon.
func build_landscape() -> void:
	var ground:Color=[Color("83b77a"),Color("79a265"),Color("cc9b68")][path.index]
	var surround:Color=[Color("48afbe"),Color("557b60"),Color("af7958")][path.index]
	add_box(Vector3(0,-3.6,0),Vector3(900,2,900),surround)
	add_box(Vector3(0,-1.7,0),Vector3(280,3,280),Color("e5cf9d"))
	add_box(Vector3(0,-.22,0),Vector3(277,.4,277),ground)
	for side in [-1,1]:
		add_box(Vector3(side*138,-.02,0),Vector3(1,.3,276),Color("f2dfb6"))
		add_box(Vector3(0,-.02,side*138),Vector3(276,.3,1),Color("f2dfb6"))
	if path.index==0:
		for i in range(9):
			add_box(Vector3(-157, -.9, -114+i*28),Vector3(15,.12,.65),Color("8dd7d7"),decoration)
		for i in range(3):
			var dock_z:float=-76+i*65
			add_box(Vector3(151,-.1,dock_z),Vector3(26,.6,5),Color("b68a60"),decoration)
			for k in range(8):
				add_box(Vector3(140+k*3,-.1,dock_z),Vector3(.18,.7,5),Color("805e49"),decoration)
			add_box(Vector3(151,-.9,dock_z+9),Vector3(5,1.8,12),Color("f6efe0"),decoration)
			add_box(Vector3(151,.5,dock_z+10),Vector3(3,1.2,5),Color("ed7551"),decoration)

func clear_plot(p:Vector2, radius:float) -> bool:
	return maxf(absf(p.x),absf(p.y))<127-radius and path.nearest(p).distance>path.WIDTH*.5+radius+2

func signboard(parent:Node3D, caption:String, at:Vector3, width:float, tint:Color) -> void:
	add_box(at,Vector3(width,2.6,.35),tint,parent)
	for side in [-1,1]:
		add_box(at+Vector3(side*(width*.5-.6),-2,0),Vector3(.22,4,.22),Color("e3ded0"),parent)
	var label:=Label3D.new()
	label.text=caption
	label.font_size=64
	label.pixel_size=.022
	label.position=at+Vector3(0,0,.21)
	label.no_depth_test=false
	label.modulate=Color("fff6dc")
	parent.add_child(label)

func pavilion(p:Vector2, angle:float, kind:int) -> void:
	var group:=Node3D.new()
	decoration.add_child(group)
	group.position=PathData.world(p)
	group.rotation.y=angle
	var accent:Color=[Color("ef7750"),Color("e7c15e"),Color("51a7b2")][kind%3]
	add_box(Vector3(0,.02,0),Vector3(18,.16,16),Color("bcb5a1"),group)
	if kind%3==0:
		# Open garage fronts, deep dark bays, a striped fascia and roof vents.
		add_box(Vector3(0,2.5,-2),Vector3(15,5,8),Color("f1dfbb"),group)
		for x in [-5,0,5]:
			add_box(Vector3(x,2,2.04),Vector3(4.1,3.6,.15),Color("344a53"),group)
			add_box(Vector3(x,.12,5),Vector3(.18,.12,5),Color("fff0c5"),group)
		add_box(Vector3(0,5.1,-1.8),Vector3(16,.55,9),accent,group)
		for x in [-4,4]:
			add_box(Vector3(x,5.7,-2),Vector3(2,.6,2),Color("e1dac7"),group)
		signboard(group,"APEX / PIT",Vector3(0,6.4,2.2),12,accent)
	elif kind%3==1:
		# Terraced grandstand with colorful seat rows and a canopy.
		for row in range(4):
			add_box(Vector3(0,.5+row*.7,-row*2),Vector3(16,1+row*1.4,2),Color("d1d7c8"),group)
			for seat in range(10):
				add_box(Vector3(-7+seat*1.55,1.2+row*1.4,-row*2),Vector3(1,.5,.85),accent if seat%3 else Color("f5edcd"),group)
		for x in [-8,8]:
			add_box(Vector3(x,4,-3),Vector3(.35,8,.35),Color("445e61"),group)
		add_box(Vector3(0,8,-3),Vector3(18,.4,10),accent,group)
	else:
		for x in [-5,5]:
			for z in [-4,4]:
				add_box(Vector3(x,2.5,z),Vector3(.2,5,.2),Color("f0e4ce"),group)
		var roof:=add_box(Vector3(0,5,0),Vector3(12,.4,10),accent,group)
		roof.rotation.z=.06
		add_box(Vector3(0,1.2,0),Vector3(8,2.4,3),Color("eadebf"),group)
		signboard(group,"MINI / CLUB",Vector3(0,5.8,4.5),10,accent)

func build_scenery() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=8139+path.index
	var occupied:Array[Vector2]=[]
	# Put landmarks close to the route, oriented toward the passing cars.
	for i in range(0,24,2):
		var at:Dictionary=path.sample(path.length*i/24.0)
		var n:=Vector2(-at.tangent.y,at.tangent.x)
		for side in [-1,1]:
			var p:Vector2=at.point+n*24*side
			if not clear_plot(p,12):continue
			var available:=true
			for previous in occupied:
				if previous.distance_to(p)<26:available=false
			if not available:continue
			pavilion(p,atan2(-n.x*side,-n.y*side),occupied.size())
			occupied.append(p)
	# Dense, deterministic clusters make the surroundings read as a designed place.
	for i in range(270):
		var p:=Vector2(rng.randf_range(-130,130),rng.randf_range(-130,130))
		if not clear_plot(p,3.5):continue
		var available:=true
		for previous in occupied:
			if previous.distance_to(p)<15:available=false
		if not available:continue
		if path.index==2 and i%3!=0:
			var rock:=model("rock",PathData.world(p),rng.randf()*TAU,decoration)
			rock.scale=Vector3(rng.randf_range(2,4),rng.randf_range(3,7),rng.randf_range(2,4))
			tint_model(rock,Color("b8734c") if i%2 else Color("d39960"))
		elif path.index==2:
			add_box(PathData.world(p,2.6),Vector3(.9,5.2,.9),Color("618b59"),decoration)
			add_box(PathData.world(p+Vector2(.8,0),3),Vector3(2.3,.65,.65),Color("618b59"),decoration)
			add_box(PathData.world(p+Vector2(1.7,0),3.7),Vector3(.65,2,.65),Color("618b59"),decoration)
		else:
			var tree:=model("tree",PathData.world(p),rng.randf()*TAU,decoration)
			tree.scale=Vector3.ONE*rng.randf_range(2.6,4.2)
	# Short billboard/tire groups follow the road without cluttering the racing line.
	for i in range(0,48,3):
		var at:Dictionary=path.sample(path.length*i/48.0)
		var n:=Vector2(-at.tangent.y,at.tangent.x)
		var p:Vector2=at.point+n*11.5
		if not clear_plot(p,1):continue
		var group:=Node3D.new()
		decoration.add_child(group)
		group.position=PathData.world(p)
		group.rotation.y=PathData.heading(at.tangent)
		for k in range(3):
			var tire:=model("tire_barrier",Vector3(0,0,(k-1)*2.3),0,group)
			tire.scale=Vector3.ONE*1.2
	# Painted starting boxes follow the grid positions.
	for i in range(6):
		var at:Dictionary=path.sample(-6-float(i/2)*6)
		var n:=Vector2(-at.tangent.y,at.tangent.x)
		var p:Vector2=at.point+n*(-2 if i%2==0 else 2)
		var mark:=add_box(PathData.world(p,.065),Vector3(2,.035,.18),Color("f5e8ba"))
		mark.rotation.y=PathData.heading(at.tangent)

func tint_model(node:Node, color:Color) -> void:
	if node is MeshInstance3D:
		node.material_override=material(color)
	for child in node.get_children():
		tint_model(child,color)
