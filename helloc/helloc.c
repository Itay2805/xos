
/*
 * Hello World Program in C for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 */

#include <xos.h>

int xos_main()
{
	// create a window
	xos_window window;
	window = xos_create_window(64, 64, 256, 128, 0, "Hello world");

	xos_create_label(window, 8, 8, 0xFFFFFF, "Hello, world!\nThis program is written in C.\nThis is a label component.\n\nAbove is an empty line.");
	xos_redraw(window);

	// hang until the window closes
	while((k_read_event(libxos_windows[window].k_window) & WM_CLOSE) == 0)
	{
		k_yield();
	}

	return 0;
}


