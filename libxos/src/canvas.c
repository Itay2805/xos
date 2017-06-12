
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>
#include "component.h"

// xos_create_canvas:
// Creates a canvas component

xos_component xos_create_canvas(xos_window window, int16_t x, int16_t y, int16_t width, int16_t height)
{
	xos_component component = xos_find_free_component(window);
	if(component == -1)
		return -1;

	xos_canvas_t *canvas = (xos_canvas_t*)((component << 8) + libxos_windows[window].components);

	canvas->component_type = COMPONENT_CANVAS;
	canvas->x = x;
	canvas->y = y;
	canvas->width = width;
	canvas->height = height;
	canvas->buffer = malloc(width * height * 4);

	int count = width*height;
	int i = 0;

	while(i < count)
	{
		canvas->buffer[i] = 0xFFFFFF;		// reset canvas to white, default color
		i++;
	}

	xos_redraw(window);
	return component;
}

// xos_redraw_canvas:
// Redraws a canvas

void xos_redraw_canvas(xos_window window, xos_canvas_t *canvas)
{
	k_window window_info;
	k_get_window(libxos_windows[window].k_window, &window_info);

	uint32_t *offset = ((canvas->y * window_info.width) + (canvas->x * 4) + window_info.canvas);
	uint32_t *buffer = canvas->buffer;

	int16_t x2 = 0, y2 = 0;

	for(y2 = 0; y2 < canvas->height; y2++)
	{
		for(x2 = 0; x2 < canvas->width; x2++)
		{
			offset[x2] = buffer[x2];
		}

		offset += window_info.width;
		buffer += canvas->width;
	}
}

// xos_canvas_get_buffer:
// Returns a raw 32-bit RGB pixel buffer of a canvas

uint32_t *xos_canvas_get_buffer(xos_window window, xos_component component)
{
	xos_canvas_t *canvas;
	canvas = (xos_canvas_t*)((component << 8) + libxos_windows[window].components);

	return canvas->buffer;
}


