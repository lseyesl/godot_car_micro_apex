extends RefCounted
# Export preparation seals this config. Device environment variables cannot alter a package.
const STYLES=["original","bright_clay"]
const ENVIRONMENT_VARIABLE="MICRO_APEX_MODEL_STYLE"
const CONFIG_PATH="res://config/model_style.json"
static var _cached_style:=""
static func selected() -> String:
	if not _cached_style.is_empty():return _cached_style
	var data=JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not data is Dictionary or data.get("format")!=1 or not data.get("locked") is bool:
		push_error("Invalid or missing model style build config")
		_cached_style="invalid";return _cached_style
	var value:String=str(data.get("model_style",""))
	if not data.locked and OS.has_feature("editor") and not OS.has_feature("android") and OS.has_environment(ENVIRONMENT_VARIABLE):
		value=OS.get_environment(ENVIRONMENT_VARIABLE).strip_edges()
	if value not in STYLES:
		push_error("Unsupported model style: %s. Expected original or bright_clay."%value)
		_cached_style="invalid";return _cached_style
	_cached_style=value
	return value
static func is_clay() -> bool:return selected()=="bright_clay"
static func model_path(id:String) -> String:
	return model_path_for(selected(),id)
static func model_path_for(style:String,id:String) -> String:
	assert(style in STYLES,"Invalid model style")
	return ("res://assets/styles/bright_clay/models/" if style=="bright_clay" else "res://assets/models/")+id+".glb"
static func clay_color(color:Color) -> Color:
	# Keep wheels, signs and road markings readable against a high-key environment.
	if color.get_luminance()<.10:return color.lerp(Color("526674"),.45)
	return color.lerp(Color("f4f2eb"),.18)
