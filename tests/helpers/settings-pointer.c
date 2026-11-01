/* Live test transport only. The Python harness restricts gestures to Settings. */
#include <wayland-client.h>
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include "pointer-client.h"
static struct zwlr_virtual_pointer_manager_v1 *manager;
struct output {struct wl_output *object;char name[128];};
static struct output outputs[16];static int output_count;
static void geometry(void*d,struct wl_output*o,int32_t x,int32_t y,int32_t a,int32_t b,int32_t sub,const char*make,const char*model,int32_t tr){(void)d;(void)o;(void)x;(void)y;(void)a;(void)b;(void)sub;(void)make;(void)model;(void)tr;}
static void mode(void*d,struct wl_output*o,uint32_t f,int32_t w,int32_t h,int32_t r){(void)d;(void)o;(void)f;(void)w;(void)h;(void)r;}
static void done(void*d,struct wl_output*o){(void)d;(void)o;}
static void scale(void*d,struct wl_output*o,int32_t s){(void)d;(void)o;(void)s;}
static void name(void*d,struct wl_output*o,const char*n){(void)o;snprintf(((struct output*)d)->name,128,"%s",n);}
static void description(void*d,struct wl_output*o,const char*s){(void)d;(void)o;(void)s;}
static const struct wl_output_listener output_listener={geometry,mode,done,scale,name,description};
static int cursor_matches(int x,int y){
    const char *runtime=getenv("XDG_RUNTIME_DIR"),*signature=getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if(!runtime||!signature)return 0;
    struct sockaddr_un address={.sun_family=AF_UNIX};
    if(snprintf(address.sun_path,sizeof(address.sun_path),"%s/hypr/%s/.socket.sock",runtime,signature)>=(int)sizeof(address.sun_path))return 0;
    int fd=socket(AF_UNIX,SOCK_STREAM,0);if(fd<0)return 0;
    struct timeval timeout={.tv_sec=2};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
    if(connect(fd,(struct sockaddr*)&address,sizeof(address))<0){close(fd);return 0;}
    const char *request="j/cursorpos";if(write(fd,request,strlen(request))<0){close(fd);return 0;}
    char buffer[512]={0};ssize_t count=read(fd,buffer,sizeof(buffer)-1);close(fd);if(count<=0)return 0;
    int cx=-999,cy=-999;char *px=strstr(buffer,"\"x\""),*py=strstr(buffer,"\"y\"");
    if(!px||!py)return 0;
    sscanf(px,"\"x\": %d",&cx);sscanf(py,"\"y\": %d",&cy);
    return abs(cx-x)<=2 && abs(cy-y)<=2;
}
static void global(void *data,struct wl_registry *registry,uint32_t name,const char *interface,uint32_t version) {
    (void)data;
    if(!strcmp(interface,"wl_output") && output_count<16){struct output *o=&outputs[output_count++];o->object=wl_registry_bind(registry,name,&wl_output_interface,version<4?version:4);wl_output_add_listener(o->object,&output_listener,o);}
    if(!strcmp(interface,"zwlr_virtual_pointer_manager_v1")) manager=wl_registry_bind(registry,name,&zwlr_virtual_pointer_manager_v1_interface,version<2?version:2);
}
static void removed(void *data,struct wl_registry *r,uint32_t name){(void)data;(void)r;(void)name;}
static const struct wl_registry_listener listener={global,removed};
static uint32_t now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (uint32_t)(t.tv_sec*1000+t.tv_nsec/1000000);}
static void move(struct wl_display *d,struct zwlr_virtual_pointer_v1 *p,int x,int y,int w,int h){
    zwlr_virtual_pointer_v1_motion_absolute(p,now(),x,y,w,h);zwlr_virtual_pointer_v1_frame(p);wl_display_roundtrip(d);
}
int main(int argc,char **argv){
    if(argc!=10){fprintf(stderr,"Expected local-x local-y output-width output-height delta-x delta-y connector global-x global-y\n");return 2;}
    int x=atoi(argv[1]),y=atoi(argv[2]),w=atoi(argv[3]),h=atoi(argv[4]),dx=atoi(argv[5]),dy=atoi(argv[6]);
    if(x<0||y<0||w<1||h<1||x>=w||y>=h||x+dx<0||y+dy<0||x+dx>=w||y+dy>=h)return 2;
    struct wl_display *d=wl_display_connect(NULL);if(!d)return 3;
    struct wl_registry *r=wl_display_get_registry(d);wl_registry_add_listener(r,&listener,NULL);wl_display_roundtrip(d);wl_display_roundtrip(d);if(!manager)return 4;
    struct wl_output *output=NULL;
    for(int i=0;i<output_count;i++)if(!strcmp(outputs[i].name,argv[7]))output=outputs[i].object;
    if(!output)return 5;
    struct zwlr_virtual_pointer_v1 *p=zwlr_virtual_pointer_manager_v1_create_virtual_pointer_with_output(manager,NULL,output);
    move(d,p,x,y,w,h);usleep(80000);
    if(!cursor_matches(atoi(argv[8]),atoi(argv[9]))){fprintf(stderr,"Pointer mapping mismatch; no button press sent.\n");return 6;}
    zwlr_virtual_pointer_v1_button(p,now(),BTN_LEFT,WL_POINTER_BUTTON_STATE_PRESSED);zwlr_virtual_pointer_v1_frame(p);wl_display_roundtrip(d);usleep(80000);
    for(int step=1;step<=12;step++){move(d,p,x+dx*step/12,y+dy*step/12,w,h);usleep(15000);}
    zwlr_virtual_pointer_v1_button(p,now(),BTN_LEFT,WL_POINTER_BUTTON_STATE_RELEASED);zwlr_virtual_pointer_v1_frame(p);wl_display_roundtrip(d);
    zwlr_virtual_pointer_v1_destroy(p);zwlr_virtual_pointer_manager_v1_destroy(manager);wl_registry_destroy(r);wl_display_disconnect(d);return 0;
}
