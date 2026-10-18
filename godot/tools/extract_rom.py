#!/usr/bin/env python3
"""Read-only GBA header/LZ77/tile investigation. Candidates are not identified game assets."""
import argparse, hashlib, json, struct
from pathlib import Path
from PIL import Image, ImageDraw

def decompress(b, start):
    size=int.from_bytes(b[start+1:start+4],'little')
    if not 32<=size<=262144: return None
    out=bytearray(); p=start+4
    try:
        while len(out)<size:
            flags=b[p]; p+=1
            for bit in range(7,-1,-1):
                if len(out)>=size: break
                if flags&(1<<bit):
                    a,c=b[p:p+2];p+=2
                    length=(a>>4)+3; distance=((a&15)<<8|c)+1
                    if distance>len(out): return None
                    for _ in range(min(length,size-len(out))): out.append(out[-distance])
                else:out.append(b[p]);p+=1
                if p-start>524288:return None
    except (IndexError,ValueError):return None
    return bytes(out),p

def atlas(data, mode=4, palette=None):
    stride=32 if mode==4 else 64
    count=min(len(data)//stride,4096)
    if count<1:return None
    cols=32; rows=(count+cols-1)//cols
    im=Image.new('RGBA',(cols*8,rows*8),(0,0,0,0));px=im.load()
    colors=palette or [(i*17,i*17,i*17,255) for i in range(16)]
    for t in range(count):
        for y in range(8):
            for x in range(8):
                v=data[t*stride+y*(4 if mode==4 else 8)+(x//2 if mode==4 else x)]
                v=(v>>(4*(x%2)))&15 if mode==4 else v
                color=colors[v] if v<len(colors) else (v,v,v,255)
                px[t%cols*8+x,t//cols*8+y]=color
    return im

def main():
    a=argparse.ArgumentParser();a.add_argument('rom',type=Path);a.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[1]);args=a.parse_args()
    b=args.rom.read_bytes();root=args.out;dest=root/'assets/extracted';dest.mkdir(parents=True,exist_ok=True);(root/'analysis').mkdir(exist_ok=True)
    header={'size_bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'title':b[0xa0:0xac].decode('ascii','replace'),'game_code':b[0xac:0xb0].decode('ascii','replace'),'maker_code':b[0xb0:0xb2].decode('ascii','replace'),'revision':b[0xbc],'header_checksum_valid':b[0xbd]==(-sum(b[0xa0:0xbd])-0x19)&255,'entry_arm_word':hex(int.from_bytes(b[:4],'little')),'save_signature_offset':b.find(b'FLASH_V126'),'region_inference':'J code suggests Japan; modification/translation not established'}
    word=int.from_bytes(b[:4],'little');imm=word&0xffffff;imm=imm if imm<0x800000 else imm-0x1000000
    header['arm_entry_branch_rom_offset']=hex(8+imm*4)
    refs={}
    for off in range(0,len(b)-3,4):
        value=int.from_bytes(b[off:off+4],'little')
        if 0x08000000<=value<0x08000000+len(b):refs.setdefault(value-0x08000000,[]).append(off)
    candidates=[];covered=-1;thumbs=[]
    for off in range(0,len(b)-4,4):
        if off<covered or b[off]!=0x10:continue
        result=decompress(b,off)
        if result is None:continue
        data,end=result
        if len(data)<end-off:continue # require actual compression; still heuristic
        n=len(candidates); stem=f'lz77_{off:06x}'
        record={'rom_offset':off,'rom_address':hex(0x08000000+off),'compressed_end':end,'decoded_size':len(data),'sha256':hashlib.sha256(data).hexdigest(),'pointer_references':refs.get(off,[]),'classification':'unidentified_lz77_candidate','exported':n<256}
        if n<256:
            (dest/(stem+'.bin')).write_bytes(data)
            im=atlas(data)
            if im:
                im.save(dest/(stem+'.png'));record['preview']='res://assets/extracted/'+stem+'.png'
                thumb=im.crop((0,0,256,min(im.height,128))).convert('RGB');thumbs.append((stem,thumb))
            record['binary']='res://assets/extracted/'+stem+'.bin'
        candidates.append(record);covered=end
    for off in [0x100000,0x200000,0x300000,0x400000,0x500000,0x600000,0x700000]:
        im=atlas(b[off:off+32768]);name=f'raw4bpp_{off:06x}.png';im.save(dest/name)
        candidates.append({'rom_offset':off,'decoded_size':32768,'classification':'raw_4bpp_interpretation_not_identified','preview':'res://assets/extracted/'+name,'exported':True})
    manifest={'header':header,'limitations':['4-byte aligned GBA LZ77 type 0x10 candidates only; false positives possible','Non-overlapping heuristic; no guarantee of exhaustive coverage','Preview uses grayscale index values, not verified game palettes','Tiles shown sequentially, not reconstructed sprites or maps','At most 256 compressed blocks exported; no original gameplay code reconstructed'],'resources':candidates}
    (root/'data/rom_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    (root/'analysis/rom_report.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    sheet=Image.new('RGB',(4*272,((min(48,len(thumbs))+3)//4)*158),(24,28,37));draw=ImageDraw.Draw(sheet)
    for i,(name,im) in enumerate(thumbs[:48]):x=i%4*272;y=i//4*158;sheet.paste(im,(x,y+20));draw.text((x,y+2),name,fill='white')
    if thumbs:sheet.save(root/'analysis/contact_sheet.png')
    print(json.dumps({'header':header,'lz77_candidates':len(candidates)-7,'exported_lz77':min(256,len(candidates)-7)},indent=2))
if __name__=='__main__':main()
