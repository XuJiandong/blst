/* SPDX-License-Identifier: Apache-2.0
 * Fixed-size Montgomery arithmetic for RV64 and CKB-VM.
 *
 * Keep mulhu/mul and add/sltu/add adjacent, with the operand order below:
 * CKB-VM fuses them into WIDE_MULU and ADD3 (VM version 2). These are ordinary
 * RV64 instructions, so correctness does not depend on fusion being enabled.
 * All loops and memory addresses are independent of field-element values.
 */
.text

/* t2: carry in/out; t4: multiplier; t0/t1/t3: scratch.
 * The product plus two limbs fits in 128 bits. Each carry addition is an
 * ADD3A or ADD3C pattern; t1 must not alias the low destination or flag.
 */
.macro mont_mac dst, acc, limb
    /* c.add rewrites rs1/rs2 and can break ADD3 matching. Preserve order. */
    .option push
    .option norvc
    mulhu t1, \limb, t4
    mul   t0, \limb, t4
    add   t0, t2, t0
    sltu  t3, t0, t2
    add   t1, t3, t1
    add   \dst, t0, \acc
    sltu  t2, \dst, t0
    add   t2, t2, t1
    .option pop
.endm

/* Subtract modulus and incoming borrow without overflowing modulus+borrow.
 * Both sub/sltu pairs match SBBS. Keep the original accumulator for selection.
 */
.macro mont_sub dst, acc, modulus
    sub   t0, \acc, \modulus
    sltu  t1, \acc, \modulus
    sub   \dst, t0, t2
    sltu  t3, t0, t2
    or    t2, t1, t3
.endm

.macro mont_select diff, original, offset
    xor   \diff, \diff, \original
    and   \diff, \diff, t2
    xor   \diff, \diff, \original
    sd    \diff, \offset(a0)
.endm

.section .text.blst_mul_mont_256,"ax",@progbits
.p2align 2
.globl blst_mul_mont_256
.type blst_mul_mont_256,@function
/* (out, a, b, modulus, n0). Supports out==a and out==b.
 * CIOS Montgomery multiplication: s0..s4 hold the accumulator, s5..s8 a,
 * s9..s11/t6 the modulus. a5 holds the carry above s4 within a round.
 */
blst_mul_mont_256:
    addi sp, sp, -96
    sd s0, 0(sp)
    sd s1, 8(sp)
    sd s2, 16(sp)
    sd s3, 24(sp)
    sd s4, 32(sp)
    sd s5, 40(sp)
    sd s6, 48(sp)
    sd s7, 56(sp)
    sd s8, 64(sp)
    sd s9, 72(sp)
    sd s10, 80(sp)
    sd s11, 88(sp)
    ld s5, 0(a1)
    ld s6, 8(a1)
    ld s7, 16(a1)
    ld s8, 24(a1)
    ld s9, 0(a3)
    ld s10, 8(a3)
    ld s11, 16(a3)
    ld t6, 24(a3)
    addi a1, a2, 32
    li s0, 0
    li s1, 0
    li s2, 0
    li s3, 0
    li s4, 0
.Lfr_round:
    ld t4, 0(a2)
    li t2, 0
    mont_mac s0, s0, s5
    mont_mac s1, s1, s6
    mont_mac s2, s2, s7
    mont_mac s3, s3, s8
    add s4, t2, s4
    sltu a5, s4, t2
    mul t4, s0, a4
    li t2, 0
    mont_mac t5, s0, s9
    mont_mac s0, s1, s10
    mont_mac s1, s2, s11
    mont_mac s2, s3, t6
    add s3, t2, s4
    sltu t3, s3, t2
    add s4, t3, a5
    addi a2, a2, 8
    bne a2, a1, .Lfr_round
    li t2, 0
    mont_sub s5, s0, s9
    mont_sub s6, s1, s10
    mont_sub s7, s2, s11
    mont_sub s8, s3, t6
    sub t2, s4, t2
    not t2, t2                 /* all ones iff subtraction should be kept */
    mont_select s5, s0, 0
    mont_select s6, s1, 8
    mont_select s7, s2, 16
    mont_select s8, s3, 24
    ld s0, 0(sp)
    ld s1, 8(sp)
    ld s2, 16(sp)
    ld s3, 24(sp)
    ld s4, 32(sp)
    ld s5, 40(sp)
    ld s6, 48(sp)
    ld s7, 56(sp)
    ld s8, 64(sp)
    ld s9, 72(sp)
    ld s10, 80(sp)
    ld s11, 88(sp)
    addi sp, sp, 96
    ret
.size blst_mul_mont_256, .-blst_mul_mont_256

/* Add a 128-bit product to the 192-bit Comba accumulator s6:s7:s8.
 * A product's high half is at most 2^64-2, so adding the low carry cannot
 * overflow t2. The high accumulator is at most the number of column terms.
 */
.macro square_accumulate
    .option push
    .option norvc
    add s6, t0, s6
    sltu t2, s6, t0
    add t2, t2, t1
    add s7, t2, s7
    sltu t3, s7, t2
    add s8, t3, s8
    .option pop
.endm

.macro square_product x, y
    mulhu t1, \x, \y
    mul t0, \x, \y
    square_accumulate
    .ifnc \x,\y
        square_accumulate
    .endif
.endm

.macro square_column offset
    sd s6, \offset(sp)
    mv s6, s7
    mv s7, s8
    li s8, 0
.endm

.section .text.blst_sqr_mont_384,"ax",@progbits
.p2align 2
.globl blst_sqr_mont_384
.type blst_sqr_mont_384,@function
/* (out, a, modulus, n0). Supports out==a.
 * Form the square with 21 wide products instead of 36, then REDC. The low
 * six limbs stay in registers during reduction; only the upper limbs of
 * the square are read from the stack, once each.
 */
blst_sqr_mont_384:
    addi sp, sp, -192
    sd s0, 96(sp)
    sd s1, 104(sp)
    sd s2, 112(sp)
    sd s3, 120(sp)
    sd s4, 128(sp)
    sd s5, 136(sp)
    sd s6, 144(sp)
    sd s7, 152(sp)
    sd s8, 160(sp)
    sd s9, 168(sp)
    sd s10, 176(sp)
    sd s11, 184(sp)
    ld s0, 0(a1)
    ld s1, 8(a1)
    ld s2, 16(a1)
    ld s3, 24(a1)
    ld s4, 32(a1)
    ld s5, 40(a1)
    li s6, 0
    li s7, 0
    li s8, 0
    square_product s0, s0
    square_column 0
    square_product s0, s1
    square_column 8
    square_product s0, s2
    square_product s1, s1
    square_column 16
    square_product s0, s3
    square_product s1, s2
    square_column 24
    square_product s0, s4
    square_product s1, s3
    square_product s2, s2
    square_column 32
    square_product s0, s5
    square_product s1, s4
    square_product s2, s3
    square_column 40
    square_product s1, s5
    square_product s2, s4
    square_product s3, s3
    square_column 48
    square_product s2, s5
    square_product s3, s4
    square_column 56
    square_product s3, s5
    square_product s4, s4
    square_column 64
    square_product s4, s5
    square_column 72
    square_product s5, s5
    square_column 80
    sd s6, 88(sp)
    ld s0, 0(sp)
    ld s1, 8(sp)
    ld s2, 16(sp)
    ld s3, 24(sp)
    ld s4, 32(sp)
    ld s5, 40(sp)
    ld s6, 0(a2)
    ld s7, 8(a2)
    ld s8, 16(a2)
    ld s9, 24(a2)
    ld s10, 32(a2)
    ld s11, 40(a2)
    addi a4, sp, 48
    addi a5, sp, 96
    li a6, 0
.Lfp_reduce:
    mul t4, s0, a3
    li t2, 0
    mont_mac t5, s0, s6
    mont_mac s0, s1, s7
    mont_mac s1, s2, s8
    mont_mac s2, s3, s9
    mont_mac s3, s4, s10
    mont_mac s4, s5, s11
    ld t5, 0(a4)
    add t0, t5, t2
    sltu t1, t0, t5
    add s5, a6, t0
    sltu a6, s5, t0
    add a6, a6, t1
    addi a4, a4, 8
    bne a4, a5, .Lfp_reduce
    li t2, 0
    mont_sub s6, s0, s6
    mont_sub s7, s1, s7
    mont_sub s8, s2, s8
    mont_sub s9, s3, s9
    mont_sub s10, s4, s10
    mont_sub s11, s5, s11
    sub t2, a6, t2
    not t2, t2
    mont_select s6, s0, 0
    mont_select s7, s1, 8
    mont_select s8, s2, 16
    mont_select s9, s3, 24
    mont_select s10, s4, 32
    mont_select s11, s5, 40
    ld s0, 96(sp)
    ld s1, 104(sp)
    ld s2, 112(sp)
    ld s3, 120(sp)
    ld s4, 128(sp)
    ld s5, 136(sp)
    ld s6, 144(sp)
    ld s7, 152(sp)
    ld s8, 160(sp)
    ld s9, 168(sp)
    ld s10, 176(sp)
    ld s11, 184(sp)
    addi sp, sp, 192
    ret
.size blst_sqr_mont_384, .-blst_sqr_mont_384

.section .note.GNU-stack,"",@progbits
