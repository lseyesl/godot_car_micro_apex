extends RefCounted
# Identical placements for both art styles. No collision or moving gameplay nodes.
const PathData=preload("res://scripts/track_path.gd")
const PARCELS=[Vector2(94,143),Vector2(-45,-145)]
static func skyline_clear(point:Vector2) -> bool:
 for parcel in PARCELS:
  if point.distance_to(parcel)<46.0:return false
 return true
const LANDMARKS=[
 ["prop_ferris_wheel","prop_market_hall"],
 ["prop_pavilion","prop_clock_tower"],
 ["prop_market_hall","prop_clock_tower"],
 ["prop_ferris_wheel","prop_pavilion"],
 ["prop_clock_tower","prop_market_hall"],
 ["prop_pavilion","prop_clock_tower"]]
static func landmarks(d) -> void:
 var placed:Array[Dictionary]=[]
 for i in range(2):
  var id:String=LANDMARKS[d.path.index][i]
  var radius:float=16.0 if id=="prop_ferris_wheel" else 12.0
  var p:Vector2=d.fit_landmark(PARCELS[i],radius)
  if not p.is_finite():continue
  d.reserve(p,radius)
  var node:Node3D=d.view.model(id,PathData.world(p),0,d.props)
  node.set_meta("scenery_addition",id)
  for side in [-1,1]:
   d.art_tree(p+Vector2(side*(12.0 if id=="prop_ferris_wheel" else 9.0),6.0 if id=="prop_ferris_wheel" else 5.0),.4,d.path.index in [1,5])
  placed.append({"id":id,"point":p,"radius":radius})
 d.set_meta("new_landmarks",placed)
static func greenery(d) -> void:
 var placed:Array[Dictionary]=[]
 # Fixed budget, separate deterministic sequence: do not consume the legacy RNG.
 for i in range(96):
  var at:Dictionary=d.path.sample(d.path.length*(i+.65)/96.0)
  if d.path.height_at(at.s)>.2:continue
  var normal:=Vector2(-at.tangent.y,at.tangent.x)
  for side in [-1,1]:
   if placed.size()>=48:break
   var shrub:bool=placed.size()%3==0
   var radius:float=2.4 if shrub else .8
   var p:Vector2=at.point+normal*float(side)*(14.0 if shrub else 11.8)
   if not d.available(p,radius):continue
   d.reserve(p,radius)
   var id:String=("foliage_shrub_flower" if i%2==0 else "foliage_shrub_round") if shrub else ("foliage_grass_dry" if d.path.index in [2,5] else "foliage_grass_green")
   var node:Node3D=d.view.model(id,PathData.world(p),i*2.399,d.props)
   node.set_meta("scenery_addition",id)
   placed.append({"id":id,"point":p,"radius":radius})
 d.set_meta("new_greenery",placed)
static func leaf_clusters(d,tree:Node3D) -> void:
 for side in [-1,1]:
  var leaf:Node3D=d.view.model("foliage_leaf_cluster",Vector3(side*.55,4.7,0),0,tree)
  leaf.scale=Vector3.ONE*.55
 d.set_meta("new_leaf_clusters",int(d.get_meta("new_leaf_clusters",0))+2)
