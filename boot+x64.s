# Copyright 2015 Philipp Oppermann
#
# Licensed under the Apache License, Version 2.0 (the "License")#
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.global start

.section .text
.code32
start:
    movl $stack_top, %esp 

    call check_multiboot
    jmp .
    call check_cpuid
    call check_long_mode

    call set_up_page_tables
    call enable_paging
    call set_up_sse

    # load the 64-bit GDT
    lgdt .gdtpointer

    # update selectors
    movw .gdtdata, %ax
    movw %ax, %ss
    movw %ax, %ds
    movw %ax, %es

    ljmp $8, $long_mode_start
long_mode_start:

set_up_page_tables:
    # map first P4 entry to P3 table
    movl $p3_table, %eax 
    orl $0x3, %eax # present + writable
    movl %eax, p4_table

    # map first P3 entry to P2 table
    movl p2_table, %eax
    orl $0x3, %eax # present + writable
    mov %eax, p3_table

    # map each P2 entry to a huge 2MiB page
    xorl %ecx, %ecx
.map_p2_table:
    # map ecx-th P2 entry to a huge page that starts at address (2MiB * ecx)
    movl $0x200000, %eax  # 2MiB
    mull %ecx		# start address of ecx-th page
    orl $0x83, %eax	# present + writable + huge
    movl %eax,p2_table(,%ecx,8) # map ecx-th entry

    incl %ecx            # increase counter
    cmpl $512,%ecx       # if counter == 512, the whole P2 table is mapped
    jne .map_p2_table  # else map the next entry

    ret

enable_paging:
    # load P4 to cr3 register (cpu uses this to access the P4 table)
    movl $p4_table, %eax
    movl %eax, %cr3

    # enable PAE-flag in cr4 (Physical Address Extension)
    movl %cr4, %eax
    orl $(1<<5), %eax
    movl %eax,%cr4

    # set the long mode bit in the EFER MSR (model specific register)
    movl $0xC0000080, %ecx
    rdmsr
    orl $(1 << 8), %eax
    wrmsr

    # enable paging in the cr0 register
    movl %cr0, %eax
    or 1 << 31, %eax
    mov %eax, %cr0

    ret

# Prints `ERR: ` and the given error code to screen and hangs.
# parameter: error code (in ascii) in al
error:
    movl $0x4f524f45, 0xb8000
    movl $0x4f3a4f52, 0xb8004
    movl $0x4f204f20, 0xb8008
    movb %al, 0xb800a
    hlt

# Throw error 0 if eax doesn't contain the Multiboot 2 magic value (0x36d76289).
check_multiboot:
    cmpl $0x36d76289,%eax
    jne .no_multiboot
    ret
.no_multiboot:
    movb $'0',%al
    jmp error

# Throw error 1 if the CPU doesn't support the CPUID command.
check_cpuid:
    # Check if CPUID is supported by attempting to flip the ID bit (bit 21) in
    # the FLAGS register. If we can flip it, CPUID is available.

    # Copy FLAGS in to EAX via stack
    pushfl
    pop %eax

    # Copy to ECX as well for comparing later on
    mov %eax, %ecx

    # Flip the ID bit
    xor $(1 << 21), %eax

    # Copy EAX to FLAGS via the stack
    pushl %eax
    popfl

    # Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfl
    popl %eax

    # Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit
    # back if it was ever flipped).
    pushl %ecx
    popfl

    # Compare EAX and ECX. If they are equal then that means the bit wasn't
    # flipped, and CPUID isn't supported.
    xor %ecx, %eax
    jz .no_cpuid
    ret
.no_cpuid:
    mov $'1', %al
    jmp error

# Throw error 2 if the CPU doesn't support Long Mode.
check_long_mode:
    movl $0x80000000, %eax    # Set the A-register to 0x80000000.
    cpuid                  # CPU identification.
    cmpl 0x80000001, %eax    # Compare the A-register with 0x80000001.
    jb .no_long_mode       # It is less, there is no long mode.
    mov $0x80000001, %eax    # Set the A-register to 0x80000001.
    cpuid                  # CPU identification.
    test $(1 << 29), %edx       # Test if the LM-bit, which is bit 29, is set in the D-register.
    jz .no_long_mode       # They aren't, there is no long mode.
    ret
.no_long_mode:
    mov $'2', %al
    jmp error

# Check for sse and enable it. If it's not supported throw error "a".
set_up_sse:
    # check for sse
    movl $0x1, %eax
    cpuid
    test $(1<<25), %edx
    jz .no_sse

    # enable sse
    movl %cr0, %eax
    andw $0xFFFB, %ax      # clear coprocessor emulation CR0.EM
    orw 0x2, %ax          # set coprocessor monitoring  CR0.MP
    movl %eax, %cr0
    movl %cr4, %eax
    orw $(3<<9), %ax       # set CR4.OSFXSR and CR4.OSXMMEXCPT at the same time
    movl %eax, %cr4

    ret
.no_sse:
    movb $'a',%al
    jmp error

.bss
/*.align 4096*/
p4_table:
    .fill 4096, 1, 0
p3_table:
    .fill 4096, 1, 0
p2_table:
    .fill 4096, 1, 0
stack_bottom:
    .fill 64, 1, 0
stack_top:

.data
gdt64:
    .quad 0 # zero entry
.gdtcode:
    .quad (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53) # code segment
.gdtdata:
    .quad (1<<44) | (1<<47) | (1<<41) # data segment
.gdtpointer:
    .long . - gdt64 - 1
    .quad gdt64
