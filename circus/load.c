
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>
#include "parse.h"
#include "render.h"

extern xos_window window;
extern char status_text[64];
extern char current_uri[512];
extern char idle_status_text[];
extern char loading_status_text[];
extern char rendering_status_text[];
extern char parsing_status_text[];
extern char missing_status_text[];
extern char no_file_status_text[];
extern char no_protocol_status_text[];
extern char no_content_status_text[];
extern char http_3xx_status_text[];
extern char http_4xx_status_text[];
extern char http_5xx_status_text[];
extern char unknown_status_text[];
extern int yield_times;

void load_local_page();
void load_http_page();
extern void *http_decode_chunk(char *data, size_t response_size, size_t *final_size);

// load_page:
// Loads a page, as specified by current_uri

void load_page()
{
	yield_times = 0;

	// check if we're using local file or remote file
	if(memcmp(current_uri, "file://", 7) == 0)
		return load_local_page();

	else
	{
		return load_http_page();
		strcpy(status_text, missing_status_text);
		xos_redraw(window);
	}
}

// load_local_page:
// Loads a page from the hard disk

void load_local_page()
{
	char *filename = current_uri + 7;

	if(filename[0] == '/')
		filename++;

	// indicate loading our status
	strcpy(status_text, loading_status_text);
	xos_redraw(window);

	// open the file
	int32_t file;
	file = k_open(filename, FILE_READ);
	if(file == -1)
	{
		strcpy(status_text, no_file_status_text);
		xos_redraw(window);
		return;
	}

	// get file size
	size_t file_size;
	k_seek(file, SEEK_END, 0);
	file_size = k_tell(file);
	k_seek(file, SEEK_SET, 0);

	if(!file_size)
	{
		k_close(file);
		strcpy(status_text, no_file_status_text);
		xos_redraw(window);
		return;
	}

	// read the file
	char *buffer = malloc(file_size);
	if(k_read(file, file_size, buffer) != file_size)
	{
		free(buffer);
		k_close(file);
		strcpy(status_text, no_file_status_text);
		xos_redraw(window);
		return;
	}

	// okay, parse and render
	k_close(file);
	render(parse(buffer, file_size));
}

// load_http_page:
// Loads a webpage over HTTP

void load_http_page()
{
	// indicate loading our status
	strcpy(status_text, loading_status_text);
	xos_redraw(window);

	int retries = 10;
	size_t size;

	// load the web page
	k_http kernel_http_response;

load:
	k_http_get(current_uri, &kernel_http_response);

	if(kernel_http_response.size == 0 || kernel_http_response.response == 0 || kernel_http_response.response == 0xFFFFFFFF)
	{
		retries--;
		if(retries == 0)
		{
			strcpy(status_text, no_file_status_text);
			xos_redraw(window);
			return;
		} else
			goto load;
	}

	char *http_response = (char*)kernel_http_response.response;
	size_t index = 0;

	// is it HTTP 1.1?
	if(memcmp(http_response, "HTTP/1.1", 8) != 0)
	{
		strcpy(status_text, no_protocol_status_text);
		xos_redraw(window);
		return;
	}

	// find the HTTP header size
	while(1)
	{
		if(http_response[0] == 13 && http_response[1] == 10 && http_response[2] == 13 && http_response[3] == 10)
			break;

		else
			http_response++;
	}

	char *end_http_header = http_response;

	// check for the status
	http_response = (char*)kernel_http_response.response;
	if(http_response[9] == '2')		// 2xx
		goto search_content;

	else if(http_response[9] == '3')	// 3xx
	{
		// search for redirects
		while(1)
		{
			if(memcmp(http_response, "Location: ", 10) == 0)
				break;

			http_response++;
			if(http_response >= end_http_header)
			{
				strcpy(status_text, http_3xx_status_text);
				xos_redraw(window);
				return;
			}
		}

		http_response += 10;		// skip "Location: "

		int location_index = 0;

		while(http_response[location_index] != '\r' && http_response[location_index] != '\n')
		{
			current_uri[location_index] = http_response[location_index];
			location_index++;
		}

		current_uri[location_index] = 0;	// null terminator
		xos_redraw(window);
		goto load;
	}

	else if(http_response[9] == '4')	// 4xx
	{
		strcpy(status_text, http_4xx_status_text);
		xos_redraw(window);
		return;
	}

	else if(http_response[9] == '5')	// 5xx
	{
		strcpy(status_text, http_5xx_status_text);
		xos_redraw(window);
		return;
	}

	else
	{
		strcpy(status_text, unknown_status_text);
		xos_redraw(window);
		return;
	}

search_content:
	// search for the content type
	http_response = (char*)kernel_http_response.response;
	while(1)
	{
		if(memcmp(http_response, "Content-Type: text/html", 23) == 0)
			break;

		http_response++;

		if(http_response >= end_http_header)
		{
			strcpy(status_text, no_content_status_text);
			xos_redraw(window);
			return;
		}
	}

	// okay we know it's HTML, now search for the transfer encoding type
	http_response = (char*)kernel_http_response.response;
	char *http_decoded_response;
	while(1)
	{
		if(memcmp(http_response, "Transfer-Encoding: chunked", 26) == 0)
		{
			http_response = (char*)kernel_http_response.response;
			http_decoded_response = http_decode_chunk(http_response, kernel_http_response.size, &size);
			free(http_response);
			break;
		}

		http_response++;
		if(http_response >= end_http_header)
		{
			http_decoded_response = (char*)end_http_header + 4;
			size = kernel_http_response.size;
			break;
		}
	}

	// parse and render
	render(parse(http_decoded_response, size));
}


