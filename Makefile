# SPDX-FileCopyrightText: © 2022 James Reynolds
# SPDX-License-Identifier: GPL-3.0-or-later

AS=riscv64-unknown-elf-as
CC=riscv64-unknown-elf-gcc
LD=riscv64-unknown-elf-ld

ASFLAGS = -mabi=lp64 -march=rv64im
CFLAGS = -mabi=lp64 -march=rv64im -O3

linux.b64: bootloader.bin Image rawk.dtb
	base64 bootloader.bin > $@
	echo ">SEEK 1048576" >> $@
	base64 rawk.dtb >> $@
	echo ">SEEK 2147483648" >> $@
	base64 Image >> $@

%.b64: %.bin
	base64 $< > $@

%.dtb: %.dts
	dtc -O dtb -o $@ $<

%.bin: %.o serial.o crt.o
	$(LD) -T script.ld -o $@ $< serial.o

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ -c $<

.PHONY:
clean:
	rm -f *.bin
	rm -f *.dtb
	rm -f *.b64
	rm -f *.o
