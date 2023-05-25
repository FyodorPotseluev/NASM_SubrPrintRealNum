%define HighestDigits ebp-4

%define str ebp+12
%define StrLen ebp+8
%define HighestFracDigits ebp-4
%define LowerFracDigits ebp-8
%define HighestPowerDigits ebp-12
%define LowerPowerDigits ebp-16
%define ECX ebp-20
%define FirstFracBitFlag ebp-24
%define FracBitCounter ebp-28
%define FracUnsign0sCounter ebp-32
%define NumberOfPower5Digits ebp-36

global	_start

section	.bss
RealStr resb 25
RealStrLen equ $-RealStr
real resd 1
exponent resb 1
mantissa resd 1
IntPart resd 1
FracPartBufStr resb 19

section	.data
a dd 0.0001220703125
;b dd 2.0
five dd 5
ten dd 10
billion dd 1000000000
BreakLine db 10

section	.text
NumToStr:
        push    ebp
        mov     ebp, esp
	sub	esp, 4
	pushad
	xor	ecx, ecx
	mov	edx, [ebp + 16]
        mov     eax, [ebp + 12]
        mov     edi, [ebp + 8]
	cmp	edx, 0
	je	.ShortArithmetic
	div	dword [billion]
	mov	[HighestDigits], eax
	mov	eax, edx
	mov	ebx, 9
.lp:	xor	edx, edx
	cmp	eax, 0
	je	.PushUnsign0s
	div	dword [ten]
	push	edx
	dec	ebx
	inc	ecx
	jmp	.lp	
.PushUnsign0s:
	cmp	ebx, 0
	je	.HighestDigitsRegister
	push	dword 0
	dec	ebx
	inc	ecx
	jmp	.PushUnsign0s
.HighestDigitsRegister:
	mov	eax, [HighestDigits]
.lp2:	xor     edx, edx; clear the 1st half of dividend
        cmp     eax, 0  ; does quotient equal "0" at last?
        je      .record ; if so, record number of chars
        div     dword [ten]
                        ; divide eax by 10
        push    edx
                        ; record current dividend into the stack
        inc     ecx     ; increase digit counter
        jmp     .lp2	
.ShortArithmetic:
        cmp     eax, 0  ; do we have at least one char in our text?
        je      .PrintZ ; if no then just return "0"
        ;mov     ebx, 1  ; preparing
        ;shl     ebx, 31 ; the mask and
        ;test    eax, ebx; apply it. Do we have a negative number?
        ;jz      .lp      ; if not - process it as a positive number
        ;not     eax     ; if negative - convert it 
        ;inc     eax     ; into a positive one
        ;add     esi, 1  ; and set negative flag
.lp3:   xor     edx, edx; clear the 1st half of dividend
        cmp     eax, 0  ; does quotient equal "0" at last?
        je      .record ; if so, record number of chars
        div     dword [ten]
                        ; divide eax by 10
        push    edx
                        ; record current dividend into the stack
        inc     ecx     ; increase digit counter
        jmp     .lp3
;.NegChck:
	;cmp     esi, 1  ; do we have a negative number?
        ;jne     .record
        ;mov     [edi], byte '-'
                        ; put '-' in the begining of the string
        ;inc     edi     ; next symbol
.record:pop     eax     ; save another digit to intermidiate storage
        add     al, 48  ; convert it into ascii format 
        mov     [edi], al
        inc     edi
        loop    .record
        jmp     .quit
.PrintZ:mov     [edi], byte '0'
.quit:  nop
.break: popad
	add	esp, 4
        pop     ebp
        ret

RealToStr:
	push	ebp
	mov	ebp, esp
	sub	esp, 36	; I don't know the final value yet
	pushad
	xor	ecx, ecx
	fst	dword [real]
			; convert ST0 into single precision real number and
			; write it into the memory area
	mov	edi, exponent
	lea	esi, [real + 3]
	movsb		; extract exponent
	shl	byte [exponent], 1
			; erasing sign bit from the exponent
	test	byte [real + 2], 0x80
	jz	.next
	inc	byte [exponent]
.next:	add	byte [exponent], 129
			; converting exponent into a sign number
	mov	edi, mantissa
	lea	esi, [real]
	movsd
	shl	dword [mantissa], 9
			; clean up the exponent and the sign bit
	cmp	byte [exponent], 0
			; depending on what exponent we've got we
			; transforming mantissa into a number
	jl	.fract
	inc	dword [IntPart]
			; 0x 00 00 00 00 => 01 00 00 00
			; add implicit bit to the integer part	
	cmp	byte [exponent], 0
	je	.next3
	mov	cl, byte [exponent]
.lp:	shl	dword [IntPart], 1
	shl	dword [mantissa], 1
	jnc	.cont	
	inc	dword [IntPart]
.cont:	loop	.lp
	jmp	.next3  	
.fract:	mov	cl, byte [exponent]
	not	cl
	inc	cl	; converting negative number into positive	
	shr	dword [mantissa], 1
	add	dword [mantissa], 0x80000000
			; add unsignificant bit to mantissa
	dec	cl	; count -1 because of the iteration above
	jcxz	.next3
.lp2:	shr	dword [mantissa], 1
	loop	.lp2
	
	; calculate the decimal length of the integer part and compare it
	; with the StrLen
.next3:	xor	edx, edx; clear the first half of the dividend
	mov	eax, dword [IntPart]
	cmp	eax, 0
	je	.next4
.lp3:	div	dword [ten]
	inc	ecx
	xor	edx, edx
	cmp	eax, 0
	je	.next4
	jmp	.lp3
.next4:	inc	ecx	; counting that we have to have one extra char space
			; for zero byte
	cmp	[StrLen], ecx
			; comparing StrLen with the length of the integer
			; part (counting the space for zero byte)
	ja	.next5
	lea	eax, [str]
			; if memory area length is less than integer part 
	mov	[eax], byte 0
			; length then record into the memory area zero byte
	jmp	.error	; and quit the subroutine
.next5: dec	ecx	; minus zero byte space
	push	dword [IntPart]
	push	dword [str]
	call	NumToStr
	add	esp, 8
	cmp	[mantissa], dword 0
			; if we have only integer number	
	je	.integer; then print zero byte behind the integer part
	add	ecx, 2	; now we need to find out whether we have space only 
	cmp	[StrLen], ecx
			; for decimal point and zero byte
	jbe	.integer; if not - then print zero byte behind the integer part	
	sub	ecx, 2
	lea	eax, [str]
	mov	eax, [eax]
	mov	[eax + ecx], byte '.'
	inc	ecx
	sub	[StrLen], ecx
			; now StrLen contains the length allocated for the 
			; fractional part
	mov	[LowerPowerDigits], dword 1	
			; memory will contain the value of current power of 5
			; we'll multiply it by 5 so it starts from 1
	mov	[FirstFracBitFlag], dword 1
			; first fractional bit flag (which helps to deal
			; whith unsignificant zeros) is set
.lp4:	mov     eax, [LowerPowerDigits]
        mul     dword [five]
                        ; calculate the next power of 5
        mov     [LowerPowerDigits], eax
        inc     dword [FracBitCounter]
	;;;;
	cmp	dword [FracBitCounter], 10
	je	.DoublePrecision
	;;;;
	test	[mantissa], dword 0x80000000
			; currrent fractional bit is 1?
	jz	.ZeroBit
	cmp	[FirstFracBitFlag], dword 1
			; is this the first bit?
	jne	.next6
	mov	[FirstFracBitFlag], dword 0
	xor	edx, edx; if yes - calculate the number of digits of power
			; of 5's accumulator
	mov	eax, [LowerPowerDigits]
.again:	div	dword [ten]
	xor	edx, edx
	inc	dword [NumberOfPower5Digits]
	cmp	eax, 0
	je	.NumOfUnsign0Computation
	jmp	.again	
.NumOfUnsign0Computation:
	mov	eax, [FracBitCounter]
	sub	eax, [NumberOfPower5Digits]
	mov	[FracUnsign0sCounter], eax
.next6:	mov	eax, [LowerFracDigits]
	mul	dword [ten]
	mov	[LowerFracDigits], eax
	mov	eax, [LowerPowerDigits]
	add	[LowerFracDigits], eax
			; add the result to the accumulator
	shl	dword [mantissa], 1
			; discard the highest fractional bit	
	cmp	[mantissa], dword 0
			; are there any fractional bit left?
	je	.FracToStr
			; if no convert accumulator into the string
	jmp	.lp4
.ZeroBit:		; if current fractional bit is 0 then
	mov     eax, [LowerFracDigits]
        mul     dword [ten]
        mov     [LowerFracDigits], eax
	shl	dword [mantissa], 1
			; discard the highest fractional bit
	jmp	.lp4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.lp5:	inc     dword [FracBitCounter]
	cmp	dword [FracBitCounter], 14
        je      .ExtendedPrecision
	mov     eax, [LowerPowerDigits]
        mul     dword [five]
                        ; calculate the next power of 5
        mov     [LowerPowerDigits], eax
.DoublePrecision:	; here we calculate the value till the 13-th 
			; mantissa bit 
	test    [mantissa], dword 0x80000000
                        ; currrent fractional bit is 1?
        jz      .ZeroBitDP
        cmp     [FirstFracBitFlag], dword 1
                        ; is this the first bit?
	jne	.next7
;;;;;;;;unsignificant zeros part;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        mov     [FirstFracBitFlag], dword 0
        xor     edx, edx; if yes - calculate the number of digits of power
                        ; of 5's accumulator
        mov     eax, [LowerPowerDigits]
.again2:div     dword [ten]
        xor     edx, edx
        inc     dword [NumberOfPower5Digits]
        cmp     eax, 0
        je      .NumOfUnsign0Computation
        jmp     .again2  
.NumOfUnsign0ComputationDP:
        mov     eax, [FracBitCounter]
        sub     eax, [NumberOfPower5Digits]
        mov     [FracUnsign0sCounter], eax
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.next7:	cmp	[HighestFracDigits], dword 0
			; multiplying the accumulator by 10
			; adding the power of 5 to the accumulator
	jne	.LongArithmetic	
			; if highest digits are not equal 0 then use new
			; method
	mov     eax, [LowerFracDigits]
        mul     dword [ten]
        mov     [LowerFracDigits], eax
	mov	[HighestFracDigits], edx
			; old accumulator multiplied by 10 is written into
			; the memory
	jmp	.SignificantBitDPend
.LongArithmetic:
	shl	dword [HighestFracDigits], 1
	shl	dword [LowerFracDigits], 1
	jnc	.next8
	inc	dword [HighestFracDigits]
.next8:	mov	edx, [HighestFracDigits]
	mov	eax, [LowerFracDigits]
	mov	ebx, 2
.again3:shl	edx, 1
	shl	eax, 1
	jnc	.next9
	inc	edx
.next9:	dec	ebx
	cmp	ebx, 0
	jne	.again3	
	add	eax, [LowerFracDigits]
	adc	edx, [HighestFracDigits]
			; now EDX:EAX registers contain previous accumulator
			; multiplyed by 10
	mov	[LowerFracDigits], eax
	mov	[HighestFracDigits], edx
			; new accumulator value is stored in the memory 
.SignificantBitDPend:
	xor	edx, edx
        mov     eax, [LowerPowerDigits]
			; current power of 5 is in EDX:EAX registers
        add     [LowerFracDigits], eax
                        ; add the result to the accumulator
	adc	[HighestFracDigits], edx
			; taking into account the carry flag
        shl     dword [mantissa], 1
                        ; discard the highest fractional bit    
        cmp     [mantissa], dword 0
                        ; are there any fractional bit left?
        je      .FracToStr
                        ; if no convert accumulator into the string
        jmp     .lp5
.ZeroBitDP:		; if current fractional bit is 0 then
        ;mov     eax, [LowerFracDigits]
        ;mul     dword [ten]
        ;mov     [LowerFracDigits], eax
	cmp     [HighestFracDigits], dword 0
                        ; multiplying the accumulator by 10
                        ; adding the power of 5 to the accumulator
        jne     .LongArithmetic2 
                        ; if highest digits are not equal 0 then use new
                        ; method
        mov     eax, [LowerFracDigits]
        mul     dword [ten]
        mov     [LowerFracDigits], eax
        mov     [HighestFracDigits], edx
                        ; old accumulator multiplied by 10 is written into
                        ; the memory
        jmp     .UnsignificantBitDPend
.LongArithmetic2:
        shl     dword [HighestFracDigits], 1
        shl     dword [LowerFracDigits], 1
        jnc     .next10
        inc     dword [HighestFracDigits]
.next10:mov     edx, [HighestFracDigits]
        mov     eax, [LowerFracDigits]
        mov     ebx, 2
.again4:shl     edx, 1
        shl     eax, 1
	jnc     .next11
        inc     edx
.next11:dec     ebx
        cmp     ebx, 0
        jne     .again4 
        add     eax, [LowerFracDigits]
        adc     edx, [HighestFracDigits]
                        ; now EDX:EAX registers contain previous accumulator
                        ; multiplyed by 10
        mov     [LowerFracDigits], eax
        mov     [HighestFracDigits], edx
                        ; new accumulator value is stored in the memory
.UnsignificantBitDPend:
	shl     dword [mantissa], 1
                        ; discard the highest fractional bit
        jmp     .lp5	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.ExtendedPrecision:	; here we calculate the value till the 18-th 
                        ; mantissa bit
	


.FracToStr:		; here we transform the part behind the decimal
			; point from a number to a string
	lea     eax, [HighestFracDigits]
        push    dword [eax]
	lea	eax, [LowerFracDigits]
	push	dword [eax]
        push    FracPartBufStr
        call    NumToStr
.break:	add     esp, 12
			; type into destination string unsignificant zeros
	cmp	[FracUnsign0sCounter], dword 0
	je	.nextt
	mov	edi, [str]
	add	edi, ecx
	mov	eax, '0'
.againn:stosb	
	inc	ecx
	dec	dword [FracUnsign0sCounter]
	cmp     [FracUnsign0sCounter], dword 0
	je	.nextt
	jmp	.againn	
.nextt:			; transfer the bytes of string representation of 
			; fractional part to the destination string
	mov	esi, FracPartBufStr
	mov	edi, [str]
	add	edi, ecx
.repeat:movsb
	inc	ecx
	dec	dword [StrLen]
	cmp	dword [StrLen], 1
	je	.Add0Byte
	cmp	byte [esi], 0
	je	.Add0Byte
	jmp	.repeat
.Add0Byte:
	mov	[edi], byte 0 	
	jmp	.quit
.integer:		; jump here if we only have enough space to write the
	sub	ecx, 2	; integer part of the number
	mov	[RealStr + ecx], byte 0
	mov	eax, ecx
	inc	eax
	jmp	.quit
.error:	mov	eax, 0
.quit:	mov	[ECX], ecx
	popad
	mov	eax, [ECX]
	add	esp, 36
	pop	ebp
	ret

;%define FirstFracBitFlag ebp-24
;%define FracBitCounter ebp-28
;%define FracUnsign0sCounter ebp-32
;%define NumberOfPower5Digits ebp-36

		
	
_start:	;fld	dword [b]	
			; ST1
	fld	dword [a]	
			; ST0
	;fdiv	st1	; division
	mov	eax, RealStr
	mov	ecx, RealStrLen
	push	eax
	push	ecx
	call	RealToStr
	add	esp, 12
	mov	edx, eax; put in edx string length for "print" syscall
	mov	eax, 4	; print
	mov	ebx, 1
	mov	ecx, RealStr
	int	80h
	mov	eax, 4	; print break line symbol
	mov	ebx, 1
	mov	ecx, BreakLine
	mov	edx, 1
	int	80h
exit:	mov	eax, 1
	mov	ebx, 0
	int	80h