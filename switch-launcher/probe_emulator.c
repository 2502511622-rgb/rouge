#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>
int WINAPI wWinMain(HINSTANCE a,HINSTANCE b,PWSTR c,int d){(void)a;(void)b;(void)c;(void)d;wchar_t path[2048],cwd[2048];if(!GetEnvironmentVariableW(L"SWITCH_LAUNCHER_PROBE_FILE",path,2048))return 30;HANDLE f=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,0,NULL);if(f==INVALID_HANDLE_VALUE)return 31;DWORD n;WORD bom=0xfeff;WriteFile(f,&bom,2,&n,NULL);GetCurrentDirectoryW(2048,cwd);WriteFile(f,cwd,(DWORD)wcslen(cwd)*2,&n,NULL);WriteFile(f,L"\r\n",4,&n,NULL);int argc;wchar_t**args=CommandLineToArgvW(GetCommandLineW(),&argc);for(int i=0;i<argc;++i){WriteFile(f,args[i],(DWORD)wcslen(args[i])*2,&n,NULL);WriteFile(f,L"\r\n",4,&n,NULL);}LocalFree(args);CloseHandle(f);return 0;}
