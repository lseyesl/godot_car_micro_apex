extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const View=preload("res://scripts/track_view.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i(1500,540)
	root.size=Vector2i(1500,540)
	for i in range(3):
		var container:=SubViewportContainer.new()
		container.position=Vector2(i*500,0)
		root.add_child(container)
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(500,540)
		viewport.own_world_3d=true
		container.add_child(viewport)
		var view=View.new()
		viewport.add_child(view)
		view.build(Track.new(i),1)
		var env:=WorldEnvironment.new()
		env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color("15232b")
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color=Color.WHITE
		env.environment.ambient_light_energy=.25
		viewport.add_child(env)
		var sun:=DirectionalLight3D.new()
		viewport.add_child(sun)
		sun.rotation_degrees=Vector3(-55,-30,0)
		sun.light_energy=.65
		sun.directional_shadow_max_distance=1000
		sun.shadow_enabled=true
		var camera:=Camera3D.new()
		viewport.add_child(camera)
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=570
		camera.far=2000
		camera.position=Vector3(0,650,200)
		camera.look_at(Vector3.ZERO)
		camera.current=true
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/square-tracks.png")
	quit()
