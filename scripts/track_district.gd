extends Node3D

# Original, deterministic miniature districts. Building plots are fitted to the road,
# not scattered across a generic island. Nothing is placed in the driving corridor.
const PathData=preload("res://scripts/track_path.gd")
var view
var path
var props:Node3D
var plots:Array[Dictionary]=[]
var finishes:Dictionary={}
var rng:=RandomNumberGenerator.new()

func box(at:Vector3,size:Vector3,tint:String,parent:Node3D=null) -> MeshInstance3D:
	var node:MeshInstance3D=view.add_box(at,size,Color(tint),props if parent==null else parent)
	if minf(size.x,size.z)>1.5:
		var asset:="concrete_wall_005"
		if size.y<.6:asset="cobblestone_floor_03" if at.y<.6 else "weathered_brown_planks"
		node.material_override=view.textured_material(asset,.35,Color(tint).lightened(.25))
	return node

func group_at(point:Vector2,angle:float=0.0) -> Node3D:
	var group:=Node3D.new()
	props.add_child(group)
	group.position=PathData.world(point)
	group.rotation.y=angle
	return group

func available(p:Vector2,radius:float) -> bool:
	if path.nearest(p).distance<path.WIDTH*.5+radius+1.2:return false
	for plot in plots:
		if p.distance_to(plot.point)<radius+plot.radius+1.5:return false
	return true

func reserve(p:Vector2,radius:float) -> void:
	plots.append({"point":p,"radius":radius})

func build_ground(owner_view) -> void:
	view=owner_view
	path=view.path
	props=view.decoration
	rng.seed=89013+path.index
	var colors:=["b8b9a0","83937c","c5a687"]
	var ground:MeshInstance3D=view.add_box(Vector3(100,-1.08,0) if path.theme==0 else Vector3(0,-1.08,0),Vector3(448,2,640) if path.theme==0 else Vector3(640,2,640),Color(colors[path.theme]))
	ground.material_override=view.textured_material("cobblestone_floor_03" if path.theme==0 else ("grass_ground" if path.theme==1 else "brown_mud_dry"),.32 if path.theme==0 else .14,Color("d0cebe") if path.theme==0 else Color.WHITE)
	if path.index==3:ground.material_override=view.textured_material("clean_asphalt",.18,Color("b4b7b2"))
	if path.theme==0:
		var sea:MeshInstance3D=view.add_box(Vector3(-330,-2.3,0),Vector3(412,.3,640),Color("639c9d"))
		var water:=ShaderMaterial.new()
		water.shader=load("res://assets/shaders/coastal_water.gdshader")
		sea.material_override=water
		# Retaining wall, continuous esplanade and marina, rather than concentric islands.
		view.add_box(Vector3(-123,-.9,0),Vector3(3,3,560),Color("a6a391"))
		view.add_box(Vector3(-120,.02,0),Vector3(6,.15,560),Color("d1c6ae"))
		for z in range(-180,181,5):
			box(Vector3(-124,.65,z),Vector3(.28,1.5,.28),"737e79")
		box(Vector3(-124,1.25,0),Vector3(.14,.14,365),"abb4a6")
		for z in [-70,12,90]:marina(z)
	else:
		# Layered skyline outside the playable field gives the circuit a setting.
		for i in range(22):
			var angle:=i*TAU/22.0
			var p:=Vector2(cos(angle),sin(angle))*rng.randf_range(156,190)
			if path.theme==1:
				var hill:Node3D=view.model("district_outcrop",PathData.world(p,-1),rng.randf()*TAU,props)
				hill.scale=Vector3(23,9,23)
				apply_surface(hill,view.textured_material("grass_ground",.13,Color("b0bb9e")))
			else:
				mesa(p,rng.randf_range(13,20),rng.randf_range(12,20))

func marina(z:float) -> void:
	box(Vector3(-145,-.7,z),Vector3(43,.65,6),"9b856b")
	for x in range(-164,-125,2):box(Vector3(x,-.32,z),Vector3(.08,.08,6),"6d655b")
	for x in [-130,-145,-163]:
		for side in [-1,1]:box(Vector3(x,0,z+side*3),Vector3(.45,2.5,.45),"c7bc9e")
	var boat:=group_at(Vector2(-153,z+10))
	var hull:MeshInstance3D=view.solid_cone(Vector3(0,-1.2,0),2.3,2.8,1.3,Color("e4e0ce"),boat,10)
	hull.scale.z=2.1
	box(Vector3(0,-.25,0),Vector3(3,1,4.5),"607f87",boat)
	box(Vector3(0,.4,0),Vector3(3.2,.2,4.7),"d8d0b9",boat)

func build_details(owner_view) -> void:
	view=owner_view
	race_control()
	landscape_pockets()
	# Larger scene anchors occupy explicitly chosen outer parcels.
	if path.theme==0:
		warehouse(Vector2(142,-53),PI*.5,0)
		warehouse(Vector2(145,-10),PI*.5,1)
		container_yard(Vector2(137,57))
		parking(Vector2(-33,133),0)
	elif path.theme==1:
		warehouse(Vector2(141,-35),PI*.5,2)
		log_yard(Vector2(137,30))
		parking(Vector2(-33,133),0)
	else:
		warehouse(Vector2(142,-40),PI*.5,3)
		freight_train()
		water_tower(Vector2(-45,-122))

	# Repeatable plots follow both sides of the circuit. A radius reservation protects
	# the entire footprint, including roof overhang, from road and neighbouring plots.
	for i in range(0,48):
		var at:Dictionary=path.sample(path.length*(i+.12)/48.0)
		var normal:=Vector2(-at.tangent.y,at.tangent.x)
		for side in [-1,1]:
			var p:Vector2=at.point+normal*19.5*side
			if absf(p.x)>115 or absf(p.y)>117 or not available(p,9):continue
			var angle:=atan2(-normal.x*side,-normal.y*side)
			reserve(p,9)
			if path.index>=3:expansion_plot(p,angle,i)
			elif path.theme==0:art_building(p,angle,i%2)
			elif path.theme==1:art_building(p,angle,2+i%2)
			else:art_building(p,angle,4+i%2)
	# Deliberate clusters in remaining plots and at the edge of the map.
	for x in range(-140,151,11):
		for z in range(-140,151,11):
			var p:=Vector2(x+rng.randf_range(-2,2),z+rng.randf_range(-2,2))
			if path.theme==0 and (p.x < -114 or p.x>115 or absf(p.y)>113):continue
			if not available(p,3.8):continue
			if path.theme==0:
				if rng.randf()>.4:continue
				planter(p)
			elif path.theme==1:
				art_tree(p,rng.randf_range(.8,1.25),true)
				if rng.randf()<.3:boulders(p+Vector2(3,2))
			else:
				if rng.randf()<.32 and available(p,6):
					mesa(p,rng.randf_range(3.5,5.8),rng.randf_range(3.5,7))
				else:boulders(p)
	if path.index==5:snow_cover()
	street_furniture()
	starting_grid()
	batch_primitives()

func townhouse(p:Vector2,angle:float,variant:int) -> void:
	var group:=group_at(p,angle)
	var width:=9.0+float(variant%3)
	var height:=5.5+float(variant%3)*1.8
	var wall:String=["c9c3a8","aabbb1","c7aa8e","c2b7a3"][variant%4]
	box(Vector3(0,.05,0),Vector3(15,.25,15),"b4b2a1",group)
	facade(Vector3(0,height*.5,-1),Vector3(width,height,9),wall,group,0)
	box(Vector3(0,.45,-1),Vector3(width+.3,.6,9.3),"92988f",group)
	box(Vector3(0,height+.15,-1),Vector3(width+.9,.35,9.8),"ddd4bb",group)
	box(Vector3(0,height+.4,-1),Vector3(width,.35,8.9),"687b7b",group)
	# Shop windows, separate upper-storey frames, recessed entrance, fabric awning.
	for x in [-2.9,2.9]:
		box(Vector3(x,1.8,3.54),Vector3(2.6,2.25,.12),"405b60",group)
		box(Vector3(x,1.8,3.66),Vector3(.1,2.2,.12),"b8c4b8",group)
		if height>6:
			box(Vector3(x,5.1,3.56),Vector3(2.2,2,.15),"e3d8bc",group)
			box(Vector3(x,5.1,3.68),Vector3(1.7,1.5,.12),"5e7c81",group)
	box(Vector3(0,1.55,3.6),Vector3(1.35,3,.2),"596d68",group)
	for i in range(8):
		var awning:=box(Vector3(-width*.5+width*(i+.5)/8,3.25,4.45),Vector3(width/8,.16,2),"a35f50" if i%2==0 else "d9d0b7",group)
		awning.rotation.x=.12
	box(Vector3(0,3.8,3.7),Vector3(width,.65,.2),"5f7775",group)
	if variant%3==0:
		box(Vector3(-2,height+1,-2),Vector3(2,1.3,2),"a0a899",group)
		box(Vector3(2,height+1.2,-2),Vector3(.8,2,.8),"b4a38b",group)
	# Rear windows and roof coping keep the camera-facing facades articulated.
	for x in [-2.8,2.8]:
		box(Vector3(x,2.6,-5.56),Vector3(1.9,1.8,.12),"607b7b",group)
		box(Vector3(x,3.6,-5.6),Vector3(2.3,.15,.2),"d5ccb2",group)
		if height>6:box(Vector3(x,5.3,-5.56),Vector3(1.9,1.7,.12),"607b7b",group)
	for side in [-1,1]:
		box(Vector3(side*width*.5,height+.55,-1),Vector3(.2,.5,9.1),"b8b79f",group)
	box(Vector3(0,height+.55,-5.5),Vector3(width,.5,.2),"b8b79f",group)
	if variant%4==0:
		box(Vector3(0,4.3,4.2),Vector3(8,.25,1.5),"c7c5af",group)
		for x in range(-4,5):box(Vector3(x,4.9,4.8),Vector3(.08,1.1,.08),"657c76",group)
		box(Vector3(0,5.45,4.8),Vector3(8,.1,.1),"657c76",group)
	# Side facade details are visible from the fixed oblique gameplay camera.
	for z in [-3,0,2]:
		box(Vector3(width*.5+.06,height*.58,z),Vector3(.15,1.8,1.65),"56757a",group)
	bench(Vector3(4,.4,6),group)

func warehouse(p:Vector2,angle:float,variant:int) -> void:
	reserve(p,19)
	var group:=group_at(p,angle)
	box(Vector3(0,.05,0),Vector3(32,.15,32),"9e9e90",group)
	box(Vector3(0,4,-3),Vector3(26,8,15),["b6b7aa","a5b3ae","aaa18a","a59983"][variant],group)
	for x in [-8,0,8]:
		box(Vector3(x,3.3,4.56),Vector3(6.2,6,.2),"526465",group)
		for row in range(5):box(Vector3(x,1.1+row,4.7),Vector3(6,.08,.1),"81908a",group)
		box(Vector3(x,.2,8),Vector3(.15,.1,6),"d8ceb2",group)
	for side in [-1,1]:
		var roof:=box(Vector3(0,8.8,-3+side*4),Vector3(28,.45,8.8),"788481",group)
		roof.rotation.x=side*.22
	box(Vector3(0,7.3,4.7),Vector3(25,1,.25),["a77759","617f8a","727b59","a17d58"][variant],group)
	for x in [-9,8]:
		box(Vector3(x,1,11),Vector3(2,2,2),"b09d78",group)

func workshop(p:Vector2,angle:float,variant:int) -> void:
	var group:=group_at(p,angle)
	box(Vector3(0,.05,0),Vector3(15,.15,15),"a8a38b",group)
	facade(Vector3(0,2.6,-1),Vector3(10,5.2,9),"a69779",group,1)
	for row in range(7):box(Vector3(0,.5+row*.7,3.56),Vector3(10,.06,.12),"827a65",group)
	for side in [-1,1]:
		var roof:=box(Vector3(side*2.8,5.95,-1),Vector3(6.4,.35,11),"596f6b" if variant%2==0 else "8a7964",group)
		roof.rotation.z=-side*.4
		box(Vector3(side*3,2.7,3.65),Vector3(2.1,1.9,.14),"d3c7a7",group)
		box(Vector3(side*3,2.7,3.75),Vector3(1.65,1.45,.1),"5d7978",group)
	box(Vector3(0,1.6,3.65),Vector3(1.6,3.2,.15),"5c6358",group)
	box(Vector3(0,.3,5),Vector3(12,.4,3),"a49373",group)
	box(Vector3(0,3.9,5),Vector3(12,.2,3),"7c8871",group)
	for side in [-1,1]:box(Vector3(side*5,2,6),Vector3(.2,4,.2),"c4b695",group)
	box(Vector3(3,6,-2),Vector3(1.2,3.5,1.2),"8f9181",group)
	for side in [-1,1]:
		for row in range(7):box(Vector3(side*5.04,.5+row*.7,-1),Vector3(.12,.055,9),"827a65",group)
		for z in [-3,1]:box(Vector3(side*5.12,2.7,z),Vector3(.12,1.6,1.7),"657d76",group)
		box(Vector3(side*2.8,2.7,-5.56),Vector3(1.8,1.7,.15),"657d76",group)
	if variant%2==0:
		for k in range(3):
			var log:MeshInstance3D=view.solid_cone(Vector3(6,.45+k*.7,-2),.45,.45,4,Color("8c7658"),group,8)
			log.rotation.x=PI*.5

func frontier(p:Vector2,angle:float,variant:int) -> void:
	var group:=group_at(p,angle)
	box(Vector3(0,.06,0),Vector3(15,.2,15),"b6a080",group)
	facade(Vector3(0,2.8,-1),Vector3(10,5.6,8),["af9f82","bca688","a8a78e"][variant%3],group,1)
	box(Vector3(0,5.9,3),Vector3(11,1.7,.55),"ae8765",group)
	box(Vector3(0,5.8,-1),Vector3(11,.35,9),"807b67",group)
	box(Vector3(0,.3,4.6),Vector3(12,.35,4),"a58f6d",group)
	box(Vector3(0,3.6,4.8),Vector3(12,.3,4),"9b8060",group)
	for x in [-5,5]:box(Vector3(x,1.9,6),Vector3(.28,3.8,.28),"83755c",group)
	for x in [-3,3]:box(Vector3(x,2,3.1),Vector3(2,2,.2),"556e6d",group)
	box(Vector3(0,1.5,3.1),Vector3(1.5,3,.2),"766b54",group)
	box(Vector3(0,5.7,3.36),Vector3(7,.75,.15),"d7c19a",group)
	for x in [-6,6]:
		view.solid_cone(Vector3(x,.65,2),.6,.6,1.3,Color("8f7560"),group,10)

func container_yard(p:Vector2) -> void:
	reserve(p,24)
	var group:=group_at(p)
	box(Vector3(0,.05,0),Vector3(37,.2,38),"9ca39a",group)
	for i in range(6):
		var x:float=-10+(i%2)*14
		var z:float=-12+(i/2)*10
		var tint:String=["7f9694","b48968","8a8d78"][i%3]
		box(Vector3(x,2.3,z),Vector3(12,4.6,6),tint,group)
		for rib in range(7):box(Vector3(x-5+rib*1.6,2.3,z+3.05),Vector3(.13,4.2,.15),"c0b79b",group)
	box(Vector3(8,12,-9),Vector3(1,24,1),"b5a47d",group)
	box(Vector3(-3,23,-9),Vector3(25,.8,1.3),"b5a47d",group)
	box(Vector3(-14,17,-9),Vector3(.12,12,.12),"747d75",group)

func log_yard(p:Vector2) -> void:
	reserve(p,22)
	var group:=group_at(p)
	box(Vector3(0,.1,0),Vector3(32,.2,35),"b7a383",group)
	for stack in range(3):
		for row in range(3):
			for col in range(4-row):
				var log:MeshInstance3D=view.solid_cone(Vector3(-9+col*1.8+row*.85,1+row*1.5,-11+stack*10),.85,.85,8,Color("9c8462"),group,10)
				log.rotation.x=PI*.5
	for x in [-15,15]:
		for z in range(-17,18,4):box(Vector3(x,1,z),Vector3(.25,2,.25),"9d9175",group)
		box(Vector3(x,1.5,0),Vector3(.18,.18,35),"b5a580",group)

func freight_train() -> void:
	var group:=group_at(Vector2(140,65))
	reserve(Vector2(140,65),23)
	box(Vector3(0,.1,0),Vector3(50,.2,12),"9d917c",group)
	for z in [-2,2]:box(Vector3(0,.4,z),Vector3(60,.25,.2),"737b77",group)
	for x in range(-28,29,2):box(Vector3(x,.2,0),Vector3(.35,.25,6),"8c7b60",group)
	for x in [-17,0,17]:
		box(Vector3(x,3,0),Vector3(14,4.5,5.5),"9d7e61",group)
		box(Vector3(x,5.3,0),Vector3(14.5,.35,5.8),"787d71",group)
		for axle in [-4,4]:
			for side in [-1,1]:
				var wheel:MeshInstance3D=view.solid_cone(Vector3(x+axle,.9,side*2.8),.9,.9,.45,Color("535e59"),group,12)
				wheel.rotation.x=PI*.5

func water_tower(p:Vector2) -> void:
	reserve(p,9)
	var group:=group_at(p)
	for x in [-3,3]:
		for z in [-3,3]:box(Vector3(x,5,z),Vector3(.5,10,.5),"827963",group)
	view.solid_cone(Vector3(0,11,0),4.8,4.8,5,Color("aaa087"),group,16)
	view.solid_cone(Vector3(0,14,0),5,.2,1.5,Color("737e75"),group,16)
	for y in [9,11,13]:
		var band:MeshInstance3D=view.solid_cone(Vector3(0,y,0),4.9,4.9,.18,Color("6c776d"),group,16)
		band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func parking(p:Vector2,angle:float) -> void:
	reserve(p,20)
	var group:=group_at(p,angle)
	box(Vector3(0,.06,0),Vector3(37,.15,15),"858e87",group)
	for i in range(7):
		box(Vector3(-16+i*5,.16,1),Vector3(.12,.04,8),"d1c6aa",group)
		if i%3==0:continue
		var car:Node3D=view.model(["car_speed","car_balanced","car_dirt"][i%3],Vector3(-13.5+i*5,.18,1),0,group)
		car.scale=Vector3.ONE*1.15

func planter(p:Vector2) -> void:
	var group:=group_at(p)
	box(Vector3(0,.3,0),Vector3(5,.6,5),"b2b49e",group)
	box(Vector3(0,.62,0),Vector3(4.4,.05,4.4),"868d71",group).material_override=view.textured_material("brown_mud_dry",.3)
	art_tree(p,.9,false)

func mesa(p:Vector2,radius:float,height:float) -> void:
	var rock:Node3D=view.model("district_outcrop",PathData.world(p,-.12),rng.randf()*TAU,props)
	rock.scale=Vector3(radius*.8,height,radius*.75)
	apply_surface(rock,view.textured_material("marble_cliff_02",.13,Color("c5ab8b")))

func apply_surface(node:Node,surface:Material) -> void:
	if node is MeshInstance3D:node.material_override=surface
	for child in node.get_children():apply_surface(child,surface)

func boulders(p:Vector2) -> void:
	for i in range(3):
		var rock:Node3D=view.model("rock",PathData.world(p+Vector2(i*1.2,0)),rng.randf()*TAU,props)
		rock.scale=Vector3(1.6,1+i*.3,1.4)
		apply_surface(rock,view.textured_material("marble_cliff_02",.3,Color("c3a98d") if path.theme==2 else Color("a9b3a2")))

func bench(at:Vector3,parent:Node3D) -> void:
	box(at+Vector3(0,.4,0),Vector3(2.7,.2,.75),"8e8870",parent)
	box(at+Vector3(0,.85,-.35),Vector3(2.7,.7,.15),"9d9476",parent)
	for x in [-1,1]:box(at+Vector3(x,0,0),Vector3(.15,.8,.6),"6a7871",parent)

func street_furniture() -> void:
	# Edge furniture is sampled against the whole route, including nearby hairpins.
	for i in range(64):
		var at:Dictionary=path.sample(path.length*i/64.0)
		var normal:=Vector2(-at.tangent.y,at.tangent.x)
		var p:Vector2=at.point+normal*10.8
		if not available(p,1.4):continue
		var group:=group_at(p,PathData.heading(at.tangent))
		if i%4==0:
			box(Vector3(0,3,0),Vector3(.2,6,.2),"77867d",group)
			box(Vector3(-.8,6,0),Vector3(1.8,.2,.2),"77867d",group)
			box(Vector3(-1.6,5.9,0),Vector3(.7,.18,.6),"d7d0ae",group)
		else:
			for j in range(3):
				var tire:Node3D=view.model("tire_barrier",Vector3(0,0,(j-1)*1.6),0,group)
				tire.scale=Vector3.ONE*.9
		if i%8==2:
			box(Vector3(0,2,0),Vector3(.15,4,.15),"9aa795",group)
			box(Vector3(0,3.4,0),Vector3(.15,1.1,2.7),"bdb893",group)
		if i%8==4:
			box(Vector3(0,1.1,0),Vector3(.25,1.6,5.8),"d4d6c8",group)
			var label:=Label3D.new()
			label.text=["APX MOTORS","RIVET TYRES","HARBOUR GP"][i%3]
			label.font_size=48
			label.pixel_size=.016
			label.modulate=Color("264959")
			label.position=Vector3(-.14,1.1,0)
			label.rotation.y=-PI*.5
			group.add_child(label)

func starting_grid() -> void:
	for i in range(6):
		var at:Dictionary=path.sample(-6-float(i/2)*6)
		var n:=Vector2(-at.tangent.y,at.tangent.x)
		var p:Vector2=at.point+n*(-2 if i%2==0 else 2)
		var mark:MeshInstance3D=view.add_box(PathData.world(p,.065),Vector3(2,.035,.18),Color("e2d8b9"))
		mark.rotation.y=PathData.heading(at.tangent)

func batch_primitives() -> void:
	# Architecture and vegetation are merged into instanced material groups after authoring.
	# This preserves shadows and quality toggling without hundreds of draw calls.
	var groups:Dictionary={}
	var pending:Array[Node]=[props]
	while not pending.is_empty():
		var node:Node=pending.pop_back()
		for child in node.get_children():pending.append(child)
		if not node is MeshInstance3D:continue
		if node.mesh==null or node.mesh.get_surface_count()!=1:continue
		var surface:Material=node.material_override if node.material_override!=null else node.get_active_material(0)
		if surface==null:continue
		var transform:Transform3D=props.global_transform.affine_inverse()*node.global_transform
		var lengths:=transform.basis.get_scale().abs()
		if not node.mesh is BoxMesh and (absf(lengths.x-lengths.y)>.01 or absf(lengths.z-lengths.y)>.01):continue
		var cell:=Vector2i(floori(node.global_position.x/48),floori(node.global_position.z/48))
		var key:String=str(surface.get_instance_id())+str(cell)
		var dimensions:=Vector3.ONE
		var prototype:Mesh
		if node.mesh is BoxMesh:
			key+="/box"
			dimensions=node.mesh.size
			prototype=BoxMesh.new()
		elif node.mesh is CylinderMesh:
			var source:CylinderMesh=node.mesh
			# Keep authored cone proportions in the shared mesh. Normalizing cones and
			# restoring them with nonuniform instance scale distorts GL normals.
			key+="/cylinder/%s/%s/%s/%s"%[source.bottom_radius,source.top_radius,source.height,source.radial_segments]
			prototype=source
		else:
			key+="/mesh/"+str(node.mesh.get_rid())
			prototype=node.mesh
		if not groups.has(key):groups[key]={"material":surface,"transforms":[],"mesh":prototype}
		transform.basis=transform.basis.scaled_local(dimensions)
		groups[key].transforms.append(transform)
		node.queue_free()
	for entry in groups.values():
		var batch:=MultiMeshInstance3D.new()
		batch.multimesh=MultiMesh.new()
		batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=entry.mesh
		batch.multimesh.instance_count=entry.transforms.size()
		batch.material_override=entry.material
		for i in range(entry.transforms.size()):batch.multimesh.set_instance_transform(i,entry.transforms[i])
		props.add_child(batch)

func race_control() -> void:
	var at:Dictionary=path.gate(0)
	var normal:=Vector2(-at.tangent.y,at.tangent.x)
	var p:Vector2=at.point-normal*25
	if not available(p,11):return
	reserve(p,11)
	var group:=group_at(p,atan2(normal.x,normal.y))
	box(Vector3(0,.1,0),Vector3(17,.25,17),"b0ad97",group)
	box(Vector3(-4,3,0),Vector3(6,6,9),"b8b9a6",group)
	box(Vector3(-4,7,0),Vector3(6.6,2.5,9.5),"647f80",group)
	box(Vector3(-4,8.5,0),Vector3(7.6,.45,10.2),"ccc7ad",group)
	for z in [-4.7,4.7]:
		box(Vector3(-4,7,z),Vector3(6.6,.15,.12),"bfc6b3",group)
		for x in [-6,-4,-2]:box(Vector3(x,7,z),Vector3(.13,2.5,.13),"bfc6b3",group)
	for row in range(3):
		box(Vector3(4,.5+row*.55,-row*2),Vector3(8,1+row*1.1,2),"aaa891",group)
		for seat in range(5):
			var x:float=.7+seat*1.6
			view.solid_cone(Vector3(x,1.5+row*1.1,-row*2),.21,.28,.65,Color(["b19873","6b8d8b","9b7967"][seat%3]),group,10)
			view.solid_cone(Vector3(x,2.04+row*1.1,-row*2),.18,.18,.35,Color("c7ad87"),group,8)
	var sign:=Label3D.new()
	sign.text=["BAY / GRAND PRIX","TIMBER / SPRINT","REDSTONE / RALLY","DOCKSIDE / SPRINT","MARKET / CIRCUIT","ALPINE / RALLY"][path.index]
	sign.font_size=48
	sign.pixel_size=.013
	sign.position=Vector3(0,9,5.3)
	box(Vector3(0,9,5),Vector3(17,1.7,.4),"465f63",group)
	group.add_child(sign)
	var back:=sign.duplicate() as Label3D
	back.position.z=4.7
	back.rotation.y=PI
	group.add_child(back)

func facade(at:Vector3,size:Vector3,tint:String,parent:Node3D,kind:int) -> void:
	var key:=tint+str(kind)
	if not finishes.has(key):
		var finish:=ShaderMaterial.new()
		finish.shader=load("res://assets/shaders/district_surface.gdshader")
		finish.set_shader_parameter("tint",Color(tint))
		finish.set_shader_parameter("finish_kind",float(kind))
		finishes[key]=finish
	box(at,size,tint,parent).material_override=finishes[key]

func art_building(p:Vector2,angle:float,variant:int) -> void:
	var group:=group_at(p,angle)
	var building:Node3D=view.model("district_art_"+str(variant),Vector3.ZERO,0,group)
	finish_model(building,variant)

func finish_model(node:Node,variant:int) -> void:
	if node is MeshInstance3D:
		var key:=String(node.name)
		var asset:=""
		var scale_factor:=.3
		if key.begins_with("plaster"):asset="concrete_wall_005"
		elif key.begins_with("stone"):asset="concrete_wall_005"
		elif key.begins_with("roof"):
			asset="clay_roof_tiles" if variant<2 else "weathered_brown_planks"
			scale_factor=.28
		elif key.begins_with("wood") or key.begins_with("timber"):asset="weathered_brown_planks"
		if not asset.is_empty():
			var tint:=Color.WHITE
			if key.begins_with("plaster"):
				# Quiet, warm facades frame the track instead of competing with it.
				tint=Color(["ded4b9","c6d2cc","d3c6aa","c3c7b0","dbbda0","d0c0a6"][variant])
				var finish_key:="plaster_"+str(variant)
				if not finishes.has(finish_key):
					var finish:=ShaderMaterial.new()
					finish.shader=load("res://assets/shaders/district_plaster.gdshader")
					finish.set_shader_parameter("plaster_tint",tint)
					finish.set_shader_parameter("surface_texture",load("res://assets/textures/surfaces/concrete_wall_005_albedo.jpg"))
					finishes[finish_key]=finish
				node.material_override=finishes[finish_key]
			else:node.material_override=view.textured_material(asset,scale_factor,tint)
	for child in node.get_children():finish_model(child,variant)

func art_tree(p:Vector2,size:float,pine:bool) -> void:
	var tree:Node3D=view.model("district_pine" if pine else "district_oak",PathData.world(p),rng.randf()*TAU,props)
	tree.scale=Vector3.ONE*size
	finish_foliage(tree)

func finish_foliage(node:Node) -> void:
	if node is MeshInstance3D and String(node.name).begins_with("leaf"):
		node.material_override=view.textured_material("grass_ground",.7,Color("6f895b"))
	for child in node.get_children():finish_foliage(child)

func landscape_pockets() -> void:
	var terrain:=ShaderMaterial.new()
	terrain.shader=load("res://assets/shaders/terrain_bank.gdshader")
	terrain.set_shader_parameter("grass_tex",load("res://assets/textures/surfaces/grass_ground_albedo.jpg"))
	terrain.set_shader_parameter("rock_tex",load("res://assets/textures/surfaces/marble_cliff_02_albedo.jpg"))
	for i in range(12):
		var at:Dictionary=path.sample(path.length*(i+.3)/12.0)
		var normal:=Vector2(-at.tangent.y,at.tangent.x)
		var p:Vector2=at.point+normal*24
		if absf(p.x)>107 or absf(p.y)>107 or not available(p,10):continue
		reserve(p,10)
		var bank:Node3D=view.model("district_outcrop",PathData.world(p,-.1),rng.randf()*TAU,props)
		bank.scale=Vector3(7.5,4.5,7.5)
		apply_surface(bank,terrain if path.theme!=2 else view.textured_material("marble_cliff_02",.17,Color("c5ac92")))
		for side in [-1,1]:
			var boulder:Node3D=view.model("district_outcrop",PathData.world(p+Vector2(side*5,3),-.1),rng.randf()*TAU,props)
			boulder.scale=Vector3(2.2,1.6,2.5)
			apply_surface(boulder,view.textured_material("marble_cliff_02",.22))

func expansion_plot(p:Vector2,angle:float,variant:int) -> void:
	var group:=group_at(p,angle)
	if path.index==3:
		# Stacked freight modules and gantry cranes create a port silhouette.
		for row in range(2):
			for level in range(1+variant%2):
				var at:=Vector3(-3.1+row*6.2,1.4+level*2.8,0)
				var tint:Color=Color(["af6352","477b88","b3a66c"][(variant+row)%3])
				var cargo:=box(at,Vector3(5.6,2.7,9),"657e81",group)
				cargo.material_override=view.material(tint)
				for rib in range(12):
					box(at+Vector3(0,0,-4.3+rib*.78),Vector3(5.7,2.76,.065),"536469",group)
		if variant%3==0:
			for x in [-6.5,6.5]:box(Vector3(x,4.5,0),Vector3(.65,9,.65),"d4ae51",group)
			box(Vector3(0,9,0),Vector3(14,.85,1.1),"d4ae51",group)
			box(Vector3(2,6.8,0),Vector3(.1,4,.1),"39484d",group)
			box(Vector3(2,4.8,0),Vector3(2.2,.3,.7),"39484d",group)
	elif path.index==4:
		if variant%4==0:
			box(Vector3(0,4,0),Vector3(4,8,4),"c6b598",group)
			view.solid_cone(Vector3(0,9,0),3,0,3,Color("806958"),group,4)
			var clock:=Label3D.new()
			clock.text="XII\n◷";clock.font_size=96;clock.pixel_size=.017
			clock.position=Vector3(0,6.6,2.1);group.add_child(clock)
		else:
			for x in [-4.0,3.5]:
				var tint:=Color(["bb6251","cbac57","598b80"][(variant+int(x+4))%3])
				for dx in [-2.4,2.4]:
					for z in [-2.4,2.4]:box(Vector3(x+dx,1.5,z),Vector3(.13,3,.13),"6d6956",group)
				var canopy:MeshInstance3D=view.solid_cone(Vector3(x,3.4,0),3.7,0,1.6,tint,group,4)
				canopy.rotation.y=PI*.25
				box(Vector3(x,1.0,1.5),Vector3(4.5,1.6,1.3),"9f805e",group)
				for crate in range(3):
					box(Vector3(x-1.4+crate*1.4,1.95,1.5),Vector3(1.15,.35,1),"c7a77c",group)
					for fruit in range(3):view.solid_cone(Vector3(x-1.65+crate*1.4+fruit*.26,2.23,1.5),.16,.12,.25,Color("c59c49" if crate%2 else "8caa59"),group,8)
	else:
		art_building(p,angle,2+variant%2)
		# Cabin snow caps and timber ski racks give the alpine camp a new silhouette.
		for side in [-1,1]:
			var cap:=box(Vector3(0,7.18,side*2.625),Vector3(11.3,.18,5.75),"e2e8e6",group)
			cap.rotation.x=side*.413
			cap.material_override=view.material(Color("d8e5ec"))
		for x in [-5.5,-4.7,-3.9]:
			var ski:=box(Vector3(x,1.5,5),Vector3(.25,3,.12),"b55d52",group)
			ski.rotation.z=.2
		if variant%4==0:
			box(Vector3(5,5,-4),Vector3(.5,10,.5),"65777a",group)
			box(Vector3(5,9.5,-4),Vector3(4,.35,.4),"65777a",group)
			box(Vector3(4,7.7,-4),Vector3(.08,3.3,.08),"46575b",group)
			box(Vector3(4,6.2,-4),Vector3(2,.25,1.4),"b97251",group)

func snow_cover() -> void:
	var snow:=ShaderMaterial.new()
	snow.shader=load("res://assets/shaders/district_plaster.gdshader")
	snow.set_shader_parameter("plaster_tint",Color("a6bac8"))
	snow.set_shader_parameter("surface_texture",load("res://assets/textures/surfaces/concrete_wall_005_albedo.jpg"))
	# Ground is structural scenery and remains visible in low quality mode.
	for child in view.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.x>400:
			child.material_override=snow
