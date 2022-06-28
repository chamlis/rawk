/*
 * SPDX-FileCopyrightText: © 2022 James Reynolds
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

ENTRY(_start)
STARTUP(crt.o)

SECTIONS{
    . = 0x1000;
    .text : { *(.text) }

    .data : ALIGN(0x1000) {
        *(.data)
    }

    .stack : ALIGN(0x1000) {
        _stack_bottom = .;
        . += 0x1000;
        _stack_top = .;
    }
}
