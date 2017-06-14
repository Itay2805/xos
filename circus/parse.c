
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>
#include "parse.h"

extern xos_window window;
extern char status_text[64];
extern char current_uri[512];
extern char idle_status_text[];
extern char loading_status_text[];
extern char parsing_status_text[];
extern char missing_status_text[];
extern char no_file_status_text[];

html_parse_t *parse_buffer;
size_t parse_buffer_size;
size_t html_offset;

void parse_tag(char *data, size_t size);

size_t copy_text(char *html, char *buffer)
{
	size_t i = 0;

	while(html[i] != 0 && html[i] != '<' && html[i] != '>')
	{
		buffer[i] = html[i];
		i++;
	}

	return i;
}

size_t copy_tag(char *html, char *buffer)
{
	size_t i = 0;

	while(html[i] != 0 && html[i] != ' ' && html[i] != '<' && html[i] != '>' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	return i;
}

html_parse_t *parse(char *data, size_t size)
{
	// update status
	strcpy(status_text, parsing_status_text);
	xos_redraw(window);

	parse_buffer = malloc(HTML_PARSE_WINDOW);
	parse_buffer_size = 0;
	html_offset = 0;
	html_text_t *text;

	while(html_offset < size)
	{
		if(parse_buffer_size % HTML_PARSE_WINDOW == 0)
			parse_buffer = realloc(parse_buffer, parse_buffer_size + HTML_PARSE_WINDOW);

		if(data[html_offset] == '<')
			parse_tag(data + html_offset, size);

		else
		{
			text = (html_text_t*)(parse_buffer + parse_buffer_size);
			text->type = HTML_PARSE_TEXT;
			text->size = copy_text(data + html_offset, text->text);

			html_offset += text->size;
			text->size += sizeof(html_parse_t);
			parse_buffer_size += text->size;
		}
	}

	return parse_buffer;
}

// parse_tag:
// Parses a tag

void parse_tag(char *data, size_t size)
{
	html_tag_t *tag;

	if(data[1] == '/')
	{
		tag = (html_tag_t*)(parse_buffer + parse_buffer_size);
		tag->type = HTML_PARSE_CLOSE_TAG;
		tag->size = copy_tag(data + 2, tag->tag);

		html_offset += tag->size + 3;
		tag->size += sizeof(html_parse_t);

		parse_buffer_size += tag->size;
	}
	else
	{
		tag = (html_tag_t*)(parse_buffer + parse_buffer_size);
		tag->type = HTML_PARSE_OPEN_TAG;
		tag->size = copy_tag(data + 1, tag->tag);

		html_offset += tag->size + 2;
		tag->size += sizeof(html_parse_t);

		parse_buffer_size += tag->size;
	}
}




