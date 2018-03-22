	AREA	AsmTemplate, CODE, READONLY
	IMPORT	main

; sample program makes the 4 LEDs P1.16, P1.17, P1.18, P1.19 go on and off in sequence
; (c) Mike Brady, 2011.

	EXPORT	start
start

IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C

	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
; r1 points to the SET register
; r2 points to the CLEAR register

	
	LDR R6, =0x00100000  ;p19
	LDR R7, =0x00020000  ;p16
	MOV R3, R6
while
	CMP R3, R7
	BGT reduce
	STR R3, [R2]
	
	LDR R4, =10000000
dloop subs R4, R4, #1
	BNE dloop
	
	STR R3, [R1]
	LSL R3, R3, #1
	CMP R3, R6
	BLE while
reduce
	STR R3, [R2]
	
	LDR R4, =10000000
dloop2 subs R4, R4, #1
	BNE dloop2
	
	STR R3, [R1]
	LSR R3, R3, #1
	CMP R3, R7
	BGT while
	MOV R3, R7
	B while
	
stop	B	stop

	END