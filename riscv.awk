# SPDX-FileCopyrightText: © 2022 James Reynolds
# SPDX-License-Identifier: GPL-3.0-or-later

function base64_decode(input, output, output_index, BASE64_TABLE, ix, n){
    BASE64_TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    gsub(/=/, "A", input)

    for(ix = 1; ix <= length(input); ix+=4){
        n = lshift(index(BASE64_TABLE, substr(input, ix, 1)) - 1, 18)
        n += lshift(index(BASE64_TABLE, substr(input, ix+1, 1)) - 1, 12)
        n += lshift(index(BASE64_TABLE, substr(input, ix+2, 1)) - 1, 6)
        n += index(BASE64_TABLE, substr(input, ix+3, 1)) - 1

        output[output_index] = and(rshift(n, 16), 255)
        output[output_index+1] = and(rshift(n, 8), 255)
        output[output_index+2] = and(n, 255)
        output_index += 3
    }

    return (length(input) / 4) * 3
}

function dlab(){
    rshift(MEMORY[SERIAL_START + 3], 7)
}

function serial_read(offset){
    if(offset == 1 && dlab() == 0){
        return 0
    }
    else if(offset == 5){
        # LSR

        return lshift(1, 5) + lshift(1, 6)
    }

    return MEMORY[SERIAL_START + offset]
}

function serial_write(offset, value){
    if(offset == 0 && dlab() == 0){
        # THB
        printf "%c", value
        fflush()
    }
    else{
        MEMORY[SERIAL_START + offset] = value
    }
}

function clint_read(offset, bytes){
    if(offset == 0x4000 && bytes == 8){
        # mtimecmp
        return TIMECMP
    }
    else if(offset == 0xbff8 && bytes == 8){
        # mtime
        return TIME
    }
}

function clint_write(offset, value, bytes){
    if(offset == 0){
        set_interrupt(3, value != 0)
    }
    if(offset == 0x4000 && bytes == 8){
        # mtimecmp
        TIMECMP = value
    }
    else if(offset == 0xbff8 && bytes == 8){
        # mtime
        TIME = value
    }
}

function read_csr(ix){
    if(ix == 3073){
        # time
        return read_memory(CLINT_START + 0xbff8, 8)
    }

    return CSR[ix]
}

function write_csr(ix, value){
    if(ix == 3073){
        # time
        # read-only
        return
    }

    CSR[ix] = fit_register(value)
}

function fit_register(x){
    if(x >= 0){
        return and(x, 0xffffffffffffffff)
    }

    return -and(-x, 0xffffffffffffffff)
}

function fit_half_register(x){
    if(x >= 0){
        return and(x, 0xffffffff)
    }

    return -and(-x, 0xffffffff)
}

function read_register(ix){
    if(ix == 0) return 0
    return REGISTERS[ix]
}

function read_half_register(ix){
    return de_twos_complement(get_bits(re_twos_complement(read_register(ix), 64), 0, 31), 32)
}

function write_register(ix, value){
    if(ix == 0) return

    value = fit_register(value)

    REGISTERS[ix] = value
}

function write_half_register(ix, value){
    if(ix == 0) return

    value = fit_half_register(value)

    REGISTERS[ix] = value
}

function read_memory(offset, bytes, n, ix){
    if(bytes == 1 && offset >= SERIAL_START && offset <= SERIAL_END){
        return serial_read(offset - SERIAL_START)
    }

    if(offset >= CLINT_START && offset <= CLINT_END){
        return clint_read(offset - CLINT_START, bytes)
    }

    if(!(offset in MEMORY)){
        return 0
    }

    n = 0

    for(ix = 0; ix < bytes; ix++){
        n += lshift(MEMORY[offset + ix], ix * 8)
    }

    return n
}

function write_memory(offset, value, bytes, ix){
    value = re_twos_complement(value, bytes * 8)

    if(bytes == 1 && offset >= SERIAL_START && offset <= SERIAL_END){
        return serial_write(offset - SERIAL_START, value)
    }

    if(offset >= CLINT_START && offset <= CLINT_END){
        return clint_write(offset - CLINT_START, value, bytes)
    }

    for(ix = 0; ix < bytes; ix++){
        MEMORY[offset+ix] = and(rshift(value, ix * 8), 255)
    }
}

function re_twos_complement(value, bits){
    if(value < 0){
        value += 2 * lshift(1, bits - 1)
    }

    return value
}

function de_twos_complement(value, bits){
    if(value < 0){
        print "invalid arg to de_twos_complement"
        die()
    }

    if(and(value, lshift(1, bits - 1)) != 0){
        value -= 2 * lshift(1, bits - 1)
    }
    return value
}

function get_bits(instruction, start_bit, end_bit){
    if(instruction < 0){
        print "invalid arg to get_bits"
        die()
    }

    return and(rshift(instruction, start_bit), lshift(1, end_bit - start_bit + 1) - 1)
}

function get_bit(instruction, bit){
    return get_bits(instruction, bit, bit)
}

function set_bit(value, ix, bit){
    if(bit == 0){
        return and(value, xor(0xffffffffffffffff, lshift(1, ix)))
    }
    else{
        return or(value, lshift(1, ix))
    }
}

function i_immediate(instruction){
    return de_twos_complement(get_bits(instruction, 20, 31), 12)
}

function s_immediate(instruction){
    return de_twos_complement(get_bits(instruction, 7, 11) + lshift(get_bits(instruction, 25, 31), 5), 12)
}

function b_immediate(instruction){
    return de_twos_complement(lshift(get_bits(instruction, 8, 11), 1) + lshift(get_bits(instruction, 25, 30), 5) + lshift(get_bits(instruction, 7, 7), 11) + lshift(get_bits(instruction, 31, 31), 12), 13)
}

function u_immediate(instruction){
    return lshift(get_bits(instruction, 12, 31), 12)
}

function j_immediate(instruction){
    return de_twos_complement(lshift(get_bits(instruction, 21, 30), 1) + lshift(get_bits(instruction, 20, 20), 11) + lshift(get_bits(instruction, 12, 19), 12) + lshift(get_bits(instruction, 31, 31), 20), 21)
}

function die(){
    printf "PC: %x\n", PC
    exit 1
}

function set_interrupt(irq, value, mip){
    mip = re_twos_complement(read_csr(0x344), 64)
    if(value){
        mip = set_bit(mip, irq, 1)
    }
    else{
        mip = set_bit(mip, irq, 0)
    }
    write_csr(0x344, de_twos_complement(mip, 64))
}

function pend_interrupt(irq){
    set_interrupt(irq, 1)
}

function unpend_interrupt(irq){
    set_interrupt(irq, 0)
}

function process_interrupts(mstatus, interrupts, irq, mtvec, base, old_pc){
    mstatus = re_twos_complement(read_csr(0x300), 64)

    # Check mstatus.MIE
    if(and(mstatus, 8) == 0){
        return
    }

    interrupts = and(read_csr(0x304), read_csr(0x344))

    for(irq = 0; irq < 64; irq++){
        if(and(interrupts, lshift(1, irq)) == 0) continue

        # MCAUSE
        write_csr(0x342, de_twos_complement(or(lshift(1, 63), irq), 64))

        mstatus = set_bit(mstatus, 7, 1)
        mstatus = set_bit(mstatus, 3, 0)

        # set previous privilege to M
        mstatus = set_bit(mstatus, 11, 1)
        mstatus = set_bit(mstatus, 12, 1)

        write_csr(0x300, de_twos_complement(mstatus, 64))

        # MEPC
        write_csr(0x341, de_twos_complement(PC, 64))

        # Jump!
        mtvec = re_twos_complement(read_csr(0x305), 64)
        base = and(mtvec, 0xfffffffffffffffc)

        old_pc = PC

        if(get_bits(mtvec, 0, 1) == 0){
            PC = base
        }
        else{
            PC = base + (irq * 4)
        }

        break
    }
}

function fetch(n){
    n = read_memory(PC, 4)
    PC += 4
    return n
}

function execute(instruction, opcode, rd, rs1, rs2, funct3, imm, handled){
    opcode = and(instruction, 127)
    rd = and(rshift(instruction, 7), 31)
    rs1 = and(rshift(instruction, 15), 31)
    rs2 = and(rshift(instruction, 20), 31)
    funct3 = and(rshift(instruction, 12), 7)

    handled = 0

    if(opcode == 3){
        imm = i_immediate(instruction)
        off = read_register(rs1) + imm

        if(funct3 == 0){
            # LB
            write_register(rd, de_twos_complement(read_memory(off, 1), 8))
            handled = 1
        }
        else if(funct3 == 1){
            # LH
            write_register(rd, de_twos_complement(read_memory(off, 2), 16))
            handled = 1
        }
        else if(funct3 == 2){
            # LW
            write_register(rd, de_twos_complement(read_memory(off, 4), 32))
            handled = 1
        }
        else if(funct3 == 3){
            # LD
            write_register(rd, de_twos_complement(read_memory(off, 8), 64))
            handled = 1
        }
        else if(funct3 == 4){
            # LBU
            write_register(rd, read_memory(off, 1))
            handled = 1
        }
        else if(funct3 == 5){
            # LHU
            write_register(rd, read_memory(off, 2))
            handled = 1
        }
        else if(funct3 == 6){
            # LWU
            write_register(rd, read_memory(off, 4))
            handled = 1
        }
    }
    else if(opcode == 15){
        if(funct3 == 0){
            # FENCE

            # noop
            handled = 1
        }
        else if(funct3 == 1){
            # FENCE.I

            # noop
            handled = 1
        }
    }
    else if(opcode == 19){
        funct6 = get_bits(instruction, 26, 31)

        if(funct3 == 0){
            # ADDI
            imm = i_immediate(instruction)
            write_register(rd, read_register(rs1) + imm)
            handled = 1
        }
        else if(funct3 == 1){
            if(funct6 == 0){
                # SLLI
                shift = get_bits(instruction, 20, 25)
                write_register(rd, de_twos_complement(and(lshift(re_twos_complement(read_register(rs1), 64), shift), 0xffffffffffffffff), 64))
                handled = 1
            }
            else{
                print "funct6: " funct6
            }
        }
        else if(funct3 == 2){
            # SLTI
            imm = i_immediate(instruction)
            if(read_register(rs1) < imm){
                write_register(rd, 1)
            }
            else{
                write_register(rd, 0)
            }
            handled = 1
        }
        else if(funct3 == 3){
            # SLTIU
            imm = i_immediate(instruction)
            if(re_twos_complement(read_register(rs1), 64) < re_twos_complement(imm, 12)){
                write_register(rd, 1)
            }
            else{
                write_register(rd, 0)
            }
            handled = 1
        }
        else if(funct3 == 4){
            # XORI
            imm = re_twos_complement(i_immediate(instruction), 64)
            write_register(rd, de_twos_complement(xor(re_twos_complement(read_register(rs1), 64), imm), 64))
            handled = 1
        }
        else if(funct3 == 5){
            shift = get_bits(instruction, 20, 25)
            if(funct6 == 0){
                # SRLI
                write_register(rd, de_twos_complement(rshift(re_twos_complement(read_register(rs1), 64), shift), 64))
                handled = 1
            }
            else if(funct6 == 16){
                # SRAI
                write_register(rd, de_twos_complement(rshift(re_twos_complement(read_register(rs1), 64), shift), 64 - shift))
                handled = 1
            }
            else{
                print "funct6: " funct6
            }
        }
        else if(funct3 == 6){
            # ORI
            imm = re_twos_complement(i_immediate(instruction), 64)
            write_register(rd, de_twos_complement(or(re_twos_complement(read_register(rs1), 64), imm), 64))
            handled = 1
        }
        else if(funct3 == 7){
            # ANDI
            imm = re_twos_complement(i_immediate(instruction), 64)
            write_register(rd, de_twos_complement(and(re_twos_complement(read_register(rs1), 64), imm), 64))
            handled = 1
        }
    }
    else if(opcode == 23){
        # AUIPC
        imm = de_twos_complement(u_immediate(instruction), 32)
        write_register(rd, imm + (PC - 4))
        handled = 1
    }
    else if(opcode == 27){
        funct7 = get_bits(instruction, 25, 31)
        imm = i_immediate(instruction)

        if(funct3 == 0){
            # ADDIW
            write_half_register(rd, read_half_register(rs1) + imm)
            handled = 1
        }
        else if(funct3 == 1){
            if(funct7 == 0){
                # SLLIW
                shift = get_bits(instruction, 20, 25)
                write_half_register(rd, de_twos_complement(lshift(re_twos_complement(read_half_register(rs1), 32), shift), 32))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 5){
            shift = get_bits(instruction, 20, 25)

            if(funct7 == 0){
                # SRLIW
                write_half_register(rd, de_twos_complement(rshift(re_twos_complement(read_half_register(rs1), 32), shift), 32))
                handled = 1
            }
            else if(funct7 == 32){
                # SRAIW
                write_half_register(rd, de_twos_complement(rshift(re_twos_complement(read_half_register(rs1), 32), shift), 32 - shift))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
    }
    else if(opcode == 35){
        imm = s_immediate(instruction)
        off = read_register(rs1) + imm
        val = read_register(rs2)

        if(funct3 == 0){
            # SB
            write_memory(off, val, 1)
            handled = 1
        }
        else if(funct3 == 1){
            # SH
            write_memory(off, val, 2)
            handled = 1
        }
        else if(funct3 == 2){
            # SW
            write_memory(off, val, 4)
            handled = 1
        }
        else if(funct3 == 3){
            # SD
            write_memory(off, val, 8)
            handled = 1
        }
    }
    else if(opcode == 47){
        funct5 = get_bits(instruction, 27, 31)

        if(funct3 == 2){
            width = 4
        }
        else if(funct3 == 3){
            width = 8
        }
        else{
            print "Unknown width for atomic op"
        }

        if(funct5 == 0){
            # AMOADD.*
            off = read_register(rs1)
            val = de_twos_complement(read_memory(off, width), width * 8)

            if(width == 4){
                val2 = read_half_register(rs2)
                write_half_register(rd, val)
            }
            else{
                val2 = read_register(rs2)
                write_register(rd, val)
            }

            val += val2
            write_memory(off, val, width)
            handled = 1
        }
        else if(funct5 == 1){
            # AMOSWAP.D
            off = read_register(rs1)
            val = read_memory(off, width)

            if(width == 4){
                val2 = read_half_register(rs2)
                write_half_register(rd, val)
            }
            else{
                val2 = read_register(rs2)
                write_register(rd, val)
            }

            write_memory(off, val2, width)
            handled = 1
        }
        else if(funct5 == 2){
            # LR.*
            val = de_twos_complement(read_memory(read_register(rs1), width), width * 8)
            if(width == 4){
                write_half_register(rd, val)
            }
            else{
                write_register(rd, val)
            }
            handled = 1
        }
        else if(funct5 == 3){
            # SC.*
            if(width == 4){
                val = read_half_register(rs2)
            }
            else{
                val = read_register(rs2)
            }
            write_memory(read_register(rs1), val, width)
            write_register(rd, 0)
            handled = 1
        }
        else if(funct5 == 8){
            # AMOOR.*
            off = read_register(rs1)
            val = read_memory(off, width)

            if(width == 4){
                val2 = de_twos_complement(or(val, re_twos_complement(read_half_register(rs2), 32)), 32)
                write_half_register(rd, val)
            }
            else{
                val2 = de_twos_complement(or(val, re_twos_complement(read_register(rs2), 64)), 64)
                write_register(rd, val)
            }

            write_memory(off, val2, width)
            handled = 1
        }
        else if(funct5 == 12){
            # AMOAND.W
            off = read_register(rs1)
            val = read_memory(off, width)

            if(width == 4){
                val2 = de_twos_complement(and(val, re_twos_complement(read_half_register(rs2), 32)), 32)
                write_half_register(rd, val)
            }
            else{
                val2 = de_twos_complement(and(val, re_twos_complement(read_register(rs2), 64)), 64)
                write_register(rd, val)
            }

            write_memory(off, val2, width)
            handled = 1
        }
        else{
            print "funct5:" funct5
        }
    }
    else if(opcode == 51){
        funct7 = get_bits(instruction, 25, 31);

        if(funct3 == 0){
            if(funct7 == 0){
                # ADD
                write_register(rd, read_register(rs1) + read_register(rs2))
                handled = 1
            }
            else if(funct7 == 1){
                # MUL
                write_register(rd, read_register(rs1) * read_register(rs2))
                handled = 1
            }
            else if(funct7 == 32){
                # SUB
                write_register(rd, read_register(rs1) - read_register(rs2))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 1){
            if(funct7 == 0){
                # SLL
                write_register(rd, de_twos_complement(lshift(re_twos_complement(read_register(rs1), 64), get_bits(re_twos_complement(read_register(rs2), 64), 0, 5)), 64))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 2){
            if(funct7 == 0){
                # SLT
                if(read_register(rs1) < read_register(rs2)){
                    write_register(rd, 1)
                }
                else{
                    write_register(rd, 0)
                }
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 3){
            if(funct7 == 0){
                # SLTU
                if(re_twos_complement(read_register(rs1), 64) < re_twos_complement(read_register(rs2), 64)){
                    write_register(rd, 1)
                }
                else{
                    write_register(rd, 0)
                }
                handled = 1
            }
            else if(funct7 == 1){
                # MULHU
                write_register(rd, rshift(re_twos_complement(read_register(rs1), 64) * re_twos_complement(read_register(rs2), 64), 64))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 4){
            if(funct7 == 0){
                # XOR
                write_register(rd, de_twos_complement(xor(re_twos_complement(read_register(rs1), 64), re_twos_complement(read_register(rs2), 64)), 64))
                handled = 1
            }
            else if(funct7 == 1){
                # DIV
                write_register(rd, de_twos_complement(read_register(rs1) / read_register(rs2), 64))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 5){
            if(funct7 == 0){
                # SRL
                write_register(rd, de_twos_complement(rshift(re_twos_complement(read_register(rs1), 64), get_bits(re_twos_complement(read_register(rs2), 64), 0, 5)), 64))
                handled = 1
            }
            else if(funct7 == 1){
                # DIVU
                write_register(rd, de_twos_complement(re_twos_complement(read_register(rs1), 64) / re_twos_complement(read_register(rs2), 64), 64))
                handled = 1
            }
            else if(funct7 == 32){
                # SRA
                shift = get_bits(re_twos_complement(read_register(rs2), 64), 0, 5)
                write_register(rd, de_twos_complement(rshift(re_twos_complement(read_register(rs1), 64), shift), 64 - shift))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 6){
            if(funct7 == 0){
                # OR
                write_register(rd, de_twos_complement(or(re_twos_complement(read_register(rs1), 64), re_twos_complement(read_register(rs2), 64)), 64))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
        else if(funct3 == 7){
            if(funct7 == 0){
                # AND
                write_register(rd, de_twos_complement(and(re_twos_complement(read_register(rs1), 64), re_twos_complement(read_register(rs2), 64)), 64))
                handled = 1
            }
            else if(funct7 == 1){
                # REMU
                write_register(rd, re_twos_complement(read_register(rs1), 64) % re_twos_complement(read_register(rs2), 64))
                handled = 1
            }
            else{
                print "funct7 " funct7
            }
        }
    }
    else if(opcode == 55){
        # LUI
        imm = u_immediate(instruction)
        write_register(rd, de_twos_complement(imm, 32))
        handled = 1
    }
    else if(opcode == 59){
        funct7 = get_bits(instruction, 25, 31)

        if(funct3 == 0){
            if(funct7 == 0){
                # ADDW
                write_half_register(rd, read_half_register(rs1) + read_half_register(rs2))
                handled = 1
            }
            else if(funct7 == 1){
                # MULW
                write_half_register(rd, read_half_register(rs1) * read_half_register(rs2))
                handled = 1
            }
            else if(funct7 == 32){
                # SUBW
                write_half_register(rd, read_half_register(rs1) - read_half_register(rs2))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
        else if(funct3 == 1){
            if(funct7 == 0){
                # SLLW
                write_half_register(rd, lshift(read_half_register(rs1), get_bits(read_half_register(rs2), 0, 5)))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
        else if(funct3 == 4){
            if(funct7 == 1){
                # DIVW
                write_half_register(rd, read_half_register(rs1) / read_half_register(rs2))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
        else if(funct3 == 5){
            if(funct7 == 0){
                # SRLW
                shift = re_twos_complement(read_half_register(rs2), 32)
                write_half_register(rd, de_twos_complement(rshift(re_twos_complement(read_half_register(rs1), 32), shift), 32))
                handled = 1
            }
            else if(funct7 == 1){
                # DIVUW
                write_half_register(rd, de_twos_complement(re_twos_complement(read_half_register(rs1), 32) / re_twos_complement(read_half_register(rs2), 32), 64))
                handled = 1
            }
            else if(funct7 == 32){
                # SRAW
                shift = re_twos_complement(read_half_register(rs2), 32)
                write_half_register(rd, de_twos_complement(rshift(re_twos_complement(read_half_register(rs1), 32), shift), 32 - shift))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
        else if(funct3 == 6){
            if(funct7 == 1){
                # REMW
                write_half_register(rd, read_half_register(rs1) % read_half_register(rs2))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
        else if(funct3 == 7){
            if(funct7 == 1){
                # REMUW
                write_half_register(rd, re_twos_complement(read_half_register(rs1), 32) % re_twos_complement(read_half_register(rs2), 32))
                handled = 1
            }
            else{
                print "funct7:" funct7
            }
        }
    }
    else if(opcode == 99){
        imm = b_immediate(instruction)

        if(funct3 == 0){
            # BEQ
            if(read_register(rs1) == read_register(rs2)){
                PC += (imm - 4)
            }
            handled = 1
        }
        else if(funct3 == 1){
            # BNE
            if(read_register(rs1) != read_register(rs2)){
                PC += (imm - 4)
            }
            handled = 1
        }
        else if(funct3 == 4){
            # BLT
            if(read_register(rs1) < read_register(rs2)){
                PC += (imm - 4)
            }
            handled = 1
        }
        else if(funct3 == 5){
            # BGE
            if(read_register(rs1) >= read_register(rs2)){
                PC += (imm - 4)
            }
            handled = 1
        }
        else if(funct3 == 6){
            # BLTU
            if(re_twos_complement(read_register(rs1), 64) < re_twos_complement(read_register(rs2), 64)){
                PC += (imm - 4)
            }
            handled = 1
        }
        else if(funct3 == 7){
            # BGEU
            if(re_twos_complement(read_register(rs1), 64) >= re_twos_complement(read_register(rs2), 64)){
                PC += (imm - 4)
            }
            handled = 1
        }
    }
    else if(opcode == 103){
        # JALR
        imm = i_immediate(instruction)
        target = and(read_register(rs1) + imm, 0xffffffffffffffff - 1)
        write_register(rd, PC)
        PC = target
        handled = 1

    }
    else if(opcode == 111){
        # JAL
        imm = j_immediate(instruction)
        write_register(rd, PC)
        PC += (imm - 4)
        handled = 1
    }
    else if(opcode == 115){
        imm = i_immediate(instruction)

        if(funct3 == 0){
            if(imm == 1){
                # EBREAK
                printf "[%x] Break!\n", PC

                HALT = 1
                handled = 1
            }
            else if(imm == 261){
                # WFI

                # As the only interrupt that can arise other than software is the timer, we just trigger that now.
                # This will need to change if the serial etc gets interrupts
                TIME = TIMECMP
                handled = 1
            }
            else if(imm == 770){
                # MRET

                mstatus = re_twos_complement(read_csr(0x300), 64)
                mstatus = set_bit(mstatus, 3, get_bit(mstatus, 7))
                mstatus = set_bit(mstatus, 7, 0)
                write_csr(0x300, de_twos_complement(mstatus, 64))

                PC = re_twos_complement(read_csr(0x341), 64)

                handled = 1
            }
            else{
                print "imm:" imm
            }
        }
        else if(funct3 == 1){
            # CSRRW
            val = read_csr(imm)
            write_csr(imm, read_register(rs1))
            write_register(rd, val)
            handled = 1
        }
        else if(funct3 == 2){
            # CSRRS
            val = read_csr(imm)
            mask = re_twos_complement(read_register(rs1), 64)
            write_register(rd, val)
            write_csr(imm, de_twos_complement(or(re_twos_complement(val, 64), mask), 64))
            handled = 1
        }
        else if(funct3 == 3){
            # CSRRC
            val = read_csr(imm)
            mask = re_twos_complement(compl(re_twos_complement(read_register(rs1), 64)), 64)
            write_register(rd, val)
            write_csr(imm, de_twos_complement(and(val, mask), 64))
            handled = 1
        }
        else if(funct3 == 5){
            # CSRRWI
            val = read_csr(imm)
            write_csr(imm, rs1)
            write_register(rd, val)
            handled = 1
        }
        else if(funct3 == 6){
            # CSRRSI
            val = read_csr(imm)
            write_register(rd, val)
            write_csr(imm, de_twos_complement(or(re_twos_complement(val, 64), rs1), 64))
            handled = 1
        }
        else if(funct3 == 7){
            # CSRRCI
            val = read_csr(imm)
            write_register(rd, val)
            write_csr(imm, de_twos_complement(and(re_twos_complement(val, 64), re_twos_complement(compl(rs1), 64)), 64))
            handled = 1
        }
    }

    if(handled == 0){
        print "Unhandled instruction: " instruction
        printf "PC: %x\n", PC
        print "Op: " opcode
        print "funct3: " funct3
        exit 1
    }
}

BEGIN {
    LOAD_ADDRESS = 0
    START_ADDRESS = 0x1000

    LOAD_PTR = LOAD_ADDRESS
    PC = START_ADDRESS

    TIME = 0
    TIMECMP = 0

    HALT = 0

    for(ix = 1; ix <= 31; ix++){
        write_register(ix, 0)
    }

    for(ix = 0; ix < 4096; ix++){
        write_csr(ix, 0)
    }

    SERIAL_START = 0x1000000
    SERIAL_END = 0x1000007

    write_memory(SERIAL_START, 0, (SERIAL_END - SERIAL_START) + 1)

    CLINT_START = 0x2000000
    CLINT_END = 0x200c000

    print "Begin load:"
}

/^>SEEK/ {
    LOAD_PTR = $2
}

/^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+\/=]*$/ {
    LOAD_PTR += base64_decode($0, MEMORY, LOAD_PTR)
}

END {
    print "Machine start:\n"

    # Without accessing MEMORY[0x1000] (even MEMORY[4096] isn't good enough?) we
    # fetch a 0 instruction when running gawk in profile mode and crash
    MEMORY[0x1000]

    while(HALT == 0){
        execute(fetch())

        if(PC % 4 != 0){
            print "Unaligned instruction access"
            die()
        }

        TIME++

        set_interrupt(7, TIME >= TIMECMP)

        process_interrupts()
    }

    print ""
    print "HALTed:"

    printf "pc: %x\n", PC
    print "return: " read_register(10)
}
