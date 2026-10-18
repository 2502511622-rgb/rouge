"""Decode GBA text backgrounds and OBJ from mGBA memory, preserving tile references.
No game logic is inferred. Unsupported effects are recorded, never silently claimed exact.
"""
from pathlib import Path
from PIL import Image
import struct,json,hashlib,argparse

def decode(snapshot,out):
    snapshot=Path(snapshot);out=Path(out);out.mkdir(parents=True,exist_ok=True)
    vram=(snapshot/'vram.bin').read_bytes();pal=(snapshot/'palette.bin').read_bytes();oam=(snapshot/'oam.bin').read_bytes();io=(snapshot/'io.bin').read_bytes()
    u16=lambda b,n:struct.unpack_from('<H',b,n)[0]
    palette=[]
    for x in struct.unpack('<512H',pal):
        cs=[(x>>s)&31 for s in (0,5,10)];palette.append(tuple((c<<3)|(c>>2) for c in cs)+(255,))
    dc=u16(io,0);mode=dc&7;layers=[];manifest={'backdrop':list(palette[0][:3]),'display_control':dc,'display_mode':mode,'source_checkpoint':str(snapshot),'memory_sha256':{n:hashlib.sha256((snapshot/n).read_bytes()).hexdigest() for n in ['vram.bin','palette.bin','oam.bin','io.bin']},'layers':[],'objects':[],'unsupported':[]}
    if mode!=0:manifest['unsupported'].append('Only mode 0 text BGs are reconstructed by this decoder')
    if dc&0xe000:manifest['unsupported'].append('Window masking not implemented')
    if u16(io,0x50)&0xc0:manifest['unsupported'].append('Color effects not implemented')
    for bg in range(4):
        if not dc&(1<<(8+bg)) or mode!=0:continue
        cnt=u16(io,8+bg*2);priority=cnt&3;charbase=((cnt>>2)&3)*0x4000;screenbase=((cnt>>8)&31)*0x800;depth=8 if cnt&128 else 4;size=cnt>>14
        tw=64 if size&1 else 32;th=64 if size&2 else 32;scrollx=u16(io,0x10+4*bg)&511;scrolly=u16(io,0x12+4*bg)&511
        max_tiles=min(1024,(65536-charbase)//(32 if depth==4 else 64));banks=16 if depth==4 else 1
        atlas=Image.new('RGBA',(256,((max_tiles+31)//32)*8*banks));ap=atlas.load();tile_rows=(max_tiles+31)//32
        for bank in range(banks):
            for tile in range(max_tiles):
                for y in range(8):
                    for x in range(8):
                        adr=charbase+tile*(32 if depth==4 else 64)+y*(4 if depth==4 else 8)+(x//2 if depth==4 else x)
                        val=vram[adr];idx=(val>>(4*(x&1)))&15 if depth==4 else val
                        ap[tile%32*8+x,(tile//32+bank*tile_rows)*8+y]=palette[(bank*16 if depth==4 else 0)+idx] if idx else (0,0,0,0)
        atlas_name=f'bg{bg}_tiles.png';atlas.save(out/atlas_name)
        image=Image.new('RGBA',(tw*8,th*8));grid=[]
        for y in range(th):
            row=[]
            for x in range(tw):
                screen=(x//32)+(y//32)*(tw//32);adr=screenbase+screen*2048+((y%32)*32+x%32)*2;entry=u16(vram,adr);tile=entry&1023;bank=entry>>12 if depth==4 else 0
                if tile>=max_tiles:row.append(None);continue
                ax=tile%32;ay=tile//32+bank*tile_rows
                im=atlas.crop((ax*8,ay*8,ax*8+8,ay*8+8))
                if entry&1024:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                if entry&2048:im=im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                image.paste(im,(x*8,y*8));row.append([ax,ay,bool(entry&1024),bool(entry&2048),entry])
            grid.append(row)
        image.save(out/f'bg{bg}_full.png');viewport=Image.new('RGBA',(240,160));vp=viewport.load();ip=image.load()
        for y in range(160):
            for x in range(240):vp[x,y]=ip[(x+scrollx)%image.width,(y+scrolly)%image.height]
        viewport.save(out/f'bg{bg}_viewport.png');layers.append(((priority,1,bg),viewport))
        manifest['layers'].append({'bg':bg,'priority':priority,'width_tiles':tw,'height_tiles':th,'scroll':[scrollx,scrolly],'charbase':charbase,'screenbase':screenbase,'depth':depth,'atlas':atlas_name,'grid':grid})
    dimensions=[[(8,8),(16,16),(32,32),(64,64)],[(16,8),(32,8),(32,16),(64,32)],[(8,16),(8,32),(16,32),(32,64)]]
    if dc&4096:
        for n in range(128):
            a,b,c=struct.unpack_from('<HHH',oam,n*8);affine=bool(a&256)
            if not affine and a&512:continue
            shape=a>>14
            if shape==3:continue
            kind=(a>>10)&3
            if kind==2:manifest['unsupported'].append(f'OBJ {n} window mask omitted');continue
            if kind==1:manifest['unsupported'].append(f'OBJ {n} semi-transparency rendered opaque')
            w,h=dimensions[shape][b>>14];double=affine and bool(a&512);dw,dh=(w*2,h*2) if double else (w,h);depth=8 if a&8192 else 4;tile=c&1023;bank=(c>>12)&15;priority=(c>>10)&3
            raw=Image.new('RGBA',(w,h));rp=raw.load()
            for y in range(h):
                for x in range(w):
                    t=tile+(y//8)*((w//8)*(2 if depth==8 else 1) if dc&64 else 32)+(x//8)*(2 if depth==8 else 1)
                    adr=65536+t*32+(y%8)*(8 if depth==8 else 4)+(x%8 if depth==8 else x%8//2)
                    if adr>=len(vram):continue
                    val=vram[adr];idx=val if depth==8 else val>>(4*(x&1))&15
                    if idx:rp[x,y]=palette[256+idx+(bank*16 if depth==4 else 0)]
            if affine:
                matrix=(b>>9)&31;pa,pb,pc,pd=[struct.unpack_from('<h',oam,matrix*32+6+8*i)[0] for i in range(4)];im=Image.new('RGBA',(dw,dh));op=im.load()
                for yy in range(dh):
                    for xx in range(dw):
                        sx=((pa*(xx-dw//2)+pb*(yy-dh//2))>>8)+w//2;sy=((pc*(xx-dw//2)+pd*(yy-dh//2))>>8)+h//2
                        if 0<=sx<w and 0<=sy<h:op[xx,yy]=rp[sx,sy]
            else:
                im=raw
                if b&4096:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                if b&8192:im=im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            x=b&511;y=a&255;x=x-512 if x>=240 else x;y=y-256 if y>=160 else y
            name=f'obj_{n:03d}.png';im.save(out/name);vp=Image.new('RGBA',(240,160));vp.paste(im,(x,y));layers.append(((priority,0,n),vp))
            manifest['objects'].append({'oam_index':n,'position':[x,y],'size':[dw,dh],'priority':priority,'tile':tile,'palette_bank':bank,'depth':depth,'affine':affine,'image':name})
    composite=Image.new('RGBA',(240,160),palette[0])
    for _,im in sorted(layers,key=lambda p:p[0],reverse=True):composite=Image.alpha_composite(composite,im)
    composite.convert('RGB').save(out/'reconstructed.png')
    actual=Image.frombytes('RGBA',(240,160),(snapshot/'frame.rgba').read_bytes()).convert('RGB');actual.save(out/'reference.png')
    different=sum(a!=b for a,b in zip(composite.convert('RGB').getdata(),actual.getdata()));manifest['comparison']={'total_pixels':38400,'different_pixels':different,'equal_pixel_fraction':1-different/38400,'method':'RGB equality; independent text BG + OBJ decode versus emulator framebuffer'}
    (out/'scene.json').write_text(json.dumps(manifest,separators=(',',':')))
    print(out.name,json.dumps(manifest['comparison']),manifest['unsupported'][:5])
    return manifest
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('snapshot');p.add_argument('output');a=p.parse_args();decode(a.snapshot,a.output)
