"""Exact ROM byte matches for used background tiles. Not proof of loader provenance."""
from pathlib import Path
import json,hashlib,sys
r=Path(__file__).resolve().parents[1];rom=Path(sys.argv[1]).read_bytes();records=[];cache={}
for name in ['title','village','dialogue']:
 m=json.loads((r/'assets/verified'/name/'scene.json').read_text());v=Path(m['source_checkpoint'],'vram.bin').read_bytes();count=0;matched=0
 for layer in m['layers']:
  seen=set()
  for row in layer['grid']:
   for cell in row:
    if cell is None:continue
    tile=cell[4]&1023
    if tile in seen:continue
    seen.add(tile);stride=64 if layer['depth']==8 else 32;start=layer['charbase']+tile*stride;b=v[start:start+stride]
    if len(set(b))<4:continue # exclude low-information patterns
    count+=1
    if b not in cache:
     at=rom.find(b);offsets=[]
     while at>=0 and len(offsets)<5:
      offsets.append(at);at=rom.find(b,at+1)
     cache[b]={'offsets':offsets,'more_than_five_matches':at>=0}
    found=cache[b];matched+=bool(found['offsets']);records.append({'scene':name,'bg':layer['bg'],'tile_index':tile,'vram_address':0x6000000+start,'sha256':hashlib.sha256(b).hexdigest(),**found})
 print(name,'nontrivial used tiles',count,'exact ROM byte matches',matched)
(r/'analysis/rom_tile_byte_matches.json').write_text(json.dumps({'method':'Exact byte equality, not validated loader references; repeated matches retained, low-information tiles excluded','rom_sha256':hashlib.sha256(rom).hexdigest(),'tiles':records},indent=2))
