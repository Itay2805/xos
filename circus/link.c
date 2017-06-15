
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>
#include "render.h"

extern xos_window window;
extern char current_uri[];
extern unsigned char *render_tree;
extern size_t render_tree_size;
extern short render_x, render_y, render_y_pos, render_x_pos;
extern void load_page();

// handle_canvas_event:
// Handles canvas mouse click event

int handle_canvas_event(short x, short y)
{
	x += render_x_pos;
	y += render_y_pos;

	// determine if the mouse was clicked on a link
	// if so, follow the link
	render_op_link *link = (render_op_link*)render_tree;
	render_op_link *end_render_tree = (render_op_link*)(render_tree + render_tree_size);
	size_t index = 0;

	while(link < end_render_tree)
	{
		if(link->op == RENDER_OP_LINK)
		{
			if(x >= link->x && y >= link->y && x <= link->endx && y <= link->endy)
			{
				// follow the link
				strcpy(current_uri, link->address);
				xos_redraw(window);
				load_page();
				return 0;
			}

			else
			{
				index += link->size;
				link = (render_op_link*)(render_tree + index);
			}
		}

		else
			index += link->size;
			link = (render_op_link*)(render_tree + index);
	}
}


