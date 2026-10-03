extends Node3D

const District = preload("res://scripts/track_district.gd")
const PathData = preload("res://scripts/track_path.gd")
var path
var decoration: Node3D
var gate_marker: Node3D
var cached_models: Dictionary = {}
var cached_materials: Dictionary = {}
var surface_cache: Dictionary = {}

func material(color: Color) -> StandardMaterial3D:
	if cached_materials.has(color):
		return cached_materials[color]
	var m := StandardMaterial3D.new()
	cached_materials[color]=m
	m.albedo_color=color.srgb_to_linear().lerp(color,.15)
	m.roughness=1.0
	return m

func textured_material(asset:String,scale_factor:float=1.0,tint:Color=Color.WHITE) -> StandardMaterial3D:
	var key:=asset+str(scale_factor)+str(tint)
	if surface_cache.has(key):return surface_cache[key]
	var m:=StandardMaterial3D.new()
	m.albedo_color=tint
	m.albedo_texture=load("res://assets/textures/surfaces/"+asset+"_albedo.jpg")
	m.normal_enabled=true
	m.normal_texture=load("res://assets/textures/surfaces/"+asset+"_normal.jpg")
	m.normal_scale=.55
	m.roughness=.88
	m.metallic_specular=.2
	m.uv1_triplanar=true
	m.uv1_world_triplanar=true
	m.uv1_scale=Vector3.ONE*scale_factor
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var ao_path:="res://assets/textures/surfaces/"+asset+"_ao.jpg"
	if ResourceLoader.exists(ao_path):
		m.ao_enabled=true
		m.ao_texture=load(ao_path)
		m.ao_light_affect=.25
	surface_cache[key]=m
	return m

func surface_material(color:Color,scale_factor:float=1.0) -> StandardMaterial3D:
	return textured_material("grass_path_3",.14,color)

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
	var district:=District.new()
	add_child(district)
	district.build_ground(self)
	var curb_body:=StaticBody3D.new()
	curb_body.name="TrackCurbs"
	curb_body.add_to_group("track_boundary")
	add_child(curb_body)
	var curbs:=SurfaceTool.new()
	curbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strips: Dictionary={}
	for road in ["asphalt","dirt","white","red","verge","paint","wear"]:
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
			add_curb(curbs,curb_body,inner_a,inner_b,outer_a,outer_b,ha,hb,Color("ad614e") if ta.dot(tb)<.9987 and int(path.distances[i]/3.0)%2==0 else Color("c9c7b9"))
			var edge:SurfaceTool=strips["red" if i%4<2 else "white"]
			ribbon_vertex(edge,inner_a,inner_b,outer_b,Vector3(ha,hb,hb)+Vector3.ONE*.035)
			ribbon_vertex(edge,inner_a,outer_b,outer_a,Vector3(ha,hb,ha)+Vector3.ONE*.035)
			# Thin continuous edge paint and a pair of broad, subtle rubber lines.
			if road=="asphalt":
				add_flat_strip(strips.paint,a,b,na,nb,(half-.55)*side,(half-.38)*side,ha+.035,hb+.035)
			var wear_offset:float=side*2.5
			if road=="asphalt" and ta.dot(tb)<.9995:
				for lane in range(3):
					var offset:float=wear_offset+lane*.6
					add_flat_strip(strips.wear,a,b,na,nb,offset-.08,offset+.13,ha+.025,hb+.025)
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
	curb_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curb_mesh.mesh=curbs.commit()
	var curb_material:=textured_material("concrete_wall_005",.32).duplicate() as StandardMaterial3D
	curb_material.vertex_color_use_as_albedo=true
	curb_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	curb_mesh.material_override=curb_material
	add_child(curb_mesh)
	var colors:Dictionary={"asphalt":Color("686b6a"),"dirt":Color("c49d76"),"white":Color("e5ded0"),"red":Color("f05d48"),"verge":[Color("b7b6a3"),Color("9e987f"),Color("bea184")][path.theme],"paint":Color("d6d3be"),"wear":Color("626563")}
	for road in strips:
		var node:=MeshInstance3D.new()
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.mesh=strips[road].commit()
		var m:StandardMaterial3D
		if road=="asphalt":m=textured_material("clean_asphalt",.2,Color("d8dddb")).duplicate()
		elif road=="dirt":m=textured_material("brown_mud_dry",.17,Color("ddd1b6")).duplicate()
		elif road=="verge":m=textured_material("cobblestone_floor_03" if path.theme==0 else "grass_path_3",.23,Color("c6c6b6")).duplicate()
		else:m=material(colors[road]).duplicate()
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
		node.material_override=m
		add_child(node)
	var start:Dictionary=path.gate(0)
	var gantry:=model("start_gantry",PathData.world(start.point),PathData.heading(start.tangent))
	gantry.scale.x=2.05
	var banner:=Node3D.new()
	add_child(banner)
	banner.position=PathData.world(start.point)
	banner.rotation.y=PathData.heading(start.tangent)
	add_box(Vector3(0,5.4,0),Vector3(14.5,1.25,.32),Color("284d5a"),banner)
	for side in [-1,1]:
		var lettering:=Label3D.new()
		lettering.text="MICRO APEX / GRAND PRIX"
		lettering.font_size=64
		lettering.pixel_size=.012
		lettering.position=Vector3(0,5.4,side*.18)
		lettering.rotation.y=0 if side==1 else PI
		lettering.modulate=Color("e5e5ce")
		banner.add_child(lettering)
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
	district.build_details(self)
	gate_marker=Node3D.new()
	add_child(gate_marker)
	for side in [-1,1]:
		add_box(Vector3(side*(path.WIDTH*.5+1.0),2,0),Vector3(.18,4,.18),Color("ffd34e"),gate_marker)
	set_quality(quality)

func show_gate(index: int) -> void:
	var g:Dictionary=path.gate(index)
	gate_marker.position=PathData.world(g.point,g.height)
	gate_marker.rotation.y=PathData.heading(g.tangent)

func set_quality(quality:int) -> void:
	if is_instance_valid(decoration):
		decoration.visible=quality>0

func add_flat_strip(st:SurfaceTool,a:Vector2,b:Vector2,na:Vector2,nb:Vector2,inner:float,outer:float,ha:float,hb:float) -> void:
	ribbon_vertex(st,a+na*inner,b+nb*inner,b+nb*outer,Vector3(ha,hb,hb))
	ribbon_vertex(st,a+na*inner,b+nb*outer,a+na*outer,Vector3(ha,hb,ha))

func solid_cone(at:Vector3,bottom:float,top:float,height:float,tint:Color,parent:Node3D,segments:int=10) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var shape:=CylinderMesh.new()
	shape.bottom_radius=bottom
	shape.top_radius=top
	shape.height=height
	shape.radial_segments=segments
	node.mesh=shape
	node.material_override=material(tint)
	parent.add_child(node)
	node.position=at
	return node

func tint_model(node:Node, color:Color) -> void:
	if node is MeshInstance3D:
		node.material_override=material(color)
	for child in node.get_children():
		tint_model(child,color)

# Rounded toy trees and colorful track furniture establish the miniature club style.
func club_tree(p:Vector2, scale_factor:float, variant:int) -> void:
	var group:=Node3D.new()
	decoration.add_child(group)
	group.position=PathData.world(p)
	group.scale=Vector3.ONE*scale_factor
	add_box(Vector3(0,2,0),Vector3(.8,4,.8),Color("926951"),group)
	for at in [Vector3(-1.2,4.5,0),Vector3(1.2,4.8,.6),Vector3(0,6,-.4)]:
		var crown:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=2.6
		sphere.height=4.8
		sphere.radial_segments=12
		sphere.rings=6
		crown.mesh=sphere
		crown.material_override=material([Color("66b878"),Color("93ce79"),Color("43a68a")][variant%3])
		group.add_child(crown)
		crown.position=at

func pine_tree(p:Vector2, size:float, variant:int) -> void:
	var group:=Node3D.new()
	decoration.add_child(group)
	group.position=PathData.world(p)
	group.scale=Vector3.ONE*size
	solid_cone(Vector3(0,2,0),.4,.25,4,Color("796950"),group)
	for tier in range(3):
		solid_cone(Vector3(0,3.2+tier*1.9,0),3.3-tier*.7,.08,4.6-tier*.6,[Color("496e5c"),Color("63866a"),Color("7b9873")][(variant+tier)%3],group,9)

func palm_tree(p:Vector2, size:float, angle:float) -> void:
	var group:=Node3D.new()
	decoration.add_child(group)
	group.position=PathData.world(p)
	group.scale=Vector3.ONE*size
	group.rotation.y=angle
	var trunk:=solid_cone(Vector3(.35,3.2,0),.5,.28,6.4,Color("b29164"),group)
	trunk.rotation.z=-.1
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(7):
		var d:=Vector2(cos(i*TAU/7),sin(i*TAU/7))
		var n:=Vector2(-d.y,d.x)
		var base:=Vector2(.7,0)
		for tri in [[Vector3(base.x,6.2,base.y),PathData.world(base+d*2+n*.65,7),PathData.world(base+d*4.7,5.7)], [Vector3(base.x,6.2,base.y),PathData.world(base+d*4.7,5.7),PathData.world(base+d*2-n*.65,6.9)]]:
			for v in tri:st.add_vertex(v)
	st.generate_normals()
	var leaves:=MeshInstance3D.new()
	leaves.mesh=st.commit()
	var m:=material(Color("69a578")).duplicate() as StandardMaterial3D
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	leaves.material_override=m
	group.add_child(leaves)
