
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

void load_local_page();
void load_http_page();

// load_page:
// Loads a page, as specified by current_uri

void load_page()
{
	// check if we're using local file or remote file
	if(memcmp(current_uri, "file://", 7) == 0)
		return load_local_page();

	else
	{
		// for now, at least until I have basic HTML tags...
		strcpy(status_text, missing_status_text);
		xos_redraw(window);
	}
}

// load_local_page():
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



