@tool
extends EditorScenePostImport
# Godot 4.7's glTF reader checks has_vertex_color before decoding the first
# primitive. Single-surface meshes need the flag baked into imported material.
func _post_import(scene:Node) -> Object:
 for node in scene.find_children("*","MeshInstance3D",true,false):
  for surface in range(node.mesh.get_surface_count()):
   var material=node.mesh.surface_get_material(surface)
   if material is BaseMaterial3D and not node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR].is_empty():
    material.vertex_color_use_as_albedo=true
 return scene
