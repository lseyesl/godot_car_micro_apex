extends RefCounted
const CraftUI=preload("res://scripts/clay_ui.gd")
# Safe-area coordinates are display pixels; windows can already exclude system bars.
static func safe_content_rect(window:Rect2i,safe:Rect2i,canvas:Vector2) -> Rect2:
 var full:=Rect2(Vector2.ZERO,canvas)
 if not window.has_area() or not safe.has_area():return full
 var clipped:=window.intersection(safe)
 if not clipped.has_area():return full
 var scale:=canvas/Vector2(window.size)
 return Rect2(Vector2(clipped.position-window.position)*scale,Vector2(clipped.size)*scale)

static func configure_scroll(scroll:ScrollContainer) -> void:
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone=12
 var bar:=scroll.get_v_scroll_bar()
 # ScrollContainer reserves theme minimum width, not custom_minimum_size.
 for key in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
  var paint:StyleBox
  if CraftUI.active():
   paint=CraftUI.box("scroll","pressed" if key=="grabber_pressed" else "normal",key!="scroll").duplicate()
   paint.bg_color=CraftUI.background() if key=="scroll" else paint.bg_color
   paint.border_width_bottom=1
  else:paint=bar.get_theme_stylebox(key).duplicate()
  paint.content_margin_left=12;paint.content_margin_right=12
  bar.add_theme_stylebox_override(key,paint)
