
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

// link_last_path:
// Returns pointer to the last path separator in a path

char *link_last_path(char *path)
{
	char *end_path = (char *)path + strlen(path);
	char *ret;

	while(path < end_path)
	{
		if(path[0] == '/')
			ret = path;

		path++;
	}

	return ret;
}

// handle_canvas_event:
// Handles canvas mouse click event

int handle_canvas_event(short x, short y)
{
	char link_addr[512];
	x += render_x_pos;
	y += render_y_pos;

	memset(link_addr, 0, 512);
	char *path_copy;

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
				strcpy(link_addr, link->address);

				// if the link is absolute, simply follow it
				if(memcmp(link_addr, "file://", 7) == 0 || memcmp(link_addr, "http", 4) == 0)
				{
					strcpy(current_uri, link_addr);
				} else
				{
					if(link_addr[0] == '.' && link_addr[1] == '/')
					{
						path_copy = link_last_path(current_uri);
						path_copy++;

						strcpy(path_copy, link_addr + 2);
					} else
					{
						path_copy = link_last_path(current_uri);
						path_copy++;

						strcpy(path_copy, link_addr);
					}
				}

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


