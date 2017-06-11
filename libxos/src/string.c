
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

size_t strlen(char *string)
{
	size_t ret = 0;
	while(string[0] != 0)
	{
		ret++;
		string++;
	}

	return ret;
}


