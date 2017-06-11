
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>
#include "component.h"

// xos_create_label:
// Creates a label

xos_component xos_create_label(xos_window window, int16_t x, int16_t y, uint32_t color, char *text)
{
	xos_component component = xos_find_free_component(window);
	if(component == -1)
		return -1;

	xos_label_t *label = (xos_label_t*)((component << 8) + libxos_windows[window].components);

	label->component_type = COMPONENT_LABEL;
	label->x = x;
	label->y = y;
	label->color = color;
	label->text = text;

	xos_redraw(window);
	return component;
}

// xos_redraw_label:
// Redraws a label

void xos_redraw_label(xos_window window, xos_label_t *label)
{
	int32_t k_window = libxos_windows[window].k_window;
	k_draw_text(k_window, label->x, label->y, label->color, label->text);
}


