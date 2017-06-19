
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>
#include "parse.h"
#include "render.h"

extern xos_window window;
extern xos_component canvas, vscroll, hscroll;
extern char status_text[64];
extern char current_uri[512];
extern char idle_status_text[];
extern char loading_status_text[];
extern char parsing_status_text[];
extern char rendering_status_text[];
extern char missing_status_text[];
extern char no_file_status_text[];
extern short canvas_width, canvas_height;

unsigned char *render_tree = NULL;
size_t render_tree_size;
uint8_t font[4096];
short render_x, render_y, render_y_pos, render_x_pos;
signed int render_bold_level = 0;
signed int render_underline_level = 0;
signed int render_visible = 0;
int render_is_link = 0;
unsigned int vscroll_max, vscroll_last;
char render_link_addr[512];
signed int render_list_level = -1;

void create_render_tree(html_parse_t *data);
void draw_render_tree();
void render_clear(unsigned int color);
void render_text(render_op_text *text);
void text_get_end(render_op_text *text);

// render:
// Rendering core

void render(html_parse_t *data)
{
	// update status
	strcpy(status_text, rendering_status_text);
	xos_redraw(window);

	create_render_tree(data);	// create the rendering tree

	if(render_y >= canvas_height)
		//vscroll_max = ((render_y + 31) / 32) + 3;
		vscroll_max = render_y / 32;
	else
		vscroll_max = 0;

	xos_vscroll_set_max(window, vscroll, vscroll_max);	// update the scrollbar, also sets its current value to zero

	strcpy(status_text, idle_status_text);

	vscroll_last = 0xFFFFFFFF;
	draw_render_tree();		// now render the screen
	free(data);
}

// create_render_tree:
// Builds up the tree of rendering objects

void create_render_tree(html_parse_t *data)
{
	// free any memory used by previous rendering
	if(render_tree != NULL)
		free(render_tree);

	render_visible = 0;
	render_bold_level = 0;
	render_underline_level = 0;
	render_is_link = 0;
	render_list_level = -1;

	render_tree = malloc(RENDER_TREE_WINDOW);
	render_tree_size = 0;
	render_x = 0;
	render_y = 0;

	html_tag_t *tag;
	html_text_t *text;
	html_attribute_t *attribute;

	render_op_text *op_text;
	render_op_link *op_link;

	while(data->type != HTML_PARSE_END)
	{
		if(render_tree_size % RENDER_TREE_WINDOW == 0)
			render_tree = realloc(render_tree, render_tree_size + RENDER_TREE_WINDOW);

		switch(data->type)
		{
			case HTML_PARSE_OPEN_TAG:		// handle open tags here
				tag = (html_tag_t*)data;
				if(strcmp(tag->tag, "html") == 0)
					render_visible = 0;

				else if(strcmp(tag->tag, "head") == 0)
					render_visible++;

				else if(strcmp(tag->tag, "title") == 0)
					render_visible++;

				else if(strcmp(tag->tag, "body") == 0)
					render_visible = 0;

				else if(strcmp(tag->tag, "script") == 0)
					render_visible++;

				else if(strcmp(tag->tag, "style") == 0)
					render_visible++;

				else if(strcmp(tag->tag, "strong") == 0)
					render_bold_level++;

				else if(strcmp(tag->tag, "b") == 0)
					render_bold_level++;

				else if(strcmp(tag->tag, "u") == 0)
					render_underline_level++;

				else if(strcmp(tag->tag, "br") == 0)
				{
					render_x = 0;
					render_y += 16;
				}

				else if(strcmp(tag->tag, "a") == 0)
				{
					memset(render_link_addr, 0, 512);
					render_is_link = 1;
				}

				else if(strcmp(tag->tag, "h1") == 0 || strcmp(tag->tag, "h2") == 0 || strcmp(tag->tag, "h3") == 0 || strcmp(tag->tag, "h4") == 0)
				{
					render_bold_level++;
					render_x = 0;
					render_y += 24;
				}

				else if(strcmp(tag->tag, "th") == 0)
				{
					render_bold_level++;
					render_x = 0;
					render_y += 16;
				}

				else if(strcmp(tag->tag, "td") == 0)
				{
					render_x = 0;
					render_y += 16;
				}

				else if(strcmp(tag->tag, "p") == 0)
				{
					render_x = 0;
					render_y += 16;
				}

				else if(strcmp(tag->tag, "ul") == 0)
				{
					render_x = 0;
					render_y += 16;
					render_list_level++;
				}

				else if(strcmp(tag->tag, "li") == 0)
				{
					render_y += 16;
					render_x = (render_list_level + 1) * 32;
					render_x += 16;

					op_text = (render_op_text*)(render_tree + render_tree_size);
					op_text->op = RENDER_OP_TEXT;
					op_text->size = sizeof(render_op_text) + strlen("[*]") + 1;
					op_text->font_size = 1;
					op_text->bg = 0xFFFFFFFF;
					op_text->fg = 0x000000;
					op_text->x = render_x;
					op_text->y = render_y;
					strcpy(op_text->text, "[*]");

					op_text->font_weight = render_bold_level;
					op_text->underline = render_underline_level;

					render_tree_size += op_text->size;
					text_get_end(op_text);
				}

				else if(strcmp(tag->tag, "div") == 0)
				{
					if(render_x != 0)
					{
						render_x = 0;
						render_y += 16;
					}
				}

				break;

			case HTML_PARSE_CLOSE_TAG:		// handle close tags here
				tag = (html_tag_t*)data;
				if(strcmp(tag->tag, "html") == 0)
					return;		// when we close the HTML tag, all rendering is finished

				else if(strcmp(tag->tag, "body") == 0)
					return;		// same for body

				else if(strcmp(tag->tag, "script") == 0)
					render_visible--;

				else if(strcmp(tag->tag, "style") == 0)
					render_visible--;

				else if(strcmp(tag->tag, "strong") == 0)
					render_bold_level--;

				else if(strcmp(tag->tag, "b") == 0)
					render_bold_level--;

				else if(strcmp(tag->tag, "u") == 0)
					render_underline_level--;

				else if(strcmp(tag->tag, "a") == 0)
					render_is_link = 0;

				else if(strcmp(tag->tag, "h1") == 0 || strcmp(tag->tag, "h2") == 0 || strcmp(tag->tag, "h3") == 0 || strcmp(tag->tag, "h4") == 0)
				{
					render_bold_level--;
					render_x = 0;
					render_y += 24;
				}

				else if(strcmp(tag->tag, "th") == 0)
				{
					render_bold_level--;
					render_x = 0;
					render_y += 16;
				}

				else if(strcmp(tag->tag, "p") == 0)
				{
					render_x = 0;
					render_y += 16;
				}

				else if(strcmp(tag->tag, "ul") == 0)
				{
					render_x = 0;
					render_y += 16;
					render_list_level--;
				}

				else if(strcmp(tag->tag, "div") == 0)
				{
					if(render_x != 0)
					{
						render_x = 0;
						render_y += 16;
					}
				}

				break;

			case HTML_PARSE_ATTRIBUTE:
				attribute = (html_attribute_t*)data;

				if(render_is_link == 1 && strcmp(attribute->attribute, "href") == 0)
				{
					strcpy(render_link_addr, attribute->value);
				}

				break;

			case HTML_PARSE_TEXT:
				if(render_visible > 0)
					break;

				// if it was just a newline or such, ignore the text
				text = (html_text_t*)data;
				//if(strcmp(text->text, "\n") == 0 || strcmp(text->text, "\r") == 0)
					//break;

				// is it a link a normal text?
				if(render_is_link == 1)
				{
					// add the text of the link
					op_text = (render_op_text*)(render_tree + render_tree_size);
					op_text->op = RENDER_OP_TEXT;
					op_text->size = strlen(text->text) + sizeof(render_op_text) + 1;
					op_text->font_size = 1;
					op_text->bg = 0xFFFFFFFF;
					op_text->fg = 0x0000B0;
					op_text->x = render_x;
					op_text->y = render_y;
					strcpy(op_text->text, text->text);

					op_text->font_weight = render_bold_level;
					op_text->underline = 1;

					render_tree_size += op_text->size;

					// and the action of the link, of course
					op_link = (render_op_link*)(render_tree + render_tree_size);
					op_link->op = RENDER_OP_LINK;
					op_link->size = strlen(render_link_addr) + sizeof(render_op_link) + 1;
					op_link->x = render_x;
					op_link->y = render_y;
					op_link->endx = render_x + (strlen(op_text->text) * 8);
					op_link->endy = render_y + 16;
					strcpy(op_link->address, render_link_addr);

					render_tree_size += op_link->size;

					/*if(strlen(text->text) * 8 >= canvas_width)
					{
						render_y += (((strlen(text->text) * 8 + canvas_width-1)) / canvas_width) * 16;
						render_y -= 16;
						render_x += strlen(text->text) * 8;
						while(render_x >= canvas_width)
						{
							render_x -= canvas_width;
						}

						if(render_x < 0)
							render_x = 0;
						else
							render_x += 8;
					} else
					{
						render_x += strlen(text->text) * 8;
					}*/

					text_get_end(op_text);
				} else
				{
					// add text to the rendering
					op_text = (render_op_text*)(render_tree + render_tree_size);
					op_text->op = RENDER_OP_TEXT;
					op_text->size = strlen(text->text) + sizeof(render_op_text) + 1;
					op_text->font_size = 1;
					op_text->bg = 0xFFFFFFFF;
					op_text->fg = 0x000000;
					op_text->x = render_x;
					op_text->y = render_y;
					strcpy(op_text->text, text->text);

					op_text->font_weight = render_bold_level;
					op_text->underline = render_underline_level;

					render_tree_size += op_text->size;

					//render_y += op_text->font_size << 4;	// *16
					//render_x += strlen(text->text) << 3;	// *8

					/*if(strlen(text->text) * 8 >= canvas_width)
					{
						render_y += (((strlen(text->text) * 8 + canvas_width-1)) / canvas_width) * 16;
						render_y -= 16;
						render_x += strlen(text->text) * 8;
						while(render_x >= canvas_width)
						{
							render_x -= canvas_width;
						}

						if(render_x < 0)
							render_x = 0;
						else
							render_x += 8;
					} else
					{
						render_x += strlen(text->text) * 8;
					}*/

					text_get_end(op_text);
				}

				if(render_x >= canvas_width)
				{
					render_x = 0;
					render_y += 16;
				}
				break;

			default:
				break;
		}

		data = (html_parse_t*)(data + data->size);
	}

	unsigned char *end = (unsigned char*)render_tree + render_tree_size;
	end[0] = RENDER_OP_END;
	end[1] = 0;
	end[2] = 0;
	end[3] = 0;
	end[4] = 0;

	render_tree_size += 5;

	// free the HTML parse result, we won't need it anymore
	free(data);
	return;
}

// draw_render_tree:
// Draws the render tree to the window canvas

void draw_render_tree()
{
	render_x_pos = 0;
	unsigned int vscroll_val = xos_vscroll_get_value(window, vscroll);
	if(vscroll_val == vscroll_last)
		return;

	render_y_pos = vscroll_val * 32;
	vscroll_last = vscroll_val;

	if(render_y_pos >= render_y)
		return;

	render_clear(0xFFFFFF);

	render_op_text *text;

	size_t index = 0;
	while(render_tree[index] != RENDER_OP_END || index < render_tree_size)
	{
		switch(render_tree[index])
		{
			case RENDER_OP_TEXT:
				text = (render_op_text*)(render_tree + index);

				if(text->y < render_y_pos || text->y > render_y_pos + canvas_height - 16)
					break;

				else
					render_text(text);

				break;

			case RENDER_OP_LINK:
				break;

			default:
				// undefined render opcode, should not be possible but okay..
				xos_redraw(window);
				return;
		}

		size_t *size = (size_t*)(render_tree + index + 1);
		index += size[0];
	}

	xos_redraw(window);
}

// render_clear:
// Clears the window canvas

void render_clear(unsigned int color)
{
	size_t canvas_size = canvas_width * canvas_height;
	size_t index = 0;
	unsigned int *canvas_ptr = xos_canvas_get_buffer(window, canvas);

	while(index < canvas_size)
	{
		canvas_ptr[index] = color;
		index++;
	}
}

// render_char:
// Renders a single character, formatting provided in structure for simplicity

void render_char(char character, short x, short y, render_op_text *formatting)
{
	unsigned int *offset = xos_canvas_get_buffer(window, canvas);
	offset += y * canvas_width;
	offset += x;

	uint8_t font_data[16];

	font_data[0] = font[character << 4];
	font_data[1] = font[(character << 4) + 1];
	font_data[2] = font[(character << 4) + 2];
	font_data[3] = font[(character << 4) + 3];
	font_data[4] = font[(character << 4) + 4];
	font_data[5] = font[(character << 4) + 5];
	font_data[6] = font[(character << 4) + 6];
	font_data[7] = font[(character << 4) + 7];
	font_data[8] = font[(character << 4) + 8];
	font_data[9] = font[(character << 4) + 9];
	font_data[10] = font[(character << 4) + 10];
	font_data[11] = font[(character << 4) + 11];
	font_data[12] = font[(character << 4) + 12];
	font_data[13] = font[(character << 4) + 13];
	font_data[14] = font[(character << 4) + 14];
	font_data[15] = font[(character << 4) + 15];

	int row = 0, column = 0;
	int font_height = formatting->font_size << 4;	// *16
	int font_width = font_height >> 1;		// /2
	unsigned int color;

	uint8_t font_byte = font_data[row];

	while(row < font_height)
	{
		while(column < font_width)
		{
			if(font_byte & 0x80)
			{
				offset[column] = formatting->fg;
			} else
			{
				if(formatting->bg != 0xFFFFFFFF)
					offset[column] = formatting->bg;
			}

			font_byte <<= 1;
			column++;
		}

		column = 0;
		row++;
		font_byte = font_data[row];
		offset += canvas_width;
	}

	if(formatting->underline > 0)
	{
		//offset += canvas_width;
		size_t i = 0;

		while(i < font_width)
		{
			offset[i] = formatting->fg;
			i++;
		}
	}
}

// text_get_end:
// Gets the end X/Y coords of text

void text_get_end(render_op_text *text)
{
	char *string = text->text;
	short index = 0;

	while(string[index] >= 0x20 && string[index] <= 0x7F)
	{
		if(string[index] != '\r' && string[index] != '\n' && string[index] != '\t')
		{
			if(render_x >= canvas_width - 16)
			{
				render_x = 0;
				render_y += 16;
			}

			render_x += 8;
		}

		index++;
	}
}

// render_text:
// Renders a string

void render_text(render_op_text *text)
{
	char *string = text->text;
	short index = 0;

	short x = text->x - render_x_pos;
	short y = text->y - render_y_pos;

	while(string[index] >= 0x20 && string[index] <= 0x7F)
	{
		if(string[index] != '\r' && string[index] != '\n' && string[index] != '\t')
		{
			if(x >= canvas_width - 16)
			{
				x = 0;
				y += 16;
			}

			if(y >= canvas_height - 16)
				return;

			if(text->font_weight > 0)
			{
				render_char(string[index], x, y, text);
				render_char(string[index], x+1, y, text);
			} else
			{
				render_char(string[index], x, y, text);
			}

			render_char(string[index], x, y, text);

			x += 8;
		}

		index++;
	}
}


