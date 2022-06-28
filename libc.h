/*
 * SPDX-FileCopyrightText: © 2022 James Reynolds
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

typedef unsigned char uint8_t;
typedef signed char int8_t;
typedef unsigned int uint32_t;
typedef int int32_t;
typedef unsigned long uint64_t;
typedef long int64_t;

typedef uint8_t bool;

typedef uint64_t size_t;

#define NULL ((void*)0)

#define true 1
#define false 0

static void *memcpy(void *dst, const void *src, size_t size){
    return __builtin_memcpy(dst, src, size);
}
