"""Replay the exact observed route from cold boot to initial village.
Requires the caller's ROM and a built gba_capture; never edits the ROM.
"""
from pathlib import Path
import argparse,subprocess,json,hashlib
p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('--runner',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
expected='04489e661a493d4f5ef7e0a3e91e3c30094cbf4286cf2b6eee63479b4c3721ce'
if hashlib.sha256(a.rom.read_bytes()).hexdigest()!=expected:raise SystemExit('This recorded route requires the exact analyzed ROM SHA-256; other versions are unverified.')
route=[('boot',None),('menu','boot/a_842'),('character','menu/a_menu3'),('newgame','character/intro_a'),('naming','newgame/town'),('naming2','naming/accept'),('story','naming2/after'),('advance','story/dialogue3'),('gameplay','advance/dialogue_50')]
a.output.mkdir(parents=True,exist_ok=True)
for stage,parent in route:
 cmd=[str(a.runner.resolve()),str(a.rom.resolve()),str(a.output/stage),str(root/'analysis/runtime'/f'{stage}.scenario')]
 if parent:cmd.append(str(a.output/parent/'state.bin'))
 subprocess.run(cmd,check=True)
original=root/'analysis/runtime/gameplay/idle';observed=a.output/'gameplay/idle';results={}
for name in ['frame.rgba','palette.bin','vram.bin','oam.bin']:
 expected_bytes=(original/name).read_bytes();actual_bytes=(observed/name).read_bytes();results[name]={'equal':expected_bytes==actual_bytes,'sha256':hashlib.sha256(actual_bytes).hexdigest()}
(a.output/'replay_result.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
if not all(x['equal'] for x in results.values()):raise SystemExit('Replay changed: investigate before claiming deterministic reproduction')
