"""Rasterize the keycap and its three strokes at each native asset size."""
import json
import pathlib
import struct
import zlib
import math

def png(n):
    def chunk(t,b):
        return struct.pack(">I",len(b))+t+b+struct.pack(">I",zlib.crc32(t+b))
    def box(x,y,cx,cy,rx,ry,r):
        a,b=abs(x-cx)-rx+r,abs(y-cy)-ry+r
        return math.hypot(max(0,a),max(0,b))+min(max(a,b),0)-r
    data=bytearray()
    for j in range(n):
        data.append(0)
        for i in range(n):
            x,y=(i+.5)/n,(j+.5)/n
            color=[24+int(17*y),71+int(32*x),77+int(28*y)]
            for d,fg in [(box(x,y,.5,.5,.34,.31,.12),(234,248,238)),
                         (min(box(x,y,.49,.39,.17,.027,.022),box(x,y,.45,.50,.13,.026,.022),box(x,y,.53,.61,.15,.026,.022)),(36,101,104))]:
                a=min(1,max(0,.5-d*n))
                color=[round(v*(1-a)+k*a) for v,k in zip(color,fg)]
            data.extend(color)
    return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(data))+chunk(b"IEND",b"")
p=pathlib.Path("Host/Assets.xcassets/AppIcon.appiconset")
p.mkdir(parents=True,exist_ok=True)
images=[]
for idiom,sizes,scales in [("iphone",[20,29,40,60],[2,3]),("ipad",[20,29,40,76],[1,2]),("ipad",[83.5],[2]),("ios-marketing",[1024],[1])]:
    for size in sizes:
        for scale in scales:
            n=round(size*scale)
            file=p/f"icon-{n}.png"
            if not file.exists():file.write_bytes(png(n))
            images.append(dict(size=f"{size}x{size}",idiom=idiom,scale=f"{scale}x",filename=file.name))
(p/"Contents.json").write_text(json.dumps(dict(images=images,info=dict(version=1,author="xcode"))))
(p.parent/"Contents.json").write_text('{"info":{"version":1,"author":"xcode"}}')
