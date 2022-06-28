/*
 * SPDX-FileCopyrightText: © 2022 James Reynolds
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "serial.h"

#define REGISTER_START 0x1000000
#define THB 0
#define LSR 5

volatile static char *thb = (char *) (REGISTER_START + THB);
volatile static char *lsr = (char *) (REGISTER_START + LSR);

void serial_putc(char c){
    while(!(*lsr & (1 << 5))){}

    *thb = c;
}

void serial_puts(const char *str){
    for(; *str; str++){
        serial_putc(*str);
    }
}
