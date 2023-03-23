; shared TLB miss handler
; Handles a 34-bit virtual address
; Slightly more complex than an unshared TLB as the TLB registers need to be
; protected via a semaphore. Updates must be restricted to one core at a time.
; The TLB device needs to be permanently mapped into the system's address space
; since it is MMIO and uses the TLB.
; The stack must be mapped into a global address space.
; 
;
S_ASID equ $101F
M_IE equ $3004
M_SEMA equ $300C
PTE_T equ 21


tlb_miss_irq34:
	st96 t0,[sp]										; save working registers
	st96 t1,12[sp]
	st96 t2,24[sp]
	st96 t3,36[sp]
	st96 t4,48[sp]
	st96 t5,60[sp]
	ld96 t0,TLB_MISS_ADR						; t0 = miss address, reading miss address clears interrupt
	csrrs	r0,3,M_IE									; enable interrupts
	csrrd	t1,r0,S_PTBR							; t1 = page table base
	clr	t1,t1,0,13									; clear 14 LSBs, address is page aligned
	extu t2,t0,24,9									; get miss address bits 24 to 33, index into top level page table
	ld96 t3,[t1+t2*]								; get PTP from top level table
	bbc	t3,PTE_V,.noL1PTE						; check that entry is valid
	extu t5,t3,PTE_T,0							; get PTE.T bit
	bbc	t3,PTE_T,.L1superPage				; check for 16MB superpage
	extu t1,t3,PTE_PPN,63						; get PTP pointer
	asl	t1,t1,14										; convert PPN to table address
	extu t2,t0,14,9									; get miss address bits 14 to 23
	ld96 t3,[t1+t2*]								; get MPP
	bbc	t3,PTE_V,.noL0PTE						; check that entry is valid
	bbs	t3,PTE_T,.corrupt						; should be a PTE, otherwise table corrupt
.L1superPage:
	extu t1,t0,20,75								; VPN bits 6 to 83 = miss address bits 20 to 95
	csrrd	t2,r0,S_ASID							; add ASID to miss address
	asl	t2,t2,80
	or t1,t1,t2											; t1 = VPN+ASID
	extu t2,t0,14,9									; t2 = address bits 14 to 23 = TLB entry number
	asl t2,t2,5											; shift into position
	csrrd t4,0,S_LFSR								; choose a random way to replace
	pne t5,"TFFIIIII"								; way depends on page level
	and t4,t4,3											; way 0 to 3	; normal page
	and	t4,t4,1											; way 0 or 1	; superpage
	add	t4,t4,4											; way 4 or 5	; superpage
	or t2,t2,t4											; bump out
	csrrc	r0,3,M_IE									; disable interrupts
.lock:
	csrwr t4,1,M_SEMA								; try and set semaphore
	csrrd t4,0,M_SEMA								; check and see if set, zero returned if set
	bbs	t4,0,.lock									; must have been clear
	st96 t1,TLB_PTE									; do quick stores to memory
	st96 t3,TLB_VPN
	st96 t2,TBL_CTRL
	st8 r0,TLB_WTRIG								; trigger update
	csrrc r0,1,M_SEMA								; release semaphore
	csrrs	r0,3,M_IE									; enable interrupts
	ld96 t0,[sp]										; restore working registers
	ld96 t1,12[sp]
	ld96 t2,24[sp]
	ld96 t3,36[sp]
	ld96 t4,48[sp]
	ld96 t5,60[sp]
	rti
	; Here, memory was not mapped to support the access. So, the program must be
	; trying to read or write a random address. Abort the program.
.noL1PTE:
.noL0PTE:
.corrupt:
	ldi a0,ABORT_PROGRAM
	ldi	a1,ERR_TLBMISS
	syscall
