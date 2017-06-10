
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>

libxos_internal_window *libxos_windows;

void libxos_init()
{
	libxos_windows = malloc(LIBXOS_MAX_WINDOWS * sizeof(libxos_internal_window));
}



