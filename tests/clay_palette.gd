extends SceneTree
const Style=preload("res://scripts/model_style.gd")
const View=preload("res://scripts/track_view.gd")
const Main=preload("res://scripts/main.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var color=Color("ce6852");var view=View.new()
 if Style.is_clay():
  check(Style.clay_color(color).s>color.s,"Chromatic clay no longer whitened")
  check(Style.clay_color(Color.WHITE)==Color.WHITE and Style.clay_color(Color("182d38"))==Color("182d38"),"Neutral markings and dark contrast retained")
 else:
  check(Style.clay_color(color)==color.lerp(Color("f1dfb9") if Style.is_paper() else Color("f4f2eb"),.18),"Legacy style tint unchanged")
 var grass=view.miniature_material("grass_ground",1,Color.WHITE).get_shader_parameter("tint")
 var expected=Color("64bd45") if Style.is_clay() else (Color("b2cd91") if Style.is_paper() else Color.WHITE)
 check(grass.is_equal_approx(expected.srgb_to_linear().lerp(expected,.15)),"Grass follows selected style only")
 check((grass.g>grass.r and grass.g>grass.b) if Style.is_crafted() else grass==Color.WHITE,"Craft ground green; original texture tint unchanged")
 var asphalt=view.miniature_material("clean_asphalt",1,Color.WHITE).get_shader_parameter("tint")
 expected=Color("435f73") if Style.is_clay() else (Color("71818b") if Style.is_paper() else Color.WHITE)
 check(asphalt.is_equal_approx(expected.srgb_to_linear().lerp(expected,.15)),"Neutral road contrast preserved")
 var game=Main.new();game.saved=Store.new("/tmp/clay-color-%d.cfg"%OS.get_process_id());root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for child in game.get_children():
  if child is WorldEnvironment:
   check(child.environment.tonemap_mode==Environment.TONE_MAPPER_LINEAR,"No exposure or tonemap trick")
   check(is_equal_approx(child.environment.ambient_light_energy,.46 if Style.is_crafted() else .42),"Lighting unchanged")
 check(is_equal_approx(game.sun.light_energy,.85),"Sun energy unchanged")
 view.free();game.queue_free()
 for i in range(8):await process_frame
 print("CLAY_PALETTE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
