
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#pragma once

#define HTML_PARSE_WINDOW			32768

#define HTML_PARSE_OPEN_TAG			0x01
#define HTML_PARSE_CLOSE_TAG			0x02
#define HTML_PARSE_ATTRIBUTE			0x03
#define HTML_PARSE_TEXT				0x04
#define HTML_PARSE_END				0xFF

typedef struct html_tag_t
{
	uint8_t type;
	size_t size;
	char tag[64];
} html_tag_t;

typedef struct html_attribute_t
{
	uint8_t type;
	size_t size;
	char attribute[64];
	char content[512];
} html_attribute_t;

typedef struct html_parse_text_t
{
	uint8_t type;
	size_t size;
	char text[];
} html_text_t;

typedef struct html_parse_t
{
	uint8_t type;
	size_t size;
} html_parse_t;

extern html_parse_t *parse(char *data, size_t size);


