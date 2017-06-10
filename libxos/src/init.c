
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <xos.h>

void *libxos_data;

void libxos_init()
{
	libxos_data = malloc(256*8);
}



