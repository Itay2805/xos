
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#pragma once

#define HTML_PARSE_WINDOW			1024*1024

#define HTML_PARSE_OPEN_TAG			0x01
#define HTML_PARSE_CLOSE_TAG			0x02
#define HTML_PARSE_ATTRIBUTE			0x03
#define HTML_PARSE_TEXT				0x04
#define HTML_PARSE_END				0xFF

typedef struct html_tag_t
{
	uint8_t type;
	size_t size;
	unsigned char tag[64];
}__attribute__((packed)) html_tag_t;

typedef struct html_attribute_t
{
	uint8_t type;
	size_t size;
	unsigned char attribute[64];
	unsigned char value[512];
}__attribute__((packed)) html_attribute_t;

typedef struct html_parse_text_t
{
	uint8_t type;
	size_t size;
	unsigned char text[];
}__attribute__((packed)) html_text_t;

typedef struct html_parse_t
{
	uint8_t type;
	size_t size;
}__attribute__((packed)) html_parse_t;

extern html_parse_t *parse(unsigned char *data, size_t size);


