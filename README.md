# rawk

A RISC-V emulator implemented in GNU AWK (gawk).

Implements most of `RV64IMAZicsr_Zifencei` with a single hart, but it
hasn't been rigorously tested to conform to the specification.

## Usage

Requires RISC-V gcc and binutils to build images, along with coreutils
for `base64`.

To build and run a simple test program:
```
make factorial.b64
gawk --bignum -f riscv.awk factorial.b64
```

To try and boot Linux, first build a kernel `Image` for RISC-V (I used
`make allnoconfig`) and put it in this directory. Then you should be
able to:
```
make linux.b64
gawk --bignum -f riscv.awk linux.b64
```

The boot process can take a while (12 minutes on my machine), and
should panic when no initramfs is found.