
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#pragma once

#include <stdtyp.h>

extern size_t strlen(char *string);
extern void *memcpy(void *dest, const void *src, size_t count);
extern void *memmove(void *dest, const void *src, size_t count);
extern int memcmp(const void *lhs, const void *rhs, size_t count);
extern void *memset(void *dest, int ch, size_t count);
extern char *strcpy(char *dest, char *src);


