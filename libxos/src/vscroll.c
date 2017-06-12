
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>
#include "component.h"

// xos_create_vscroll:
// Creates a vertical scrollbar

xos_component xos_create_vscroll(xos_window window, int16_t x, int16_t y, int16_t height, uint32_t max)
{
	xos_component component = xos_find_free_component(window);
	if(component == -1)
		return -1;

	if(!max)			// max value cannot be zero
		return -1;

	xos_vscroll_t *vscroll = (xos_vscroll_t*)((component << 8) + libxos_windows[window].components);

	vscroll->component_type = COMPONENT_VSCROLL;
	vscroll->x = x;
	vscroll->y = y;
	vscroll->height = height;
	vscroll->max_value = max;
	vscroll->value = 0;

	xos_redraw(window);
	return component;
}

// xos_redraw_vscroll:
// Redraws a vertical scrollbar

void xos_redraw_vscroll(xos_window window, xos_vscroll_t *vscroll)
{
	// the background
	xos_fill_rect(window, vscroll->x, vscroll->y, 16, vscroll->height, SCROLLBAR_BG);

	int16_t scroll_height = vscroll->height / (vscroll->max_value + 1);
	int16_t scroll_y = (vscroll->value * scroll_height) + vscroll->y;

	// the actual scrollbar
	xos_fill_rect(window, vscroll->x, scroll_y, 16, scroll_height, SCROLLBAR_FG);
}

// xos_handle_vscroll_event:
// Handles event of a vertical scrollbar

void xos_handle_vscroll_event(xos_window window, xos_vscroll_t *vscroll, k_mouse_status *mouse)
{
	int16_t initial_x, initial_y;
	initial_x = libxos_windows[window].initial_click.x;
	initial_y = libxos_windows[window].initial_click.y;

	int16_t endx, endy;
	endx = vscroll->x + 16;
	endy = vscroll->y + vscroll->height;

	if(initial_x < vscroll->x || initial_x > endx || initial_y < vscroll->y || initial_y > endx)
		return;

	int16_t y = mouse->y - vscroll->y;

	if(y < 0 || y > vscroll->height)		// too small or too large?
		return;					// ignore..

	int16_t scroll_height = vscroll->height / (vscroll->max_value + 1);

	vscroll->value = y / scroll_height;
	if(vscroll->value > vscroll->max_value)
		vscroll->value = vscroll->max_value;

	xos_redraw(window);
}

// xos_vscroll_set_max:
// Sets the maximum value of a vertical scrollbar

void xos_vscroll_set_max(xos_window window, xos_component component, uint32_t max)
{
	xos_vscroll_t *vscroll;
	vscroll = (xos_vscroll_t*)((component << 8) + libxos_windows[window].components);

	vscroll->max_value = max;
	if(vscroll->value > max)
		vscroll->value = 0;
}

// xos_vscroll_get_value:
// Returns the value of the vertical scrollbar

uint32_t xos_vscroll_get_value(xos_window window, xos_component component)
{
	xos_vscroll_t *vscroll;
	vscroll = (xos_vscroll_t*)((component << 8) + libxos_windows[window].components);

	return vscroll->value;
}





