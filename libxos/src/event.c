
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

// xos_determine_component:
// Determines the component from the mouse position

xos_component xos_determine_component(xos_window window, k_mouse_status *mouse)
{
	xos_component component = 0;
	xos_label_t *label;
	xos_button_t *button;
	xos_vscroll_t *vscroll;
	int16_t x, y, endx, endy;

	while(component < LIBXOS_MAX_COMPONENTS)
	{
		switch(libxos_windows[window].components[component << 8])
		{
			case COMPONENT_NONE:
				goto next_component;

			case COMPONENT_BUTTON:
				button = (xos_button_t*)((component << 8) + libxos_windows[window].components);
				x = button->x;
				y = button->y;
				endx = x + (strlen(button->text) << 4) + 32;
				endy = y + 32;

				if(mouse->x >= x && mouse->x <= endx && mouse->y >= y && mouse->y <= endy)
					return component;

				goto next_component;

			case COMPONENT_VSCROLL:
				vscroll = (xos_vscroll_t*)((component << 8) + libxos_windows[window].components);
				x = vscroll->x;
				y = vscroll->y;
				endx = x + 16;
				endy = y + vscroll->height;

				if(mouse->x >= x && mouse->x <= endx && mouse->y >= y && mouse->y <= endy)
					return component;

			default:
				goto next_component;
		}

	next_component:
		component++;
	}

	// no component..
	return 0;
}

// xos_poll_event:
// Polls for an event, blocking function

void xos_poll_event(xos_event_t *event)
{
	// check each window for an event
	xos_window window;
	xos_component component;
	uint16_t k_event;
	k_mouse_status mouse;

start:
	window = 0;
	component = 0;

	while(window < LIBXOS_MAX_WINDOWS)
	{
		if(libxos_windows[window].present != 1)
			goto next_window;

		// check for event
		k_event = k_read_event(libxos_windows[window].k_window);
		if(k_event & K_CLOSE)
		{
			event->type = XOS_EVENT_CLOSE;
			event->window = window;
			return;
		}

		else if(k_event & K_LEFT_CLICK)
		{
			event->type = XOS_EVENT_MOUSE_CLICK;
			event->window = window;

			k_read_mouse(libxos_windows[window].k_window, &mouse);

			libxos_windows[window].initial_click.x = mouse.x;
			libxos_windows[window].initial_click.y = mouse.y;

			event->mouse_coords.x = mouse.x;
			event->mouse_coords.y = mouse.y;

			// run through each component, check if any was clicked
			event->component = xos_determine_component(window, &mouse);
			return;
		}

		else if(k_event & K_DRAG)
		{
			event->type = XOS_EVENT_DRAG;
			event->window = window;

			k_read_mouse(libxos_windows[window].k_window, &mouse);
			event->mouse_coords.x = mouse.x;
			event->mouse_coords.y = mouse.y;

			// run through each component, check if any was dragged
			event->component = xos_determine_component(window, &mouse);

			if(libxos_windows[window].components[event->component << 8] == COMPONENT_VSCROLL)
				xos_handle_vscroll_event(window, (xos_vscroll_t*)((event->component << 8) + libxos_windows[window].components), &mouse);

			return;
		}

	next_window:
		window++;
	}

	// no event, wait again
	k_yield();
	goto start;
}

// xos_check_event:
// Checks for an event, non-blocking function

void xos_check_event(xos_event_t *event)
{
	// check each window for an event
	xos_window window;
	xos_component component;
	uint16_t k_event;
	k_mouse_status mouse;

start:
	window = 0;
	component = 0;

	while(window < LIBXOS_MAX_WINDOWS)
	{
		if(libxos_windows[window].present != 1)
			goto next_window;

		// check for event
		k_event = k_read_event(libxos_windows[window].k_window);
		if(k_event & K_CLOSE)
		{
			event->type = XOS_EVENT_CLOSE;
			event->window = window;
			return;
		}

		else if(k_event & K_LEFT_CLICK)
		{
			event->type = XOS_EVENT_MOUSE_CLICK;
			event->window = window;

			k_read_mouse(libxos_windows[window].k_window, &mouse);
			event->mouse_coords.x = mouse.x;
			event->mouse_coords.y = mouse.y;

			// run through each component, check if any was clicked
			event->component = xos_determine_component(window, &mouse);
			return;
		}

	next_window:
		window++;
	}

	// no event, return..
	event->type = XOS_EVENT_NONE;
	event->window = 0;
	event->component = 0;
	return;
}



