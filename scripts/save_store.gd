extends RefCounted

const RECORD_SECTION := "records_mini_v5"

var path:="user://micro_apex.cfg"
var config:=ConfigFile.new()

func _init(custom_path:String="user://micro_apex.cfg") -> void:
	path=custom_path
	config.load(path)

func setting(key:String, fallback):
	return config.get_value("settings",key,fallback)

func set_setting(key:String,value) -> void:
	config.set_value("settings",key,value)
	_save()

func best(track:int,car:int) -> float:
	return float(config.get_value(RECORD_SECTION,"%d_%d"%[track,car],INF))

func record(track:int,car:int,time:float) -> bool:
	if not is_finite(time) or time<=0.0 or time>=best(track,car):
		return false
	config.set_value(RECORD_SECTION,"%d_%d"%[track,car],time)
	_save()
	return true

func _save() -> void:
	var error:=config.save(path)
	if error!=OK:
		push_warning("Cannot save settings: %s"%error_string(error))
