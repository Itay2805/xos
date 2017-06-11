
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>
#include "component.h"

// xos_determine_component:
// Determines the component from the mouse position

xos_component xos_determine_component(xos_window window, k_mouse_status *mouse)
{
	return 0;	// stub, for now
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
			event->event_type = XOS_EVENT_CLOSE;
			event->window = window;
			return;
		}

		else if(k_event & K_LEFT_CLICK)
		{
			event->event_type = XOS_EVENT_MOUSE_CLICK;
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
			event->event_type = XOS_EVENT_CLOSE;
			event->window = window;
			return;
		}

		else if(k_event & K_LEFT_CLICK)
		{
			event->event_type = XOS_EVENT_MOUSE_CLICK;
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
	event->event_type = XOS_EVENT_NONE;
	event->window = 0;
	event->component = 0;
	return;
}



