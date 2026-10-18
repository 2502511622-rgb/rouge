from pathlib import Path
from PIL import Image,ImageDraw
import sys
root=Path(sys.argv[1]);dirs=sorted(p.parent for p in root.glob('*/frame.rgba'));sheet=Image.new('RGB',(720,200*((len(dirs)+2)//3)),(20,20,20));d=ImageDraw.Draw(sheet)
for i,p in enumerate(dirs):
 im=Image.frombytes('RGBA',(240,160),(p/'frame.rgba').read_bytes()).convert('RGB');im.save(p/'frame.png');x=i%3*240;y=i//3*200;sheet.paste(im,(x,y+25));d.text((x,y+5),p.name,fill='white')
sheet.save(root/'contact.png')
