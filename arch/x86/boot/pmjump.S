/* ----------------------------------------------------------------------- *
 *
 *   Copyright (C) 1991, 1992 Linus Torvalds
 *   Copyright 2007 rPath, Inc. - All Rights Reserved
 *
 *   This file is part of the Linux kernel, and is made available under
 *   the terms of the GNU General Public License version 2.
 *
 * ----------------------------------------------------------------------- */

/*
 * The actual transition into protected mode
 */

#include <asm/boot.h>
#include <asm/processor-flags.h>
#include <asm/segment.h>

	.text

	.globl	protected_mode_jump
	.type	protected_mode_jump, @function

	.code16

/*
 * void protected_mode_jump(u32 entrypoint, u32 bootparams);
   内核采用fastcall调用，函数两个前两个参数分别存放在ECX，EDX寄存器中
   EDX:&boot_params + (ds() << 4)
   EAX:boot_params.hdr.code32_start   (EAX???)
 */
protected_mode_jump:
	movl	%edx, %esi		# Pointer to boot_params table -- %esi must hold the base address of the struct boot_params

	xorl	%ebx, %ebx
	movw	%cs, %bx			#实模式代码段基址(等于X)
	shll	$4, %ebx
	addl	%ebx, 2f			#左移4位再加上2处变量值后存入2处变量--cs:in_pm32 线性地址

	movw	$__BOOT_DS, %cx		#0x18
	movw	$__BOOT_TSS, %di	#0x20

	movl	%cr0, %edx
	orb	$X86_CR0_PE, %dl	# Protected mode -- X86_CR0_PE	0x00000001 /* PE->1 */
	movl	%edx, %cr0
	jmp	1f			# Short jump to serialize on 386/486
1:

	# Transition to 32-bit mode
	.byte	0x66, 0xea		# ljmpl opcode
2:	.long	in_pm32			# offset  跳至32位代码处
	.word	__BOOT_CS		# segment 0x10

	/*
		a GDT must be loaded with the descriptors for selectors
		__BOOT_CS(0x10) and __BOOT_DS(0x18) -- boot.txt(i386)
	*/

	.size	protected_mode_jump, .-protected_mode_jump

	.code32
	.type	in_pm32, @function
in_pm32:
	# Set up data segments for flat 32-bit mode
	/*
		CS must be __BOOT_CS and DS, ES, SS must be __BOOT_DS; interrupt must be disabled; %esi must hold the base
		address of the struct boot_params; %ebp, %edi and %ebx must be zero. -- boot.txt(i386)
	*/
	movl	%ecx, %ds
	movl	%ecx, %es
	movl	%ecx, %fs
	movl	%ecx, %gs
	movl	%ecx, %ss
	# The 32-bit code sets up its own stack, but this way we do have
	# a valid stack if some debugging hack wants to use it.
	/* 
      * bx存放实模式cs值(内核地址X所在段),ebx等于cs左移过4位 
      * sp在header.S中被设置成了相对于X的段基址的偏移量, 
      * 现在esp=ebx+esp=栈顶指针,其实esp的值现在是个32位线性 
      * 地址,值与实模式下线性地址相同。 
	*/  
	addl	%ebx, %esp

	# Set up TR to make Intel VT happy
	ltr	%di

	# Clear registers to allow for future extensions to the
	# 32-bit boot protocol
	xorl	%ecx, %ecx
	xorl	%edx, %edx
	xorl	%ebx, %ebx
	xorl	%ebp, %ebp
	xorl	%edi, %edi

	# Set up LDTR to make Intel VT happy
	lldt	%cx		# %cx=0

	jmpl	*%eax			# Jump to the 32-bit entrypoint -- EAX:boot_params.hdr.code32_start   (EAX???)

	.size	in_pm32, .-in_pm32
