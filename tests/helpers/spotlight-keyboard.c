/* Restricted Spotlight test transport: fixed calculation, favorite/context-menu chords, Enter, Tab, and Escape only. */
#define _GNU_SOURCE
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "keyboard-client.h"
static struct zwp_virtual_keyboard_manager_v1 *manager;
static struct wl_seat *seat;
static void global(void *data,struct wl_registry *registry,uint32_t name,const char *interface,uint32_t version) {
    (void)data;(void)version;
    if(!strcmp(interface,"zwp_virtual_keyboard_manager_v1"))manager=wl_registry_bind(registry,name,&zwp_virtual_keyboard_manager_v1_interface,1);
    if(!strcmp(interface,"wl_seat") && !seat)seat=wl_registry_bind(registry,name,&wl_seat_interface,1);
}
static void removed(void *data,struct wl_registry *registry,uint32_t name){(void)data;(void)registry;(void)name;}
static const struct wl_registry_listener listener={global,removed};
static uint32_t now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (uint32_t)(t.tv_sec*1000+t.tv_nsec/1000000);}
static void send_key(struct wl_display *display,struct zwp_virtual_keyboard_v1 *keyboard,struct xkb_state *state,uint32_t code,int pressed){
    zwp_virtual_keyboard_v1_key(keyboard,now(),code,pressed?WL_KEYBOARD_KEY_STATE_PRESSED:WL_KEYBOARD_KEY_STATE_RELEASED);
    xkb_state_update_key(state,code+8,pressed?XKB_KEY_DOWN:XKB_KEY_UP);
    zwp_virtual_keyboard_v1_modifiers(keyboard,xkb_state_serialize_mods(state,XKB_STATE_MODS_DEPRESSED),0,0,0);
    wl_display_roundtrip(display);usleep(30000);
}
int main(int argc,char **argv){
    if(argc!=2 || (strcmp(argv[1],"calculation") && strcmp(argv[1],"tab") && strcmp(argv[1],"escape") && strcmp(argv[1],"favorite") && strcmp(argv[1],"menu") && strcmp(argv[1],"enter") && strcmp(argv[1],"overview")))return 2;
    struct wl_display *display=wl_display_connect(NULL);if(!display)return 3;
    struct wl_registry *registry=wl_display_get_registry(display);wl_registry_add_listener(registry,&listener,NULL);wl_display_roundtrip(display);
    if(!manager || !seat)return 4;
    struct xkb_context *context=xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_rule_names names={.layout="us"};
    struct xkb_keymap *keymap=xkb_keymap_new_from_names(context,&names,XKB_KEYMAP_COMPILE_NO_FLAGS);if(!keymap)return 5;
    char *text=xkb_keymap_get_as_string(keymap,XKB_KEYMAP_FORMAT_TEXT_V1);if(!text)return 6;
    size_t size=strlen(text)+1;int fd=memfd_create("swiftshell-keyboard-audit",MFD_CLOEXEC);
    if(fd<0 || write(fd,text,size)!=(ssize_t)size)return 7;
    struct zwp_virtual_keyboard_v1 *keyboard=zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager,seat);
    zwp_virtual_keyboard_v1_keymap(keyboard,WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1,fd,(uint32_t)size);wl_display_roundtrip(display);close(fd);free(text);
    struct xkb_state *state=xkb_state_new(keymap);
    if(!strcmp(argv[1],"calculation")) {
        send_key(display,keyboard,state,KEY_2,1);send_key(display,keyboard,state,KEY_2,0);
        send_key(display,keyboard,state,KEY_LEFTSHIFT,1);
        send_key(display,keyboard,state,KEY_EQUAL,1);send_key(display,keyboard,state,KEY_EQUAL,0);
        send_key(display,keyboard,state,KEY_LEFTSHIFT,0);
        send_key(display,keyboard,state,KEY_2,1);send_key(display,keyboard,state,KEY_2,0);
    } else if(!strcmp(argv[1],"overview")) {
        send_key(display,keyboard,state,KEY_LEFTALT,1);
        send_key(display,keyboard,state,KEY_TAB,1);send_key(display,keyboard,state,KEY_TAB,0);
        send_key(display,keyboard,state,KEY_LEFTALT,0);
    } else if(!strcmp(argv[1],"favorite") || !strcmp(argv[1],"menu")) {
        uint32_t modifier=!strcmp(argv[1],"favorite") ? KEY_LEFTCTRL : KEY_LEFTSHIFT;
        uint32_t code=!strcmp(argv[1],"favorite") ? KEY_D : KEY_F10;
        send_key(display,keyboard,state,modifier,1);
        send_key(display,keyboard,state,code,1);send_key(display,keyboard,state,code,0);
        send_key(display,keyboard,state,modifier,0);
    } else {
        uint32_t key=!strcmp(argv[1],"tab") ? KEY_TAB : !strcmp(argv[1],"enter") ? KEY_ENTER : KEY_ESC;
        send_key(display,keyboard,state,key,1);send_key(display,keyboard,state,key,0);
    }
    zwp_virtual_keyboard_v1_destroy(keyboard);wl_display_roundtrip(display);
    xkb_state_unref(state);xkb_keymap_unref(keymap);xkb_context_unref(context);
    zwp_virtual_keyboard_manager_v1_destroy(manager);wl_registry_destroy(registry);wl_display_disconnect(display);return 0;
}
