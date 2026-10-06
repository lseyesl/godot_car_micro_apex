extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const View=preload("res://scripts/track_view.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for index in range(Catalog.TRACKS.size()):
		var track=Track.new(index)
		var view=View.new()
		root.add_child(view)
		view.build(track,1)
		var district=view.get_child(1)
		check(district.get_script()==preload("res://scripts/track_district.gd"),"District must be the active scenery builder")
		print("SCENERY track=%d groups=%d"%[index,district.get_meta("theme_scenery_count",0)])
		check(int(district.get_meta("theme_scenery_count",0))>=40,"Each theme must populate at least forty reserved roadside groups")
		check(district.plots.size()>=20,"Circuit must have populated district plots")
		var clear_road:=true
		var clear_plots:=true
		for plot in district.plots:
			clear_road=clear_road and track.nearest(plot.point).distance>track.WIDTH*.5+plot.radius
			for other in district.plots:
				if plot==other:continue
				clear_plots=clear_plots and plot.point.distance_to(other.point)>=plot.radius+other.radius
		check(clear_road,"Entire landmark footprint must clear road")
		check(clear_plots,"Landmark reservations must not overlap")
		await process_frame
		var batches:=0
		for child in view.decoration.get_children():
			if child is MultiMeshInstance3D:batches+=1
		check(batches>0,"Architecture must use instanced material batches")
		view.set_quality(0)
		check(not view.decoration.visible,"Low quality must hide district detail")
		view.queue_free()
		await process_frame
	var file:="/tmp/apex-district-%d.cfg"%OS.get_process_id()
	var store=Store.new(file)
	store.config.set_value("records_mini_v5","0_3",32.0)
	store.config.set_value("career","credits",9000)
	check(not is_finite(store.best(0,3)),"New geometry must not compare old route records")
	check(store.record(0,3,45.0),"New route record must save")
	store=Store.new(file)
	check(store.best(0,3)==45.0,"New route record must reload")
	check(store.config.get_value("records_mini_v5","0_3")==32.0,"Old record must remain archived")
	check(store.config.get_value("career","credits")==9000,"Map change must retain wallet")
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	print("DISTRICT_LAYOUT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
