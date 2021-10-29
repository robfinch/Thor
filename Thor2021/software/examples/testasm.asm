	.text
start:
	bsr		sub1
	jsr		sub1
	bsr		lk2,sub2
	jsr		lk1,sub1
	add		r1,r2,1234
	add		r48,r32,567
	add		r4,r1,r2,r3
	add		r5,r4,r3
	bra		start
	rts

sub1:
	add		r3,r4,r5
	rts

sub2:
	add		r6,r7,r8
	rts		lk2
