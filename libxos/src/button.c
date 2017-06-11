
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>
#include <string.h>
#include "component.h"

// xos_create_button:
// Creates a button

xos_component xos_create_button(xos_window window, int16_t x, int16_t y, char *text)
{
	xos_component component = xos_find_free_component(window);
	if(component == -1)
		return -1;

	xos_button_t *button = (xos_button_t*)((component << 8) + libxos_windows[window].components);

	button->component_type = COMPONENT_BUTTON;
	button->x = x;
	button->y = y;
	button->text = text;

	xos_redraw(window);
	return component;
}

// xos_redraw_button:
// Redraws a button component

void xos_redraw_button(xos_window window, xos_button_t *button)
{
	int16_t width = (int16_t)(strlen(button->text) << 4) + 32;
	int16_t text_x;

	text_x = (button->x + (button->x + width)) >> 1;
	text_x -= strlen(button->text) << 2;

	// draw the button outline
	xos_fill_rect(window, button->x, button->y, width, 32, BUTTON_OUTLINE);

	// the actual button
	xos_fill_rect(window, button->x+1, button->y+1, width-2, 30, BUTTON_BG);

	// the button text
	k_draw_text(libxos_windows[window].k_window, text_x, button->y+8, BUTTON_FG, button->text);
}


