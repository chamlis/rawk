/*
 * SPDX-FileCopyrightText: © 2022 James Reynolds
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

.section .text
.global _start

_start:
        lui sp, %hi(_stack_top)
        addi sp, sp, %lo(_stack_top)
        jal ra, main
        ebreak
