#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <shlobj.h>
#include <strsafe.h>
#include <wchar.h>
#include <stdlib.h>
#define CAP 2048
#define MAX_GAMES 256
#define ID_ENGINE 101
#define ID_ADD 102
#define ID_REMOVE 103
#define ID_PLAY 104
#define ID_PROFILE 105
#define ID_LIST 106
#define ID_FOLDER 107
static wchar_t engine[CAP],games[MAX_GAMES][CAP],config_dir[CAP],config_file[CAP];
static int game_count,profile;
static HWND main_window,list,engine_label,status_label,combo;
static HFONT font;
static HBRUSH brush;
static const wchar_t *base_name(const wchar_t*p){const wchar_t*x=wcsrchr(p,L'\\');return x?x+1:p;}
static BOOL copy(wchar_t*d,size_t cap,const wchar_t*s){return SUCCEEDED(StringCchCopyW(d,cap,s));}
static BOOL join(wchar_t*d,const wchar_t*a,const wchar_t*b){return SUCCEEDED(StringCchPrintfW(d,CAP,L"%s\\%s",a,b));}
static BOOL file_exists(const wchar_t*p){DWORD a=GetFileAttributesW(p);return a!=INVALID_FILE_ATTRIBUTES&&!(a&FILE_ATTRIBUTE_DIRECTORY);}
static void message(const wchar_t*s){MessageBoxW(main_window,s,L"Switch 游戏启动器",MB_OK|MB_ICONINFORMATION);}
static BOOL executable(const wchar_t*p){HANDLE f=CreateFileW(p,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,0,NULL);if(f==INVALID_HANDLE_VALUE)return FALSE;unsigned char b[2];DWORD n;BOOL ok=ReadFile(f,b,2,&n,NULL)&&n==2&&b[0]=='M'&&b[1]=='Z';CloseHandle(f);return ok;}
static BOOL game_extension(const wchar_t*p){const wchar_t*ext=wcsrchr(base_name(p),L'.');return ext&&(!_wcsicmp(ext,L".xci")||!_wcsicmp(ext,L".nsp")||!_wcsicmp(ext,L".nro")||!_wcsicmp(ext,L".nso"));}
static BOOL append(wchar_t*out,size_t cap,const wchar_t*s){return SUCCEEDED(StringCchCatW(out,cap,s));}
static BOOL one_char(wchar_t*out,size_t cap,wchar_t c){wchar_t s[2]={c,0};return append(out,cap,s);}
/* Windows argv quoting: no command shell is involved. */
static BOOL quote_arg(wchar_t*out,size_t cap,const wchar_t*arg){
 if(!one_char(out,cap,L'"'))return FALSE;
 while(*arg){unsigned slashes=0;while(*arg==L'\\'){++slashes;++arg;}
  if(*arg==L'"'){for(unsigned i=0;i<slashes*2+1;++i)if(!one_char(out,cap,L'\\'))return FALSE;if(!one_char(out,cap,*arg++))return FALSE;}
  else if(!*arg){for(unsigned i=0;i<slashes*2;++i)if(!one_char(out,cap,L'\\'))return FALSE;break;}
  else {for(unsigned i=0;i<slashes;++i)if(!one_char(out,cap,L'\\'))return FALSE;if(!one_char(out,cap,*arg++))return FALSE;}
 }
 return one_char(out,cap,L'"');
}
/* Error code is returned without popping up dialogs so CLI checks use the same path. */
static int launch_game(const wchar_t*exe,int mode,const wchar_t*game,BOOL wait){
 if(!executable(exe))return 10;
 if(!file_exists(game)||!game_extension(game))return 11;
 if(mode!=0&&mode!=1)return 12;
 wchar_t cwd[CAP],cmd[CAP*3]={0};if(!copy(cwd,CAP,exe))return 13;wchar_t*s=wcsrchr(cwd,L'\\');if(!s)return 13;*s=0;
 if(!quote_arg(cmd,CAP*3,exe)||!append(cmd,CAP*3,mode==1?L" -g ":L" ")||!quote_arg(cmd,CAP*3,game))return 13;
 STARTUPINFOW si={0};si.cb=sizeof(si);PROCESS_INFORMATION pi={0};
 if(!CreateProcessW(exe,cmd,NULL,NULL,FALSE,0,NULL,cwd,&si,&pi))return 14;
 DWORD code=0;
 if(wait){DWORD result=WaitForSingleObject(pi.hProcess,15000);if(result!=WAIT_OBJECT_0){TerminateProcess(pi.hProcess,15);code=15;}else GetExitCodeProcess(pi.hProcess,&code);}
 CloseHandle(pi.hThread);CloseHandle(pi.hProcess);return (int)code;
}
static BOOL initialize_paths(void){wchar_t appdata[CAP];if(FAILED(SHGetFolderPathW(NULL,CSIDL_LOCAL_APPDATA,NULL,SHGFP_TYPE_CURRENT,appdata)))return FALSE;if(!join(config_dir,appdata,L"SwitchGameLauncher")||!join(config_file,config_dir,L"config.ini"))return FALSE;return CreateDirectoryW(config_dir,NULL)||GetLastError()==ERROR_ALREADY_EXISTS;}
static BOOL save_config(void){
 wchar_t temp[CAP];if(!join(temp,config_dir,L"config.next.ini"))return FALSE;
 HANDLE f=CreateFileW(temp,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,0,NULL);if(f==INVALID_HANDLE_VALUE)return FALSE;WORD bom=0xfeff;DWORD written;BOOL ok=WriteFile(f,&bom,2,&written,NULL)&&written==2;CloseHandle(f);if(!ok)return FALSE;
 wchar_t value[32],key[32];StringCchPrintfW(value,32,L"%d",profile);
 ok=WritePrivateProfileStringW(L"Launcher",L"Emulator",engine,temp)&&WritePrivateProfileStringW(L"Launcher",L"Profile",value,temp);
 StringCchPrintfW(value,32,L"%d",game_count);ok=ok&&WritePrivateProfileStringW(L"Launcher",L"Count",value,temp);
 for(int i=0;i<game_count&&ok;++i){StringCchPrintfW(key,32,L"Game%d",i);ok=WritePrivateProfileStringW(L"Games",key,games[i],temp);}
 WritePrivateProfileStringW(NULL,NULL,NULL,temp);
 if(!ok)return FALSE;
 return MoveFileExW(temp,config_file,MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH);
}
static void load_config(void){GetPrivateProfileStringW(L"Launcher",L"Emulator",L"",engine,CAP,config_file);profile=(int)GetPrivateProfileIntW(L"Launcher",L"Profile",0,config_file);if(profile!=0&&profile!=1)profile=0;int n=(int)GetPrivateProfileIntW(L"Launcher",L"Count",0,config_file);if(n<0)n=0;if(n>MAX_GAMES)n=MAX_GAMES;game_count=0;
 for(int i=0;i<n;++i){wchar_t key[32];StringCchPrintfW(key,32,L"Game%d",i);GetPrivateProfileStringW(L"Games",key,L"",games[game_count],CAP,config_file);if(games[game_count][0])++game_count;}
}
static void refresh(void){SetWindowTextW(engine_label,engine[0]?engine:L"尚未选择模拟器 EXE");SendMessageW(list,LB_RESETCONTENT,0,0);for(int i=0;i<game_count;++i)SendMessageW(list,LB_ADDSTRING,0,(LPARAM)base_name(games[i]));SendMessageW(combo,CB_SETCURSEL,profile,0);wchar_t text[256];StringCchPrintfW(text,256,L"%d 个本地游戏 · 双击列表或点击“启动选中游戏”",game_count);SetWindowTextW(status_label,text);}
static void persist(void){if(!save_config())message(L"配置保存失败，请检查用户数据目录权限。现有配置文件没有被删除。");}
static void select_engine(void){wchar_t file[CAP]={0};OPENFILENAMEW ofn={0};ofn.lStructSize=sizeof(ofn);ofn.hwndOwner=main_window;ofn.lpstrFile=file;ofn.nMaxFile=CAP;ofn.lpstrFilter=L"Windows 模拟器 (*.exe)\0*.exe\0\0";ofn.lpstrTitle=L"选择你已经安装并配置好的 Switch 模拟器 EXE";ofn.Flags=OFN_FILEMUSTEXIST|OFN_PATHMUSTEXIST|OFN_NOCHANGEDIR;if(!GetOpenFileNameW(&ofn))return;if(!executable(file)){message(L"所选文件不是有效的 Windows 可执行文件。");return;}copy(engine,CAP,file);persist();refresh();}
static void add_path(const wchar_t*p){if(!file_exists(p)||!game_extension(p)||wcslen(p)>=CAP)return;for(int i=0;i<game_count;++i)if(!_wcsicmp(games[i],p))return;if(game_count<MAX_GAMES)copy(games[game_count++],CAP,p);}
static void add_games(void){wchar_t*files=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,65536*sizeof(wchar_t));if(!files){message(L"无法分配文件选择缓冲区。");return;}OPENFILENAMEW ofn={0};ofn.lStructSize=sizeof(ofn);ofn.hwndOwner=main_window;ofn.lpstrFile=files;ofn.nMaxFile=65536;ofn.lpstrFilter=L"Switch 文件 (*.xci;*.nsp;*.nro;*.nso)\0*.xci;*.nsp;*.nro;*.nso\0\0";ofn.lpstrTitle=L"添加你的本地游戏（可多选）";ofn.Flags=OFN_FILEMUSTEXIST|OFN_PATHMUSTEXIST|OFN_NOCHANGEDIR|OFN_ALLOWMULTISELECT|OFN_EXPLORER;
 if(GetOpenFileNameW(&ofn)){wchar_t*next=files+wcslen(files)+1;if(!*next)add_path(files);else while(*next){wchar_t path[CAP];if(join(path,files,next))add_path(path);next+=wcslen(next)+1;}persist();refresh();if(game_count==MAX_GAMES)message(L"列表最多保存 256 个游戏；重复路径会自动忽略。");}HeapFree(GetProcessHeap(),0,files);}
static void play_selected(void){int index=(int)SendMessageW(list,LB_GETCURSEL,0,0);if(index<0||index>=game_count){message(L"请先添加并选中一个游戏。");return;}int result=launch_game(engine,profile,games[index],FALSE);if(result){wchar_t text[512];StringCchPrintfW(text,512,L"启动失败（代码 %d，Windows 错误 %lu）。请检查模拟器和游戏路径，并确认参数模式与本地模拟器版本兼容。",result,GetLastError());message(text);}else SetWindowTextW(status_label,L"启动请求已交给模拟器；实际加载状态请查看模拟器窗口。");}
static HWND control(const wchar_t*type,const wchar_t*text,DWORD style,int x,int y,int w,int h,int id){HWND child=CreateWindowExW(0,type,text,WS_CHILD|WS_VISIBLE|style,x,y,w,h,main_window,(HMENU)(INT_PTR)id,GetModuleHandleW(NULL),NULL);SendMessageW(child,WM_SETFONT,(WPARAM)font,TRUE);return child;}
static LRESULT CALLBACK window_proc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp){switch(msg){
 case WM_CREATE:main_window=hwnd;font=CreateFontW(-18,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Microsoft YaHei UI");
  control(L"STATIC",L"SWITCH / 本地游戏启动器",0,24,18,750,30,0);
  control(L"STATIC",L"使用你自己的模拟器和游戏；首次运行请先在模拟器内完成配置。",0,24,55,820,28,0);
  engine_label=control(L"STATIC",L"",SS_PATHELLIPSIS,24,102,650,28,0);control(L"BUTTON",L"选择模拟器",BS_PUSHBUTTON,690,94,160,36,ID_ENGINE);
  control(L"STATIC",L"参数模式",0,24,145,90,28,0);combo=control(L"COMBOBOX",L"",CBS_DROPDOWNLIST|WS_TABSTOP,120,140,530,200,ID_PROFILE);SendMessageW(combo,CB_ADDSTRING,0,(LPARAM)L"直接传路径（Ryujinx 类：模拟器.exe 游戏路径）");SendMessageW(combo,CB_ADDSTRING,0,(LPARAM)L"-g 参数（yuzu 类：模拟器.exe -g 游戏路径）");
  list=control(L"LISTBOX",L"",LBS_NOTIFY|WS_VSCROLL|WS_BORDER|WS_TABSTOP,24,190,826,270,ID_LIST);
  control(L"BUTTON",L"添加游戏…",BS_PUSHBUTTON,24,477,150,38,ID_ADD);control(L"BUTTON",L"移除选中",BS_PUSHBUTTON,186,477,140,38,ID_REMOVE);control(L"BUTTON",L"打开配置目录",BS_PUSHBUTTON,338,477,170,38,ID_FOLDER);control(L"BUTTON",L"启动选中游戏",BS_DEFPUSHBUTTON,640,477,210,38,ID_PLAY);
  status_label=control(L"STATIC",L"",0,24,535,826,28,0);refresh();return 0;
 case WM_DROPFILES:{HDROP drop=(HDROP)wp;UINT count=DragQueryFileW(drop,0xffffffff,NULL,0);for(UINT i=0;i<count;++i){wchar_t path[CAP];if(DragQueryFileW(drop,i,NULL,0)<CAP){DragQueryFileW(drop,i,path,CAP);add_path(path);}}DragFinish(drop);persist();refresh();return 0;}
 case WM_COMMAND:switch(LOWORD(wp)){
  case ID_ENGINE:select_engine();break;case ID_ADD:add_games();break;case ID_PLAY:play_selected();break;
  case ID_REMOVE:{int i=(int)SendMessageW(list,LB_GETCURSEL,0,0);if(i>=0&&i<game_count){for(int j=i;j<game_count-1;++j)copy(games[j],CAP,games[j+1]);--game_count;persist();refresh();}break;}
  case ID_PROFILE:if(HIWORD(wp)==CBN_SELCHANGE){profile=(int)SendMessageW(combo,CB_GETCURSEL,0,0);persist();}break;
  case ID_LIST:if(HIWORD(wp)==LBN_DBLCLK)play_selected();else if(HIWORD(wp)==LBN_SELCHANGE){int i=(int)SendMessageW(list,LB_GETCURSEL,0,0);if(i>=0&&i<game_count)SetWindowTextW(status_label,games[i]);}break;
  case ID_FOLDER:ShellExecuteW(hwnd,L"open",config_dir,NULL,NULL,SW_SHOWNORMAL);break;
 }return 0;
 case WM_CTLCOLORSTATIC:SetTextColor((HDC)wp,RGB(225,232,242));SetBkColor((HDC)wp,RGB(22,29,42));return (LRESULT)brush;
 case WM_CLOSE:DestroyWindow(hwnd);return 0;
 case WM_DESTROY:DeleteObject(font);PostQuitMessage(0);return 0;
 }return DefWindowProcW(hwnd,msg,wp,lp);}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE previous,PWSTR command,int show){(void)previous;(void)command;
 int argc;wchar_t**args=CommandLineToArgvW(GetCommandLineW(),&argc);if(!args)return 2;
 if(argc==5&&!wcscmp(args[1],L"--config-check")){
  if(!copy(config_dir,CAP,args[4])||!join(config_file,config_dir,L"config.ini")){LocalFree(args);return 20;}
  if(!CreateDirectoryW(config_dir,NULL)&&GetLastError()!=ERROR_ALREADY_EXISTS){LocalFree(args);return 21;}
  copy(engine,CAP,args[2]);copy(games[0],CAP,args[3]);game_count=1;profile=1;
  if(!save_config()){LocalFree(args);return 22;}
  engine[0]=0;games[0][0]=0;game_count=0;profile=0;load_config();
  int result=(!wcscmp(engine,args[2])&&game_count==1&&!wcscmp(games[0],args[3])&&profile==1)?0:23;LocalFree(args);return result;
 }
 if(argc==5&&!wcscmp(args[1],L"--probe")){int mode=!wcscmp(args[3],L"direct")?0:!wcscmp(args[3],L"dash-g")?1:-1;int result=launch_game(args[2],mode,args[4],TRUE);LocalFree(args);return result;}
 LocalFree(args);HANDLE mutex=CreateMutexW(NULL,FALSE,L"Local\\SwitchGameLauncher");if(!mutex)return 6;if(GetLastError()==ERROR_ALREADY_EXISTS){HWND other=FindWindowW(L"SwitchGameLauncherWindow",NULL);if(other){ShowWindow(other,SW_RESTORE);SetForegroundWindow(other);}CloseHandle(mutex);return 0;}SetProcessDPIAware();if(!initialize_paths()){message(L"无法创建本地配置目录。");return 3;}load_config();brush=CreateSolidBrush(RGB(22,29,42));WNDCLASSW wc={0};wc.hInstance=instance;wc.lpfnWndProc=window_proc;wc.lpszClassName=L"SwitchGameLauncherWindow";wc.hCursor=LoadCursorW(NULL,IDC_ARROW);wc.hIcon=LoadIconW(NULL,IDI_APPLICATION);wc.hbrBackground=brush;if(!RegisterClassW(&wc))return 4;
 HWND hwnd=CreateWindowExW(0,wc.lpszClassName,L"Switch 游戏启动器",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_MINIMIZEBOX,CW_USEDEFAULT,CW_USEDEFAULT,900,620,NULL,NULL,instance,NULL);if(!hwnd)return 5;DragAcceptFiles(hwnd,TRUE);ShowWindow(hwnd,show);UpdateWindow(hwnd);MSG msg;while(GetMessageW(&msg,NULL,0,0)>0){TranslateMessage(&msg);DispatchMessageW(&msg);}DeleteObject(brush);CloseHandle(mutex);return 0;
}
