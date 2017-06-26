
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
size_t html_offset, html_size;
char *html_buffer;

void parse_tag(unsigned char *data, size_t size);
void parse_attributes(unsigned char *data);
void skip_comment(unsigned char *data);

// copy_text:
// Copies text, returns size of copied text including NULL terminator

size_t copy_text(unsigned char *html, unsigned char *buffer)
{
	size_t i = 0;

	while((uint32_t)(html + i) < (uint32_t)(html_buffer + html_size) && html[i] != 0 && html[i] != '<' && html[i] >= 0x20 && html[i] <= 0x7F)
	{
		if(html[i] == 0xA0)
			buffer[i] = ' ';

		else
			buffer[i] = html[i];

		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// copy_tag:
// Copies HTML tag, returns size of total copied text including NULL terminator

size_t copy_tag(unsigned char *html, unsigned char *buffer)
{
	size_t i = 0;

	while((uint32_t)(html + i) < (uint32_t)(html_buffer + html_size) && html[i] != 0 && html[i] != '/' && html[i] != ' ' && html[i] != '<' && html[i] != '>' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// copy_attribute_name:
// Copies the name of an attribute

size_t copy_attribute_name(unsigned char *html, unsigned char *buffer)
{
	size_t i = 0;

	while((uint32_t)(html + i) < (uint32_t)(html_buffer + html_size) && html[i] != 0 && html[i] != '=' && html[i] != '>' && html[i] != ' ' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// copy_attribute_dq:
// Copies content of an attribute, surround by double quotes

size_t copy_attribute_dq(unsigned char *html, unsigned char *buffer)
{
	size_t i = 0;

	while((uint32_t)(html + i) < (uint32_t)(html_buffer + html_size) && html[i] != 0 && html[i] != '"' && html[i] != '>' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// copy_attribute_sq:
// Copies content of attribute, surrounded by single quotes

size_t copy_attribute_sq(unsigned char *html, unsigned char *buffer)
{
	size_t i = 0;

	while((uint32_t)(html + i) < (uint32_t)(html_buffer + html_size) && html[i] != 0 && html[i] != '\'' && html[i] != '>' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// copy_attribute_nq:
// Copies content of attribute, not surrounded by quotes

size_t copy_attribute_nq(unsigned char *html, unsigned char *buffer)
{
	size_t i = 0;

	while((uint32_t)(html + i) < (uint32_t)(html_buffer + html_size) && html[i] != 0 && html[i] != ' ' && html[i] != '>' && html[i] != '\n' && html[i] != '\r')
	{
		buffer[i] = html[i];
		i++;
	}

	buffer[i] = 0;
	return strlen(buffer) + 1;
}

// lowercase_string:
// Changes all characters in a string to lowercase

void lowercase_string(unsigned char *string)
{
	unsigned char *end_string = (unsigned char*)string + strlen(string);

	while(string < end_string)
	{
		if(string[0] >= 'A' && string[0] <= 'Z')
			string[0] += 0x20;

		string++;
	}
}

// remove_newlines:
// Removes newlines from a file

size_t remove_newlines(unsigned char *data, size_t size)
{
/*	size_t count = 0;
	size_t index = 0;

	char *data2 = malloc(size);
	memcpy(data2, data, size);

	size_t new_data_size = 0;

	while(index < size)
	{
		if(data[index] == '\n' || data[index] == '\r')
		{
			count++;
		} else
		{
			data2[new_data_size] = data[index];
			new_data_size++;
		}

		index++;
	}

	memcpy(data, data2, new_data_size+1);
	free(data2);
	return new_data_size;*/

	size_t count = 0;
	while(count < size)
	{
		if(data[count] == '\n' || data[count] == '\r' || data[count] == '\t' || data[count] < 0x20 || data[count] > 0x7F)
			data[count] = 0xA0;		// non-breaking space

		count++;
	}

	return count;
}

// parse:
// Main parser

html_parse_t *parse(unsigned char *data, size_t size)
{
	// update status
	strcpy(status_text, parsing_status_text);
	xos_redraw(window);

	size = remove_newlines(data, size);

	parse_buffer = malloc(HTML_PARSE_WINDOW);
	parse_buffer_size = 0;
	html_offset = 0;
	html_text_t *text;
	html_parse_t *end;

	html_size = size;
	html_buffer = data;

	while(1)
	{
		if(parse_buffer_size % HTML_PARSE_WINDOW == 0)
			parse_buffer = realloc(parse_buffer, parse_buffer_size + HTML_PARSE_WINDOW);

		if(html_offset >= size)
			goto finish;

		if(data[html_offset] == 0)
			goto finish;

		//while(data[html_offset] == ' ' || data[html_offset] == '\n' || data[html_offset] == '\r' || data[html_offset] == 0xA0)
		if(data[html_offset] == ' ' && data[html_offset-1] != ' ' && data[html_offset+1] != ' ')
		{
			html_offset++;
			text = (html_text_t*)(parse_buffer + parse_buffer_size);
			text->type = HTML_PARSE_TEXT;
			text->size = copy_text(" ", text->text);
			text->size += sizeof(html_parse_t);
			parse_buffer_size += text->size;
			continue;
		}

		while(data[html_offset] <= 0x20 || data[html_offset] > 0x7F || data[html_offset] == '\t')
		{
			html_offset++;

			if(html_offset >= size)
				goto finish;
		}

		if(data[html_offset] == '<' && data[html_offset+1] == '!')
			skip_comment(data + html_offset);

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

		if(html_offset < size)
			continue;

		else
			break;
	}

finish:
	end = (html_parse_t*)(parse_buffer + parse_buffer_size);
	end->type = HTML_PARSE_END;
	end->size = sizeof(html_parse_t);
	parse_buffer_size += sizeof(html_parse_t);

	return parse_buffer;
}

// parse_tag:
// Parses a tag

void parse_tag(unsigned char *data, size_t size)
{
	html_tag_t *tag;
	size_t tag_size;

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
		tag_size = tag->size;
		lowercase_string(tag->tag);		// case-insensitive
		tag->size += sizeof(html_parse_t);
		parse_buffer_size += tag->size;

		html_offset += tag_size;
		data += tag_size;

		if(data[0] == ' ')
			// parse attributes...
			return parse_attributes(data);

		else if(data[0] == '/')
			html_offset += 2;

		else
			html_offset += 1;
	}
}

// skip_comment:
// Skips over a comment

void skip_comment(unsigned char *data)
{
	size_t i = 0;

	html_offset += 2;
	data += 2;

	while(1)
	{
		if(data[i] == '>')
			break;

		else
			i++;
	}

	html_offset += i + 1;
}

// parse_attributes:
// Parses attributes of a tag

void parse_attributes(unsigned char *data)
{
	//data++;
	//html_offset++;

	html_attribute_t *attribute;
	size_t attribute_size = 0, attribute_value_size = 0;

	//while(data[0] != 0 && data[0] != '>' && data[0] != '/' && data[0] != '\n' && data[0] != '\r')
	while(data[0] == ' ' || data[0] == '\r' || data[0] == '\n' || data[0] == 0xA0)
	{
		while(data[0] == ' ' || data[0] == '\r' || data[0] == '\n' || data[0] == 0xA0)
		{
			data++;
			html_offset++;
			if(data[0] == '>')
				break;
		}

		//data++;
		//html_offset++;

		// copy the attribute name
		attribute = (html_attribute_t*)(parse_buffer + parse_buffer_size);
		attribute->type = HTML_PARSE_ATTRIBUTE;
		attribute->size = copy_attribute_name(data, attribute->attribute);
		lowercase_string(attribute->attribute);
		attribute_size = attribute->size;

		html_offset += attribute_size - 1;
		data += attribute_size - 1;

		if(data[0] == '=')
		{
			// copy attribute value
			data++;
			html_offset++;
			if(data[0] == '"')
			{
				data++;
				html_offset++;
				attribute_value_size = copy_attribute_dq(data, attribute->value);
				attribute->size += attribute_value_size;

				html_offset += attribute_value_size;
				data += attribute_value_size;
			}

			else if(data[0] == '\'')
			{
				data++;
				html_offset++;
				attribute_value_size = copy_attribute_sq(data, attribute->value);
				attribute->size += attribute_value_size;

				html_offset += attribute_value_size;
				data += attribute_value_size;
			}

			else
			{
				attribute_value_size = copy_attribute_nq(data, attribute->value);
				attribute->size += attribute_value_size;

				html_offset += attribute_value_size - 1;
				data += attribute_value_size - 1;
			}
		}

		attribute->size += sizeof(html_parse_t);
		parse_buffer_size += attribute->size;
	}

	if(data[0] == '>')
	{
		html_offset++;
		return;
	}

	else if(data[0] == '/')
	{
		html_offset += 2;
		return;
	}
}



