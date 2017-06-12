
/*
 * Hello World Program in C for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 */

#include <xos.h>

int xos_main()
{
	xos_window window;
	xos_event_t event;
	xos_component button;

	// create a window
	window = xos_create_window(64, 64, 256, 180, 0, "Hello world");

	// make a label component
	xos_create_label(window, 8, 8, 0xFFFFFF, "Hello, world!\nThis program is written in C.\nThis is a label component.\n\nAbove is an empty line.");

	// and a button, just for showcase
	button = xos_create_button(window, 8, 98, "Test Button");

	xos_create_vscroll(window, 256-16, 0, 180, 8);

	// redraw the window
	xos_redraw(window);

	// hang until the window closes
	while(1)
	{
		xos_poll_event(&event);
		if(event.type == XOS_EVENT_CLOSE)
			break;

		else if(event.type == XOS_EVENT_MOUSE_CLICK && event.component == button)
			xos_create_label(window, 8, 146, 0xFFFFFF, "Button has been pressed.");
	}

	return 0;
}


