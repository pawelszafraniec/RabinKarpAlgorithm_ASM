.data
.code	

			; arguments locations passed by the function:
			; 1 - RCX		- text address
			; 2 - RDX		- pattern address
			; 3 - R8			- alphabet
			; 4 - R9			- modulo 
			; 5 - STACK	- text length
			; 6 - STACK	- pattern length
			; 7 - STACK	- result array address

			; arguments locations after repositioning:
			; TEXT				/ XMM0
			; PATTERN			/ XMM1
			; alph				/ XMM2
			; modulo			/ XMM3
			; text length		/ XMM4
			; pattern length	/ XMM5
			; RESULT			/ XMM10

RKAlgorithm proc ; Asm algorithm without SIMD

	;saving values 
	movd xmm0,rcx			;text address
	movd xmm1,rdx			;pattern address
	movd xmm2,r8			;alphabet
	movd xmm3,r9			;modulo


	;taking values out of the stack
	xor eax,eax
	mov eax, DWORD PTR [rsp + 40]		;text length
	mov r10d,eax 
	movd xmm4,r10								;SSE2
	
	xor eax,eax
	mov eax, DWORD PTR [rsp + 48]		;pattern length
	mov r11d,eax
	movd xmm5,r11								;SSE2

	xor eax,eax
	mov rax, QWORD PTR [rsp + 56]		;results array address
	movd xmm10,rax							;SSE2

	xor eax,eax
	mov eax,1
h: ; calculating value of h
    ; h =(h*alphabet) % modulo	
	xor edx,edx
	imul eax,r8d				; h*alphabet
	div r9d						; eax % modulo
	mov eax,edx				; move remainder to eax
	dec r11d					; decrement the loop
	cmp r11d,1				; executed N-1 times
	jnz h							; loop if not zero
	movd xmm7,eax			;saving value of h

	xor eax,eax
	movd ecx,xmm5			; loop counter
	movd r11,xmm1			; pointer to first element of pattern array

WindowPattern: ; calculating hash value for the pattern
	; p = (alphabet * p + pattern[i]) % modulo
	xor edx,edx
	imul eax,r8d				; alphabet*p
	mov r10b,[r11]			; move value of pattern[i]
	add eax,r10d				; +pattern[i]
	div r9d						; % modulo
	mov eax,edx				; move remainder to eax
	inc r11						; r11++
	loop WindowPattern	; loop according to ecx register value
	movd xmm8,rax			; save the value 

	xor eax,eax
	movd ecx,xmm5			; loop counter
	movd r11,xmm0			; pointer to first element of text array

WindowText: ; calculating hash value for first text window
	; t = (alphabet * t + text[i]) % modulo
	xor edx,edx			
	imul eax,r8d				; alphabet*t	
	mov r10b,[r11]			; move value of text[i]
	add eax,r10d				; + text[i]
	div r9d						; % modulo
	mov eax,edx				; move remainder to eax
	inc r11						; r11++
	loop WindowText		; loop according to ecx register value
	movd xmm9, rax			; save the value

	xor edx,edx
	subss xmm4,xmm5		; text.length - pattern.length *SSE
	movd r9,xmm4			; move text.length
	movd r10,xmm5			; move pattern.length
	mov ecx,0					;loop counter

MainLoop: ; looping through text
	; for (i=0; i<= (text.length - pattern.length); i++)
	cmpeqpd xmm8,xmm9 ; compare hashes for pattern and text window SSE2
	xor edx,edx
	jz CharCheck				; jump CharCheck if r11=r12
	jnz Continue				; else
		CharCheck: ; check if all digits are matching
		; for (j=0; j<pattern.length; j++)
		movd rax,xmm0		; load address of the text
		add rax,rcx				; address + i
		add rax,rdx			; address + j
		mov r11b,[rax]		; load text[i+j]
		movd rax,xmm1		; load address of the pattern
		add rax,rdx			; address + j
		mov r12b,[rax]		; load pattern[j]
		cmp r11b,r12b		; compare r11 and r12
		jnz Continue			; jump if text[i+j] != pattern[j] 

		inc edx					; edx++
		cmp edx,r10d			; check the loop
		jnz CharCheck		; loop if i<pattern.length
		jz Found				; jump if j=pattern.length -> loop finished, all digits match 
	Found:
		movd r11,xmm10	; load address of results array
		mov [r11],ecx			; add position
		add r11,4				; move to the next position in the array
		movd xmm10,r11	; save the address
	Continue:
		cmp ecx,r9d			; compare i to text.length-pattern.length	
		jb NextWindow		; jump if below
		jae Round				; jump if above or equal
	NextWindow:
		; t = (d*(t-text[i]*h)+text[i+m])mod Q
		movd eax,xmm7		; load h
		movd r11,xmm0		; load text address
		add r11,rcx			; shift by i (ecx)
		mov r12b,[r11]		; load text [i]
		imul eax,r12d			; text[i]*h
		movd r12,xmm9		; load t
		sub r12,rax			; t-text[i]*h
		movd rax,xmm2		; load d
		imul r12,rax			; d*(t-text[i]*h)
		add r11,r10			; address i + M
		mov al,[r11]			; load text[i+M]
		add r12,rax			; d*(t-text[i]*h)+text[i+M]
		mov rax,r12			; result -> eax
		movd r12, xmm3	; load modulo (Q)
		cdq						; convert double to quad
		idiv r12d				; (d*(t-text[i]*h)+text[i+M]) mod Q
		mov rax,rdx			; moving remainder to eax
		add edx,r12d			; adjust if remainder is a negative number
		cmovc eax,edx		; move if carry	
		movd xmm9,rax		; eax -> xmm9 - new window
		
Round:
	inc ecx						; Main loop increment
	cmp ecx,r9d				; comparison to text.Length - pattern.Length
	jbe MainLoop				; jump if not 0 to main loop
	ret								; return


RKAlgorithm endp
end


