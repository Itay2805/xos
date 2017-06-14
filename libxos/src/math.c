
/*
 * libXOS
 * Rudimentary custom C library for xOS
 * Copyright (C) 2017 by Omar Mohammad.
 *
 * MIT license
 */

#include <stdtyp.h>

// abs:
// Returns absolute value of i
size_t abs(size_t i){
	return i > 0 ? i : 0 - i;
}
// max:
// Returns the biggest value between a and b
size_t max(size_t a, size_t b){
	return a > b ? a : b;
}
// min:
// Returns the lowest value between a and b
size_t min(size_t a, size_t b){
	return a < b ? a : b;
}
// pow:
// Raise x to the power of y
size_t pow(size_t x, size_t y){
	size_t result = 1;
	while(y){
		result = result * x;
		y--;
	}
	return result;
}
