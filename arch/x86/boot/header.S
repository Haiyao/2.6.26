/*
 *	header.S
 *
 *	Copyright (C) 1991, 1992 Linus Torvalds
 *
 *	Based on bootsect.S and setup.S
 *	modified by more people than can be counted
 *
 *	Rewritten as a common file by H. Peter Anvin (Apr 2007)
 *
 * BIG FAT NOTE: We're in real mode using 64k segments.  Therefore segment
 * addresses must be multiplied by 16 to obtain their respective linear
 * addresses. To avoid confusion, linear addresses are written using leading
 * hex while segment addresses are written as segment:offset.
 *
 */

#include <asm/segment.h>
#include <linux/utsrelease.h>
#include <asm/boot.h>
#include <asm/e820.h>
#include <asm/page.h>
#include <asm/setup.h>
#include "boot.h"
#include "offsets.h"

SETUPSECTS	= 4			/* default nr of setup-sectors */
BOOTSEG		= 0x07C0		/* original address of boot-sector */
SYSSEG		= DEF_SYSSEG		/* system loaded at 0x10000 (65536) */
SYSSIZE		= DEF_SYSSIZE		/* system size: # of 16-byte clicks */
					/* to be loaded */
ROOT_DEV	= 0			/* ROOT_DEV is now written by "build" */
SWAP_DEV	= 0			/* SWAP_DEV is now written by "build" */

#ifndef SVGA_MODE
#define SVGA_MODE ASK_VGA
#endif

#ifndef RAMDISK
#define RAMDISK 0
#endif

#ifndef ROOT_RDONLY
#define ROOT_RDONLY 1
#endif

	.code16						/*表示16位模式*/
	.section ".bstext", "ax"	/*将以下代码放在.bstext节区，"ax"表示该节区可分配并且可执行*/

	.global bootsect_start
bootsect_start:

	# Normalize the start address
	ljmp	$BOOTSEG, $start2	/*该指令表示转移到段基址为0x7C00（seg*16），偏移为start2地址处*/

start2:			#不执行，兼容old，提示info按键重启
	movw	%cs, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	xorw	%sp, %sp	/*sp清零*/
	sti					/*中断标志位-> 1,启用中断*/
	cld

	movw	$bugger_off_msg, %si

msg_loop:
	lodsb
	andb	%al, %al
	jz	bs_die
	movb	$0xe, %ah
	movw	$7, %bx
	int	$0x10			/*显示字符中断*/
	jmp	msg_loop

bs_die:
	# Allow the user to press a key, then reboot
	xorw	%ax, %ax
	int	$0x16			/*wait keyboard input*/
	int	$0x19			/*reboot*/

	# int 0x19 should never return.  In case it does anyway,
	# invoke the BIOS reset code...
	ljmp	$0xf000,$0xfff0		/*长跳转到0xf fff0处，即重新执行BIOS中的一系列初始化过程*/

	.section ".bsdata", "a"
bugger_off_msg:
	.ascii	"Direct booting from floppy is no longer supported.\r\n"
	.ascii	"Please use a boot loader program instead.\r\n"
	.ascii	"\n"
	.ascii	"Remove disk and press any key to reboot . . .\r\n"
	.byte	0


	# Kernel attributes; used by setup.  This is part 1 of the
	# header, from the old boot sector.

	.section ".header", "a"
	.globl	hdr
/*setup header param part start*/
hdr:
setup_sects:	.byte SETUPSECTS
root_flags:	.word ROOT_RDONLY
syssize:	.long SYSSIZE
ram_size:	.word RAMDISK
vid_mode:	.word SVGA_MODE
root_dev:	.word ROOT_DEV
boot_flag:	.word 0xAA55

	# offset 512, entry point

	.globl	_start
_start:
		# Explicitly enter this as bytes, or the assembler
		# tries to generate a 3-byte jump here, which causes
		# everything else to push off to the wrong offset.
		.byte	0xeb		# short (2-byte) jump 	/*此处为了生成2位转跳直接使用的机器码命令，转跳至start_of_setup */
		.byte	start_of_setup-1f 					/*start_of_setup-1 的偏移量，f指向前forward b是会跳backward */
1:

	# Part 2 of the header, from the old setup.S

		.ascii	"HdrS"		# header signature
		.word	0x0209		# header version number (>= 0x0105)
					# or else old loadlin-1.5 will fail)
		.globl realmode_swtch
realmode_swtch:	.word	0, 0		# default_switch, SETUPSEG
start_sys_seg:	.word	SYSSEG
		.word	kernel_version-512 # pointing to kernel version string
					# above section of header is compatible
					# with loadlin-1.5 (header v1.5). Don t
					# change it.

type_of_loader:	.byte	0		# = 0, old one (LILO, Loadlin,
					#      Bootlin, SYSLX, bootsect...)
					# See Documentation/i386/boot.txt for
					# assigned ids

# flags, unused bits must be zero (RFU) bit within loadflags
loadflags:
LOADED_HIGH	= 1			# If set, the kernel is loaded high
CAN_USE_HEAP	= 0x80			# If set, the loader also has set
					# heap_end_ptr to tell how much
					# space behind setup.S can be used for
					# heap purposes.
					# Only the loader knows what is free
#ifndef __BIG_KERNEL__
		.byte	0
#else
		.byte	LOADED_HIGH
#endif

setup_move_size: .word  0x8000		# size to move, when setup is not
					# loaded at 0x90000. We will move setup
					# to 0x90000 then just before jumping
					# into the kernel. However, only the
					# loader knows how much data behind
					# us also needs to be loaded.

code32_start:				# here loaders can put a different
					# start address for 32-bit code.
#ifndef __BIG_KERNEL__
		.long	0x1000		#   0x1000 = default for zImage
#else
		.long	0x100000	# 0x100000 = default for big kernel
#endif

ramdisk_image:	.long	0		# address of loaded ramdisk image
					# Here the loader puts the 32-bit
					# address where it loaded the image.
					# This only will be read by the kernel.

ramdisk_size:	.long	0		# its size in bytes

bootsect_kludge:
		.long	0		# obsolete

heap_end_ptr:	.word	_end+STACK_SIZE-512
					# (Header version 0x0201 or later)
					# space from here (exclusive) down to
					# end of setup code can be used by setup
					# for local heap purposes.

pad1:		.word	0
cmd_line_ptr:	.long	0		# (Header version 0x0202 or later)
					# If nonzero, a 32-bit pointer
					# to the kernel command line.
					# The command line should be
					# located between the start of
					# setup and the end of low
					# memory (0xa0000), or it may
					# get overwritten before it
					# gets read.  If this field is
					# used, there is no longer
					# anything magical about the
					# 0x90000 segment; the setup
					# can be located anywhere in
					# low memory 0x10000 or higher.

ramdisk_max:	.long 0x7fffffff
					# (Header version 0x0203 or later)
					# The highest safe address for
					# the contents of an initrd
					# The current kernel allows up to 4 GB,
					# but leave it at 2 GB to avoid
					# possible bootloader bugs.

kernel_alignment:  .long CONFIG_PHYSICAL_ALIGN	#physical addr alignment
						#required for protected mode
						#kernel
#ifdef CONFIG_RELOCATABLE
relocatable_kernel:    .byte 1
#else
relocatable_kernel:    .byte 0
#endif
pad2:			.byte 0
pad3:			.word 0

cmdline_size:   .long   COMMAND_LINE_SIZE-1     #length of the command line,
                                                #added with boot protocol
                                                #version 2.06

hardware_subarch:	.long 0			# subarchitecture, added with 2.07
						# default to 0 for normal x86 PC

hardware_subarch_data:	.quad 0

payload_offset:		.long input_data
payload_length:		.long input_data_end-input_data

setup_data:		.quad 0			# 64-bit physical pointer to
						# single linked list of
						# struct setup_data

# End of setup header #####################################################

	.section ".inittext", "ax"
start_of_setup:
#ifdef SAFE_RESET_DISK_CONTROLLER
# Reset the disk controller.
	movw	$0x0000, %ax		# Reset disk controller
	movb	$0x80, %dl		# All disks
	int	$0x13
#endif

# Force %es = %ds
	movw	%ds, %ax
	movw	%ax, %es
	cld

# Apparently some ancient versions of LILO invoked the kernel with %ss != %ds,
# which happened to work by accident for the old code.  Recalculate the stack
# pointer if %ss is invalid.  Otherwise leave it alone, LOADLIN sets up the
# stack behind its own code, so we can t blindly put it directly past the heap.

	movw	%ss, %dx
	cmpw	%ax, %dx	# %ds == %ss?
	movw	%sp, %dx
	je	2f		# -> assume %sp is reasonably set 相等就转跳2

	# Invalid %ss, make up a new stack 新建栈
	movw	$_end, %dx			#_end <= 0x8000 end address of Kernel setup	
	testb	$CAN_USE_HEAP, loadflags
	jz	1f
	movw	heap_end_ptr, %dx
1:	addw	$STACK_SIZE, %dx	# 栈大小
	jnc	2f
	xorw	%dx, %dx	# Prevent wraparound

2:	# Now %dx should point to the end of our stack space
	andw	$~3, %dx	# dword align (might as well...) 最低两位清零
	jnz	3f
	movw	$0xfffc, %dx	# Make sure we re not zero
3:	movw	%ax, %ss
	movzwl	%dx, %esp	# Clear upper half of %esp 栈头指向栈底 栈建立完成
	sti			# Now we should have a working stack   开中断

# We will have entered with %cs = %ds+0x20, normalize %cs so
# it is on par with the other segments.
	pushw	%ds
	pushw	$6f
	lretw			#分别弹出至cs寄存器和eip寄存器，cs:eip指向6
6:

# Check signature at end of setup
	cmpl	$0x5a5aaa55, setup_sig  #ld文件
	jne	setup_bad

# Zero the bss
	movw	$__bss_start, %di
	movw	$_end+3, %cx
	xorl	%eax, %eax
	subw	%di, %cx
	shrw	$2, %cx
	rep; stosl 	
	#带前缀的串指令rep; stosl，循环次数存放在cx寄存器中，执行一次串指令将清除4个字节的内存空间
	#整个bss段占用的内存空间大小除以4之后的值，+3保证完全清除bss段

# Jump to C code (should not return)
	calll	main

# Setup corrupt somehow...
setup_bad:
	movl	$setup_corrupt, %eax
	calll	puts
	# Fall through...

	.globl	die
	.type	die, @function
die:
	hlt
	jmp	die

	.size	die, .-die

	.section ".initdata", "a"
setup_corrupt:
	.byte	7
	.string	"No setup signature found...\n"
