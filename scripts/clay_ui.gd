extends RefCounted
# Shared, cached paint only. ModelStyle also selects the locked Android UI flavor.
const CraftBox=preload("res://scripts/craft_box.gd")
const Style=preload("res://scripts/model_style.gd")
const INK=Color("28433d")
const MUTED=Color("53665c")
const CREAM=Color("fff8e8")
const PAPER=Color("fffdf5")
const MINT=Color("c7e6d4")
const PEACH=Color("f5c49c")
const EDGE=Color("98b7a3")
const ACCENT=Color("8a4b2f")
static var _boxes:Dictionary={}
static func active() -> bool:return Style.is_crafted()
static func background() -> Color:return Color("ebdcc0") if Style.is_paper() else Color("f2e8cc")
static func overlay_color() -> Color:return Color(.88,.83,.72,.96) if Style.is_paper() else Color(.88,.91,.77,.96)
static func text_color(source:Color) -> Color:
 if source in [Color("ffd34e"),Color("ffc857")]:return ACCENT
 if source==Color("68dec5"):return Color("256654")
 if source==Color("ff9980"):return Color("a33c30")
 if source in [Color("99b1ca"),Color("c6d5e5")]:return MUTED
 return INK
static func box(role:String="panel",state:String="normal",accent:bool=false) -> StyleBox:
 var key=Style.selected()+role+state+str(accent)
 if _boxes.has(key):return _boxes[key]
 var s=CraftBox.new();s.paper=Style.is_paper();s.role=role;s.state=state
 s.bg_color=(Color("fff9e9") if role=="panel" else (Color("f0ce9e") if accent else Color("eee1bf"))) if s.paper else (Color("f8f1d9") if role=="panel" else (Color("edb58b") if accent else Color("bed493")))
 s.border_color=Color("9b8464") if s.paper else Color("819563")
 s.border_width_bottom=4 if s.paper else 7
 s.corner_radius_top_left=0 if s.paper else 22
 s.set_content_margin_all(16 if role=="panel" else 8)
 s.content_margin_left=18;s.content_margin_right=24 if s.paper else 18
 if state=="hover":s.bg_color=s.bg_color.lightened(.08)
 elif state=="pressed":s.bg_color=s.bg_color.darkened(.09);s.border_width_bottom=1
 elif state=="disabled":s.bg_color=Color("e4e4d7");s.border_color=Color("b4bdb0");s.border_width_bottom=2
 _boxes[key]=s
 return s
static func panel() -> StyleBox:
 # Callers sometimes adjust margins; never expose the shared prototype to edits.
 return box().duplicate()
static func apply_button(button:Button,accent:bool=false) -> void:
 for state in ["normal","hover","pressed","focus","disabled"]:
  button.add_theme_stylebox_override(state,box("button",state,accent))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
  button.add_theme_color_override(state,INK)
 button.add_theme_color_override("font_disabled_color",Color("5d685e"))
 button.add_theme_color_override("font_shadow_color",Color("fff9e9") if not Style.is_paper() else Color(0,0,0,0))
 button.add_theme_constant_override("shadow_offset_y",-1 if not Style.is_paper() else 0)
static func touch_box(action:String,pressed:bool,locked:bool=false) -> StyleBox:
 return box("touch", "pressed" if pressed else ("disabled" if locked else "normal"), action=="brake")
static func theme(font:Font) -> Theme:
 var result=Theme.new();result.default_font=font;result.default_font_size=18
 result.set_color("default_color","RichTextLabel",INK)
 result.set_color("font_color","Label",INK)
 return result
static func draw_arrow(control:CanvasItem,points:PackedVector2Array,pressed:bool) -> void:
 var shadow:=PackedVector2Array()
 for p in points:shadow.append(p+Vector2(0,2 if Style.is_paper() else 1))
 control.draw_colored_polygon(shadow,Color("fff6dd") if Style.is_paper() else Color("768456"))
 control.draw_colored_polygon(points,INK)
 if Style.is_paper():
  control.draw_line(points[0],points[1].lerp(points[2],.5),Color("dfcda6"),1.2,true)
 else:
  control.draw_line(points[1]+Vector2(0,-1),points[0]+Vector2(0,-1),Color("e3ecca") if not pressed else Color("b0c080"),1.1,true)
