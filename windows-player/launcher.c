#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <shlobj.h>
#include <bcrypt.h>
#include <strsafe.h>
#include <wchar.h>
#include <string.h>
#include "engine_digest.h"
#define PATH_CAP 2048
static const unsigned char ROM_HASH[32]={0x04,0x48,0x9e,0x66,0x1a,0x49,0x3d,0x4f,0x5e,0xf7,0xe0,0xa3,0xe9,0x1e,0x3c,0x30,0x09,0x4c,0xbf,0x42,0x86,0xcf,0x2b,0x6e,0xee,0x63,0x47,0x9b,0x4c,0x37,0x21,0xce};
static void console_line(const char*s){DWORD n;HANDLE h=GetStdHandle(STD_OUTPUT_HANDLE);if(h&&h!=INVALID_HANDLE_VALUE)WriteFile(h,s,(DWORD)strlen(s),&n,NULL);}
static int fail(const wchar_t*text){MessageBoxW(NULL,text,L"光明之魂 · 启动器",MB_OK|MB_ICONERROR);return 1;}
static BOOL path_join(wchar_t*out,const wchar_t*dir,const wchar_t*name){return SUCCEEDED(StringCchPrintfW(out,PATH_CAP,L"%s\\%s",dir,name));}
static BOOL exists(const wchar_t*p){DWORD a=GetFileAttributesW(p);return a!=INVALID_FILE_ATTRIBUTES&&!(a&FILE_ATTRIBUTE_DIRECTORY);}
static BOOL make_dir(const wchar_t*p){return CreateDirectoryW(p,NULL)||GetLastError()==ERROR_ALREADY_EXISTS;}
static BOOL sha256(const wchar_t*file,unsigned char out[32]){
 HANDLE f=CreateFileW(file,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
 if(f==INVALID_HANDLE_VALUE)return FALSE;
 BCRYPT_ALG_HANDLE alg=NULL;BCRYPT_HASH_HANDLE hash=NULL;PUCHAR obj=NULL;DWORD size=0,got=0,read=0;BOOL ok=FALSE;unsigned char buf[65536];
 if(BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,NULL,0)<0)goto done;
 if(BCryptGetProperty(alg,BCRYPT_OBJECT_LENGTH,(PUCHAR)&size,sizeof(size),&got,0)<0)goto done;
 obj=HeapAlloc(GetProcessHeap(),0,size);if(!obj)goto done;
 if(BCryptCreateHash(alg,&hash,obj,size,NULL,0,0)<0)goto done;
 for(;;){if(!ReadFile(f,buf,sizeof(buf),&read,NULL))goto done;if(!read)break;if(BCryptHashData(hash,buf,read,0)<0)goto done;}
 ok=BCryptFinishHash(hash,out,32,0)>=0;
 done:if(hash)BCryptDestroyHash(hash);if(obj)HeapFree(GetProcessHeap(),0,obj);if(alg)BCryptCloseAlgorithmProvider(alg,0);CloseHandle(f);return ok;
}
static BOOL digest_matches(const wchar_t*p,const unsigned char*expected){unsigned char h[32];return sha256(p,h)&&memcmp(h,expected,32)==0;}
static BOOL create_initial_config(const wchar_t*engine_dir){
 wchar_t path[PATH_CAP];if(!path_join(path,engine_dir,L"config.ini"))return FALSE;
 HANDLE f=CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
 if(f==INVALID_HANDLE_VALUE)return GetLastError()==ERROR_FILE_EXISTS;
 const char*cfg="[ports.qt]\nframeskip=0\nuseBios=0\naudioSync=1\nvideoSync=0\nfpsTarget=59.727500569606\nvolume=256\nlockAspectRatio=1\ninterframeBlending=0\n";
 DWORD n=0;BOOL ok=WriteFile(f,cfg,(DWORD)strlen(cfg),&n,NULL)&&n==strlen(cfg);CloseHandle(f);return ok;
}
static BOOL choose_rom(wchar_t*path){
 OPENFILENAMEW ofn={0};ofn.lStructSize=sizeof(ofn);ofn.lpstrFile=path;ofn.nMaxFile=PATH_CAP;
 ofn.lpstrFilter=L"光明之魂 GBA ROM (*.gba)\0*.gba\0所有文件\0*.*\0\0";
 ofn.lpstrTitle=L"首次运行：选择此前上传的《光明之魂1.gba》";
 ofn.Flags=OFN_FILEMUSTEXIST|OFN_PATHMUSTEXIST|OFN_NOCHANGEDIR;return GetOpenFileNameW(&ofn);
}
static BOOL start_child(const wchar_t*exe,wchar_t*cmd,const wchar_t*cwd,DWORD flags,PROCESS_INFORMATION*pi){STARTUPINFOW si={0};si.cb=sizeof(si);return CreateProcessW(exe,cmd,NULL,NULL,FALSE,flags,NULL,cwd,&si,pi);}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE previous,PWSTR unused,int show){
 (void)instance;(void)previous;(void)unused;(void)show;
 int argc=0;wchar_t**args=CommandLineToArgvW(GetCommandLineW(),&argc);if(!args)return 2;
 if(argc==3&&!wcscmp(args[1],L"--hash-file")){
  unsigned char digest[32];char text[67];const char*hex="0123456789abcdef";
  BOOL ok=sha256(args[2],digest);if(ok){for(int i=0;i<32;++i){text[i*2]=hex[digest[i]>>4];text[i*2+1]=hex[digest[i]&15];}text[64]='\r';text[65]='\n';text[66]=0;console_line(text);}
  LocalFree(args);return ok?0:7;
 }
 if(argc==3&&!wcscmp(args[1],L"--validate-rom")){
  BOOL ok=digest_matches(args[2],ROM_HASH);console_line(ok?"ROM SHA256 PASS\r\n":"ROM SHA256 FAIL\r\n");LocalFree(args);return ok?0:4;
 }
 wchar_t root[PATH_CAP],engine_dir[PATH_CAP],engine[PATH_CAP],cmd[16384];DWORD length=GetModuleFileNameW(NULL,root,PATH_CAP);
 if(!length||length>=PATH_CAP)return 2;wchar_t*slash=wcsrchr(root,L'\\');if(!slash)return 2;*slash=0;
 if(!path_join(engine_dir,root,L"engine")||!path_join(engine,engine_dir,L"mGBA.exe"))return 2;
 BOOL test=argc==2&&!wcscmp(args[1],L"--self-test");
 if(!digest_matches(engine,ENGINE_HASH)){
  LocalFree(args);if(test){console_line("ENGINE SHA256 FAIL\r\n");return 3;}
  return fail(L"模拟器缺失或与已验证的官方版本不一致。请完整解压启动包，保留 engine 目录，不要只复制此 EXE。");
 }
 if(test){
  StringCchPrintfW(cmd,16384,L"\"%s\" --version",engine);PROCESS_INFORMATION pi={0};
  if(!start_child(engine,cmd,engine_dir,CREATE_NO_WINDOW,&pi)){console_line("ENGINE CREATEPROCESS FAIL\r\n");LocalFree(args);return 5;}
  DWORD wait=WaitForSingleObject(pi.hProcess,15000),code=1;if(wait==WAIT_OBJECT_0)GetExitCodeProcess(pi.hProcess,&code);else TerminateProcess(pi.hProcess,6);
  CloseHandle(pi.hProcess);CloseHandle(pi.hThread);LocalFree(args);console_line(code==0?"WINDOWS ENGINE SELFTEST PASS\r\n":"WINDOWS ENGINE SELFTEST FAIL\r\n");return code==0?0:6;
 }
 LocalFree(args);
 wchar_t appdata[PATH_CAP],data[PATH_CAP],romdir[PATH_CAP],rom[PATH_CAP],saves[PATH_CAP],states[PATH_CAP],shots[PATH_CAP];
 if(FAILED(SHGetFolderPathW(NULL,CSIDL_LOCAL_APPDATA,NULL,SHGFP_TYPE_CURRENT,appdata)))return fail(L"无法定位当前用户的数据目录。");
 if(!path_join(data,appdata,L"ShiningSoulPlayer")||!path_join(romdir,data,L"ROMs")||!path_join(rom,romdir,L"ShiningSoul.gba")||!path_join(saves,data,L"Saves")||!path_join(states,data,L"States")||!path_join(shots,data,L"Screenshots"))return fail(L"数据目录过长。");
 if(!make_dir(data)||!make_dir(romdir)||!make_dir(saves)||!make_dir(states)||!make_dir(shots))return fail(L"无法创建存档目录，请检查当前用户权限。");
 // Existing user data is never silently replaced.
 if(exists(rom)&&!digest_matches(rom,ROM_HASH))return fail(L"已导入的 ROM 校验失败。请备份数据后，移走 LocalAppData\\ShiningSoulPlayer\\ROMs\\ShiningSoul.gba 并重新导入；存档不会被自动删除。");
 if(!exists(rom)){
  wchar_t selected[PATH_CAP]={0};if(!choose_rom(selected))return 0;
  if(!digest_matches(selected,ROM_HASH))return fail(L"这不是此前分析的同一份 ROM，或文件已经损坏。请选择你上传的《光明之魂1.gba》（8 MiB，AHUJ 汉化版本）。本启动包不包含游戏 ROM。");
  if(!CopyFileW(selected,rom,TRUE))return fail(L"无法导入 ROM。请检查用户目录权限，或重新启动导入。");
  if(!digest_matches(rom,ROM_HASH))return fail(L"导入后的 ROM 校验失败；请保留原始文件并重新导入。");
 }
 if(!create_initial_config(engine_dir))return fail(L"无法创建首次配置。请把完整解压目录放到桌面或其他可写目录，不要直接在压缩包或只读目录内启动。");
 HRESULT hr=StringCchPrintfW(cmd,16384,L"\"%s\" --scale 4 -C \"savegamePath=%s\" -C \"savestatePath=%s\" -C \"screenshotPath=%s\" -C useBios=0 \"%s\"",engine,saves,states,shots,rom);
 if(FAILED(hr))return fail(L"启动参数过长。");
 PROCESS_INFORMATION pi={0};if(!start_child(engine,cmd,engine_dir,0,&pi)){
  wchar_t message[512];StringCchPrintfW(message,512,L"无法启动模拟器，Windows 错误码 %lu。请确认使用 Windows 10/11 64 位，并完整解压。",GetLastError());return fail(message);
 }
 // Holding the launcher process permits detection of immediate child failures.
 DWORD wait=WaitForSingleObject(pi.hProcess,2500);
 if(wait==WAIT_OBJECT_0){DWORD code;GetExitCodeProcess(pi.hProcess,&code);CloseHandle(pi.hProcess);CloseHandle(pi.hThread);if(code)return fail(L"模拟器启动后异常退出。可运行 engine\\mGBA.exe 查看详细提示。");return 0;}
 CloseHandle(pi.hProcess);CloseHandle(pi.hThread);return 0;
}
