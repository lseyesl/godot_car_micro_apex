extends RefCounted
const Path=preload("res://scripts/track_path.gd")
const COLORS=["739d9b","997953","b78d63","d3aa51","b8a387","799cab"]
static func segment(view,a:Vector2,b:Vector2,na:Vector2,nb:Vector2,ha:float,hb:float,index:int) -> void:
	var path=view.path
	var feature:Dictionary=path.feature_at((path.distances[index]+path.distances[index+1])*.5)
	if feature.is_empty() or maxf(ha,hb)<.08:return
	var tint:=Color(COLORS[path.index])
	if feature.kind=="hill":
		# Continuous filled shoulders communicate an earth ramp, not a floating ribbon.
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1,1]:
			var top_a:Vector2=a+na*(path.WIDTH*.5+2.9)*side
			var top_b:Vector2=b+nb*(path.WIDTH*.5+2.9)*side
			var foot_a:Vector2=a+na*(path.WIDTH*.5+3.0)*side
			var foot_b:Vector2=b+nb*(path.WIDTH*.5+3.0)*side
			view.ribbon_vertex(st,top_a,top_b,foot_b,Vector3(ha,hb,-.06))
			view.ribbon_vertex(st,top_a,foot_b,foot_a,Vector3(ha,-.06,-.06))
		var mesh:=MeshInstance3D.new();mesh.mesh=st.commit()
		mesh.material_override=view.miniature_material("brown_mud_dry",.25,tint,.2)
		view.add_child(mesh)
		return
	var midpoint:Vector2=(a+b)*.5
	var normal:Vector2=(na+nb).normalized()
	var span:=a.distance_to(b)
	for side in [-1,1]:
		var edge:Vector2=midpoint+normal*(path.WIDTH*.5+1.25)*side
		for level in [-.5,1.35]:
			var beam:MeshInstance3D=view.add_box(Path.world(edge,(ha+hb)*.5+level),Vector3(.3,.28,span+.12),tint)
			beam.rotation=Vector3(atan2(hb-ha,span),Path.heading((b-a).normalized()),0)
		if index%4==0:
			view.add_box(Path.world(edge,(ha+hb)*.5+.5),Vector3(.4,1.9,.4),tint)
			var height:float=(ha+hb)*.5
			if height>1.4 and path.nearest(edge).distance>path.WIDTH*.5:
				view.add_box(Path.world(edge,height*.5-.25),Vector3(1.2,height,1.2),tint.darkened(.12))
				view.add_box(Path.world(edge,.05),Vector3(2,.25,2),tint.darkened(.2))
static func signs(view) -> void:
	for feature in view.path.elevations:
		for entry in [0,3]:
			var s:float=feature.stops[entry]
			if view.path.reversed:s=view.path.length-s
			var pose:Dictionary=view.path.sample(s)
			var normal:=Vector2(-pose.tangent.y,pose.tangent.x)
			var group:=Node3D.new();view.add_child(group)
			group.position=Path.world(pose.point+normal*8.5,pose.height)
			group.rotation.y=Path.heading(pose.tangent)+(PI if entry==3 else 0.0)
			view.add_box(Vector3(0,1.3,0),Vector3(.15,2.6,.15),Color("667978"),group)
			view.add_box(Vector3(0,2.7,0),Vector3(2.1,.95,.15),Color("e2ba65"),group)
			var label:=Label3D.new();label.text="BRIDGE" if feature.kind=="bridge" else "CREST"
			label.font_size=56;label.pixel_size=.006;label.modulate=Color("283b45")
			label.position=Vector3(0,2.7,.1);group.add_child(label)
