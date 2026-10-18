from pathlib import Path
import os,subprocess,sys
import ziglang
root=Path(__file__).resolve().parent
zig=Path(ziglang.__file__).parent/('zig.exe' if os.name=='nt' else 'zig')
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'SwitchLauncher.exe'
args=[str(zig),'cc',str(root/'launcher.c'),'-target','x86_64-windows-gnu','-O2','-municode','-Wl,--subsystem,windows','-luser32','-lgdi32','-lshell32','-lcomdlg32','-lole32','-o',str(out)]
subprocess.run(args,check=True)
