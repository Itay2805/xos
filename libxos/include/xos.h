
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

// Internal kernel functions
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

extern void *libxos_data;

#endif


