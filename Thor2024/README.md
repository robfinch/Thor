# Welcome to Thor2024

## Overview
Thor2024 is an implementation of the Thor2024 instruction set architecture. The ISA is for a 64-bit general purpose machine. The Thor2024 ISA supports SIMD style vector operations.

### Versions
Thor2024 is the 2024 version of the Thor processor which has evolved over the years. Different versions are completely incompatible with one another as the author has learned and gained more experience.
Thor2024.sv is the top level for the CPU.

### History
Work started on Thor2024 in May of 2023.

### Features Out-of-Order version
Fixed length instruction set, 40-bit instructions.
64-bit datapath
8 entry (or more) reorder entry buffer (ROB)
63 general purpose registers, unified integer and float register file
63 vector registers
Out-of-order execution of instructions
Interruptible micro-code.
1024 entry, five way TLB for virtual memory support

## Out-of-Order Version
### Status
The Thor2024 OoO machine is currently in development. The base machine has
been undergoing simulation runs. Running a test program in the FPGA the core was able to clear a text screen. A long way to go yet. 

### Register File
The register file contains 63 registers and is unified, supporting integer and floating-point operations using the same set of registers. One register code, 63, is dedicated to indicate the use of a postfix immediate for the value.
There is a dedicated zero register, r0. There is also a register dedicated to refer to the program counter or the stack canary. The same register code serves both purposes. The register referring to the PC allows program counter relative addresses to be formed. Predicate registers are also part of the general purpose register file and the same set of instructions may be applied to them as to other registers. A register is also dedicated to the stack pointer, which is special in that it is banked for different operating modes.
Four registers are dedicated to micro-code use.

### Instruction Length
The author has found that in an FPGA the decode of variable length instruction length was on the critical timing path, limiting the maximum clock frequency and performance. So, he has decided to go with a fixed length instruction set for Thor2024. This is different than earlier versions which were variable length. However, while fixed length, Thor2024 supports extended length constants using postfix instructions. Postfix instructions are associated with the previous instruction and are fetched at the same time as the previous instruction. Effectively they are treated as if they were part of the instruction, but, the program counter still increments by a fixed amount so the postfix instructions end up being fetched and treated as NOPs. This is slightly better than using additional instructions to encode constants as the entire instruction word is used to hold a constant making it more memory efficient.
The five byte instruction length was chosen because of the number of operations supported by the processor and the use of predicates. A 32-bit instruction was just too cramped.

### Instruction alignment
Instructions may be aligned on any byte boundary. While the instruction set is not variable length, the instruction length of five bytes makes byte aligned instructions mandatory. Branch displacements and other target addresses are precise to the byte. Code may be relocated to any byte boundary.

### Pipeline
There are roughly five stages in the pipeline, fetch, decode, queue, execute and writeback.
The first step for an instruction is instruction fetch. At instruction fetch a pair of instructions is fetched from the instruction cache and placed in a fetch buffer. Any postfix instructions associated with the fetched instructions are also fetched. If there is a hardware interrupt, a special interrupt instruction overrides the fetched instructions and the PC increment is disabled until the interrupt is recognized.
After instruction fetch the instructions are decoded and register values are fetched. And the instruction decodes and register values that are available are placed in the reorder buffer / queued.
The next stage is execution. Note that the execute stage waits until all the instruction arguments are valid before trying to execute the instruction.
Instruction arguments are made valid by the execution or writeback of prior instructions. Note that while the instruction may not be able to execute, decode and execute are *not* stalled. Other instructions are decoded and executed while waiting for an instruction missing arguments. Execution of instructions can be multi-cycle as for loads, stores, multiplies and divides.
At the end of instruction execution the result is placed back into the reorder buffer. There may be a maximum of four instruction being executed at the same time. An alu, an fpu a memory and one flow control.
The last stage, writeback, reorders instructions into program order reading the oldest instructions from the ROB. The core may writeback or commit two instructions per clock cycle.

### Branch Prediction
Branch prediction is via a simple backwards branch predictor. Backwards branches are predicted taken. There is also a branch target buffer in the works. The BTB has 1024 entries. There is a 64-entry return stack buffer, RSB, to predict return addresses.

### Interrupts and Exceptions
Interrupts and exceptions are precise.

### Arithmetic Operations
The ISA supports many arithmetic operations including add, sub, mulitply and divide. Multi-bit shifts and rotates are supported. And a full set of logic operations and their complements are supported.

### Floating-point Operations
Several floating-point ops have been added to the core, including fused multiply-add, reciprocal and reciprocal square root estimates and sine and cosine functions.

### Branches
Conditional branches are a fused compare-and-branch instruction. Values of two registers are compared, then a branch is made depending on the relationship between the two.
Conditional branches may update the link register allowing conditional subroutine calls. Conditional branch to register is also supported to allow conditional branches to take place to a target farther away than can be supported by the displacement. Conditional branch to register also allow conditional subroutine returns to be performed. The branch displacement is seventeen bits, so the range is +/- 64kB from the branch instruction.

### Loads and Stores
Load and store operations are queued in a memory queue. Once the operation is queued execution of other instructions continues. The core currently allows only strict ordering of memory operations. Load and store instructions are queued in program order.
Stores are allowed to proceed only if it is known that there are no prior instructions that can cause a change of program flow.
Loads do not yet bypass stores. There is a component in the works that allows this but it does not work 100% yet.
There are bits in control register zero assigned for future use to indicate more relaxed memory models.

### Predicated Execution
Instructions may be conditionally executed based on Boolean value in a predicate register. Most instruction have a three bit field allowing one of eight predicate registers to be specified.

### Vector Instructions
The eventual goal is to support SIMD style vector instructions. The ISA is setup to support these. A large FPGA will be required to support the vector instructions.

### Instruction Postfixes
The author has learned a new trick, the one of using instruction postfixes.
The ISA uses instruction postfixes to extend constant ranges. In the author's opinion this is one of the better ways to handle large constants because the extension can be applied to a wide range of instructions without needing to add a whole bunch of instructions for larger constants. It can also be done with a fixed length instruction set.
Postfix processing is simpler than using prefixes because the postfix values can be pulled from the cache line after the instruction. Postfixes encountered in the instruction stream are treated as NOP instructions.

## Memory Management
The core is decoupled from memory management. The core uses virtual addresses. The MMU is external to the core and shared by all CPUs. The MMU page size is 64kB. This is quite large and was chosen to reduce the number of block RAMs required to implement a hashed page table. The large page size also means that the address space of the test system can be mapped using only a single level of tables.

### TLB
The TLB is five-way associative with 1024 entries per way. The TLB is shared between all cores, instructions and data and is always enabled. The fifth way of the TLB is automatically loaded with values allowing access to the boot ROM at startup.The fifth way of the TLB may only be updated by software in a fixed fashion. The other four ways may be updated according to fixed, LRU or random algorithms.
One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.

### Table Walker
There is a hardware page table walker in the works. There is a single table walker for multiple cores. The table walker is triggered by a TLB miss and walks the page tables to find a translation.

### Hash Page Table
Also available is hash based page table that is implemented using block RAMs. The hash page table is quite fast since it does not rely on main memory and makes use of a wide bus to perform parallel searches. The hash page table is clocked at twice the CPU clock rate.

### Instruction Cache
The instruction cache is a four-way set associative cache, 32kB in size with a 512-bit line size. There is only a single level of cache. The cache is divided into even and odd lines which are both fetched when the PC changes. Using even / odd lines allows instructions to span cache lines. While instructions are fixed length, they may be associated with instruction postfixes which provide extended immediate values for instructions. The instruction plus postfixes will always fit into a 512-bit cache line.

### Data Cache
The data cache is 64kB in size.

# Software
Thor2024 will use vasm and vlink to assemble and link programs. vlink is used 'out of the box'. A Thor2024 backend is being written for vasm. The CC64 compiler may be used for high-level work and compiles to vasm compatible source code.

# Core Size
Including only basic integer instructions the core is about 60,000 LUTs or 100,000 LC's in size. Not including the MPU component or MMU. *The core size
seems to be constantly increasing as updates occur.

# Performance
The toolset indicates the core should be able to reach 33 MHz operation. Under absolutely ideal conditions the core may execute two instructions per clock. All stages support processing at least two instructions per clock. Realistically the core will typically execute less than one instruction per clock.
