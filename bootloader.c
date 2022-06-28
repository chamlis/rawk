/*
 * SPDX-FileCopyrightText: © 2022 James Reynolds
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "libc.h"
#include "serial.h"

static void *dtb = (void *) 0x100000L;
static void *relocated_linux = (void *) 0x80000000L;

struct __attribute__((__packed__)) header{
    uint32_t code0;
    uint32_t code1;
    uint64_t text_offset;
    uint64_t image_size;
    uint64_t flags;
    uint32_t version;
    uint32_t res1;
    uint64_t res2;
    uint64_t magic;
    uint32_t magic2;
    uint32_t res3;
};

int main(int argc, char **argv){
    serial_puts("                        __  \n");
    serial_puts("   _________ __      __/ /__\n");
    serial_puts("  / ___/ __ `/ | /| / / //_/\n");
    serial_puts(" / /  / /_/ /| |/ |/ / ,<   \n");
    serial_puts("/_/   \\__,_/ |__/|__/_/|_| \n");
    serial_puts("\n");

    serial_puts("Welcome to the RISC-V AWK bootloader!\n");

    serial_puts("Checking Linux boot header...\n");

    struct header *linux_header = relocated_linux;

    if(linux_header->image_size == 0){
        serial_puts("Invalid image size!\n");
        return 1;
    }

    if(linux_header->magic != 0x5643534952 ||
       linux_header->magic2 != 0x05435352){
        serial_puts("Invalid image magic!\n");
        return 1;
    }

    serial_puts("Jumping to Linux...\n");

    void (*entry)(unsigned long, void *) = (void (*)(unsigned long, void *)) relocated_linux;
    entry(0, dtb);
    return 0;
}
