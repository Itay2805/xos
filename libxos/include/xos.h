
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

// Kernel Events
#define K_LEFT_CLICK			0x0001
#define K_RIGHT_CLICK			0x0002
#define K_KEYPRESS			0x0004
#define K_CLOSE				0x0008
#define K_GOT_FOCUS			0x0010
#define K_LOST_FOCUS			0x0020
#define K_DRAG				0x0040

// Events
#define XOS_EVENT_NONE			0
#define XOS_EVENT_CLOSE			1
#define XOS_EVENT_MOUSE_CLICK		2
#define XOS_EVENT_KEYPRESS		3
#define XOS_EVENT_GOT_FOCUS		4
#define XOS_EVENT_LOST_FOCUS		5
#define XOS_EVENT_DRAG			6

// File Permission
#define FILE_WRITE			2
#define FILE_READ			4
#define FILE_CREATE			128

// Seeking in File
#define SEEK_SET			0
#define SEEK_CUR			1
#define SEEK_END			2

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

extern int32_t k_open(char *filename, uint32_t permissions);
extern void k_close(int32_t handle);
extern int32_t k_seek(int32_t handle, uint32_t base, size_t offset);
extern size_t k_tell(int32_t handle);
extern size_t k_read(int32_t handle, size_t count, void *buffer);
extern size_t k_write(int32_t handle, size_t count, void *buffer);

typedef struct libxos_internal_window
{
	uint8_t present;
	uint8_t lock;
	int32_t k_window;
	uint32_t color;
	uint8_t *components;
	k_mouse_status initial_click;
} libxos_internal_window;

typedef int32_t xos_window;
typedef int32_t xos_component;

typedef struct xos_mouse_event_t
{
	int16_t x;
	int16_t y;
} xos_mouse_event_t;

typedef struct xos_kbd_event_t
{
	uint8_t character;
	uint8_t scancode;
} xos_kbd_event_t;

typedef struct xos_event_t
{
	uint16_t type;
	xos_window window;
	xos_component component;
	xos_mouse_event_t mouse_coords;
	xos_kbd_event_t kbd;
} xos_event_t;

typedef struct xos_label_t
{
	uint8_t component_type;
	int16_t x;
	int16_t y;
	uint32_t color;
	const char *text;
} xos_label_t;

typedef struct xos_button_t
{
	uint8_t component_type;
	int16_t x;
	int16_t y;
	char *text;
} xos_button_t;

typedef struct xos_vscroll_t
{
	// these fields can be used by application
	uint8_t component_type;
	int16_t x;
	int16_t y;
	int16_t height;
	uint32_t max_value;
	uint32_t value;

	// these fields are for internal use and may change any time
	int16_t initial_click;
	uint32_t initial_value;
} xos_vscroll_t;

// These functions are meant for internal use by libXOS
extern void xos_fill_rect(xos_window window, int16_t x, int16_t y, int16_t width, int16_t height, uint32_t color);

// These functions are meant for the user program
extern libxos_internal_window *libxos_windows;
extern xos_window xos_create_window(int16_t x, int16_t y, int16_t width, int16_t height, uint16_t flags, const char *title);
extern void xos_lock(xos_window window);
extern void xos_unlock(xos_window window);
extern void xos_redraw(xos_window window);
extern xos_component xos_find_free_component(xos_window window);
extern void xos_poll_event(xos_event_t *event);
extern void xos_check_event(xos_event_t *event);

extern xos_component xos_create_label(xos_window window, int16_t x, int16_t y, uint32_t color, char *text);
extern void xos_redraw_label(xos_window window, xos_label_t *label);

extern xos_component xos_create_button(xos_window window, int16_t x, int16_t y, char *text);
extern void xos_redraw_button(xos_window window, xos_button_t *button);

extern xos_component xos_create_vscroll(xos_window window, int16_t x, int16_t y, int16_t height, uint32_t max);
extern void xos_redraw_vscroll(xos_window window, xos_vscroll_t *vscroll);
extern void xos_handle_vscroll_event(xos_window window, xos_vscroll_t *vscroll, k_mouse_status *mouse);

#endif


