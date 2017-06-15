
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
signed int render_visible = 0;

void create_render_tree(html_parse_t *data);
void draw_render_tree();
void render_clear(unsigned int color);
void render_text(render_op_text *text);

// render:
// Rendering core

void render(html_parse_t *data)
{
	// update status
	strcpy(status_text, rendering_status_text);
	xos_redraw(window);

	create_render_tree(data);	// create the rendering tree

	int vscroll_max = (render_y + 15) / 16;
	if(vscroll_max == 0)
		vscroll_max++;

	xos_vscroll_set_max(window, vscroll, vscroll_max);	// update the scrollbar, which also sets it to zero
	draw_render_tree();		// now render the screen

	free(data);
}

// create_render_tree:
// Builds up the tree of rendering objects

void create_render_tree(html_parse_t *data)
{
	render_visible = 0;
	render_bold_level = 0;

	// free any memory used by previous rendering
	if(render_tree != NULL)
		free(render_tree);

	render_tree = malloc(RENDER_TREE_WINDOW);
	render_tree_size = 0;
	render_x = 0;
	render_y = 0;

	html_tag_t *tag;
	html_text_t *text;
	render_op_text *op_text;

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

				else if(strcmp(tag->tag, "br") == 0)
				{
					render_x = 0;
					render_y += 16;
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

				break;

			case HTML_PARSE_TEXT:
				if(render_visible > 0)
					break;

				// if it was just a newline or such, ignore the text
				text = (html_text_t*)data;
				if(strcmp(text->text, "\n") == 0 || strcmp(text->text, "\r") == 0)
					break;

				// okay, add text to the rendering...
				op_text = (render_op_text*)(render_tree + render_tree_size);
				op_text->op = RENDER_OP_TEXT;
				op_text->size = strlen(text->text) + sizeof(render_op_text);
				op_text->font_size = 1;
				op_text->bg = 0xFFFFFFFF;
				op_text->fg = 0x000000;
				op_text->x = render_x;
				op_text->y = render_y;
				strcpy(op_text->text, text->text);

				op_text->font_weight = render_bold_level;

				render_tree_size += op_text->size;
				//render_y += op_text->font_size << 4;	// *16
				render_x += strlen(text->text) << 3;	// *8

				if(render_x >= canvas_width)
				{
					render_x = 0;
					render_y += op_text->font_size << 4;	// *16
				}
				break;

			default:
				break;
		}

		data = (html_parse_t*)(data + data->size);
	}

	unsigned char *end = (unsigned char*)render_tree + render_tree_size;
	end[0] = RENDER_OP_END;
	return;
}

// draw_render_tree:
// Draws the render tree to the window canvas

void draw_render_tree()
{
	render_x_pos = 0;
	render_y_pos = xos_vscroll_get_value(window, vscroll) * 16;

	render_clear(0xFFFFFF);

	render_op_text *text;

	size_t index = 0;
	while(render_tree[index] != RENDER_OP_END || index < render_tree_size)
	{
		switch(render_tree[index])
		{
			case RENDER_OP_TEXT:
				text = (render_op_text*)(render_tree + index);
				if(text->y < render_y_pos)
					break;

				else
					render_text(text);

				break;

			default:
				// undefined render opcode, should not be possible but okay..
				goto finish;
		}

		size_t *size = (size_t*)(render_tree + index + 1);
		index += size[0];
	}

finish:
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
	//offset += ((formatting->y + (formatting->font_size << 4)) * canvas_width) + ((formatting->x + (index << 3)) << 2);
	offset += y * canvas_width;
	offset += x;

	uint8_t font_data[17];

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
}

// render_text:
// Renders a string

void render_text(render_op_text *text)
{
	char *string = text->text;
	short index = 0;

	short x = text->x;
	short y = text->y;

	while(string[index] >= 0x20 && string[index] <= 0x7F)
	{
		if(string[index] != '\r' && string[index] != '\n')
		{
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





