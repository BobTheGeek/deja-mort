import re, sys, os, glob
import xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONTS = {
  "w": ("/home/claude/fonts/archivo/Archivo-Medium.ttf", -0.015),   # wordmark: Archivo Medium, tracking -1.5%
  "t": ("/home/claude/fonts/inter/extras/ttf/Inter-Regular.ttf", 0.0),  # tagline: Inter Regular
}
_cache={}
def load(path):
    if path not in _cache:
        f=TTFont(path); _cache[path]=(f, f.getGlyphSet(), f['cmap'].getBestCmap(), f['head'].unitsPerEm,
                                       (f['kern'] if 'kern' in f else None))
    return _cache[path]

def kern_pairs(font):
    # GPOS pair kerning is complex; use 'kern' table if present, else none.
    k=font.get('kern')
    if not k: return {}
    pairs={}
    for sub in k.kernTables:
        pairs.update(getattr(sub,'kernTable',{}))
    return pairs

def text_to_path(txt, x, y, size, cls):
    fpath, tracking = FONTS[cls]
    font, gs, cmap, upem, _ = load(fpath)
    kp = kern_pairs(font)
    scale = size/upem
    d=[]; pen_x = x; prev=None
    for ch in txt:
        gname = cmap.get(ord(ch))
        if gname is None: continue
        if prev and (prev,gname) in kp: pen_x += kp[(prev,gname)]*scale
        g = gs[gname]
        spen = SVGPathPen(gs)
        tpen = TransformPen(spen, (scale,0,0,-scale,pen_x,y))
        g.draw(tpen)
        cmd = spen.getCommands()
        if cmd: d.append(cmd)
        pen_x += g.width*scale + tracking*size
        prev=gname
    return " ".join(d), pen_x

def outline_file(src, dst):
    s=open(src).read()
    s=re.sub(r"<metadata>.*?</metadata>","",s,flags=re.S)          # drop c2pa blob (hash would be invalid after edit)
    s=re.sub(r'\s*xmlns:c2pa="[^"]*"',"",s)
    def repl(m):
        attrs=m.group(1); inner=m.group(2)
        a=dict(re.findall(r'([\w:-]+)="([^"]*)"',attrs))
        cls=a.get("class","w"); x=float(a.get("x",0)); y=float(a.get("y",0)); size=float(a.get("font-size",16)); fill=a.get("fill","#000")
        txt=inner.replace("&apos;","'").replace("&#39;","'").replace("&amp;","&")
        d,_=text_to_path(txt,x,y,size,cls)
        return f'<path d="{d}" fill="{fill}"/>'
    s=re.sub(r'<text([^>]*)>(.*?)</text>',repl,s,flags=re.S)
    open(dst,"w").write(s)

if __name__=="__main__":
    srcdir, dstdir = sys.argv[1], sys.argv[2]; os.makedirs(dstdir,exist_ok=True)
    for f in sorted(glob.glob(os.path.join(srcdir,"*.svg"))):
        outline_file(f, os.path.join(dstdir, os.path.basename(f)))
        print("outlined", os.path.basename(f))
