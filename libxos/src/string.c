
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <stdtyp.h>

// strlen:
// Returns string length

size_t strlen(const char *string)
{
	size_t ret = 0;
	while(string[0] != 0)
	{
		ret++;
		string++;
	}

	return ret;
}

// memcpy:
// Copies memory

void *memcpy(void *dest, const void *src, size_t count)
{
	if(!dest || !src)
		return dest;

	unsigned char *dest2 = dest;
	const unsigned char *src2 = src;
	size_t count2 = 0;

	while(count2 < count)
	{
		dest2[count2] = src2[count2];
		count2++;
	}

	return dest;
}

// memmove:
// Copies overlapping memory

void *memmove(void *dest, const void *src, size_t count)
{
	// we use byte copies anyway, so memmove can just call memcpy
	return memcpy(dest, src, count);
}

// memcmp:
// Compares memory

int memcmp(const void *lhs, const void *rhs, size_t count)
{
	if(!lhs || !rhs)
		return -1;

	const unsigned char *lhs2 = lhs;
	const unsigned char *rhs2 = rhs;
	size_t count2 = 0;

	while(lhs2[count2] == rhs2[count2])
	{
		count2++;
		if(count2 >= count)
			return 0;
	}

	if(lhs2[count2] > rhs2[count2])
		return 1;

	else
		return -1;
}

// memset:
// Sets memory to a value

void *memset(void *dest, int ch, size_t count)
{
	if(!dest)
		return NULL;

	unsigned char *dest2 = dest;
	size_t count2 = 0;

	while(count2 < count)
	{
		dest2[count2] = (unsigned char)ch;
		count2++;
	}

	return dest;
}

// strcpy:
// Copies a string

char *strcpy(char *dest, char *src)
{
	if(!dest || !src)
		return dest;

	while(src[0] != 0)
	{
		dest[0] = src[0];
		dest++;
		src++;
	}

	dest[0] = 0;

	return dest;
}

// strcmp:
// Compares strings

int strcmp(const char *lhs, const char *rhs)
{
	size_t size = strlen(lhs);
	if(size != strlen(rhs))
		return 1;

	return memcmp(lhs, rhs, size);
}


