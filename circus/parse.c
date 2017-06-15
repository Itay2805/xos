
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
extern char rendering_status_text[];
extern char missing_status_text[];
extern char no_file_status_text[];

html_parse_t *parse_buffer;
size_t parse_buffer_size;
size_t html_offset;

void parse_tag(char *data, size_t size);

// copy_text:
// Copies text, returns size of copied text including NULL terminator

size_t copy_text(char *html, char *buffer)
{
	size_t i = 0;

	while(html[i] != 0 && html[i] != '<' && html[i] != '>')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// copy_tag:
// Copies HTML tag, returns size of total copied text including NULL terminator

size_t copy_tag(char *html, char *buffer)
{
	size_t i = 0;

	while(html[i] != 0 && html[i] != ' ' && html[i] != '<' && html[i] != '>' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// lowercase_string:
// Changes all characters in a string to lowercase

void lowercase_string(char *string)
{
	char *end_string = (char*)string + strlen(string);

	while(string < end_string)
	{
		if(string[0] >= 'A' && string[0] <= 'Z')
			string[0] += 0x20;

		string++;
	}
}

// remove_newlines:
// Removes newlines from a file

size_t remove_newlines(char *data, size_t size)
{
	size_t count = 0;
	size_t index = 0;

	while(index < size)
	{
		if(data[index] == '\n' || data[index] == '\r')
		{
			memcpy(data + index, data + index + 1, size - index);
			size--;
			count++;
		}

		index++;
	}

	return count;
}

// parse:
// Main parser

html_parse_t *parse(char *data, size_t size)
{
	// update status
	strcpy(status_text, parsing_status_text);
	xos_redraw(window);

	size -= remove_newlines(data, size);

	parse_buffer = malloc(HTML_PARSE_WINDOW);
	parse_buffer_size = 0;
	html_offset = 0;
	html_text_t *text;
	html_parse_t *end;

	while(html_offset < size)
	{
		if(parse_buffer_size % HTML_PARSE_WINDOW == 0)
			parse_buffer = realloc(parse_buffer, parse_buffer_size + HTML_PARSE_WINDOW);

		if(data[html_offset] == 0)
			goto finish;

		else if(data[html_offset] == '<')
			parse_tag(data + html_offset, size);

		else
		{
			text = (html_text_t*)(parse_buffer + parse_buffer_size);
			text->type = HTML_PARSE_TEXT;
			text->size = copy_text(data + html_offset, text->text);

			html_offset += text->size - 1;
			text->size += sizeof(html_parse_t);

			parse_buffer_size += text->size;
		}
	}

finish:
	end = (html_parse_t*)(parse_buffer + parse_buffer_size);

	end->type = HTML_PARSE_END;
	end->size = sizeof(html_parse_t);

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
		lowercase_string(tag->tag);		// case-insensitive

		html_offset += tag->size + 2;
		tag->size += sizeof(html_parse_t);

		parse_buffer_size += tag->size;
	}
	else
	{
		tag = (html_tag_t*)(parse_buffer + parse_buffer_size);
		tag->type = HTML_PARSE_OPEN_TAG;
		tag->size = copy_tag(data + 1, tag->tag);
		lowercase_string(tag->tag);		// case-insensitive

		html_offset += tag->size + 1;
		tag->size += sizeof(html_parse_t);

		parse_buffer_size += tag->size;
	}
}




