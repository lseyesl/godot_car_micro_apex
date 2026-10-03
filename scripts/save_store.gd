extends RefCounted

const RECORD_SECTION := "records_district_v6"
var path := "user://micro_apex.cfg"
var config := ConfigFile.new()
var last_error := OK
var recovered_from_backup := false
var load_failed := false

func _init(custom_path:String="user://micro_apex.cfg") -> void:
	path=custom_path
	var status:=config.load(path)
	if status==OK:
		return
	if FileAccess.file_exists(path+".bak") and config.load(path+".bak")==OK:
		recovered_from_backup=true
		return
	config=ConfigFile.new()
	load_failed=status!=ERR_FILE_NOT_FOUND
	last_error=status if load_failed else OK

func setting(key:String, fallback):
	var value=config.get_value("settings",key,fallback)
	return value if typeof(value)==typeof(fallback) else fallback

func set_setting(key:String,value) -> bool:
	return transaction(func(): config.set_value("settings",key,value))

func best(track:int,car:int,variant:String="") -> float:
	var value=config.get_value(RECORD_SECTION,"%d_%d%s"%[track,car,variant],INF)
	return float(value) if (value is float or value is int) and float(value)>0 else INF

func record(track:int,car:int,time:float,variant:String="") -> bool:
	if not is_finite(time) or time<=0.0 or time>=best(track,car,variant):
		return false
	return transaction(func(): config.set_value(RECORD_SECTION,"%d_%d%s"%[track,car,variant],time))

# Wallet, unlock and event receipt mutations are committed together or rolled back.
func transaction(change:Callable) -> bool:
	if load_failed:
		return false
	var before:=config.encode_to_text()
	change.call()
	if _save()==OK:
		return true
	config=ConfigFile.new()
	config.parse(before)
	return false

func _save() -> Error:
	var absolute:=ProjectSettings.globalize_path(path)
	var temporary:=absolute+".tmp"
	last_error=config.save(temporary)
	if last_error!=OK:
		return last_error
	var verification:=ConfigFile.new()
	last_error=verification.load(temporary)
	if last_error!=OK:
		return last_error
	# Preserve the last valid primary. Never replace a good backup with a corrupt file.
	var old:=ConfigFile.new()
	if FileAccess.file_exists(absolute) and old.load(absolute)==OK:
		last_error=old.save(absolute+".bak.tmp")
		if last_error==OK:
			last_error=DirAccess.rename_absolute(absolute+".bak.tmp",absolute+".bak")
		if last_error!=OK:
			return last_error
	last_error=DirAccess.rename_absolute(temporary,absolute)
	return last_error

# Called only after an explicit in-game recovery confirmation. Preserve both originals.
func reset_damaged_profile() -> bool:
	if not load_failed:return false
	var absolute:=ProjectSettings.globalize_path(path)
	var stamp:=str(Time.get_unix_time_from_system()).replace(".","-")
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(absolute+suffix):
			last_error=DirAccess.copy_absolute(absolute+suffix,absolute+suffix+".damaged-"+stamp)
			if last_error!=OK:return false
	config=ConfigFile.new()
	load_failed=false
	if _save()!=OK:
		load_failed=true
		return false
	return true
