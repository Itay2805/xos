
/*
 * Hello World Program in C for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 */

#include <xos.h>

int xos_main()
{
	xos_window window;
	xos_event_t event;

	// create a window
	window = xos_create_window(64, 64, 256, 128, 0, "Hello world");

	// make a label component
	xos_create_label(window, 8, 8, 0xFFFFFF, "Hello, world!\nThis program is written in C.\nThis is a label component.\n\nAbove is an empty line.");

	// redraw the window
	xos_redraw(window);

	// hang until the window closes
	while(1)
	{
		xos_poll_event(&event);
		if(event.event_type == XOS_EVENT_CLOSE)
			break;
	}

	return 0;
}


