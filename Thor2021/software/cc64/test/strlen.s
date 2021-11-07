; Two approaches
; a) disable interrupts while string op is taking place
; b) check the character after string op to make sure it's
;    actually what's expected.

.cont:
	strlen	$v0,$a0
	lc		$v1,[$a0+$v0*2]
	bne		$v1,$r0,.cont


.cont:
	strcmp	$v0,$a0,$a1
	lc		$v1,[$a0+$v0*2]
	lc		$t1,[$a1+$v0*2]
	beq		$t1,$v1,.cont
	cmp		$v0,$t1,$v1

.cont:
	strcpy	$v0,$a0,$a1
	lc		$v1,[$a1+$v0*2]
	bne		$v1,$r0,.cont


_strnlen:
	ldi		$v0,#0
.cont:
	lc		$v1,[$a0+$v0*2]
	beq		$v1,$r0,.done
	ibne	$v0,$a1,.cont
.done:
	ret

_strlen:
	ldi		$v0,#0
	ldi		$
.cont:
	lc		$v1,[$a0+$v0*2]
	beq		$v1,$r0,.done
	ibne	$v0,$a1,.cont
.done:
	ret

	ldi		$v0,#0
.cont:
	memcpy	$v0,$a0,$a1,$a2
	bne		$v0,$a2,.cont

