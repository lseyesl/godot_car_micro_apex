extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Track=preload("res://scripts/track_path.gd")
const Career=preload("res://scripts/career.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():
 var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_routes.json"))
 for i in range(6):
  check(JSON.stringify(Catalog.TRACKS[i])==legacy.tracks[i],"Legacy track definition/order unchanged")
  check(hash(Track.new(i).points)==int(legacy.point_hashes[i]),"Legacy sampled geometry unchanged")
 for i in range(36):check(JSON.stringify(Career.event(i))==legacy.events[i],"Legacy career events/unlocks/rewards unchanged")
 var file="/tmp/apex-route-compatibility-%d.cfg"%OS.get_process_id();var store=Store.new(file)
 store.config.set_value("career","credits",4567);store.config.set_value("events","stars_35",3)
 check(store.record(0,3,45),"Existing track record persists")
 check(store.record(9,3,33,"_reverse"),"New route reverse record persists separately")
 store=Store.new(file)
 check(store.best(0,3)==45 and store.best(9,3,"_reverse")==33,"Old/new direction record keys do not collide")
 check(store.config.get_value("career","credits")==4567 and Career.new(store).stars(35)==3,"Wallet and old career stars survive")
 for suffix in ["",".bak"]:
  if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
 print("ROUTE_COMPATIBILITY checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
