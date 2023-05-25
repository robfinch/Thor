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
64 general purpose registers, unified integer and float register file
64 vector registers
Out-of-order execution of instructions
1024 entry, five way TLB for virtual memory support

## Out-of-Order Version
### Status
The Thor2024 OoO machine is currently in development. It has not yet reached the point of begin simulated.

### Register File
The register file contains 64 registers and is unified, supporting integer and floating-point operations using the same set of registers. There is a dedicated zero register, r0. There is also a register dedicated to refer to the program counter or the stack canary. The same register code serves both purposes. The register referring to the PC allows program counter relative addresses to be formed. Predicate registers are also part of the general purpose register file and the same set of instructions may be applied to them as to other registers. A register is also dedicated to the stack pointer, which is special in that it is banked for different operating modes.

### Instruction Length
The author has found that in an FPGA the decode of variable length instruction length was on the critical timing path, limiting the maximum clock frequency and performance. So, he has decided to go with a fixed length instruction set for Thor2024. This is different that eariler versions which were variable length. However, while fixed length, Thor2024 supports extended length constants using postfix instructions. Postfix instructions are associated with the previous instruction and are fetched at the same time as the previous instruction. Effectively they are treated as if they were part of the instruction, but, the program counter still increments by a fixed amount so the postfix instructions end up being fetched and treated as NOPs. This is slightly better than using additional instructions to encode constants as the entire instruction word is used to hold a constant making it more memory efficient.
The five byte instruction length was chosen because of the number of operations supported by the processor and the use of predicates. A 32-bit instruction was just too cramped.

### Instruction alignment
Instructions may be aligned on any byte boundary. While the instruction set is not variable length, the instruction length of five bytes makes byte aligned instructions mandatory. Branch displacements and other target addresses are precise to the byte.

### Pipeline
There are roughly five stages in the pipeline, fetch, decode, queue, execute and writeback.
The first step for an instruction is instruction fetch. At instruction fetch an instruction is fetched from the instruction cache and placed in a fetch buffer. Any postfix instructions associated with the fetched instruction are also fetched. If there is a hardware interrupt, a special interrupt instruction overrides the fetched instruction and the PC increment is disabled until the interrupt is recognized.
After instruction fetch the instruction is decoded and register values are fetched. And the instruction decodes and register values that are available are placed in the reorder buffer.
The next stage is execution. Note that the execute stage waits until all the instruction arguments are valid before trying to execute the instruction.
Instruction arguments are made valid by the execution or writeback of prior instructions. Note that while the instruction may not be able to execute, decode and execute are *not* stalled. Other instructions are decoded and exeuted while waiting for an instruction missing arguments.
At the end of instruction execution the result is placed back into the reorder buffer.
The last stage, writeback, reorders instructions into program order reading the oldest instruction from the ROB.

### Arithmetic Operations
The ISA supports many arithmetic operations including add, sub, mulitply and divide. Multi-bit shifts and rotates are supported. And a full set of logic operations and their complements are supported.

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

### Instruction Postfixes
The author has learned a new trick, the one of using instruction postfixes.
The ISA uses instruction postfixes to extend constant ranges. In the author's opinion this is one of the better ways to handle large constants because the extension can be applied to a wide range of instructions without needing to add a whole bunch of instructions for larger constants. It can also be done with a fixed length instruction set.
Postfix processing is simpler than using prefixes because the postfix values can be pulled from the cache line after the instruction. Postfixes encountered in the instruction stream are treated as NOP instructions.

## TLB
One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.
The TLB is shared between instructions and data. The fifth way of the TLB may only be updated by software in a fixed fashion. The other four ways may be updated according to fixed, LRU or random algorithms.
The TLB may be updated either by software or by hardware. Hardware updates are untested.

### Instruction Cache
The instruction cache is a four-way set associative cache, 32kB in size with a 512-bit line size. There is only a single level of cache. The cache is divided into even and odd lines which are both fetched when the PC changes. Using even / odd lines allows instructions to span cache lines. While instructions are fixed length, they may be associated with instruction postfixes which provide extended immediate values for instructions. The instruction plus postfixes will always fit into a 512-bit cache line.

### Data Cache
The data cache is 64kB in size.

# Software
Thor2024 will use vasm and vlink to assemble and link programs. vlink is used 'out of the box'. A Thor2024 backend is being written for vasm. The CC64 compiler may be used for high-level work and compiles to vasm compatible source code.

