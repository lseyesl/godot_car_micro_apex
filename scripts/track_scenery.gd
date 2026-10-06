extends RefCounted
# Compact roadside vignettes, all constrained to reserved circular footprints.
const GROUND=["b5c6a1","597952","bf8960","728b91","c6b393","cedce1"]
const ROAD=["526773","62695e","766354","495967","736c64","596e80"]
const DIRT=["bda579","918368","c18c60","918373","ab9678","9aaeb1"]
const EDGE=["4ba9a7","cfaa55","b9583e","d4ae51","b87678","619ab7"]
const VERGE=["d5c6a1","93a36c","d39f70","a4a998","ccb799","bed2db"]
var d
var count:=0
var sphere:=SphereMesh.new()
func _init(district) -> void:
	d=district
	sphere.radial_segments=12;sphere.rings=6
func ball(at:Vector3,size:float,tint:String,parent:Node3D) -> void:
	var mesh:=MeshInstance3D.new()
	mesh.mesh=sphere;mesh.scale=Vector3.ONE*size;mesh.position=at
	mesh.material_override=d.view.material(Color(tint));parent.add_child(mesh)
func block(at:Vector3,size:Vector3,tint:String,parent:Node3D) -> void:
	d.view.add_box(at,size,Color(tint),parent)
func build() -> void:
	# Close foreground repeats create a continuous inhabited edge, not isolated props.
	var samples:=int(d.path.length/5.5)
	for i in range(samples):
		var at:Dictionary=d.path.sample(d.path.length*(i+.4)/samples)
		var normal:=Vector2(-at.tangent.y,at.tangent.x)
		for side in [-1,1]:
			var p:Vector2=at.point+normal*side*10.4
			if d.path.height_at(at.s)>.2 or not d.available(p,1.05):continue
			d.reserve(p,1.05)
			var group:Node3D=d.group_at(p,d.PathData.heading(at.tangent))
			var tint:String=EDGE[d.path.index]
			if i%4==0:
				block(Vector3(0,1.6,0),Vector3(.13,3.2,.13),"68756b",group)
				block(Vector3(0,2.7,0),Vector3(.09,.85,1.4),tint,group)
			else:
				block(Vector3(0,.24,0),Vector3(.6,.48,1.7),VERGE[d.path.index],group)
				match d.path.index:
					0,4:
						for z in [-.5,0,.5]:
							ball(Vector3(0,.72,z),.8,"668753",group)
							ball(Vector3(0,1.1,z),.35,"e6bc6a" if d.path.index==0 else "ca7d91",group)
					1,5:
						for tier in range(3):d.view.solid_cone(Vector3(0,.9+tier*.7,0),.8-tier*.17,.03,1.4,Color("719068" if d.path.index==1 else "9eb9b4"),group,10)
					2:
						block(Vector3(0,1.1,0),Vector3(.45,1.8,.45),"72916a",group)
						block(Vector3(0,1.2,0),Vector3(.4,.35,1.2),"72916a",group)
						ball(Vector3(0,2,0),.45,"72916a",group)
					3:
						for z in [-.45,.45]:d.view.solid_cone(Vector3(0,.9,z),.38,.38,1.2,Color("d09e56"),group,12)
			count+=1
	# Fill the land between buildings and hairpins with theme-specific small clusters.
	for x in range(-109,111,7):
		for z in range(-109,111,7):
			var p:=Vector2(x+d.rng.randf_range(-1,1),z+d.rng.randf_range(-1,1))
			var distance:float=d.path.nearest(p).distance
			if distance>40 or not d.available(p,2.8):continue
			d.reserve(p,2.8)
			vignette(p,count)
			count+=1
	d.set_meta("theme_scenery_count",count)
func vignette(p:Vector2,index:int) -> void:
	var group:Node3D=d.group_at(p,float(index%4)*PI*.5)
	match d.path.index:
		0: # Riviera: palms, striped parasols, cafe terraces and flower beds.
			if index%3==0:
				d.view.palm_tree(p,.52,float(index));return
			block(Vector3(0,.06,0),Vector3(3.8,.12,3.8),"d9cba6",group)
			block(Vector3(0,1.2,0),Vector3(.13,2.4,.13),"8f8060",group)
			d.view.solid_cone(Vector3(0,2.5,0),1.9,.3,.6,Color("e5a76e" if index%2 else "67aaa5"),group,12)
			d.view.solid_cone(Vector3(0,.9,0),.7,.7,.15,Color("e6d3aa"),group,12)
			for side in [-1,1]:block(Vector3(side*1.25,.4,0),Vector3(.7,.8,.75),"709999",group)
		1: # Woodland: close groves, mushrooms and cut timber.
			d.art_tree(p,.48,true)
			for side in [-1,1]:
				ball(Vector3(side*1.4,.4,1),.85,"76954d",group)
				block(Vector3(side*.9,.28,-1.4),Vector3(.25,.55,.25),"e5cf9f",group)
				d.view.solid_cone(Vector3(side*.9,.58,-1.4),.52,.1,.3,Color("ba6c4f"),group,10)
		2: # Red rock: layered sandstone, cactus and dry tufts.
			var rock:Node3D=d.view.model("district_outcrop",Vector3(-.6,0,0),float(index),group)
			rock.scale=Vector3(1.5,1.5+index%3*.5,1.5)
			d.apply_surface(rock,d.view.miniature_material("marble_cliff_02",.3,Color("bf7854"),.17))
			block(Vector3(1.5,1.15,0),Vector3(.45,2.3,.45),"72916a",group)
			block(Vector3(1.05,1.25,0),Vector3(.8,.35,.35),"72916a",group)
			block(Vector3(.8,1.6,0),Vector3(.3,.8,.3),"72916a",group)
			ball(Vector3(1.5,2.3,0),.45,"72916a",group)
		3: # Working port: pallets, drums, safety paint and buoy stacks.
			block(Vector3(0,.1,0),Vector3(3.8,.2,3.8),"c9af63",group)
			for side in [-1,1]:
				block(Vector3(side*.95,.3,0),Vector3(1.6,.25,2.4),"997952",group)
				for z in [-.6,.6]:
					d.view.solid_cone(Vector3(side*.95,.95,z),.48,.48,1.1,Color("779a9e" if index%2 else "b77453"),group,12)
		4: # Market: vivid flower carts, produce crates and festival flags.
			block(Vector3(0,.85,0),Vector3(3,1.3,1.5),"b4855a",group)
			for side in [-1,1]:
				ball(Vector3(side*1.25,.4,.8),.65,"58696b",group)
				block(Vector3(side*1.3,1.8,0),Vector3(.12,2.8,.12),"806b50",group)
			block(Vector3(0,3.1,0),Vector3(3.5,.25,2.4),"bd7474" if index%2 else "d6b564",group)
			for x in [-1,0,1]:ball(Vector3(x,1.65,0),.7,["e2b954","b95e69","88a164"][posmod(index+x,3)],group)
		5: # Alpine: snow-covered fir groves and red trail markers.
			d.art_tree(p,.48,true)
			for side in [-1,1]:ball(Vector3(side*1.1,.3,1),1.0,"dfebeb",group)
			block(Vector3(1.5,1.25,-1),Vector3(.15,2.5,.15),"ae6255",group)
			block(Vector3(1.5,2.3,-1),Vector3(1.3,.4,.18),"709cac",group)
