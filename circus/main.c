
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>

#define CIRCUS_CLOSE				1
#define CIRCUS_SCROLL				2

xos_window window, uri_window;
xos_component back, forward, stop, uri, canvas, vscroll, hscroll, status;
short window_width, window_height, canvas_width, canvas_height;
int yield_times = 0;

char status_text[64];
char current_uri[512];
char homepage[] = "http://forum.osdev.org/";

char idle_status_text[] = "Status: Idle.";
char loading_status_text[] = "Status: Loading...";
char parsing_status_text[] = "Status: Parsing...";
char rendering_status_text[] = "Status: Rendering...";
char missing_status_text[] = "Status: Unimplemented feature, idle.";
char no_file_status_text[] = "Status: Requested file not found, idle.";
char no_protocol_status_text[] = "Status: Unsupported protocol, idle.";
char no_content_status_text[] = "Status: Content is not text/html, idle.";
char http_3xx_status_text[] = "Status: HTTP status 3xx, idle.";
char http_4xx_status_text[] = "Status: HTTP status 4xx, idle.";
char http_5xx_status_text[] = "Status: HTTP status 5xx, idle.";
char unknown_status_text[] = "Status: Undefined HTTP status, idle.";

int handle_events();
extern void load_page();
extern uint8_t font[];
extern void draw_render_tree();
extern int handle_canvas_event(short x, short y);

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
	vscroll = xos_create_vscroll(window, window_width-16, 32, canvas_height, 0);

	memset(status_text, 0, 64);
	memset(current_uri, 0, 512);
	strcpy(current_uri, homepage);
	strcpy(status_text, idle_status_text);

	status = xos_create_label(window, 4, window_height - 22, 0x000000, status_text);

	xos_create_canvas(window, 124, 4, window_width-128, 24);
	uri = xos_create_label(window, 128, 4+4, 0x000000, current_uri);

	xos_unlock(window);
	xos_redraw(window);

	// load the font
	int32_t file;
	file = k_open("font.bin", FILE_READ);
	k_read(file, 4096, font);
	k_close(file);

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

	if(event.type == XOS_EVENT_NONE)
		return 0;

	else if(event.type == XOS_EVENT_CLOSE)
		return CIRCUS_CLOSE;

	else if(event.type == XOS_EVENT_DRAG && event.component == vscroll)
	{
		yield_times = 8;
		return CIRCUS_SCROLL;
	}

	else if(event.type == XOS_EVENT_MOUSE_CLICK && event.component == canvas)
		return handle_canvas_event(event.mouse_coords.x, event.mouse_coords.y - 32);

	return 0;
}

// xos_yield_handler:
// Called every time the widget library is idle

void xos_yield_handler()
{
	yield_times++;
	if(yield_times >= 10)
	{
		draw_render_tree();
		yield_times = 0;
	}
}


