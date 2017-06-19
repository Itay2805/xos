
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#pragma once

#include "parse.h"

#define RENDER_TREE_WINDOW		1024*1024
#define RENDER_OP_TEXT			0x01
#define RENDER_OP_RECT			0x02
#define RENDER_OP_LINK			0x03
#define RENDER_OP_END			0xFF

typedef struct render_op_text
{
	unsigned char op;
	size_t size;
	short x, y;
	unsigned char font_size;
	signed int font_weight;
	signed int underline;
	unsigned int bg, fg;
	unsigned char text[];
}__attribute__((packed)) render_op_text;

typedef struct render_op_link
{
	unsigned char op;
	size_t size;
	short x, y;
	short endx, endy;
	unsigned char address[512];
}__attribute__((packed)) render_op_link;

typedef struct render_op_rect
{
	unsigned char op;
	size_t size;
	short x, y;
	short width, height;
	unsigned int bg;
}__attribute__((packed)) render_op_rect;

extern void render(html_parse_t *data);




