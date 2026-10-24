extends StyleBox
# One cached paint resource per state; opaque polygons, no blur shader or UI nodes.
@export var paper:=false
@export var role:="panel"
@export var state:="normal"
@export var bg_color:=Color("fff9e9")
@export var border_color:=Color("78976c")
@export var border_width_bottom:=6
@export var corner_radius_top_left:=22
func shape(rect:Rect2) -> PackedVector2Array:
 var points:=PackedVector2Array()
 if paper:
  var fold:=minf(18,minf(rect.size.x,rect.size.y)*.25)
  return PackedVector2Array([rect.position,Vector2(rect.end.x-fold,rect.position.y),Vector2(rect.end.x,rect.position.y+fold),rect.end,Vector2(rect.position.x+3,rect.end.y),Vector2(rect.position.x,rect.end.y-3)])
 var radius:=minf(24,minf(rect.size.x,rect.size.y)*.42)
 var centers:=[rect.position+Vector2(radius,radius),Vector2(rect.end.x-radius,rect.position.y+radius),rect.end-Vector2(radius,radius),Vector2(rect.position.x+radius,rect.end.y-radius)]
 for c in range(4):
  for i in range(7):
   var a:=PI+float(c)*PI*.5+float(i)*PI/12
   var irregular:=1.2*sin(a*5.3+rect.size.x*.017)+.55*cos(a*9.1)
   points.append(centers[c]+Vector2(cos(a),sin(a))*(radius+irregular))
  if c==0 or c==2:
   var left:Vector2=points[-1];var next:Vector2=centers[(c+1)%4]+Vector2(cos(PI+(c+1)*PI*.5),sin(PI+(c+1)*PI*.5))*radius
   for j in range(1,5):points.append(left.lerp(next,j/5.0)+Vector2(0,sin(j*2.2+rect.size.x*.01)*1.1))
 return points
var _vertices:=PackedVector2Array()
var _indices:=PackedInt32Array()
var _colors:=PackedColorArray()
var _strokes:=PackedVector2Array()
var _stroke_colors:=PackedColorArray()
func poly(_canvas:RID,points:PackedVector2Array,color:Color):
 var offset:=_vertices.size()
 for i in Geometry2D.triangulate_polygon(points):_indices.append(offset+i)
 for p in points:_vertices.append(p);_colors.append(color)

func line(_canvas:RID,points:PackedVector2Array,color:Color,_width:float=1.0):
 for i in range(points.size()-1):
  _strokes.append(points[i]);_strokes.append(points[i+1]);_stroke_colors.append(color)
func flush(canvas:RID):
 if not _indices.is_empty():RenderingServer.canvas_item_add_triangle_array(canvas,_indices,_vertices,_colors)
 if not _strokes.is_empty():RenderingServer.canvas_item_add_multiline(canvas,_strokes,_stroke_colors,1.0,true)
func _draw(canvas:RID,rect:Rect2) -> void:
 _vertices.clear();_indices.clear();_colors.clear();_strokes.clear();_stroke_colors.clear()
 if rect.size.x<=0 or rect.size.y<=0:return
 var depth:=float(border_width_bottom)
 if state=="focus":
  var loop:=shape(rect.grow(-2));loop.append(loop[0]);line(canvas,loop,Color("725a3c") if paper else Color("5f794d"),2);flush(canvas);return
 poly(canvas,shape(Rect2(rect.position+Vector2(1,depth+1),rect.size)),Color(.12,.12,.07,.16))
 if paper:
  poly(canvas,shape(Rect2(rect.position+Vector2(-2,depth),rect.size)),Color("ccb58e"))
  poly(canvas,shape(rect),border_color)
  var face:=rect.grow(-1.4);poly(canvas,shape(face),bg_color)
  var fold:=minf(18,minf(face.size.x,face.size.y)*.25)
  poly(canvas,PackedVector2Array([Vector2(face.end.x-fold,face.position.y),Vector2(face.end.x-fold,face.position.y+fold),Vector2(face.end.x,face.position.y+fold)]),Color("d9c59f"))
  line(canvas,PackedVector2Array([Vector2(face.end.x-fold,face.position.y),Vector2(face.end.x-fold,face.position.y+fold),Vector2(face.end.x,face.position.y+fold)]),Color(.32,.26,.18,.45))
  # Sparse paper fibres stay on the margin, away from type.
  for j in range(3):
   var y:=face.position.y+5+j*4
   line(canvas,PackedVector2Array([Vector2(face.position.x+5,y),Vector2(face.position.x+12+j*2,y-.5)]),Color(.42,.33,.21,.14))
 else:
  poly(canvas,shape(rect),border_color.darkened(.08))
  var face:=Rect2(rect.position+Vector2(1.8,1.5),rect.size-Vector2(3.6,depth*.45+2.0))
  poly(canvas,shape(face),bg_color)
  var rim:=PackedVector2Array()
  for j in range(9):rim.append(Vector2(face.position.x+25+(face.size.x-50)*j/8,face.position.y+3+sin(j*1.7)*.7))
  line(canvas,rim,bg_color.lightened(.22),1.6)
  # Pressed thumb marks along the raised clay edge, not over the label.
  for mark in range(2):
   var arc:=PackedVector2Array()
   for i in range(8):arc.append(rect.position+Vector2(7+mark*3+cos(i*.25)*2.0,rect.size.y*.52+sin(i*.25)*8))
   line(canvas,arc,border_color.darkened(.05),.8)

 var outline:=shape(rect);outline.append(outline[0]);line(canvas,outline,border_color)
 flush(canvas)
