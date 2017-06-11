
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>

libxos_internal_window *libxos_windows;

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

// libxos_init:
// Called internally, initializes anything needed for the library

void libxos_init()
{
	libxos_windows = malloc(LIBXOS_MAX_WINDOWS * sizeof(libxos_internal_window));
}


