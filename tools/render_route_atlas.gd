extends SceneTree
const Track=preload("res://scripts/track_path.gd")
const Catalog=preload("res://scripts/catalog.gd")
class Atlas extends Control:
 var font=load("res://assets/fonts/NotoSansCJK-Regular.ttc")
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("101c2d"))
  draw_string(font,Vector2(24,36),"MICRO APEX · 实际赛道中心线 / Godot 顶视",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
  for i in range(Catalog.TRACKS.size()):
   var path=Track.new(i);var origin:=Vector2(14+(i%5)*318,58+int(i/5)*380)
   var color:=Color("68dec5") if i>=6 else Color("9aa9bc")
   draw_style_box(panel(),Rect2(origin,Vector2(306,365)))
   draw_string(font,origin+Vector2(12,30),"%02d  %s"%[i+1,Catalog.TRACKS[i].name],HORIZONTAL_ALIGNMENT_LEFT,-1,21,color)
   var center:=origin+Vector2(153,180);var route:=PackedVector2Array()
   for p in path.points:route.append(center+p*.99)
   route.append(route[0]);draw_polyline(route,Color("263b50"),14,true);draw_polyline(route,color,3,true)
   var start:Dictionary=path.sample(0);var p:Vector2=center+start.point*.99
   draw_circle(p,6,Color("ffd34e"));draw_line(p,p+start.tangent*16,Color("ffd34e"),3,true)
   draw_string(font,origin+Vector2(12,335),"%.0f m · %s"%[path.length,"新增独立轮廓" if i>=6 else "保留原路线"],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c6d5e5"))
 func panel():
  var s=StyleBoxFlat.new();s.bg_color=Color("14263b");s.set_corner_radius_all(10);return s
func _initialize():call_deferred("run")
func run():
 root.content_scale_size=Vector2i(1600,840);root.size=Vector2i(1600,840);var atlas=Atlas.new();atlas.size=Vector2(1600,840);root.add_child(atlas)
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/validation/routes/route-atlas.png")
 atlas.queue_free();await process_frame;quit()
