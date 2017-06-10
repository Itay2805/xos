
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>
#include "component.h"

// xos_poll_event:
// Polls for an event

void xos_poll_event(xos_event_t *event)
{
	// check each window for an event
	xos_window window;
	xos_component component;
	uint16_t k_event;

start:
	window = 0;
	component = 0;

	while(window < LIBXOS_MAX_WINDOWS)
	{
		if(libxos_windows[window].present != 1)
			goto next_window;

		// check for event
		k_event = k_read_event(libxos_windows[window].k_window);
		if((k_event & K_CLOSE) != 0)
		{
			event->event_type = XOS_EVENT_CLOSE;
			event->window = window;
			return;
		}

	next_window:
		window++;
	}

	// no event, wait again
	k_yield();
	goto start;
}



