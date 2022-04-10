# Welcome to Thor2022

## Overview
Thor2022 is an implementation of the Thor2022 instruction set architecture. The ISA is for a 64-bit general purpose machine.

### Versions
Thor2022 is the 2022 version of the Thor processor which has evolved over the years. Different versions are completely incompatible with one another as the author has learned and gained more experience.
There are two versions of the 2022 core, Thor2022io which is an in-order version and Thor2022oo which is an out-of-order version. Thor2022oo is the one actively being worked on.

### History
Work started on Thor2022 in January of 2022.

### Features Out-of-Order version
Variable length instruction set, 16, 32, 48 or 64-bit instructions.
64-bit datapath
Five stage pipeline, Fetch, Decompress, Decode, Execute, and Writeback.
6 entry (or more) reorder entry buffer (REB)
32 general purpose registers, unified integer and float register file
Out-of-order execution of instructions
Branch predictors including branch target buffer and return address stack predictors.
128-bit decimal floating-point
1024 entry, five way TLB for virtual memory support

### Features In-order version
Same ISA
Variable length instruction set, 16, 32, 48 or 64-bit instructions.
64-bit datapath
Classic five stage pipeline, Fetch, Decode, Execute, Memory and Writeback
32 general purpose registers, unified integer and float register file
In-order execution of instructions
128-bit decimal floating-point
1024 entry, five way TLB for virtual memory support

## Out-of-Order Version
### Status
The Thor2022oo machine currently runs successfully in simulation at least to the point of activating LEDs, which takes about 800 instructions. Work is ongoing to get the machine running in an FPGA.

### Pipeline
There are five pipeline stages that act independently on the reorder entry buffer, REB. As each stage completes it sets a flag in the buffer entry that indicates to the next stage that the entry is ready to be processed. The stages work in an overlapped fashion.
The first step for an instruction is instruction fetch. At instruction fetch an instruction is fetched from the instruction cache and placed in the REB in the first open slot. Since branches make parts of the REB available eventually open slots may appear anywhere in the buffer making placement of the instruction essentially random.
Order is maintained in the buffer using sequence numbers. When the instruction is queued in the buffer an incrementing sequence number is assigned to it. Fetch, decompress and decode ignore the sequence number. Execute and writeback use the sequence number to order things when needed.
After instruction fetch, the instruction may be decompressed if it is a compressed instruction. Next the instruction is decoded and register values are fetched. Note that the execute stage waits until all the instructions arguments are valid before trying to execute the instruction.
Instruction arguments are made valid by the execution or writeback of prior instructions. Note that while the instruction may not be able to execute, decode and execute are *not* stalled. Other instructions are decoded and exeuted while waiting for an instruction missing arguments.
The last stage, writeback, reorders instructions into program order by writing back the instruction with the oldest sequence number. Writeback may pull instructipns from any slot as long as it is the oldest instruction.
The REB does not work in a circular fashion. It does work according to the order determined by a sequence number.

### Branches
Branches remove the instructions with a higher sequence number than the branch from the buffer. To improve performance branches are predicted using a branch target buffer, BTB, and a gshare branch predictor. If the branch is corectly predicted then no instructions are removed from the buffer.
The branch target buffer works at the fetch stage of the core. The gshare predictor works at the decode stage of the core.
There is also a 32-entry return address stack, RAS, predictor to predict the return address at the fetch stage of the core.
The BTB and gshare predictors may be turned off by bits in control register zero.
The core maintains performance counters for the number of branch instructions, number of branch misses, number of BTB hits and number of RAS predictions.

### Loads and Stores
Load and store operations are queued in a memory queue. Once the operation is queued execution of other instructions continues. The core currently allows only strict ordering of memory operations. Load and store instructions are queued in program order, determined using the sequence number of the instruction.
Stores are allowed to proceed only if it is known that there are no prior instructions that can cause a change of program flow.
Loads do not yet bypass stores. There is a component in the works that allows this but it does not work 100% yet.
There are bits in control register zero assigned for future use to indicate more relaxed memory models.

### Instruction Prefixes
The ISA uses instruction prefixes to extend constant ranges. In the author's opinion this is one of the better ways to handle large constants because the extension can be applied to a wide range of instructions without needing to add a whole bunch of instructions for larger constants.
Prefix processing is complicated because the prefix needs to be pulled from a random location in the buffer to be used for the following instruction.
Prefixes are associated with instructions by having a sequence number one lower than the following instruction. The instruction prefix does not get retired until the following instruction is ready to retire, at which point both the instruction and prefix are retired.
It is important that the prefix remain present in the buffer until it can be used by the following instruction. Since execution is out-of-order technically a prefix may be ready to be removed before the following instruction has even been fetched. Prefixes are treated as NOP operations.

## In-Order Version
### Status
The Thor2022io version is not currently being worked on. It was left in a state where it could run a small demo moving sprites around on the screen, however the demo did not work correctly.

## Both Versions
Both versions of the core share the same bus interface unit, BIU. Virtual memory is always active. The TLB is preinitialized at startup to enable access to the system ROM.
One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.
The TLB is shared between instructions and data. The fifth way of the TLB may only be updated by software in a fixed fashion. The other four ways may be updated according to fixed, LRU or random algorithms.

### Instruction Cache
The instruction cache is 32kB in size with a 640-bit line size. The 640 bits was chosen to allow instructions that would wrap cache lines to otherwise remain on the same line. Since instructions are variable length they may not fit evenly into a 512-bit cache line.
They will always fit into a 640-bit line. There is some duplication of instruction data but it is better than dual-porting the cache.

### Data Cache
The data cache is 64kB in size. The cache uses even, odd pairs of cache lines to allow unaligned data which may overflow a cache line to be fetched from the cache.
The data cache is currently untested.

