/* Read-only ROM runner using unmodified mGBA 0.10.5 (MPL-2.0).
 * Checkpoints contain emulated memory; SWI logs record actual call arguments.
 * This is an analysis tool, not a replacement for the Godot gameplay port. */
#include <mgba/core/core.h>
#include <mgba/internal/gba/gba.h>
#include <mgba/internal/arm/arm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
static unsigned frame;
static struct mCore *core;
static FILE *dma_log;
static void logger_cb(struct mLogger*l,int category,enum mLogLevel level,const char*format,va_list args){(void)l;(void)level;const char*name=mLogCategoryName(category);if(name && strstr(name,"DMA")){fprintf(dma_log,"frame=%u ",frame);vfprintf(dma_log,format,args);fputc('\n',dma_log);}}
static struct mLogger logger = {.log=logger_cb};
static FILE *trace;
static void (*swi16_original)(struct ARMCore*,int);
static void (*swi32_original)(struct ARMCore*,int);
static void record_swi(struct ARMCore* cpu,int n) {
 if ((n>=0x10 && n<=0x18) || ((n==0x0b || n==0x0c) && (unsigned)cpu->gprs[0]>=0x08000000 && (unsigned)cpu->gprs[0]<0x0a000000)) {
 fprintf(trace,"{\"frame\":%u,\"swi\":%d,\"pc\":%u,\"r0\":%u,\"r1\":%u,\"r2\":%u,\"source_header\":%u}\n",frame,n,(unsigned)cpu->gprs[15],(unsigned)cpu->gprs[0],(unsigned)cpu->gprs[1],(unsigned)cpu->gprs[2],core->busRead32(core,cpu->gprs[0]));
 }
}
static void swi16(struct ARMCore *cpu,int n){record_swi(cpu,n);swi16_original(cpu,n);}
static void swi32(struct ARMCore *cpu,int n){record_swi(cpu,(unsigned)n>>16);swi32_original(cpu,n);}
static void blob(const char *root,const char *name,const void *p,size_t n){char path[2048];snprintf(path,sizeof(path),"%s/%s",root,name);FILE*f=fopen(path,"wb");if(!f){perror(path);exit(4);}if(fwrite(p,1,n,f)!=n)exit(5);fclose(f);}
static void dump(const char*root,color_t*pixels){
 struct GBA *gba=core->board;
 mkdir(root,0700);
 blob(root,"frame.rgba",pixels,240*160*sizeof(color_t));
 blob(root,"palette.bin",gba->video.palette,1024);
 blob(root,"vram.bin",gba->video.vram,98304);
 blob(root,"oam.bin",&gba->video.oam,1024);
 blob(root,"ewram.bin",gba->memory.wram,262144);
 blob(root,"iwram.bin",gba->memory.iwram,32768);
 blob(root,"io.bin",gba->memory.io,1024);
 size_t n=core->stateSize(core);void *s=malloc(n);if(!core->saveState(core,s))exit(6);blob(root,"state.bin",s,n);free(s);
 char path[2048];snprintf(path,sizeof(path),"%s/cpu.json",root);FILE*f=fopen(path,"w");fprintf(f,"{\"frame\":%u,\"gprs\":[",frame);for(int i=0;i<16;++i)fprintf(f,"%s%u",i?",":"",(unsigned)((struct ARMCore*)core->cpu)->gprs[i]);fprintf(f,"]}\n");fclose(f);
}
int main(int argc,char**argv){
 if(argc<4){fprintf(stderr,"usage: gba_capture ROM OUTPUT_DIR SCENARIO [STATE]\nscenario lines: frames keymask checkpoint_name; use - for no checkpoint\n");return 2;}
 mkdir(argv[2],0700);char path[2048];snprintf(path,sizeof(path),"%s/swi.jsonl",argv[2]);trace=fopen(path,"w");if(!trace)return 3;
 snprintf(path,sizeof(path),"%s/dma.log",argv[2]);dma_log=fopen(path,"w");mLogSetDefaultLogger(&logger);
 core=mCoreFind(argv[1]);if(!core||!core->init(core))return 3;
 mCoreInitConfig(core,NULL);mCoreConfigSetDefaultIntValue(&core->config,"logLevel",0);mCoreLoadConfig(core);
 color_t*pixels=calloc(240*160,sizeof(color_t));core->setVideoBuffer(core,pixels,240);
 if(!mCoreLoadFile(core,argv[1]))return 3;core->reset(core);
 if(argc>4){FILE*f=fopen(argv[4],"rb");if(!f)return 7;size_t n=core->stateSize(core);void*s=malloc(n);if(fread(s,1,n,f)!=n)return 7;fclose(f);if(!core->loadState(core,s))return 7;free(s);}
 struct ARMCore *cpu=core->cpu;swi16_original=cpu->irqh.swi16;swi32_original=cpu->irqh.swi32;cpu->irqh.swi16=swi16;cpu->irqh.swi32=swi32;
 FILE*scenario=fopen(argv[3],"r");if(!scenario)return 8;unsigned count,keys;char name[128];
 while(fscanf(scenario,"%u %u %127s",&count,&keys,name)==3){core->setKeys(core,keys);for(unsigned i=0;i<count;++i){++frame;core->runFrame(core);}if(strcmp(name,"-")){snprintf(path,sizeof(path),"%s/%s",argv[2],name);dump(path,pixels);fprintf(stderr,"checkpoint %s frame=%u pc=%08x\n",name,frame,(unsigned)cpu->gprs[15]);}}
 fclose(scenario);fclose(trace);fclose(dma_log);core->deinit(core);free(pixels);return 0;
}
