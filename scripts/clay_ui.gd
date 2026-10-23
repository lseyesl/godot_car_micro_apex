extends RefCounted
# Shared, cached paint only. ModelStyle also selects the locked Android UI flavor.
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
static func active() -> bool:return Style.is_clay()
static func text_color(source:Color) -> Color:
 if source in [Color("ffd34e"),Color("ffc857")]:return ACCENT
 if source==Color("68dec5"):return Color("256654")
 if source==Color("ff9980"):return Color("a33c30")
 if source in [Color("99b1ca"),Color("c6d5e5")]:return MUTED
 return INK
static func box(role:String="panel",state:String="normal",accent:bool=false) -> StyleBoxFlat:
 var key=role+state+str(accent)
 if _boxes.has(key):return _boxes[key]
 var s=StyleBoxFlat.new()
 s.bg_color=PAPER if role=="panel" else (PEACH if accent else MINT)
 s.border_color=Color("b5c6ad") if role=="panel" else Color("6d9883")
 s.set_corner_radius_all(22 if role=="panel" else (28 if role=="touch" else 18))
 s.set_border_width_all(2);s.border_width_bottom=5 if role!="panel" else 3
 s.set_content_margin_all(16 if role=="panel" else 8)
 s.content_margin_left=18;s.content_margin_right=18
 # One small shadow; no blur shaders or extra control nodes.
 s.shadow_color=Color(.16,.25,.20,.14);s.shadow_size=2;s.shadow_offset=Vector2(0,2)
 if state=="hover":s.bg_color=s.bg_color.lightened(.10);s.border_color=Color("437c67")
 elif state=="pressed":
  s.bg_color=Color("e8af84") if accent else Color("92c5ac")
  s.border_width_bottom=2;s.border_width_top=4;s.shadow_size=0
 elif state=="disabled":
  s.bg_color=Color("e4e4d7");s.border_color=Color("b4bdb0");s.shadow_size=0
 elif state=="focus":
  s.bg_color=Color(0,0,0,0);s.border_color=Color("437c67");s.set_border_width_all(3);s.shadow_size=0
 _boxes[key]=s
 return s
static func panel() -> StyleBoxFlat:
 # Callers sometimes adjust margins; never expose the shared prototype to edits.
 return box().duplicate()
static func apply_button(button:Button,accent:bool=false) -> void:
 for state in ["normal","hover","pressed","focus","disabled"]:
  button.add_theme_stylebox_override(state,box("button",state,accent))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
  button.add_theme_color_override(state,INK)
 button.add_theme_color_override("font_disabled_color",Color("5d685e"))
static func touch_box(action:String,pressed:bool) -> StyleBoxFlat:
 return box("touch", "pressed" if pressed else "normal", action=="brake")
static func theme(font:Font) -> Theme:
 var result=Theme.new();result.default_font=font;result.default_font_size=18
 result.set_color("default_color","RichTextLabel",INK)
 result.set_color("font_color","Label",INK)
 return result
