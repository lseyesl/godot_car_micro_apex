"""Saturated clay pigments. Hex palette is sRGB; glTF corner colors are linear."""
import re
PALETTE={
 'scarlet':'FF574F','red':'FF574F','tail':'F02E29','scenery_coral':'FF574F',
 'honey':'FFD21F','scenery_flower':'FFD21F','azure':'28BDF4','mint':'22CF88',
 'apricot':'FF9226','orange':'FF8624','ice':'31DDE8','plum':'B34FFF','sand':'F3B52C',
 'scenery_teal':'28BDF4','roof':'FF574F','cloth':'FFB526',
 'bark':'8F4B24','timber':'8F4B24','wood':'BE7833','plaster':'FFE6AB',
 'scenery_cream':'FFF1CC','scenery_dry':'E1BA31','scenery_leaf':'55D936','grass':'55D936',
 'glass':'12536C','scenery_glass':'12536C','rubber':'182D38','trim':'182D38','dark':'182D38',
 'rim':'B8D6D8','metal':'B8D6D8','disc':'B8D6D8','lamp':'FFF7DC','white':'FFF7DC'}
def linear(hex_color):
 c=[int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
 return [x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in c]
def pigment(name,source):
 name=re.sub(r'\.\d{3}$','',name.lower())
 if name.startswith('leaf'):
  i=int(re.search(r'\d+$',name)[0]) if re.search(r'\d+$',name) else 2
  return linear(['2BAC2B','43C82E','55D936','7BE742','98EB46'][min(i,4)])
 if name.startswith('asphalt'):return linear('435F73')
 if name.startswith('dirt'):return linear('DB8F3F')
 if name.startswith('stone'):return linear('9CA3AD')
 if name not in PALETTE:raise ValueError('Unmapped clay material: '+name)
 return linear(PALETTE[name])
def legacy_pigment(name,source):
 c=list(source);name=name.lower()
 if any(x in name for x in ['rubber','trim']):c=[.032,.042,.044]
 elif 'glass' in name:c=[.045,.085,.10]
 elif any(x in name for x in ['rim','metal','disc']):c=[.53,.50,.42]
 elif any(x in name for x in ['leaf','grass']):c=[max(.09,c[0]*.95),min(.65,c[1]*1.15+.06),max(.055,c[2]*1.25)]
 else:c=[min(.94,max(.025,x*.95+.035)) for x in c]
 if max(c)-min(c)>.25:c=[x*.72 for x in c]
 return c
