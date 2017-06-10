
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#ifndef __XOS_H_LIBXOS__
#define __XOS_H_LIBXOS__

#include <stdtyp.h>

#define LIBXOS_MAX_WINDOWS		256
#define LIBXOS_MAX_COMPONENTS		256

// Default Colors
#define WINDOW_COLOR			0x383838
#define BUTTON_OUTLINE			0x505060
#define BUTTON_BG			0x202020
#define BUTTON_FG			0xD8D8D8
#define TEXTBOX_BG			0x484848
#define TEXTBOX_FG			0xFFFFFF
#define OUTLINE_FOCUS			0x505060
#define OUTLINE				0x383838

// Window Events
#define WM_LEFT_CLICK			0x0001
#define WM_RIGHT_CLICK			0x0002
#define WM_KEYPRESS			0x0004
#define WM_CLOSE			0x0008
#define WM_GOT_FOCUS			0x0010
#define WM_LOST_FOCUS			0x0020
#define WM_DRAG				0x0040

typedef struct k_mouse_status
{
	int16_t x;		// 00
	int16_t y;		// 02
}__attribute__((packed)) k_mouse_status;

typedef struct k_window
{
	int16_t x;		// 00
	int16_t y;		// 02
	int16_t width;		// 04
	int16_t height;		// 06
	uint16_t flags;		// 08
	uint32_t canvas;	// 0A
	uint32_t title;		// 0E
}__attribute__((packed)) k_window;

typedef struct libxos_internal_window
{
	uint8_t present;
	uint8_t lock;
	int32_t k_window;
	uint32_t color;
	uint8_t *components;
}__attribute__((packed)) libxos_internal_window;

// Internal kernel functions - meant to be used internally by libxos
extern int32_t k_create_window(int16_t x, int16_t y, int16_t width, int16_t height, uint16_t flags, const char *title);
extern void k_yield();
extern uint32_t k_pixel_offset(int32_t window, int16_t x, int16_t y);
extern void k_redraw();
extern uint16_t k_read_event(int32_t window);
extern void k_read_mouse(int32_t window, k_mouse_status *mouse);
extern void k_get_window(int32_t window, k_window *window_info);
extern void k_draw_text(int32_t window, int16_t x, int16_t y, uint32_t color, const char *text);
extern void k_clear(int32_t window, uint32_t color);
extern void *malloc(size_t size);
extern void free(void *memory);

extern libxos_internal_window *libxos_windows;

typedef int32_t xos_window;
typedef int32_t xos_component;

typedef struct xos_label_t
{
	uint8_t component_type;
	int16_t x;
	int16_t y;
	uint32_t color;
	const char *text;
}__attribute__((packed)) xos_label_t;

// These functions are meant for the user program
extern xos_window xos_create_window(int16_t x, int16_t y, int16_t width, int16_t height, uint16_t flags, const char *title);
extern void xos_lock(xos_window window);
extern void xos_unlock(xos_window window);
extern void xos_redraw(xos_window window);
extern xos_component xos_find_free_component(xos_window window);
extern xos_component xos_create_label(xos_window window, int16_t x, int16_t y, uint32_t color, const char *text);
extern void xos_redraw_label(xos_window window, xos_label_t *label);

#endif


