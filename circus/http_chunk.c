
/*
 * Circus - simple, lightweight browser for xOS
 * Copyright (C) 2017 by Omar Mohammad
 */

#include <xos.h>
#include <string.h>

// copy_hex:
// Copies a hex number represented in ASCII digits

size_t copy_hex(char *source, char *destination)
{
	size_t size = 0;
	while((source[size] >= 'A' && source[size] <= 'F') || (source[size] >= 'a' && source[size] <= 'f') || (source[size] >= '0' && source[size] <= '9'))
	{
		destination[size] = source[size];
		size++;
	}

	destination[size] = 0;		// null terminator
	return size;
}

// copy_dec:
// Copies a decimal number represented in ASCII digits

size_t copy_dec(char *source, char *destination)
{
	size_t size = 0;
	while(source[size] >= '0' && source[size] <= '9')
	{
		destination[size] = source[size];
		size++;
	}

	destination[size] = 0;		// null terminator
	return size;
}

// hex_to_int:
// Converts a hex number represented in ASCII digits to an integer

uint32_t hex_to_int(char *string)
{
	uint32_t number = 0;
	size_t index, size;

	size = strlen(string);

	if(!size)
		return 0;

	index = size;

	uint32_t multiplier = 1;
	uint8_t val;

	while(index != 0)
	{
		val = string[index - 1];
		if(val >= '0' && val <= '9')
			val -= '0';

		else if(val >= 'a' && val <= 'f')
		{
			val -= 'a';
			val += 10;
		}

		else if(val >= 'A' && val <= 'F')
		{
			val -= 'A';
			val += 10;
		}

		number += (uint32_t)val * multiplier;
		multiplier <<= 4;

		index--;
	}

	return number;
}

// dec_to_int:
// Converts a decimal number represented in ASCII digits to an integer

uint32_t dec_to_int(char *string)
{
	uint32_t number = 0;
	size_t index, size;

	size = strlen(string);

	if(!size)
		return 0;

	index = size;

	uint32_t multiplier = 1;
	uint8_t val;

	while(index != 0)
	{
		val = string[index - 1];
		val -= '0';

		number += (uint32_t)val * multiplier;
		multiplier = multiplier * 10;

		index--;
	}

	return number;
}

// http_decode_chunk:
// Decodes chunked HTTP data

void *http_decode_chunk(char *data, size_t response_size, size_t *final_size)
{
	char *buffer = malloc(response_size + 32768);
	memset(buffer, 0, response_size + 32768);

	// skip the HTTP header
	while(1)
	{
		if(data[0] == '\r' && data[1] == '\n' && data[2] == '\r' && data[3] == '\n')
			break;

		data++;
	}

	data += 4;

	// okay, these are the actual chunks
	char chunk_size_str[16];		// much more than enough
	size_t chunk_str_size;
	size_t chunk_size;

	char *buffer_ptr = buffer;

	while(1)
	{
		chunk_str_size = copy_hex(data, chunk_size_str);
		chunk_size = hex_to_int(chunk_size_str);

		if(chunk_size == 0)		// end of chunks?
			break;

		// copy the chunk
		data += chunk_str_size + 2;
		memcpy(buffer_ptr, data, chunk_size);

		buffer_ptr += chunk_size;
		data += chunk_size + 2;
	}

	final_size[0] = (size_t)(buffer_ptr - buffer);
	return buffer;
}

