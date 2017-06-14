
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>

#define CIRCUS_CLOSE				1

xos_window window, uri_window;
xos_component back, forward, stop, uri, canvas, vscroll, hscroll, status;
short window_width, window_height, canvas_width, canvas_height;

char status_text[64];
char current_uri[512];
char homepage[] = "file:///C:/test.html";

char idle_status_text[] = "Status: Idle.";
char loading_status_text[] = "Status: Loading...";
char parsing_status_text[] = "Status: Parsing...";
char missing_status_text[] = "Status: Unimplemented feature, idle.";
char no_file_status_text[] = "Status: Requested file not found.";

int handle_events();
extern void load_page();

// xos_main:
// Entry point

int xos_main()
{
	// create the interface
	k_screen screen;
	k_get_screen(&screen);

	window_width = screen.width - 4;
	window_height = screen.height - 56;

	window = xos_create_window(0, 0, window_width, window_height, 0, "Circus");
	xos_lock(window);

	back = xos_create_button(window, 0, 0, "<");
	forward = xos_create_button(window, 40, 0, ">");
	stop = xos_create_button(window, 80, 0, "x");

	canvas_width = window_width - 16;
	canvas_height = window_height - 32 - 24;

	canvas = xos_create_canvas(window, 0, 32, canvas_width, canvas_height);
	vscroll = xos_create_vscroll(window, window_width-16, 32, canvas_height, 1);

	memset(status_text, 0, 64);
	memset(current_uri, 0, 512);
	strcpy(current_uri, homepage);
	strcpy(status_text, idle_status_text);

	status = xos_create_label(window, 4, window_height - 22, 0x000000, status_text);

	xos_create_canvas(window, 124, 4, window_width-128, 24);
	uri = xos_create_label(window, 128, 4+4, 0x000000, current_uri);

	xos_unlock(window);
	xos_redraw(window);

	// load the home page
	load_page();

	int event;

	// wait here for event
	while(1)
	{
		event = handle_events();
		if(event == CIRCUS_CLOSE)
		{
			xos_destroy_window(window);
			return 0;
		}
	}
}

// handle_events:
// Handles GUI events

int handle_events()
{
	xos_event_t event;
	xos_poll_event(&event);

	if(event.type == XOS_EVENT_CLOSE)
		return CIRCUS_CLOSE;

	return 0;
}



