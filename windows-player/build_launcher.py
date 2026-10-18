"""Build with `python -m pip install ziglang==0.13.0`, then python build_launcher.py."""
from pathlib import Path
import os,subprocess,sys
import ziglang
root=Path(__file__).resolve().parent
zig=Path(ziglang.__file__).parent/('zig.exe' if os.name=='nt' else 'zig')
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'ShiningSoul.exe'
cmd=[str(zig),'cc',str(root/'launcher.c'),'-target','x86_64-windows-gnu','-O2','-municode','-Wl,--subsystem,windows','-luser32','-lshell32','-lcomdlg32','-lbcrypt','-lole32','-o',str(out),'-fno-ident']
subprocess.run(cmd,check=True)
print(out)
