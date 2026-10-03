extends Node3D
# Bounded skid pool: each update replaces one instance instead of growing nodes.
var marks:MultiMeshInstance3D
var mesh:MultiMesh
var cursor:=0
var previous:Dictionary={}
var enabled:=true
const CAPACITY:=360
func _ready() -> void:
	marks=MultiMeshInstance3D.new()
	mesh=MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_3D
	var quad:=QuadMesh.new()
	quad.size=Vector2(.20,.7)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(.08,.10,.12,.42)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	quad.material=material
	mesh.mesh=quad
	mesh.instance_count=CAPACITY
	for i in range(CAPACITY):mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
	marks.multimesh=mesh
	marks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)
func sample(cars:Array) -> void:
	if not enabled:return
	for car in cars:
		if car.dynamics.slip<2.8 or car.dynamics.velocity.length()<7 or car.dynamics.surface!="asphalt":continue
		var id:int=car.get_instance_id()
		var at:Vector3=car.position
		if previous.has(id) and previous[id].distance_to(at)<.55:continue
		previous[id]=at
		var side:=Vector3(cos(car.dynamics.yaw),0,-sin(car.dynamics.yaw))*.63
		for offset in [-side,side]:
			var basis:=Basis(Vector3.UP,car.dynamics.yaw)*Basis(Vector3.RIGHT,-PI*.5)
			mesh.set_instance_transform(cursor,Transform3D(basis,at+offset+Vector3(0,-.015,0)))
			cursor=(cursor+1)%CAPACITY
