extends Control

var fingers:Dictionary={}
var mouse_action:=""
var enabled:=false
var reset_held:=0.0
var areas:Dictionary={}
var font:Font
var auto_throttle:=false
var large:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font=ThemeDB.fallback_font
	resized.connect(queue_redraw)

func layout() -> void:
	var h:=minf(126.0 if large else 100.0,size.y*.20)
	var bottom:=size.y-26
	areas={"left":Rect2(28,bottom-h,h,h),"right":Rect2(42+h,bottom-h,h,h),"brake":Rect2(size.x-44-2*h,bottom-h,h,h),"throttle":Rect2(size.x-28-h,bottom-h,h,h),"reset":Rect2(size.x-132,115,104,48)}

func action_at(p:Vector2) -> String:
	layout()
	for key in areas:
		if areas[key].has_point(p):
			return key
	return ""

func _input(event:InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var action:=action_at(get_global_transform_with_canvas().affine_inverse()*event.position)
			if action!="":
				fingers[event.index]=action
		else:
			fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		if fingers.has(event.index):
			fingers[event.index]=action_at(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		mouse_action=action_at(get_global_transform_with_canvas().affine_inverse()*event.position) if event.pressed else ""
	elif event is InputEventMouseMotion and mouse_action!="":
		mouse_action=action_at(get_global_transform_with_canvas().affine_inverse()*event.position)
	queue_redraw()

func held(action:String) -> bool:
	if not enabled:
		return false
	if action in fingers.values() or mouse_action==action:
		return true
	match action:
		"left": return Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
		"right": return Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
		"throttle": return Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
		"brake": return Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_SPACE)
		"reset": return Input.is_physical_key_pressed(KEY_R)
	return false

func driving() -> Dictionary:
	return {"steer":float(held("right"))-float(held("left")),"throttle":held("throttle") or (enabled and auto_throttle and not held("brake")),"brake":held("brake")}

func clear() -> void:
	fingers.clear()
	mouse_action=""
	reset_held=0.0
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	layout()
	for key in areas:
		var rect:Rect2=areas[key]
		var active:=held(key)
		var fill:=Color(.06,.14,.24,.78)
		if active:
			fill=Color("ffd34e")
		draw_style_box(style(fill,Color("6d9cbb") if not active else Color("fff0a3")),rect)
		var text:String={"left":"◀","right":"▶","brake":"BRAKE","throttle":"GAS","reset":"RESET"}[key]
		if key in ["left","right"]:
			var center:=rect.get_center()
			var direction:=1.0 if key=="right" else -1.0
			draw_colored_polygon(PackedVector2Array([center+Vector2(12*direction,0),center+Vector2(-9*direction,-13),center+Vector2(-9*direction,13)]),Color("122015") if active else Color("f0eee6"))
			continue
		var font_size:=20 if key in ["brake","reset"] else 27
		var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,rect.get_center()+Vector2(-width*.5,font_size*.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("122015") if active else Color("f0eee6"))
		if key=="reset" and reset_held>0:
			draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-4),Vector2(rect.size.x*minf(reset_held/1.2,1),4)),Color("ffd34e"))

func style(fill:Color,border:Color) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=border
	s.set_border_width_all(3)
	s.set_corner_radius_all(32)
	s.shadow_color=Color(0,0,.02,.25)
	s.shadow_size=4
	s.shadow_offset=Vector2(0,4)
	return s
