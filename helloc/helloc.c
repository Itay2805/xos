
/*
 * Hello World Program in C for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 */

#include <xos.h>

int xos_main()
{
	// create a window
	int32_t window;
	window = k_create_window(64, 64, 320, 128, 0, "Hello, world!");

	// draw text in the window
	k_draw_text(window, 8, 8, 0xFFFFFF, "Welcome to the Hello World application\nThis application was written in C.\n\nThere should be an empty line above.");

	// redraw the screen
	k_redraw();

	// hang until the window closes
	while((k_read_event(window) & WM_CLOSE) == 0)
	{
		k_yield();
	}

	return 0;
}


